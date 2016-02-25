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
  short       : 'f'
  long        : 'field'
  description : 'target field'
  value       : true
  required    : true
,
  short       : 'a'
  long        : 'append'
  description : 'append mode'
  value       : true
  required    : false
,
  short       : 'D'
  long        : 'dictionary'
  description : 'dictionary config path'
  value       : true
  required    : false
,
  short       : 'c'
  long        : 'config'
  description : 'config path'
  value       : true
  required    : false
]
src = opts.get 'src'
dst = opts.get('dst') || "#{src}.token"
field = opts.get 'field'
append = opts.get('append') || undefined
configPath = opts.get('config') || 'config/momonger.conf'
dictionaryPath = opts.get('dictionary') || 'config/dictionary.conf'


async   = require 'async'
Config = require 'momonger/config'
{JobControl} = require 'momonger/core'
{Tokenize} = require 'momonger/tokenize'

options = {
  chunkSize: 10 # TODO: 100 or 1000 ?
  runLocal: false
  src
  dst
  field
  dictionary: Config.load dictionaryPath
  append
}

momonger = Config.load configPath

jobControl = new JobControl momonger
jobid = null
async.series [
  (done) => jobControl.init done
  (done) => jobControl.put Tokenize, options, (err, result)->
    jobid = result
    done err
  (done) =>
    jobControl.wait jobid, done
], (err, results)=>
  if err
    console.error err
    process.exit 1
  process.exit 0
