mongodb = require 'mongodb'

dbByKey = {}
class Mongo
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

  db: ->
    dbByKey[@key]

  col: ->
    @db().collection @config.collection

  constructor: (@config)->
    @key = JSON.stringify @config
    Mongo.connect @key, @config

  initialized: (err, done)->
    done err

  getmeta: (done)->
    return done null, @meta if @meta
    @col().findOne
      _id : '.meta'
    , (err, meta) =>
      @meta = meta
      @initialized err, done

  init: (done)->
    return @getmeta done if @db().opened
    interval = setInterval ()=>
      if @db().opened
        clearInterval interval
        @getmeta done
    , 100

  term: (done)->
    Mongo.term @key
    done null

module.exports = Mongo
