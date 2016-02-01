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
  short       : 'D'
  long        : 'dictionary'
  description : 'dictionary config path'
  value       : true
  required    : false
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
dictionaryPath = opts.get('dictionary') || 'config/dictionary.conf'


async   = require 'async'
Config = require 'momonger/config'
{importDocs} = require 'momonger/common'
JPTokenizer = require 'momonger/node-jptokenizer'

jptokenizer = new JPTokenizer Config.load dictionaryPath
async.series [
  (done) => importDocs file, jptokenizer.dictionary, done
  (done) => jptokenizer.dictionary.createIndex {w: 1}, {}, done
  (done) => jptokenizer.dictionary.createIndex {h: 1, l: -1, s: 1}, {}, done
  (done) => jptokenizer.dictionary.createIndex {t: 1}, {}, done
], (err)->
  console.log err
  process.exit 0
