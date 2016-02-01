async = require 'async'
Config = require 'momonger/config'
Mongo = require 'momonger/mongo'
{JobControl} = require 'momonger/core'
{Tfidf} = require 'momonger/vectorize'

{momonger, dictionary} = Config.load 'config/test.conf'

describe 'TFIDF job', ->
  before ->
    @options =
      runLocal: true
      src: "#{momonger.database}.sampledoc.tf"
      idf: "#{momonger.database}.sampledoc.idf"
      dst: "#{momonger.database}.sampledoc.tfidf"
      normalize: true

  it 'tfidf map', (done)->
    this.timeout 3000000
    jobControl = new JobControl momonger
    jobid = null
    async.series [
      (done) => jobControl.init done
      (done) => jobControl.put Tfidf, @options, (err, result)->
        jobid = result
        done err
      (done) => jobControl.wait jobid, done
    ], (err, results)=>
      expect(err).to.equal null
      dst = Mongo.getByNS momonger, @options.dst
      async.series [
        (done) ->
          dst.count {}
          , (err, count) ->
            expect(err).to.equal null
            expect(count).to.equal 74
            done err
        (done) ->
          dst.findOne
            _id:
              $ne: '.meta'
          , (err, doc) ->
            expect(err).to.equal null
            for k, v of doc.v
              expect(v >= 0).to.equal true
              expect(v <= 1).to.equal true
            done err
      ], done
