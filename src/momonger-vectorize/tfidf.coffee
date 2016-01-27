'use strict'
_ = require 'underscore'
async = require 'async'
{Mongo, Config, JobControl, Job, MapJob, Mapper, Worker} = require 'momonger-core'
{normalVector} = require 'common'


class Tfidf extends MapJob
  constructor: (@jobcontrol, @jobid, @config, @options)->
    super @jobcontrol, @jobid, @config, @options
    if @options.append
      @options.appendDst = true
      @options.query.a = @options.append

  beforeFirstMap: (done)->
    @idfMongo = Mongo.getByNS @config, @options.idf
    @idfMongo.getmeta (err, @meta)=>
      done err

  mapper: ->
    class TfidfMapper extends Mapper
      beforeRun: (done)=>
        @results = []
        @idfById = {}
        @idfMongo = Mongo.getByNS @config, @options.idf
        @idfMongo.find {}, (err, cursor) =>
          return done err if err
          cursor.toArray (err, idfs) =>
            return done err if err
            @idfById = _.indexBy idfs, '_id'
            done null

      map: (doc, done)=>
        tfidf = {}
        for word in doc.words
          idf = @idfById[word.w]
          if idf and idf.value
            tfidf[word.w] = word.c * idf.value
        if @options.normalize
          tfidf = normalVector tfidf

        @results.push [
          _id: doc._id
        ,
          v: tfidf
          a: @options.append
        ]
        done null

      afterRun: (done)->
        @dstMongo.bulkUpdate @results, done

  afterLastMap: (done)->
    return done null if @options.append?
    @meta.tfidf = @options.dst
    @meta.normalize = @options.normalize
    async.parallel [
      (done) => @dstMongo.insert @meta, done
      (done) => @dstMongo.createIndex {a: 1}, done
    ], (err)=>
      done err, @meta

module.exports = Tfidf
