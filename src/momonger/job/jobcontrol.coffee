#!/usr/bin/env coffee
'use strict'
async = require 'async'
_ = require 'underscore'
{toTypeValue, encodeToString, decodeFromString, addVector, divVector, multiVector, diffVector, diffAngle, normalVector} = require 'momonger/common'
{Job, MapJob, Mapper} = require './job'
Mongo = require 'momonger/mongo'
js2String = require './js2string'

class JobImpl extends Mongo

class JobControl
  constructor: (@config)->
    @localJobById = {}

  init: (done)->
    @jobImpl = new JobImpl @config
    @jobImpl.init done

  _putToMongo: (name, jobImpl, options, done) ->
    implData =
      name: name
      jobImpl: js2String jobImpl, jobImpl.__momonger_dependencies__
      options: encodeToString options
      status: 'put'
      createdAt: new Date()
      _id: Mongo.ObjectId()
    @jobImpl.createIndex {status: 1, createdAt: 1}, (err) =>
      @jobImpl.insert implData, (err, result)->
        done err, implData._id

  put: (jobImpl, options, done)->
    name = 'unknown'
    if _.isFunction jobImpl
      if jobImpl.name
        name = jobImpl.name
      else
        name = null
    return done 'Unknown job type' if name == 'unknown'

    if options.runLocal
      _id = Mongo.ObjectId().toString()
      if name
        r = Math.random()
        @_runJobClass jobImpl, _id, options, (err, result)=>
          @localJobById[_id] = {
            err,
            result
          }
          done null, _id
      else
        @_runJobImpl jobImpl, options, (err, result)=>
          @localJobById[_id] = {
            err,
            result
          }
          done null, _id
    else
      @_putToMongo name, jobImpl, options, done

  wait: (jobid, done)->
    if @localJobById[jobid]
      {err, result} = @localJobById[jobid]
      delete @localJobById[jobid]
      return done err, result
    finish = false
    job = null
    async.doDuring (done)=>
      @jobImpl.findOne
        _id: jobid
        status:
          $in: ['done', 'error']
      ,
        w: 1
        j: 1
        writeConcern: 1
        maxTimeMS: 3600000
        wtimeout: 3600000
      , (err, result)=>
        if err
          finish = true
        else if result
          finish = true
          job = result
          return @jobImpl.remove
            _id: jobid
          , (err, result)=>
            done err
        done err
    , (done) ->
      return done false if finish
      setTimeout ->
        done null, true
      , 1000
    , (err)->
      done err, job?.result

  get: (done)->
    @jobImpl.findAndModify
      status:
        $in: ['put', 'map']
    ,
      createdAt: 1
    ,
      $set:
        processTimestamp: new Date()
        status: 'doing'
    ,
      upsert: false
      new: true
    , (err, result)->
      done err, result?.value

  # getJobLock: (jobid, lockName, done) ->
  #   if @localJobById[jobid]
  #     if @localJobById[jobid][lockName]
  #       return done null, null
  #     else
  #       @localJobById[jobid][lockName] = 1
  #       return done null, {_id: jobid}

  #   query =
  #     _id: jobid
  #   query[lockName] = null

  #   set = {}
  #   set[lockName] = 1

  #   @jobImpl.col().findAndModify query,
  #     {}
  #   ,
  #     $set: set
  #   ,
  #     upsert: false
  #     new: false
  #     fields: ['_id']
  #   , (err, result)->
  #     done err, result.value

  updateStatus: (jobid, status, result, done)->
    @jobImpl.update
      _id: jobid
    ,
      $set:
        status: status
        result: result
    , done

  _runJobClass: (JobClass, jobid, options, done)->
    job = new JobClass this, jobid, @config, options
    job._run (err, result)=>
      result ||= {} # TODO: dirty...
      if err
        result.err = err
        console.error err
      done err, result

  _runJobImpl: (jobImpl, options, done)->
    jobImpl @config, options, (err, result)=>
      result ||= {}
      if err
        result.err = err
        console.error err
      done err, result

  run: (implData, done)->
    jobImpl = options = null
    options = decodeFromString implData.options
    if implData.name
      JobClass = null
      eval "#{implData.jobImpl}\nJobClass = #{implData.name}"
      @_runJobClass JobClass, implData._id, options, (err, result)=>
        if err
          @updateStatus implData._id, 'error', result, (e)->
            done err, result
        else
          @updateStatus implData._id, 'done', result, (e)->
            done e, result

    else
      eval "jobImpl = #{implData.jobImpl}"
      @_runJobImpl jobImpl, options, (err, result)=>
        if err
          @updateStatus implData._id, 'error', result, (e)->
            done err, result
        else
          @updateStatus implData._id, 'done', result, (e)->
            done e, result

module.exports = JobControl
