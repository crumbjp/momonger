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
,
  short       : 'n'
  long        : 'normalize'
  description : 'Adjust vector size to 1.0'
  value       : false
  required    : false
]
src = opts.get 'src'
dst = opts.get('dst') || "#{src}.tfidf"
append = opts.get('append') || undefined
configPath = opts.get('config') || 'config/momonger.conf'
normalize = opts.get('normalize') || false

async   = require 'async'
Config = require 'momonger/config'
Mongo = require 'momonger/mongo'
{JobControl} = require 'momonger/job'
{Tfidf} = require 'momonger/vectorize'

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
    normalize
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
