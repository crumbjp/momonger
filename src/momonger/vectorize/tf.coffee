'use strict'
_ = require 'underscore'
async = require 'async'
{JobControl, Job, MapJob, Mapper} = require 'momonger/job'

class Tf extends MapJob
  constructor: (@jobcontrol, @jobid, @config, @options)->
    super @jobcontrol, @jobid, @config, @options
    if @options.append
      @options.appendDst = true
      @options.query.a = @options.append

  beforeFirstMap: (done)->
    async.series [
      (done) => @srcMongo.getmeta (err, @meta) ->
        done err
      (done) => @dstMongo.createIndex {a: 1}, done
    ], done

  mapper: ->
    class TfMapper extends Mapper
      map: (doc, done)=>
        @emit doc.d, [{w: doc.c, c: 1}]
        done null

      reduce: (id, array, done)->
        wordCountByWord = {}
        for words in array
          for word in words
            wordCountByWord[word.w] ||=
              w: word.w
              c: 0

            wordCountByWord[word.w].c += word.c

        done null, _.values wordCountByWord

      lastFormat: (value)=>
        [
          _id: value.id
        ,
          words: value.value
          a: @options.append
        ]

  afterLastMap: (done)->
    return done null if @options.append?
    @meta.tf = @options.dst
    @dstMongo.insert @meta, done

  afterRun: (done) ->
    done null, @meta

module.exports = Tf
