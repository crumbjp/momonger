async = require 'async'
Config = require 'momonger/config'
Mongo = require 'momonger/mongo'
{JobControl} = require 'momonger/core'
{Tf} = require 'momonger/vectorize'

{momonger, dictionary} = Config.load 'config/test.conf'

describe 'TF job', ->
  before ->
    @options =
      runLocal: true
      src: "#{momonger.database}.sampledoc.token"
      dst: "#{momonger.database}.sampledoc.tf"

  it 'tf map', (done)->
    this.timeout 3000000
    jobControl = new JobControl momonger
    jobid = null
    async.series [
      (done) => jobControl.init done
      (done) => jobControl.put Tf, @options, (err, result)->
        jobid = result
        done err
      (done) => jobControl.wait jobid, done
    ], (err, results)=>
      expect(err).to.equal null
      dst = Mongo.getByNS momonger, @options.dst
      dst.findOne
        'words.c':
          $all: [ 136, 40, 32]
      , (err, elem) =>
        expect(err).to.equal null
        counts = []
        for word in elem.words
          counts.push word.c
        counts = counts.sort (a, b)-> a - b
        expect(JSON.stringify(counts[-5..])).to.equal JSON.stringify([ 117, 119, 136, 200, 252 ])
        done err
