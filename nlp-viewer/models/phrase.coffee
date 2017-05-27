'use strict'

_ = require 'underscore'
Base = require 'models/base'
mongodb = require 'mongodb'
Dictionary = require './dictionary'

class Phrase extends Base
  initialized: (done)->
    @getmeta (err, @meta)=>
      @dictionary ||= new Dictionary @meta.dictionary
      @dictionary.initialized done

  put: (word, done)->
    @dictionary.put word, 'PHRASE', (err)=>
      @del word, (err)->
        done err

  del: (word, done)->
    @remove
      _id: word
    , done

  get: (done)->
    @find
      _id:
        $ne: '.meta'
      tcv:
        $exists: true
    , (err, cursor)->
      return done err if err
      cursor.sort({tcv: -1}).limit(1000).toArray (err, phrases)=>
        console.log "phrase.get #{phrases.length}"
        done err, phrases

  search: (search, done)->
    @find
      $or: [
        _id:
          $regex: "^#{search}"
      ,
        ws: search
      ]
      tcv:
        $exists: true
    , (err, cursor)->
      return done err if err
      cursor.sort({tcv: -1}).limit(1000).toArray (err, phrases)=>
        console.log "phrase.search #{phrases.length}"
        done err, phrases

module.exports = Phrase
