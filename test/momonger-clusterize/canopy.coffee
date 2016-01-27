async = require 'async'
{Mongo, Config, JobControl, Job, MapJob, Mapper, Worker} = require 'momonger-core'
{Canopy} = require 'momonger-clusterize'

{momonger, dictionary} = Config.load 'config/test.conf'

describe 'Canopy job', ->
  before ->
    @options =
      runLocal: true
      src: "#{momonger.database}.sampledoc.tfidf"
      dst: "#{momonger.database}.sampledoc.canopy"
      t2: 0.93
      t1: 0.95
      threshold: 12

  it 'canopy job', (done)->
    this.timeout 3000000
    jobControl = new JobControl momonger
    jobid = null
    async.series [
      (done) => jobControl.init done
      (done) => jobControl.put Canopy, @options, (err, result)->
        jobid = result
        done err
      (done) => jobControl.wait jobid, done
    ], (err, results)=>
      expect(err).to.equal null
      dst = Mongo.getByNS momonger, @options.dst
      async.series [
        (done)->
          dst.count
            _id:
              $ne: '.meta'
          , (err, count) =>
            expect(err).to.equal null
            expect(count).to.equal 2
            done null
        (done)->
          dst.findOne
            all: 14
          , (err, cluster) =>
            expect(err).to.equal null
            expect(cluster.all).to.equal 14
            done null
        (done)->
          dst.findOne
            all: 26
          , (err, cluster) =>
            expect(err).to.equal null
            expect(cluster.all).to.equal 26
            done null
      ], done
