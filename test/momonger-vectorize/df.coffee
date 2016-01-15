async = require 'async'
{Mongo, Config, JobControl, Job, MapJob, Mapper, Worker} = require 'momonger-core'
{Df} = require 'momonger-vectorize'

{momonger, dictionary} = Config.load 'config/test.conf'

describe 'DF job', ->
  before ->
    @options =
      runLocal: true
      src: "#{momonger.database}.sampledoc.tf"
      dst: "#{momonger.database}.sampledoc.df"

  it 'df map', (done)->
    this.timeout 3000000
    jobControl = new JobControl momonger
    jobid = null
    async.series [
      (done) => jobControl.init done
      (done) => jobControl.put Df, @options, (err, result)->
        jobid = result
        done err
      (done) => jobControl.wait jobid, done
    ], (err, results)=>
      expect(err).to.equal null
      dst = Mongo.getByNS momonger, @options.dst
      dst.count
        value: 73
      , (err, count) =>
        expect(err).to.equal null
        expect(count).to.equal 16
        done err
