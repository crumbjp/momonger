'use strict'

_ = require 'underscore'
Config = require 'momonger/config'
Mongo = require 'momonger/mongo'
mongodb = require 'mongodb'

dictionaryPath = 'config/dictionary.conf'
dictionary = Config.load dictionaryPath
class Dictionary extends Mongo
  constructor: ->
    super(dictionary.mongo)

  initialized: (done)->
    @getmeta (err, @meta)=>
      done err

  search: (search, options, done)->
    query =
      '$or': [
        w:
          $regex: search
      ,
        sy:
          $regex: search
      ]
    @findAsArray _.extend(query, options), done

  put: (word, t, done)->
    rec =
      $setOnInsert:
        w: word
        l: word.length
        s: 300
        c: 3000
        t: _.chain(['名詞', '一般', 'ORG'].concat(t)).compact().value()
        f: {}
        h: word[0..(@meta.nheads-1)]
    @update
      w: word
    ,
      rec
    ,
      upsert: true
    , done

  updateById: (id, update, done)->
    @update {_id: mongodb.ObjectId(id)}, update, done

  get: (dic_ids, done)->
    ids = []
    for id in dic_ids
      id = mongodb.ObjectId(id) if _.isString id
      ids.push id
    @findAsArray
      _id:
        $in: ids
    , (err, dics)=>
      console.log "dictionary.get #{dics.length}"
      done err, dics

module.exports = Dictionary
