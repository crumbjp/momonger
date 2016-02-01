async = require 'async'
Config = require 'momonger/config'
Mongo = require 'momonger/mongo'
{JobControl} = require 'momonger/core'
{Kmeans} = require 'momonger/clusterize'

{momonger, dictionary} = Config.load 'config/test.conf'

describe 'Kmeans job', ->
  before ->
    @options =
      runLocal: true
      src: "#{momonger.database}.sampledoc.tfidf"
      cluster: "#{momonger.database}.sampledoc.canopy"
      dst: "#{momonger.database}.sampledoc.kmeans"
      iterate: 5

  it 'kmeans job', (done)->
    this.timeout 3000000
    jobControl = new JobControl momonger
    jobid = null
    async.series [
      (done) => jobControl.init done
      (done) => jobControl.put Kmeans, @options, (err, result)->
        jobid = result
        done err
      (done) => jobControl.wait jobid, done
    ], (err, results)=>
      expect(err).to.equal null
      dstCluster = Mongo.getByNS momonger, "#{@options.dst}.cluster"
      dstData = Mongo.getByNS momonger, "#{@options.dst}.data"
      async.series [
        (done)->
          dstCluster.count
            _id:
              $ne: '.meta'
          , (err, count) =>
            expect(err).to.equal null
            expect(count).to.equal 2
            done null
        (done)->
          dstCluster.findOne
            n: 36
          , (err, cluster) =>
            expect(err).to.equal null
            expect(Math.floor cluster.d).to.equal 23
            done null
        (done)->
          dstData.count
            _id:
              $ne: '.meta'
          , (err, count) =>
            expect(err).to.equal null
            expect(count).to.equal 73
            done null
      ], done
