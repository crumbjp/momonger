'use strict'

_ = require 'underscore'
async = require 'async'
{Mongo, Config, JobControl, Job, MapJob, Mapper, Worker} = require 'momonger-core'

class Tokenize extends MapJob
  mapper: ->
    class TokenizeMapper extends Mapper
      beforeRun: (done) =>
        @JPTokenizer = require 'node-jptokenizer'
        done null

      map: (doc, done)=>
        jptokenizer = new @JPTokenizer @options.dictionary
        jptokenizer.modifier = (result, candidate, done)->
          return done null, null if '不明' in candidate.t
          return done null, null if '記号' in candidate.t
          done null, result

        jptokenizer.init (err) =>
          return done err if err
          jptokenizer.parse_doc doc.body, (err, tokens)=>
            return done err if err
            results = []
            for token in tokens
              results.push {
                d: doc._id
                i: token.i
                p: token.p
                w: token.w
                c: token.c
                a: @options.append
              }
            @dstMongo.bulkInsert results, done

  afterLastMap: (done)->
    JPTokenizer = require 'node-jptokenizer'
    jptokenizer = new JPTokenizer @options.dictionary
    meta =
      src: @options.src
      token: @options.dst
      dictionary: @options.dictionary
    async.parallel [
      (done) => @dstMongo.update {_id: '.meta'}, meta, {upsert: true}, done
      (done) => @dstMongo.createIndex {d: 1, i: 1}, done
    ], (err) ->
      done err, meta

module.exports = Tokenize
