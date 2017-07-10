'use strict'

_ = require 'underscore'
async = require 'async'
mongodb = require 'mongodb'
Base = require 'models/base'
Dictionary = require './dictionary'

class Data extends Base
  initialized: (done)->
    @getmeta (err, @meta)=>
      @dictionary = new Dictionary @meta.dictionary
      @token = new Base @meta.token
      @doc = new Base @meta.docs
      @tfidf = new Base @meta.tfidf
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
    async.map search_words
    , (search_word, done)=>
      @dictionary.findAsArray {w: search_word}, (err, words)=>
        ids = []
        for word in words
          ids.push word._id
        @token.findAsArray
          c:
            $in: ids
        ,
          d: 1
        , (err, tokens)=>
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
          data = ''
          for field in @meta.fields
            data += doc[field] + "\n"
          ret.push {
            _id: doc._id
            doc: data
          }
        done err, ret

  getTokens: (id, done)->
    @token.find
      d: id
    ,
      d: 1
      i: 1
      w: 1
      c: 1
    , (err, cursor) ->
      return done err if err
      cursor.sort({d: 1, i: 1}).toArray done

  get: (id, done)->
    @findOne
      _id: id
    , (err, document)=>
      document.cs = document.cs[0..9]
      @getDocs [id], (err, docs)=>
        document.doc = docs[0].doc
        document.loc = @headLoc docs[0].loc
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
          docsById[doc._id].loc = doc.loc
          docsById[doc._id].doc = ''
          for field in @meta.fields
            docsById[doc._id].doc += doc[field] + "\n"
        ret = []
        for id, doc of docsById
          ret.push @formDocument(doc)
        done err, ret

  getDocs: (ids, done)->
    console.log "getDocs #{ids.length}"

    @tfidf.findAsArray
      _id :
        $in: ids
    , (err, tfidfs) =>
      return done err if err
      tfidfById = {}
      for tfidf in tfidfs
        tfidfById[tfidf._id] =
          _id: tfidf._id
          loc: tfidf.v
      fields = {}
      for field in @meta.fields
        fields[field] = 1
      @doc.findAsArray
        _id :
          $in: ids
      , fields
      , (err, docs) =>
        return done err if err
        for doc in docs
          for field in @meta.fields
            tfidfById[doc._id][field] = doc[field]
        done err, _.values(tfidfById)

module.exports = Data
