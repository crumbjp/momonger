async = require 'async'
mongodb = require 'mongodb'

dbByKey = {}
class Mongo
  @ObjectId: mongodb.ObjectId

  @term: (key)->
    db = dbByKey[key]
    dbByKey[key] = null
    db.close() if db

  @connect: (key, config)->
    if dbByKey[key]
      db = dbByKey[key]
      return
    if config.authdbname
      db = new mongodb.Db config.authdbname, mongodb.Server(config.host, config.port), safe: true
      db.open (err)->
        throw Error err if err
        db.authenticate config.user, config.password, (err)=>
          throw Error err if err
        db = db.db config.database
        db.opened = true
    else
      db = new mongodb.Db config.database, mongodb.Server(config.host, config.port), safe: true
      db.open (err)->
        throw Error err if err
        db.opened = true
    dbByKey[key] = db
    db.on 'close', ->
      unless dbByKey[key] == null
        dbByKey[key] = undefined
        Mongo.connect key, config

  @getByNS = (config, ns) ->
    splitted = ns.split '.'
    dbName = splitted.shift()
    collectionName = splitted.join '.'

    return new Mongo {
      host: config.host
      port: config.port
      database: dbName
      collection: collectionName
      authdbname: config.authdbname
      user: config.user
      password: config.password
    }

  _db: ->
    dbByKey[@key]

  _col: (done)->
    @init (err, db)=>
      done err, db.collection @config.collection

  ns: ->
    "#{@config.database}.#{@config.collection}"

  constructor: (@config)->
    @key = JSON.stringify {
      host: @config.host
      port: @config.port
      database: @config.database
      authdbname: @config.authdbname
      user: @config.user
      password: @config.password
    }
    Mongo.connect @key, @config

  getmeta: (done)->
    @findOne
      _id : '.meta'
    , (err, meta) =>
      @meta = meta
      done err, @meta

  init: (done)->
    return done null, @_db() if @_db().opened
    # TODO: async.doUntil
    @interval ||= setInterval ()=>
      if @_db().opened
        clearInterval @interval
        done null, @_db()
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

  @inBatch: (cursor, batchSize, formatter, callback, done) ->
    # Silly event design... 'end' events will occur regardless of calling stream.pause()
    # So cannot use 'end'
    cursor.count (err, all) ->
      return done err if err
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
