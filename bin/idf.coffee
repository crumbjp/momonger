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
  long        : 'noun-only'
  description : ''
  value       : false
  required    : false
,
  short       : 'u'
  long        : 'use-dictionary-coefficient'
  description : ''
  value       : false
  required    : false
,
  short       : 'f'
  long        : 'filter-noise'
  description : 'Filter small number, single KANA, and so on'
  value       : false
  required    : false
]
src = opts.get 'src'
dst = opts.get('dst') || "#{src}.idf"
configPath = opts.get('config') || 'config/momonger.conf'
noun = opts.get 'noun-only'
useDictionaryCoefficient = opts.get 'use-dictionary-coefficient'
filterNoise = opts.get 'filter-noise'

async   = require 'async'
{Mongo, Config, JobControl, Job, MapJob, Mapper, Worker} = require 'momonger-core'
{Idf} = require 'momonger-vectorize'

options = {
  runLocal: false
  src
  dst
  noun
  useDictionaryCoefficient
  filterNoise
}

momonger = Config.load configPath

jobControl = new JobControl momonger
jobid = null
async.series [
  (done) => jobControl.init done
  (done) => jobControl.put Idf, options, (err, result)->
    jobid = result
    done err
  (done) => jobControl.wait jobid, done
], (err, results)=>
  if err
    console.error err
    process.exit 1
  process.exit 0
