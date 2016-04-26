'use strict'
async = require 'async'
_ = require 'underscore'
Mongo = require './mongo'
Logger = require './logger'
OplogReader = require './oplog_reader'

class Sync
  constructor: (@config) ->
    @logger = new Logger @config.options.loglv

    @oplogReader = new OplogReader @config

    @config.options.targetDB ||= {'*': true}
    @config.options.syncCommand ||= {}
    @config.options.syncIndex ||= {}

    @oplogConfig = _.extend {}, @config.src, {
      database: 'local'
      collection: 'oplog.rs'
    }
    @lastConfig = _.extend {
      database: 'mongosync'
      collection: 'last'
    }, @config.dst

  init: (done) ->
    @opByNs = {}
    @oplogReader.init()
    @lastMongo = new Mongo @lastConfig
    @replicateCallbacks = []
    @replicating = false
    done null

  getTailTS: (done) ->
    @oplogReader.getTailTS (err, last) =>
      return done err if err
      @lastTS = last.ts
      done null, @lastTS

  getLastTS: (done) ->
    if @config.options.force_tail
      return @getTailTS done
    @logger.verbose 'Get lastTS: ', {_id: @config.name}
    @lastMongo.findOne {_id: @config.name}, (err, last) =>
      return done err if err
      return @getTailTS done unless last
      @lastTS = last.ts
      done null, @lastTS

  saveLastTimestamp: (last, done) ->
    return done null if @config.options.dryrun
    @lastMongo.update
      _id: @config.name
    ,
      $set:
        ts: last
    ,
      upsert: true
    , done

  parseNS: (ns) ->
    ns_split  = ns.split('\.')
    {
      db  : ns_split.shift()
      col : ns_split.join('\.')
    }

  convertDB: (logNS) ->
    ns = @parseNS(logNS)
    if _.isString @config.options.targetDB[ns.db]
      ns.db = @config.options.targetDB[ns.db]
      return ns
    return ns if @config.options.targetDB['*']
    null

  getDstMongo: (ns) ->
    return @dstMongoByNs[ns] if @dstMongoByNs[ns]
    @dstMongoByNs[ns] = Mongo.getByNS @config.dst, ns
    @dstMongoByNs[ns]

  applyOplog: (oplog, repairMode, done) =>
    @logger.debug 'applyOplog', oplog
    convertedNS = @convertDB oplog.ns
    return done null unless convertedNS
    ns = "#{convertedNS.db}.#{convertedNS.col}"
    if oplog.op == 'n'
      @logger.info 'NP', oplog
      return done null
    if  oplog.op == 'i' and convertedNS.col == 'system.indexes'
      if @config.options.syncIndex.create
        @replication =>
          return @createIndex "#{convertedNS.db}.#{@parseNS(oplog.o.ns).col}", oplog, (err) => done err
      else
        @logger.info 'Skip createIndex', oplog.o
        return done null
      return
    if oplog.op == 'c'
      if oplog.o['deleteIndexes']
        unless @config.options.syncIndex.drop
          @logger.info 'Skip dropIndex', oplog.o
          return done null
        @logger.info 'dropIndex', oplog.o
      else
        o = {}
        for cmd,v of oplog.o
          if (if @config.options.syncCommand[cmd]? then @config.options.syncCommand[cmd] else @config.options.syncCommand['*'])
            o[cmd] = v
          else
            @logger.info "Skip command {#{cmd}: #{v}}"
        oplog.o = o
        return done null if _.isEmpty(oplog.o)
      @replication =>
        return @runCommand ns, oplog, (err) => done err
      return

    @opByNs[ns] ||= {
      i: 0
      u: 0
      d: 0
      m: 0
    }
    op = @opByNs[ns]
    # Skip migrate operation
    if oplog.fromMigrate
      op.m++
      return done null

    mongo = @getDstMongo ns
    mongo._col (err, col) =>
      return done err if err
      op.bulk ||= col.initializeOrderedBulkOp() unless repairMode
      # Insert
      if  oplog.op == 'i'
        op.i++
        if repairMode
          return mongo.insert oplog.o, (err) =>
            return done null if err and err.code = 11000 # Squash duplicate key error
            done err
        else
          #  There is a possibility of the duplicate key error.
          #  However, cannot do bellows
          #    bulk.find(_id: oplog.o._id).upsert().updateOne(oplog.o)
          #  due to considering sharded cluster... (must contain shard-key in `find`)
          op.bulk.insert oplog.o
          return done null, oplog
      # Update
      if  oplog.op == 'u'
        op.u++
        if oplog.b
          if repairMode
            return mongo.update oplog.o2, oplog.o, {upsert: true}, (err) => done err
          else
            op.bulk.find(oplog.o2).upsert().updateOne(oplog.o)
            return done null, oplog
        else
          if repairMode
            return mongo.update oplog.o2, oplog.o, {}, (err) => done err
          else
            op.bulk.find(oplog.o2).updateOne(oplog.o)
            return done null, oplog
      # Delete
      if  oplog.op == 'd'
        op.d++
        if repairMode
          return mongo.removeOne oplog.o, (err) => done err
        else
          op.bulk.find(oplog.o).removeOne()
          return done null, oplog

      @logger.error 'unknown op', oplog
      throw Error 'unknown op'

  runCommand: (ns, oplog, done) ->
    @logger.info 'command', oplog.o
    return done null if @config.options.dryrun
    mongo = Mongo.getByNS @config.dst, ns
    mongo.init (err, db) =>
      return done err if err
      db.command oplog.o, (err) =>
        return done err if err
        @saveLastTimestamp oplog.ts, done

  createIndex: (ns, oplog, done) ->
    key = oplog.o.key
    delete oplog.o.key
    delete oplog.o.ns
    @logger.info 'createIndex', ns, key, oplog.o
    return done null if @config.options.dryrun
    mongo = Mongo.getByNS @config.dst, ns
    mongo.createIndex key, oplog.o, (err) =>
      return done err if err
      @saveLastTimestamp oplog.ts, done

  replication: (done) ->
    @logger.trace "replication(): replicating: #{@replicating}, numCallbacks: #{@replicateCallbacks.length}, opByNs: #{_.isEmpty(@opByNs)}, logs: #{@oplogReader.length()}"
    if @replicating
      @replicateCallbacks.push done
      return
    return done null unless @oplogReader.length()
    @replicating = true
    now = Math.floor(Date.now() / 1000)
    # Flip buffers
    @replicateCallbacks.push done
    callbacks = @replicateCallbacks
    @replicateCallbacks = []
    opByNs = @opByNs
    @opByNs = {}
    oplogs = @oplogReader.clearLogs()
    last = oplogs[oplogs.length-1].ts
    @logger.info "replication: (#{last.high_},#{last.low_}): delay: #{now - last.high_} op: #{oplogs.length}"

    # Reflect
    async.each _.keys(opByNs), (ns, done) =>
      op = opByNs[ns]
      @logger.verbose "#{ns}: i:#{op.i}, u:#{op.u}, d:#{op.d}, m: #{op.m}"
      return done null if @config.options.dryrun
      return done null unless op.bulk
      op.bulk.execute done
    , (err) =>
      finish = =>
        @saveLastTimestamp last, (err) =>
          async.each callbacks, (callback, done) =>
            callback err
            done null
          , =>
            @replicating = false
            if _.isEmpty @opByNs
              setTimeout =>
                @replication =>
              , 0

      if err
        @logger.error '@replication error', err
        if err.code == 11000 # E11000 duplicate key error
          @logger.info 'Try to repair: logs:', oplogs.length
          async.eachSeries oplogs, (oplog, done) =>
            @applyOplog oplog, true, done
          , (err) =>
            if err
              @logger.error 'Repair error', err
              throw Error '@replication error'
            finish()
          return
        else
          # Should die immediately !!
          throw Error '@replication error'
      finish()

  sync: (done) ->
    @dstMongoByNs = {}
    eachCallback = (oplog, done)=>
      @applyOplog oplog, false, (err, filteredLog) =>
        @oplogReader.resume() unless @replicating
        done err, filteredLog

    bulkCallback = (oplogs, done)=>
      @replication done

    @oplogReader.start @lastTS, eachCallback, bulkCallback, done

  start: (done) ->
    @logger.verbose 'start', @config
    @init (err) =>
      async.during (done) =>
        done null, true
      , (done) =>
        @getLastTS (err) =>
          return done err if err
          @sync done
      , (err) =>
        @logger.error 'error', err

module.exports = Sync
