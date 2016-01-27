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
  short       : '1'
  long        : 't1'
  description : 'default: 0.98'
  value       : true
  required    : false
,
  short       : '2'
  long        : 't2'
  description : 'default: 0.95'
  value       : true
  required    : false
,
  short       : 't'
  long        : 'threshold'
  description : 'default: 1'
  value       : true
  required    : false
]
src = opts.get 'src'
dst = opts.get('dst') || "#{src}.canopy"
configPath = opts.get('config') || 'config/momonger.conf'
t1 = parseFloat(opts.get('t1')) || 0.98
t2 = parseFloat(opts.get('t2')) || 0.95
threshold = parseInt(opts.get('threshold')) || 1

async   = require 'async'
{Mongo, Config, JobControl, Job, MapJob, Mapper, Worker} = require 'momonger-core'
{Canopy} = require 'momonger-clusterize'

options = {
  runLocal: false
  src
  dst
  t2
  t1
  threshold
}

momonger = Config.load configPath

jobControl = new JobControl momonger
jobid = null
async.series [
  (done) => jobControl.init done
  (done) => jobControl.put Canopy, options, (err, result)->
    jobid = result
    done err
  (done) => jobControl.wait jobid, done
], (err, results)=>
  if err
    console.error err
    process.exit 1
  process.exit 0
