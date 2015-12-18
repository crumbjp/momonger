#!/usr/bin/env coffee
'use strict'
async = require 'async'
config = require 'config'

JobControl = require 'jobcontrol'

setting = config.load 'test.conf'
jobControl = new JobControl setting

jobControl.init ->
  console.log 'Start worker'
  finish = false
  async.doDuring (done)->
    jobControl.get (err, implData)->
      if err
        console.err "Error fetching job", err
        finish = err
        return done err
      unless implData
        return done null
      console.log "Fetch job", implData._id
      jobControl.run implData, (err, result)->
        console.log "Finish job", implData._id, err, result
        done err
  , (done)->
    setTimeout ->
      done null, !finish
    , 1000
  , (err)->
    console.log 'Finish worker', err
    jobControl.term()
