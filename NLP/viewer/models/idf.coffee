'use strict'

_ = require 'underscore'
async = require 'async'
mongodb = require 'mongodb'
Base = require 'models/base'
Dictionary = require './dictionary'

class Idf extends Base
  constructor: (ns)->
    super(ns)

  initialized: (err, done)->
    @dictionary = new Dictionary @meta.dic
    @dictionary.init done

  getDictinary: (idfs, done)->
    ids = []
    for idf in idfs
      ids.push idf._id
    @dictionary.get ids, (err, dics)=>
      done err, dics

  list: (query, done)->
    query._id = {$ne: '.meta'}
    @col().find(
      query
    ).sort({i: -1}).limit(1000).toArray (err, idfs)=>
      @getDictinary idfs, (err, dics)=>
        done err, idfs, _.indexBy(dics, '_id')

  find: (search, done)->
    @dictionary.find search, (err, dics)=>
      ids = []
      for dic in dics
        ids.push ''+dic._id
      @get ids, (err, idfs)=>
        done err, idfs, _.indexBy(dics, '_id')

  update: (id, update, done)->
    @col().update {_id: id}, update, done

  update_dictionary: (id, update, done)->
    @dictionary.update id, update, done

  get: (dic_ids, done)->
    @col().find(
      _id:
        $in: dic_ids
    ).toArray (err, idfs)=>
      console.log "idf.get #{idfs.length}"
      done err, idfs


module.exports = Idf
