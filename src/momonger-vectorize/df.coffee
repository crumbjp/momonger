'use strict'
_ = require 'underscore'
async = require 'async'
{Mongo, Config, JobControl, Job, MapJob, Mapper, Worker} = require 'momonger-core'

class Df extends MapJob
  beforeFirstMap: (done)->
    @srcMongo.getmeta (err, @meta)=>
      done err

  mapper: ->
    class DfMapper extends Mapper
      map: (doc, done)=>
        for word in doc.words
          @emit word.w, 1
        done null

      reduce: (id, counts, done)->
        count = 0
        for c in counts
          count += c
        done null, count

      lastFormat: (value)=>
        {
          _id: value.id
          value: value.value
          a: @options.append
        }

  afterLastMap: (done)->
    @meta.df = @options.dst
    @dstMongo.insert @meta, done

module.exports = Df
