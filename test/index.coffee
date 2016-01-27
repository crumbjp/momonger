async = require 'async'
fs = require 'fs'
{Mongo, Config} = require 'momonger-core'

importDocs = (filename, collection, done)->
  json = fs.readFileSync filename, 'utf-8'
  elements = JSON.parse(json)
  for element in elements
    element._id = Mongo.ObjectId element._id.$oid if element._id.$oid
  async.series [
    (done) => collection.drop ->
      done null
    (done) =>
      collection.bulkInsert elements, done
  ], done

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
  describe 'momonger-core', ->
    require './momonger-core'
  describe 'momonger-tokenize', ->
    require './momonger-tokenize'
  describe 'momonger-vectorize', ->
    require './momonger-vectorize'
