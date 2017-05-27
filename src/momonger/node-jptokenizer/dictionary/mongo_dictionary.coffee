Mongo = require '../mongo'
redis = require '../redis'
Cache = redis.Cache

class MongoDictionary extends Mongo
  constructor: (mongoConfig, cacheConfig) ->
    super mongoConfig
    @cache = new Cache cacheConfig

  nheads: ->
    @meta.nheads

  findBest: (word, done)->
    @cache.cacheFetch word, (done) =>
      @find
        w: word
      , (err, cursor)=>
        return done err if err
        cursor.sort
          s: -1
        .limit 1
        .toArray (err, arr)=>
          return done err if err
          done null, arr[0]
    , done

  findCandidates: (query, done)->
    @find query, (err, cursor)->
      return done err if err
      cursor.sort
        l: -1
        s: 1
      .toArray (err, arr)->
        done err, arr

  upsert: (doc, done)->
    @findAndModify
      w: doc.w
    ,
      {}
    ,
      $setOnInsert: doc
    ,
      upsert: true
      new: true
      w: 1
      j: 1
      writeConcern: 1
      maxTimeMS: 3600000
    , (err, doc)=>
      if err
        console.log err
      return done err if err
      @cache.cacheSet doc.value.w, doc.value, (err) ->
        done null, doc.value

module.exports = MongoDictionary
