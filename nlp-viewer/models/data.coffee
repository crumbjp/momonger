'use strict'

_ = require 'underscore'
async = require 'async'
mongodb = require 'mongodb'
Base = require 'models/base'
Dictionary = require './dictionary'

class Data extends Base
  initialized: (done)->
    @getmeta (err, @meta)=>
      console.log @meta
      @dictionary = new Dictionary @meta.dictionary
      @token = new Base @meta.token
      @doc = new Base @meta.docs
      done err

  headLoc: (loc)->
    ls = []
    for id, score of loc
      ls.push {id, score}
    ls.sort (a, b) -> b.score - a.score

  formDocument: (document)->
    ls = @headLoc document.loc
    {
      _id: document._id
      c: document.c
      loc: ls[0..4]
      cs: document.cs[0..4]
      doc: document.doc[0..255]
    }

  search: (search, done)->
    search_words = search.split /[\s　]/
    console.log search_words
    async.map search_words
    , (search_word, done)=>
      @dictionary.find search_word, (err, words)=>
        ids = []
        for word in words
          ids.push word._id
        @token.col().find(
          c:
            $in: ids
        ,
          d: 1
        ).toArray (err, tokens)=>
          ds = {}
          for token in tokens
            ds[token.d] = token.d
          done null, ds
    , (err, results)=>
      current = results.shift()
      while results.length
        next = results.shift()
        keys = _.intersection _.keys(current), _.keys(next)
        current = {}
        for key in keys
          current[key] = next[key]
      ids = _.values current

      @getDocs ids, (err, docs)=>
        console.log "getDocs docs #{docs.length}"
        ret = []
        for doc in docs
          ret.push {
            _id: doc._id
            doc: doc[@meta.doc_field][0..255]
          }
        done err, ret

  getTokens: (id, done)->
    @token.col().find(
      d: id
    ,
      d: 1
      i: 1
      w: 1
      c: 1
    ).sort(
      d: 1
      i: 1
    ).toArray done

  get: (id, done)->
    @col().findOne
      _id: id
    , (err, document)=>
      document.cs = document.cs[0..9]
      document.loc = @headLoc document.loc
      @getDocs [id], (err, docs)=>
        document.doc = docs[0]
        @getTokens id, (err, tokens)=>
          document.tokens = tokens
          done null, document

  getByCluster: (id, done)->
    @findAsArray
      c : id
    , (err, docs)=>
      console.log "getByCluster docs #{docs.length}"
      docsById = _.indexBy docs, '_id'
      @getDocs (doc._id for doc in _.values(docsById)), (err, docs)=>
        console.log "getDocs docs #{docs.length}"
        for doc in docs
          docsById[doc._id].doc = doc[@meta.doc_field]
        ret = []
        for id, doc of docsById
          ret.push @formDocument(doc)
        done err, ret

  getDocs: (ids, done)->
    console.log "getDocs #{ids.length}"
    fields = {}
    fields[@meta.doc_field] = 1
    @doc.col().find(
      _id :
        $in: ids
    ,
      fields
    ).toArray done




module.exports = Data
