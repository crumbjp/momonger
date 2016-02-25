async = require 'async'
mongodb = require 'mongodb'
_ = require 'underscore'
dbByKey = {}
class Mongo
  @ObjectId: mongodb.ObjectId

  @term: (key)->
    db = dbByKey[key]
    dbByKey[key] = null
    db.close() if db

  @topology: (config) ->
    if !config.type or config.type == 'server'
      throw Error 'Ignore host, port' unless config.host and config.port
      return mongodb.Server(config.host, config.port)
    throw Error "Ignore hosts" unless _.isArray config.hosts
    servers = []
    for host in config.hosts
      [host, port] = host.split ':'
      port = parseInt(port) or 27017
      servers.push mongodb.Server(host, port)
    if config.type == 'replset'
      return mongodb.ReplSet servers
    if config.type == 'mongos'
      return mongodb.Mongos servers
    throw Error "Unknown topology: #{JSON.stringify(config)}"

  @connect: (key, config)->
    if dbByKey[key]
      db = dbByKey[key]
      return
    if config.authdbname
      db = new mongodb.Db config.authdbname, @topology(config), safe: true
      db.open (err)->
        throw Error err if err
        db.authenticate config.user, config.password, (err)=>
          throw Error err if err
          db = db.db config.database
          db.opened = true
          dbByKey[key] = db
    else
      db = new mongodb.Db config.database, @topology(config), safe: true
      db.open (err)->
        throw Error err if err
        db.opened = true
    dbByKey[key] = db
    db.on 'close', ->
      unless dbByKey[key] == null
        # TODO: Unexpedted close.. how to treat ?
        dbByKey[key] = undefined
        Mongo.connect key, config

  @getByNS = (config, ns) ->
    splitted = ns.split '.'
    dbName = splitted.shift()
    collectionName = splitted.join '.'

    return new Mongo _.extend {}, config, {
      database: dbName
      collection: collectionName
    }

  _db: ->
    dbByKey[@key]

  _col: (done)->
    @init (err, db)=>
      done err, db.collection @config.collection

  ns: ->
    "#{@config.database}.#{@config.collection}"

  constructor: (@config)->
    @initCallbacks = []
    @key = "#{@config.type}#{@config.host}#{@config.port}#{@config.hosts}#{@config.authdbname}#{@config.user}#{@config.database}"
    Mongo.connect @key, @config

  getmeta: (done)->
    @findOne
      _id : '.meta'
    , (err, meta) =>
      @meta = meta
      done err, @meta

  initialized: (done)->
    done null

  callInitialized: (done)->
    return done null if @called
    @called = true
    @initialized done

  init: (done)->
    if @_db().opened
      @callInitialized =>
        done null, @_db()
      return
    @initCallbacks.push done
    # TODO: async.doUntil
    @interval ||= setInterval ()=>
      if @_db().opened
        clearInterval @interval
        @callInitialized =>
          for callback in @initCallbacks
            callback null, @_db()
          @initCallbacks = []
    , 100

  bulkInsert: (docs, done) ->
    @_col (err, col) =>
      bulk = null
      async.eachSeries docs, (doc, done)=>
        bulk = col.initializeUnorderedBulkOp() unless bulk
        bulk.insert(doc)
        # TODO: if bulk.length < 1000
        if bulk.length < 3
          return done null
        bulk.execute (err, result) ->
          bulk = null
          done err
      , (err)->
        return done err unless bulk
        bulk.execute done

  bulkUpdate: (updates, done) ->
    @_col (err, col)=>
      bulk = null
      async.eachSeries updates, (update, done)=>
        bulk = col.initializeUnorderedBulkOp() unless bulk
        bulkOp = bulk.find update[0]
        bulkOp = bulkOp.upsert() unless update[2]
        bulkOp.updateOne(update[1])
        # TODO: if bulk.length < 1000
        if bulk.length < 3
          return done null
        bulk.execute (err, result) ->
          bulk = null
          done err
      , (err)->
        return done err unless bulk
        bulk.execute done

  createIndex: (args...)->
    @_col (err, col) ->
      col.createIndex args...
  count: (args...)->
    @_col (err, col) ->
      col.count args...
  find: (args...)->
    @_col (err, col) ->
      col.find args...
  findAsArray: (args...)->
    callback = args.pop()
    args.push (err, cursor)->
      return done err if err
      cursor.toArray callback
    @find.apply @, args
  findOne: (args...)->
    @_col (err, col) ->
      col.findOne args...
  findAndModify: (args...)->
    @_col (err, col) ->
      col.findAndModify args...
  distinct: (args...)->
    @_col (err, col) ->
      col.distinct args...
  insert: (args...)->
    @_col (err, col) ->
      col.insert args...
  update: (args...)->
    @_col (err, col) ->
      col.update args...
  drop: (args...)->
    @_col (err, col) ->
      col.drop args...
  remove: (args...)->
    @_col (err, col) ->
      col.remove args...
  removeOne: (args...)->
    @_col (err, col) ->
      col.removeOne args...
  aggregate: (args...)->
    @_col (err, col) ->
      col.aggregate args...
  rename: (args...)->
    @_col (err, col) ->
      col.rename args...

  @inBatch: (cursor, batchSize, formatter, callback, done) ->
    # Silly event design... 'end' events will occur regardless of calling stream.pause()
    # So cannot use 'end'
    cursor.count (err, all) ->
      return done err if err
      return done null unless all
      count = 0
      stream = cursor.stream()
      elements = []
      stream.on 'data', (data)->
        elements.push formatter data
        count++
        if elements.length >= batchSize or all == count
          stream.pause()
          callback elements, (err)->
            elements = []
            stream.resume()
            done null if all == count

  term: (done)->
    Mongo.term @key
    done null

module.exports = Mongo
