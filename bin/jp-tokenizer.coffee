#!/usr/bin/env coffee
'use strict'
opts   = require 'opts'

opts.parse [
  short       : 'l'
  long        : 'separate-loan-word'
  description : 'separate loan word'
  value       : false
  required    : false
,
  short       : 'D'
  long        : 'dictionary'
  description : 'dictionary config path'
  value       : true
  required    : false
]
separateLoanWord = opts.get('separate-loan-word')
dictionaryPath = opts.get('dictionary') || 'config/dictionary.conf'

options =
  includeUnknownToken: true
if separateLoanWord
  options =
    includeUnknownToken: true
    separateLoanWord: true

Config = require 'momonger/config'
JPTokenizer = require "momonger/node-jptokenizer"
tokenizer = new JPTokenizer Config.load(dictionaryPath), options
tokenizer.modifier = (token, candidate, done) ->
  if candidate.t.indexOf("名詞") >= 0
    return done null, token
  done null, null

tokenizer.init () ->
  tokenizer.parse_doc opts.args().join(' '), (err, tokens) ->
    for token in tokens
      console.log "#{token.i} : #{token.w}"
