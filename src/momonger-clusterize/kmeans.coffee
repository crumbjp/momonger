'use strict'
_ = require 'underscore'
async = require 'async'
{Mongo, Config, JobControl, Job, MapJob, Mapper, Worker} = require 'momonger-core'
{addVector, divVector, multiVector, diffVector, diffAngle, normalVector} = require 'common'


class Kmeans extends Job
  beforeRun: (done)->
    async.series [
      (done) =>
        @dstMongo._db().collections (err, collections)=>
          async.eachSeries collections, (collection, done) =>
            if RegExp("^#{@options.dst}.*").test collection.namespace
              collection.drop done
            else
              done null
          , done
      (done) =>
        @clusterMongo = Mongo.getByNS @config, @options.cluster
        @clusterMongo.findAsArray (err, @clusters)=>
          done err
      (done) =>
        @clusterMongo.getmeta (err, @meta)=>
          done err
    ], done
  run: (done)->
    class KmeansJob extends MapJob
      mapper: ->
        class KmeansMapper extends Mapper
          beforeRun: (done)->
            async.series [
              (done) =>
                @clusterMongo = Mongo.getByNS @config, @options.cluster
                @clusterMongo.findAsArray
                  _id:
                    $ne: '.meta'
                , (err, @clusters)=>
                  done err
              (done) =>
                @clusterMongo.getmeta (err, @meta)=>
                  done err
              (done) =>
                @diffFunc = diffVector
                @diffFunc = diffAngle if @meta.normalize
                done null
            ], done

          nearestCluster: (vec)->
            min = null
            id = null
            for cluster in @clusters
              tmp = @diffFunc cluster.v, vec
              if min == null or min > tmp
                min = tmp
                id = cluster._id
            {id, d: min}

          map: (doc, done)=>
            {id, d} = @nearestCluster doc.v
            @emit id, {v: doc.v, d, n: 1}
            done null

          reduce: (id, array, done)->
            vec = {}
            d = 0
            n = 0
            for elem in array
              vec = addVector vec, elem.v
              d += elem.d
              n += elem.n
            done null, {d, n, v: normalVector vec}

          lastFormat: (value)=>
            {
              _id: value.id
              v: value.value.v
              d: value.value.d
              n: value.value.n
            }

    class KmeansDataJob extends MapJob
      mapper: ->
        class KmeansDataMapper extends Mapper
          beforeRun: (done)->
            @results = []
            async.series [
              (done) =>
                @clusterMongo = Mongo.getByNS @config, @options.cluster
                @clusterMongo.findAsArray
                  _id:
                    $ne: '.meta'
                , (err, @clusters)=>
                  done err
              (done) =>
                @clusterMongo.getmeta (err, @meta)=>
                  done err
              (done) =>
                @diffFunc = diffVector
                @diffFunc = diffAngle if @meta.normalize
                done null
            ], done

          map: (doc, done)=>
            min = null
            id = null
            clusterScores = []
            sum = 0
            for cluster in @clusters
              tmp = @diffFunc cluster.v, doc.v
              sum += tmp
              clusterScores.push
                _id: cluster._id
                s: tmp

              if min == null or min > tmp
                min = tmp
                id = cluster._id

            for clusterScore in clusterScores
              clusterScore.s = 1 - clusterScore.s / sum
            clusterScores.sort (a, b)-> b.s - a.s

            @results.push {
              _id: doc._id
              c: id
              cs: clusterScores
            }
            done null

          afterRun: (done)->
            @results.push @meta
            @dstMongo.bulkInsert @results, done

    @meta.kmeans =
      iterate: 0
      distance: null
      cluster: "#{@options.dst}.cluster"
      data: "#{@options.dst}.data"

    currentDst = null
    async.doDuring (done)=>
      @meta.kmeans.iterate++
      currentDst = "#{@options.dst}.it#{@meta.kmeans.iterate}"
      options = _.extend {}, @options, {
        dst: currentDst
        cluster: "#{@options.dst}.it#{@meta.kmeans.iterate-1}"
      }
      options.cluster = @options.cluster if @meta.kmeans.iterate == 1
      @jobcontrol.put KmeansJob, options, (err, jobid)=>
        return err if err
        @jobcontrol.wait jobid, ->
          done null
    , (done)=>
      @currentDstMongo = Mongo.getByNS @config, currentDst
      @currentDstMongo.aggregate [
        $group:
          _id: 1
          d:
            $sum: '$d'
      ], (err, result) =>
        return done err if err
        prevDistance = @meta.kmeans.distance
        @meta.kmeans.distance = result[0].d
        @currentDstMongo.insert @meta, (err)=>
          return done err if err
          return done null, false if @meta.kmeans.iterate >= @options.iterate
          if prevDistance and ((@meta.kmeans.distance - prevDistance) / @meta.kmeans.distance) < 0.01
            # Finish when affect score is less than 1%
            return done null, false
          done null, true
    , (err) =>
      return done err if err
      async.series [
        (done) =>
          @currentDstMongo.rename @meta.kmeans.cluster.split('.')[1..].join('.'), done
        (done) =>
          options = _.extend {}, @options, {
            dst: @meta.kmeans.data
            cluster: @meta.kmeans.cluster
          }
          @jobcontrol.put KmeansDataJob, options, (err, jobid)=>
            return err if err
            @jobcontrol.wait jobid, ->
              done null
      ], (err)->
        done err

module.exports = Kmeans