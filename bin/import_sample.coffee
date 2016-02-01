#!/usr/bin/env coffee
'use strict'
opts   = require 'opts'

opts.parse [
  short       : 'f'
  long        : 'file'
  description : 'json file'
  value       : true
  required    : true
,
  short       : 'd'
  long        : 'dst'
  description : 'collection ns'
  value       : true
  required    : true
,
  short       : 'c'
  long        : 'config'
  description : 'configPath'
  value       : true
  required    : false
]
file = opts.get 'file'
dst = opts.get 'dst'
configPath = opts.get('config') || 'config/momonger.conf'

async   = require 'async'
Config = require 'momonger/config'
Mongo = require 'momonger/mongo'
{importDocs} = require 'momonger/common'
momonger = Config.load configPath
collection = Mongo.getByNS momonger, dst

importDocs file, collection, (err)->
  console.log err
  process.exit 0
