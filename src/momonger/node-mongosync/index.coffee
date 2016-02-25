#!/usr/bin/env coffee
'use strict'
opts   = require 'opts'
_   = require 'underscore'

opts.parse [
  short       : 'c'
  long        : 'config'
  description : 'configPath'
  value       : true
  required    : true
,
  short       : 'f'
  long        : 'force-tail'
  description : 'Sync from tail of the OpLog. (Ignoring last sync TS)'
  value       : false
  required    : false
,
  short       : 't'
  long        : 'dry-run'
  description : 'dry run mode'
  value       : false
  required    : false
,
  short       : 'l'
  long        : 'loglv'
  description : 'debug/verbose/info/error'
  value       : true
  required    : false
]
configPath = opts.get('config')
force_tail = opts.get('force-tail')
dryrun = opts.get('dry-run')
loglv = opts.get('loglv')

Mongosync = require './mongosync'
Config = require './config'
config = Config.load configPath

config.options.force_tail = force_tail unless _.isUndefined force_tail
config.options.dryrun = dryrun unless _.isUndefined dryrun
config.options.loglv = loglv unless _.isUndefined loglv

sync = new Mongosync config
sync.start (err)->
  if err
    console.log err
    process.exit 1
  process.exit 0
