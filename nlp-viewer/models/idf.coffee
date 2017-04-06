'use strict'

_ = require 'underscore'
async = require 'async'
mongodb = require 'mongodb'
Base = require 'models/base'
Dictionary = require './dictionary'

class Idf extends Base
  initialized: (done)->
    console.log '****** initialized'
    @getmeta (err, @meta)=>
      @dictionary ||= new Dictionary @meta.dictionary
      done err

  list: (query, done)->
    query._id = {$ne: '.meta'}
    @find query, (err, cursor)=>
      return done err if err
      cursor.sort({i: -1}).limit(1000).toArray (err, idfs)=>
        ids = []
        for idf in idfs
          ids.push idf._id
        @dictionary.get ids, (err, dics)=>
          done err, idfs, _.indexBy(dics, '_id')

  search: (search, done)->
    @dictionary.search search, (err, dics)=>
      ids = []
      for dic in dics
        ids.push ''+dic._id
      @get ids, (err, idfs)=>
        done err, idfs, _.indexBy(dics, '_id')

  updateById: (id, update, done)->
    @update {_id: mongodb.ObjectId(id)}, update, done

  update_dictionary: (id, update, done)->
    @dictionary.updateById id, update, done

  get: (dic_ids, done)->
    ids = []
    for id in dic_ids
      id = mongodb.ObjectId(id) if _.isString id
      ids.push id
    @findAsArray
      _id:
        $in: ids
    , (err, idfs)=>
      console.log "idf.get #{idfs.length}"
      done err, idfs


module.exports = Idf
