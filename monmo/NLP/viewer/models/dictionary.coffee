'use strict'

_ = require 'underscore'
Base = require 'models/base'
mongodb = require 'mongodb'

class Dictionary extends Base
  find: (search, done)->
    @col().find(
      w: RegExp "^#{search.split(',')[0]}"
    ).toArray (err, words)=>
      done err, words

  put: (word, t, done)->
    rec =
      w: word
      l: word.length
      s: 300
      c: 3000
      t: ['名詞', '一般', 'PHRASE']
      f: {}
      h: word[0..(@meta.nheads-1)]
    @col().update
      w: word
    ,
      rec
    ,
      upsert: true
    , (err)->
      done err

  update: (id, update, done)->
    @col().update {_id: mongodb.ObjectId(id)}, update, done

  get: (dic_ids, done)->
    ids = []
    for id in dic_ids
      ids.push mongodb.ObjectId(id)
    @col().find(
      _id:
        $in: ids
    ).toArray (err, dics)=>
      console.log "dictionary.get #{dics.length}"
      done err, dics

module.exports = Dictionary
