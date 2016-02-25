'use strict'

_ = require 'underscore'
async = require 'async'
Mongo = require 'momonger/mongo'
{JobControl, Job, MapJob, Mapper} = require 'momonger/core'

class Tokenize extends MapJob
  constructor: (@jobcontrol, @jobid, @config, @options)->
    super @jobcontrol, @jobid, @config, @options
    if @options.append
      @options.appendDst = true
      @options.query.a = @options.append

  mapper: ->
    class TokenizeMapper extends Mapper
      beforeRun: (done) =>
        @JPTokenizer = require 'momonger/node-jptokenizer'
        done null

      map: (doc, done)=>
        @emit '.meta', 1 unless @options.append?

        jptokenizer = new @JPTokenizer @options.dictionary
        jptokenizer.modifier = (result, candidate, done)->
          return done null, null if '不明' in candidate.t
          return done null, null if '記号' in candidate.t
          done null, result

        jptokenizer.init (err) =>
          return done err if err
          jptokenizer.parse_doc doc[@options.field], (err, tokens)=>
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

            async.series [
              (done) =>
                return done null unless @options.append?
                @dstMongo.remove {d: doc._id}, done
              (done) => @dstMongo.bulkInsert results, done
            ], done


      reduce: (id, array, done)=>
        ret = 0
        for elem in array
          ret += elem
        done null, ret

      lastFormat: (value)=>
        {
          _id: '.meta'
          num: value.value
        }

  afterRun: (done)->
    JPTokenizer = require 'momonger/node-jptokenizer'
    jptokenizer = new JPTokenizer @options.dictionary
    meta =
      docs: @options.src
      token: @options.dst
      field: @options.field
      dictionary: @options.dictionary
    async.parallel [
      (done) => @dstMongo.createIndex {d: 1, i: 1}, done
      (done) => @dstMongo.createIndex {a: 1}, done
      (done) => @dstMongo.update {_id: '.meta'}, {$set: meta}, {upsert: false}, done
    ], (err) ->
      done err, meta

module.exports = Tokenize
