async = require 'async'
Mongo = require 'momonger/mongo'
Config = require 'momonger/config'
{importDocs} = require 'momonger/common'

describe 'build data', ->
  before (done)->
    this.timeout 3000000
    {momonger, dictionary} = Config.load 'config/test.conf'
    dictionaryMongo = Mongo.getByNS dictionary.mongo, "#{dictionary.mongo.database}.#{dictionary.mongo.collection}"
    srcMongo = Mongo.getByNS momonger, "#{momonger.database}.sampledoc"

    async.series [
      (done) => importDocs 'test/fixture/dictionary.json', dictionaryMongo, done
      (done) => dictionaryMongo.createIndex {w: 1}, {}, done
      (done) => dictionaryMongo.createIndex {h: 1, l: -1, s: 1}, {}, done
      (done) => dictionaryMongo.createIndex {t: 1}, {}, done
      (done) => importDocs 'test/fixture/sampledocs.json', srcMongo, done
    ], done

  describe 'common', ->
    require './common'
  describe 'node-jptokenizer', ->
    require './node-jptokenizer'
  describe 'momonger-tokenize', ->
    require './momonger-tokenize'
  describe 'momonger-vectorize', ->
    require './momonger-vectorize'
  describe 'momonger-clusterize', ->
    require './momonger-clusterize'
  describe 'momonger-core', ->
    require './momonger-core'
