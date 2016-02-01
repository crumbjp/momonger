'use strict'
_ = require 'underscore'
async = require 'async'
{JobControl, Job, MapJob, Mapper, Worker} = require 'momonger/core'
{addVector, divVector, multiVector, diffVector, diffAngle} = require 'momonger/common'


class Canopy extends Job
  beforeRun: (done)->
    async.series [
      (done) =>
        @_dropDestination done
      (done) =>
        @srcMongo.getmeta (err, @meta)=>
          done err
    ], done

  run: (done)->
    clusters = []
    diffFunc = diffVector
    diffFunc = diffAngle if @meta.normalize
    @srcMongo.find
      _id:
        $ne: '.meta'
    , (err, cursor) =>
      cursor.count (err, all) =>
        count = 0
        stream = cursor.stream()
        stream.on 'data', (tfidf) =>
          count++
          newCluster = true
          for cluster, i in clusters
            d = diffFunc cluster.v, tfidf.v
            if d < @options.t2
              newCluster = false
              cluster.all++
              break
            else if d < @options.t1
              newCluster = false
              cluster.sum = addVector cluster.sum, tfidf.v
              cluster.n++
              cluster.all++
              break
          if newCluster
            clusters.push {
              sum: tfidf.v
              n: 1
              all: 1
              v: tfidf.v
            }
          if count >= all
            async.eachSeries clusters, (cluster, done)=>
              return done null if cluster.all <= @options.threshold
              cluster.v = divVector cluster.sum, cluster.n if cluster.n > 1
              delete cluster.n
              delete cluster.sum
              @dstMongo.insert cluster, done
            , (err) =>
              return done err if err
              @srcMongo.getmeta (err, meta)=>
                meta.canopy = @options.dst
                @dstMongo.insert meta, (err)->
                  done err, meta

module.exports = Canopy
