#!/usr/bin/env coffee
'use strict'
async = require 'async'
JobControl = require './jobcontrol'

finish = false
exports.start = (config)->
  jobControl = new JobControl config

  jobControl.init ->
    id = Math.random()
    console.log 'Start worker', id
    empty = false
    async.doDuring (done)->
      empty = false
      jobControl.get (err, implData)->
        if err
          console.log "Error fetching job", err
          finish = err
          return done err
        unless implData
          empty = true
          return done null
        # console.log "Fetch job", id, implData._id
        jobControl.run implData, (err, result)->
          # console.log "Finish job", id, implData._id, err, result
          done null
    , (done)->
      return done null, !finish unless empty
      setTimeout ->
        done null, !finish
      , 1000
    , (err)->
      console.log 'Finish worker', id, err
      jobControl.term()

exports.finish = ->
  finish = 'hup'
