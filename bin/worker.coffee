#!/usr/bin/env coffee
'use strict'
opts   = require 'opts'

opts.parse [
  short       : 'c'
  long        : 'config'
  description : 'Specify config file'
  value       : true
  required    : false
,
]
configPath = 'config/momonger.conf'
configPath ||= opts.get 'config'

{Worker, Config} = require 'momonger-core'

momonger = Config.load configPath
Worker.start momonger
Worker.start momonger
Worker.start momonger
Worker.start momonger
Worker.start momonger
