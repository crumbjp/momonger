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
  short       : 'c'
  long        : 'config'
  description : 'configPath'
  value       : true
  required    : false
,
  short       : 'n'
  long        : 'ngram'
  description : 'number of ngram'
  value       : true
  required    : false
]
src = opts.get 'src'
dst = opts.get('dst') || "#{src}.phrase"
configPath = opts.get('config') || 'config/momonger.conf'
n = opts.get('ngram') || n

async   = require 'async'
{Mongo, Config, JobControl, Job, MapJob, Mapper, Worker} = require 'momonger-core'
{Tokenize, Phrase} = require 'momonger-tokenize'

options = {
  runLocal: false
  src
  dst
  n
}

momonger = Config.load configPath

jobControl = new JobControl momonger
jobid = null
async.series [
  (done) => jobControl.init done
  (done) => jobControl.put Phrase, options, (err, result)->
    jobid = result
    done err
  (done) => jobControl.wait jobid, done
], (err, results)=>
  if err
    console.error err
    process.exit 1
  process.exit 0
