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
  value       : false
  required    : false
,
  short       : 'D'
  long        : 'dictionary'
  description : 'dictionary NS'
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
append = opts.get('append') || false
configPath = opts.get('config') || 'config/momonger.conf'
dictionaryPath = opts.get('dictionary') || 'config/dictionary.conf'


async   = require 'async'
{Mongo, Config, JobControl, Job, MapJob, Mapper, Worker} = require 'momonger-core'
{Tokenize} = require 'momonger-tokenize'

options = {
  runLocal: false
  src
  dst
  dictionary: Config.load dictionaryPath
  append
}
console.log options

momonger = Config.load configPath

jobControl = new JobControl momonger
jobid = null
async.series [
  (done) => jobControl.init done
  (done) => jobControl.put Tokenize, options, (err, result)->
    jobid = result
    done err
  (done) => jobControl.wait jobid, done
], (err, results)=>
  console.log err, results
