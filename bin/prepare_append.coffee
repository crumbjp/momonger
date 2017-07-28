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
  short       : 'a'
  long        : 'append'
  description : 'append mode'
  value       : true
  required    : true
,
  short       : 'c'
  long        : 'config'
  description : 'configPath'
  value       : true
  required    : false
]
src = opts.get 'src'
append = opts.get('append') || undefined
configPath = opts.get('config') || 'config/momonger.conf'

async   = require 'async'
Config = require 'momonger/config'
Mongo = require 'momonger/mongo'

momonger = Config.load configPath

src = Mongo.getByNS momonger, src
src.update {a: null}, {'$set': {a: append}}, {multi: true}, (err, result)->
  if err
    console.error err
    process.exit 1
  console.log result.result
  process.exit 0
