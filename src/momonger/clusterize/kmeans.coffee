'use strict'
_ = require 'underscore'
async = require 'async'
Mongo = require 'momonger/mongo'
{JobControl, Job, MapJob, Mapper, Worker} = require 'momonger/job'
{addVector, divVector, multiVector, diffVector, diffAngle, normalVector} = require 'momonger/common'

class Kmeans extends Job
  constructor: (@jobcontrol, @jobid, @config, @options)->
    super @jobcontrol, @jobid, @config, @options
    if @options.append?
      @options.appendDst = true
      @options.query =
        a: @options.append
  beforeRun: (done)->
    async.series [
      (done) =>
        return done null if @options.appendDst
        @dstMongo._db().collections (err, collections)=>
          async.eachSeries collections, (collection, done) =>
            if RegExp("^#{@options.dst}.*").test collection.namespace
              collection.drop done
            else
              done null
          , done
      (done) =>
        cluster = "#{@options.dst}.cluster" if @options.append?
        cluster ||= @options.cluster
        @clusterMongo = Mongo.getByNS @config, cluster
        @clusterMongo.findAsArray (err, @clusters)=>
          done err
      (done) =>
        @srcMongo.getmeta (err, @meta) =>
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
                @orgMongo.getmeta (err, @meta) =>
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
                @orgMongo.getmeta (err, @meta) =>
                  done err
              (done) =>
                @diffFunc = diffVector
                @diffFunc = diffAngle if @meta.normalize
                done null
              (done) =>
                @dstMongo.createIndex {a: 1}, done
              (done) =>
                @dstMongo.createIndex {c: 1}, done
            ], done

          map: (doc, done)=>
            min = null
            id = null
            clusterScores = []
            sum = 0
            for cluster in @clusters
              s = @diffFunc cluster.v, doc.v
              sum += 1.0 - s
              clusterScores.push
                _id: cluster._id
                s: s

              if min == null or min > s
                min = s
                id = cluster._id
            for clusterScore in clusterScores
              clusterScore.s = (1 - clusterScore.s) / sum
            clusterScores.sort (a, b)-> b.s - a.s

            @results.push {
              _id: doc._id
              c: id
              cs: clusterScores
              a: @options.append
            }
            done null

          afterRun: (done)->
            @dstMongo.bulkInsert @results, (err) =>
              console.log(err) if err
              done err

      afterRun: (done)->
        @clusterMongo = Mongo.getByNS @config, @options.cluster
        @srcMongo.getmeta (err, @meta) =>
          return done null if @options.append?
          @dstMongo.insert @meta, done

    if @options.append
      options = _.extend {}, @options, {
        dst: @meta.kmeans.data
        cluster: @meta.kmeans.cluster
      }
      @jobcontrol.put KmeansDataJob, options, (err, jobid)=>
        return err if err
        @jobcontrol.wait jobid, =>
          done null, @meta
    else
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
            console.log "DISTANCE: #{prevDistance} => #{@meta.kmeans.distance}"
            if prevDistance and ((prevDistance - @meta.kmeans.distance) / @meta.kmeans.distance) < 0.01
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
        ], (err)=>
          done err, @meta

module.exports = Kmeans
