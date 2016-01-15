#!/usr/bin/env coffee
'use strict'
opts   = require 'opts'

opts.parse [
  short       : 's'
  long        : 'src'
  description : 'source ns'
  value       : true
  required    : true
,
  short       : 'd'
  long        : 'dst'
  description : 'destination ns'
  value       : true
  required    : false
,
  short       : 'a'
  long        : 'append'
  description : 'append mode'
  value       : true
  required    : false
,
  short       : 'c'
  long        : 'config'
  description : 'configPath'
  value       : true
  required    : false
]
src = opts.get 'src'
dst = opts.get('dst') || "#{src}.token"
append = opts.get('append') || undefined
configPath = opts.get('config') || 'config/momonger.conf'

async   = require 'async'
{Mongo, Config, JobControl, Job, MapJob, Mapper, Worker} = require 'momonger-core'
{Tfidf} = require 'momonger-vectorize'

momonger = Config.load configPath

src = Mongo.getByNS momonger, src
src.findOne {_id: '.meta'}, (err, meta)->
  if err
    console.error err
    process.exit 1

  options = {
    runLocal: false
    src: meta.tf
    idf: meta.idf
    dst
    append
  }

  jobControl = new JobControl momonger
  jobid = null
  async.series [
    (done) => jobControl.init done
    (done) => jobControl.put Tfidf, options, (err, result)->
      jobid = result
      done err
    (done) => jobControl.wait jobid, done
  ], (err, results)=>
    if err
      console.error err
      process.exit 1
    process.exit 0
