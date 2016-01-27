'use strict'

_ = require 'underscore'
Base = require 'models/base'
mongodb = require 'mongodb'
Dictionary = require './dictionary'

class Phrase extends Base
  initialized: (err, done)->
    @dictionary = new Dictionary @meta.dic
    @dictionary.init (err)=>
      done err

  put: (word, done)->
    @dictionary.put word, 'PHRASE', (err)=>
      @del word, (err)->
        done err

  del: (word, done)->
    @col().remove
      _id: word
    , (err)->
      done err

  get: (done)->
    @col().find(
      _id:
        $ne: '.meta'
    ).sort({cv: -1}).limit(1000).toArray (err, phrases)=>
      console.log "phrase.get #{phrases.length}"
      done err, phrases

module.exports = Phrase
