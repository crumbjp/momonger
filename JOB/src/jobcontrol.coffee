#!/usr/bin/env coffee
'use strict'

async = require 'async'
_ = require 'underscore'
job = require 'job'
Mongo = require 'mongo'
js2String = require 'js2string'

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
      jobImpl: js2String jobImpl
      options: js2String options
      status: 'put'
      processTimestamp: null
      _id: Mongo.ObjectId()
    @jobImpl.col().insert implData, (err, result)->
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
        JobClass = null
        # eval "JobClass = #{name}"
        @_runJobClass jobImpl, options, (err, result)=>
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
      @jobImpl.col().findOne
        _id: jobid
        status:
          $in: ['done', 'error']
      , (err, result)->
        if err
          finish = true
        else if result
          finish = true
          job = result
        done err
    , (done) ->
      return done false if finish
      setTimeout ->
        done null, true
      , 1000
    , (err)->
      console.log '----', err, jobid, job
      done err, job?.result

  get: (done)->
    @jobImpl.col().findAndModify
      processTimestamp: null
    ,
      {}
    ,
      $set:
        processTimestamp: new Date()
        status: 'doing'
    ,
      upsert: false
      new: true
    , (err, result)->
      done err, result?.value

  release: (status, implData, result)->
    @jobImpl.col().update
      _id: implData._id
    ,
      $set:
        status: status
        result: result

  _runJobClass: (JobClass, options, done)->
    job = new JobClass @config, options
    job.run done

  _runJobImpl: (jobImpl, options, done)->
    jobImpl @config, options, done

  run: (implData, done)->
    jobImpl = options = null
    eval "options = #{implData.options}"
    if implData.name
      JobClass = null
      eval "#{implData.jobImpl}\nJobClass = #{implData.name}"
      @_runJobClass JobClass, options, (err, result)=>
        if err
          @release 'error', implData, result
        else
          @release 'done', implData, result
        console.log '*****', implData._id, result
        done err, result

    else
      eval "jobImpl = #{implData.jobImpl}"
      @_runJobImpl jobImpl, options, (err, result)=>
        if err
          @release 'error', implData, result
        else
          @release 'done', implData, result
        console.log '*****', implData._id, result
        done err, result

module.exports = JobControl
