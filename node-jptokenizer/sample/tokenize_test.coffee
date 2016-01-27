'use strict'
opts   = require 'opts'
Config = require 'config'
JPTokenizer = require('node-jptokenizer')

opts.parse [
  short       : 'c'
  long        : 'config-file'
  description : ''
  value       : true
  required    : false
,
  short       : 's'
  long        : 'sentence'
  description : 'Target sentence'
  value       : true
  required    : true
]

sentence = opts.get('sentence')
config_file = opts.get('config-file')
config = Config.load config_file

console.log config
tokenizer = new JPTokenizer config

tokenizer.init ->
  tokenized = "idx:      Dictionary ID     : word\n------------------------------------\n"
  tokenizer.parse_doc sentence, (err, tokens)->
    for token in tokens
      tokenized += "#{token.i}: #{token.c} : #{token.w}"
      if '名詞' in token.candidate.t
        tokenized += ": (名詞)"
      tokenized += "\n"

    console.log tokenized
    console.log "nquery: #{tokenizer.impl.nquery}, nfetch: #{tokenizer.impl.nfetch}"

    tokenizer.term()
