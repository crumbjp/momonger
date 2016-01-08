'use strict'
_ = require 'underscore'
async = require 'async'
{Mongo, Config, JobControl, Job, MapJob, Mapper, Worker} = require 'momonger-core'

class Tf extends MapJob
  beforeFirstMap: (done)->
    @srcMongo.getmeta (err, @meta)=>
      done err

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
        {
          _id: value.id
          words: value.value
        }

  afterLastMap: (done)->
    @meta.tf = @options.dst
    @dstMongo.insert @meta, done

module.exports = Tf
