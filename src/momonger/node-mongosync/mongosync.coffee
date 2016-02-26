'use strict'
async = require 'async'
_ = require 'underscore'
Mongo = require './mongo'
Logger = require './logger'

class Mongosync
  constructor: (@config) ->
    @logger = new Logger @config.options.loglv

    @checkConfig()

    @oplogConfig = _.extend {}, @config.src, {
      database: 'local'
      collection: 'oplog.rs'
    }
    @lastConfig = _.extend {
      database: 'mongosync'
      collection: 'last'
    }, @config.dst

  checkConfig: ->
    # Validate
    error = false
    unless @config.name
      error = true
      @logger.error 'Config error: `name` is required'
    unless @config.src.type == 'replset'
      error = true
      @logger.error 'Config error: `src.type` must be `replset`'
    throw Error 'Config error' if error

    @config.options.targetDB ||= {'*': true}
    @config.options.syncCommand ||= {}
    @config.options.syncIndex ||= {}
    @config.options.bulkIntervalMS ||= 1000
    @config.options.bulkLimit ||= 5000

  init: (done) ->
    @opByNs = {}
    @oplogMongo = new Mongo @oplogConfig
    @lastMongo = new Mongo @lastConfig
    @replicateCallbacks = []
    @replicating = false
    @repairMode = false # TODO:
    @pendedLogs = []
    async.during (done) =>
      setTimeout =>
        done null, true
      , @config.options.bulkIntervalMS
    , (done) =>
      @replication done
    , (err) =>
      return
    done null

  getTailTimestamp: (done) ->
    @oplogMongo.findOne {}, {sort: {$natural:-1}}, (err, last) =>
      return done err if err
      @lastTimestamp = last.ts
      done null, @lastTimestamp

  getLastTimestamp: (done) ->
    if @config.options.force_tail
      return @getTailTimestamp done
    @logger.verbose 'Get lastTS: ', {_id: @config.name}
    @lastMongo.findOne {_id: @config.name}, (err, last) =>
      return done err if err
      return @getTailTimestamp done unless last
      @lastTimestamp = last.ts
      done null, @lastTimestamp

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

  opQuery: (ts, done) ->
    query =
      ts:
        $gt: ts
    @logger.info 'OpLog query: ', query
    @oplogMongo.find query,
      sort:
        $natural: 1
      tailable: true
      awaitdata: true
      timeout: false
      batchSize: (@config.options.bulkLimit * 2)
    , (err, cursor) =>
      done err, cursor

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

  getOp: (ns, done) ->
    return done null, @opByNs[ns] if @opByNs[ns]
    mongo = Mongo.getByNS @config.dst, ns
    mongo._col (err, col) =>
      return done err if err
      op = {
        i: 0
        u: 0
        d: 0
        m: 0
        U: 0
      }
      if @repairMode
        op.mongo = mongo
      else
        op.bulk = col.initializeOrderedBulkOp()
        @opByNs[ns] = op

      done null, op

  applyOplog: (oplog, done) =>
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
    @getOp ns, (err, op) =>
      return done err if err
      bulk = op.bulk
      mongo = op.mongo
      if oplog.fromMigrate
        # Skip sync
        op.m++
        return done null
      else if  oplog.op == 'i'
        op.i++
        if bulk
          #  There is a possibility of the duplicate key error.
          #  However, cannot do bellows
          #    bulk.find(_id: oplog.o._id).upsert().updateOne(oplog.o)
          #  due to considering sharded cluster... (must contain shard-key in `find`)
          bulk.insert oplog.o
          return done null, oplog
        else
          return mongo.insert oplog.o, (err) =>
            return done null if err and err.code = 11000 # Squash duplicate key error
            done err
      else if  oplog.op == 'u'
        op.u++
        if oplog.b
          if bulk
            bulk.find(oplog.o2).upsert().updateOne(oplog.o)
            return done null, oplog
          else
            return mongo.update oplog.o2, oplog.o, {upsert: true}, (err) => done err
        else
          if bulk
            bulk.find(oplog.o2).updateOne(oplog.o)
            return done null, oplog
          else
            return mongo.update oplog.o2, oplog.o, {}, (err) => done err
      else if  oplog.op == 'd'
        op.d++
        if bulk
          bulk.find(oplog.o).removeOne()
          return done null, oplog
        else
          return mongo.removeOne oplog.o, (err) => done err
      else
        op.U++
        @logger.error 'unknown op', oplog
        return done null
      throw Error 'Bug... applyOplog'

  runCommand: (ns, oplog, done) ->
    mongo = Mongo.getByNS @config.dst, ns
    mongo.init (err, db) =>
      return done err if err
      @logger.info 'command', oplog.o
      return done null if @config.options.dryrun
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
    @logger.trace "replication(): replicating: #{@replicating}, numCallbacks: #{@replicateCallbacks.length}, opByNs: #{_.isEmpty(@opByNs)}, logs: #{@pendedLogs.length}"
    if @replicating
      @replicateCallbacks.push done
      return
    # _.isEmpty @opByNs don't work correctly.
    # Beause, @opByNs is created but empty when all operation is fromMigrate.
    return done null unless @pendedLogs.length
    last = @pendedLogs[@pendedLogs.length-1].ts
    @replicating = true
    now = Math.floor(Date.now() / 1000)
    @logger.info "replication: (#{last.high_},#{last.low_}): delay: #{now - last.high_} op: #{@pendedLogs.length}, repair: #{@repairMode}"
    # Flip buffers
    @replicateCallbacks.push done
    callbacks = @replicateCallbacks
    @replicateCallbacks = []
    opByNs = @opByNs
    @opByNs = {}
    pendedLogs = @pendedLogs
    @pendedLogs = []

    # Reflect
    async.each _.keys(opByNs), (ns, done) =>
      op = opByNs[ns]
      @logger.verbose "#{ns}: i:#{op.i}, u:#{op.u}, d:#{op.d}, U: #{op.U}"
      return done null if @config.options.dryrun
      op.bulk.execute done
    , (err) =>
      finish = =>
        @saveLastTimestamp last, (err) =>
          async.each callbacks, (callback, done) =>
            callback err
            done null
          , =>
            @replicating = false
            @repairMode = false
            if _.isEmpty @opByNs
              setTimeout =>
                @replication =>
              , 0

      if err
        @logger.error '@replication error', err
        if !@repairMode and err.code == 11000 # E11000 duplicate key error
          @repairMode = true
          @logger.info 'Try to repair: logs:', pendedLogs.length
          async.eachSeries pendedLogs, (oplog, done) =>
            @applyOplog oplog, done
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
    @opQuery @lastTimestamp, (err, cursor) =>
      @stream = cursor.stream()
      @stream.on 'data', (oplog) =>
        @stream.pause()
        @applyOplog oplog, (err, pendedLog) =>
          @pendedLogs.push pendedLog if pendedLog
          if @pendedLogs.length >= @config.options.bulkLimit
            @stream.resume() unless @replicating
            @replication =>
              @stream.resume()
          else
            @stream.resume()
      @stream.on 'end', (err) =>
        @logger.info 'Cursor closed', err
        done err

  start: (done) ->
    @logger.verbose 'start', @config
    @init (err) =>
      async.during (done) =>
        done null, true
      , (done) =>
        @getLastTimestamp (err) =>
          return done err if err
          @sync done
      , (err) =>
        @logger.error 'error', err

module.exports = Mongosync
