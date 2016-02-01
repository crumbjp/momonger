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
  short       : 'C'
  long        : 'cluster'
  description : 'specify canopy ns'
  value       : true
  required    : false
,
  short       : 'i'
  long        : 'iterate'
  description : 'max iteration. default: 100'
  value       : true
  required    : false
]
src = opts.get 'src'
dst = opts.get('dst') || "#{src}.kmeans"
configPath = opts.get('config') || 'config/momonger.conf'
cluster = opts.get 'cluster'
iterate = parseFloat(opts.get('iterate')) || 100

async   = require 'async'
Config = require 'momonger/config'
Mongo = require 'momonger/mongo'
{JobControl} = require 'momonger/core'
{Kmeans} = require 'momonger/clusterize'

options = {
  runLocal: false
  src
  dst
  cluster
  iterate
}

momonger = Config.load configPath

jobControl = new JobControl momonger
jobid = null
async.series [
  (done) => jobControl.init done
  (done) => jobControl.put Kmeans, options, (err, result)->
    jobid = result
    done err
  (done) => jobControl.wait jobid, done
], (err, results)=>
  if err
    console.error err
    process.exit 1
  process.exit 0
