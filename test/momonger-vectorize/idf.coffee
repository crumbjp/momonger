async = require 'async'
Config = require 'momonger/config'
Mongo = require 'momonger/mongo'
{JobControl} = require 'momonger/core'
{Idf} = require 'momonger/vectorize'

{momonger, dictionary} = Config.load 'config/test.conf'

describe 'IDF job', ->
  before ->
    @options =
      runLocal: true
      src: "#{momonger.database}.sampledoc.df"
      dst: "#{momonger.database}.sampledoc.idf"

  it 'idf map', (done)->
    this.timeout 3000000
    jobControl = new JobControl momonger
    jobid = null
    async.series [
      (done) => jobControl.init done
      (done) => jobControl.put Idf, @options, (err, result)->
        jobid = result
        done err
      (done) => jobControl.wait jobid, done
    ], (err, results)=>
      expect(err).to.equal null
      dst = Mongo.getByNS momonger, @options.dst
      async.series [
        (done) ->
          dst.count
            value:
              $gte:
                3.597
          , (err, count) ->
            expect(err).to.equal null
            expect(count).to.equal 2470
            done err
        (done) ->
          dst.count
            value: 0
          , (err, count) ->
            expect(err).to.equal null
            expect(count).to.equal 16
            done err
      ], done
