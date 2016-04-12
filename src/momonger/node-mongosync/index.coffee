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
,
  short       : 'v'
  long        : 'view-mode'
  description : '--view-mode=`interval sec` Only view oplog summary. Do not connect to destination.'
  value       : true
  required    : false
]
configPath = opts.get('config')
force_tail = opts.get('force-tail')
dryrun = opts.get('dry-run')
loglv = opts.get('loglv')
view_mode = opts.get('view-mode')

Sync = require './sync'
Config = require './config'
config = Config.load configPath

config.options.force_tail = force_tail unless _.isUndefined force_tail
config.options.dryrun = dryrun unless _.isUndefined dryrun
config.options.loglv = loglv unless _.isUndefined loglv

if view_mode
  OpViewer = require './op_viewer'
  config.options.view_interval = parseInt(view_mode)
  opViewer = new OpViewer config
  opViewer.start()
  return

sync = new Sync config
sync.start (err)->
  if err
    console.log err
    process.exit 1
  process.exit 0
