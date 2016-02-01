async = require 'async'
Config = require 'momonger/config'
Mongo = require 'momonger/mongo'
{JobControl} = require 'momonger/core'
{Tokenize} = require 'momonger/tokenize'

{momonger, dictionary} = Config.load 'config/test.conf'

describe 'tokenize', ->
  before ->
    @options =
      runLocal: true
      src: "#{momonger.database}.sampledoc"
      dst: "#{momonger.database}.sampledoc.token"
      chunkSize: 3
      dictionary: dictionary

  it 'tokenize map', (done)->
    this.timeout 3000000
    jobControl = new JobControl momonger
    jobid = null
    async.series [
      (done) => jobControl.init done
      (done) => jobControl.put Tokenize, @options, (err, result)->
        jobid = result
        done err
      (done) => jobControl.wait jobid, done
    ], (err, results)=>
      expect(err).to.equal null
      dst = Mongo.getByNS momonger, @options.dst
      dst.findOne
        i: 47
        p: 138
        w: 'プログラミング'
      , (err, elem) =>
        expect(err).to.equal null
        console.log elem
        expect(elem).to.exist
        done err
