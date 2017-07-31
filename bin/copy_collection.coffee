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
  required    : true
,
  short       : 'c'
  long        : 'config'
  description : 'configPath'
  value       : true
  required    : false
]
src = opts.get 'src'
dst = opts.get 'dst'
configPath = opts.get('config') || 'config/momonger.conf'

async   = require 'async'
Config = require 'momonger/config'
Mongo = require 'momonger/mongo'

momonger = Config.load configPath

console.log src
console.log dst

src = Mongo.getByNS momonger, src
dst = Mongo.getByNS momonger, dst

async.series [
  (done) =>
    dst.drop (err) ->
      done null
  (done) =>
    src.findAsArray (err, results) =>
      dst.insert results, done
], (err) ->
  console.log "done #{err}"
  process.exit 0
