'use strict'
_ = require 'underscore'
async = require 'async'
Mongo = require 'mongo'
{toTypeValue} = require 'common'

class Job
  constructor: (@jobcontrol, @jobid, @config, @options)->
    # console.log 'JOBID', @jobid

  _prepare: (done)->
    if @options.src
      @srcMongo = Mongo.getByNS @config, @options.src
    if @options.dst
      @dstMongo = Mongo.getByNS @config, @options.dst
    if @options.emit
      @emitMongo = Mongo.getByNS @config, @options.emit
    if @options.emitids
      @emitidsMongo = Mongo.getByNS @config, @options.emitids
    async.parallel [
      (done) =>
        return done null unless @srcMongo
        @srcMongo.init done
      (done) =>
        return done null unless @dstMongo
        @dstMongo.init done
      (done) =>
        return done null unless @emitMongo
        @emitMongo.init done
      (done) =>
        return done null unless @emitidsMongo
        @emitidsMongo.init done
    ], done

  _dropDestination: (done)->
    async.parallel [
      (done) =>
        return done null unless @dstMongo
        return done null if @options.appendDst
        @dstMongo.drop ->
          done null
      (done) =>
        return done null unless @emitMongo
        @emitMongo.drop ->
          done null
      (done) =>
        return done null unless @emitidsMongo
        @emitidsMongo.drop ->
          done null
    ], done

  beforeRun: (done)->
    done null

  run: (done)->
    done 'Not implemented'

  _run: (done)->
    async.series {
      prepare:
        (done)=> @_prepare done
      beforeRun:
        (done)=> @beforeRun done
      run:
        (done)=> @run done
    }, (err, results) ->
      done err, results.run

exports.Job = Job

class Mapper extends Job
  constructor: (@jobcontrol, @jobid, @config, @options)->
    @ids ||= @options.map?.ids
    @ids ||= @options.reduce?.ids
    @emitDataById = {}

  emit: (id, value) ->
    typeVal = toTypeValue id
    @emitDataById[typeVal] ||= { id, values: []}
    @emitDataById[typeVal].values.push value

  map: (data, done)->
    done 'Not implemented'

  # reduce: (id, array, done)->
  #   done 'Not implemented'

  lastFormat: (data)->
    data

  beforeRun: (done)->
    done null

  afterRun: (done)->
    done null

  _maps: (done) ->
    @srcMongo.find
      _id:
        $in: @ids
    .toArray (err, elements)=>
      return done err if err
      if @options.map
        async.each elements, @map, done
      else if @options.reduce
        for element in elements
          typeVal = toTypeValue element.id
          @emitDataById[typeVal] ||= { id: element.id, values: []}
          for value in element.values
            @emitDataById[typeVal].values.push value
        done null
      else
        done 'Unknown map OP'

  _reduceEmitBuffer: (done) ->
    async.each _.values(@emitDataById), (emitData, done)=>
      return done null if emitData.values.length <= 1
      @reduce emitData.id, emitData.values, (err, value) =>
        return done err if err
        typeVal = toTypeValue emitData.id
        @emitDataById[typeVal].values = [value]
        done null
    , done

  _saveEmitBuffer: (done) ->
    if @options.map
      return done null unless @emitMongo and @emitidsMongo
      emitIdById = {}
      emitDatas = []
      for typeVal, emitData of @emitDataById
        emitData._id = Mongo.ObjectId()
        emitDatas.push emitData
        emitIdById[typeVal] ||= [
          _id: typeVal
        ,
          $pushAll:
            ids: []
        ]
        emitIdById[typeVal][1].$pushAll.ids.push emitData._id
      async.parallel [
        (done) => @emitMongo.bulkInsert emitDatas, done
        (done) => @emitidsMongo.bulkUpdate _.values(emitIdById), done
      ], done
    else if @options.reduce
      inserts = []
      updates = []
      for result in _.values(@emitDataById)
        result.value = result.values[0]
        delete result.values
        result = @lastFormat(result)
        if _.isArray result
          updates.push result
        else
          inserts.push result
      async.series [
        (done) => @dstMongo.bulkInsert inserts, done
        (done) => @dstMongo.bulkUpdate updates, done
      ], done
    else
      done 'Unknown map OP'


  _run: (done)->
    async.series [
      (done)=> @_prepare done
      (done)=> @beforeRun done
      (done)=> @_maps done
      (done)=> @_reduceEmitBuffer done
      (done)=> @_saveEmitBuffer done
      (done)=> @afterRun done
    ], (err) =>
      console.error err if err
      done err, null

exports.Mapper = Mapper

class MapJob extends Job
  constructor: (@jobcontrol, @jobid, @config, @options)->
    @options = _.extend {
      chunkSize: 1000
      query: {}
    }, @options
    @options.emit ||= "#{@options.dst}.emit"
    @options.emitids ||= "#{@options.emit}.ids"

  beforeFirstMap: (done)->
    console.log 'map::beforeFirstMap'
    done null

  afterLastMap: (done)->
    console.log 'map::afterLastMap'
    done null

  afterRun: (done)->
    console.log 'map::afterRun'
    done null

  cursor: ->
    return @srcMongo.find(@options.query)

  mapper: ->
    throw 'Should retern Mapper job'

  _run: (done)->
    doReduce = !!@mapper().prototype.reduce
    async.series {
      prepare:
        (done)=> @_prepare done
      drop:
        (done)=> @_dropDestination done
      beforeFirstMap:
        (done)=> @beforeFirstMap done
      mappers:
        (done)=> @_mappers done
      afterLastMap:
        (done)=> @afterLastMap done
      reducers:
        (done)=>
          return done null unless doReduce
          @_reducers done
      afterRun:
        (done)=> @afterRun done
    }, (err, results) =>
      done err, results?.afterRun

  _createMapper: (ids, done)->
    options = _.extend {}, @options, {
      map:
        ids: ids
    }
    @jobcontrol.put @mapper(), options, done

  _createReducer: (ids, done)->
    options = _.extend {}, @options, {
      src: @options.emit
      reduce:
        ids: ids
    }
    @jobcontrol.put @mapper(), options, done

  _mappers: (done)->
    @jobids = []
    async.series [
      (done) =>
        Mongo.inBatch @cursor(), @options.chunkSize,
          (data)-> data._id
        ,
          (ids, done)=>
            @_createMapper ids, (err, jobid)=>
              @jobids.push jobid
              done null
        , done
      (done) =>
        async.each @jobids, (jobid, done) =>
          @jobcontrol.wait jobid, done
        , done
    ], done

  _reducers: (done)->
    @jobids = []
    async.series [
      (done) =>
        # TODO: 1 @jobids
        Mongo.inBatch @emitidsMongo.find(), 1,
          (data)-> data.ids
        ,
          (idsArr, done)=>
            async.each idsArr, (ids, done) =>
              @_createReducer ids, (err, jobid)=>
                @jobids.push jobid
                done null
            , done
        , done
      (done) =>
        async.each @jobids, (jobid, done) =>
          @jobcontrol.wait jobid, done
        , done
    ], done


exports.MapJob = MapJob
