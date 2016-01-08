async = require 'async'
{Mongo, Config, JobControl, Job, MapJob, Mapper, Worker} = require 'momonger-core'
{Phrase} = require 'momonger-tokenize'

{momonger, dictionary} = Config.load 'config/test.conf'

describe 'phrase', ->
  before ->
    @options =
      runLocal: true
      src: "#{momonger.database}.sampledoc.token"
      dst: "#{momonger.database}.sampledoc.phrase"
      n: 4

  it 'phrase map', (done)->
    this.timeout 3000000
    jobControl = new JobControl momonger
    jobid = null
    async.series [
      (done) => jobControl.init done
      (done) => jobControl.put Phrase, @options, (err, result)->
        jobid = result
        done err
      (done) => jobControl.wait jobid, done
    ], (err, results)=>
      expect(err).to.equal null
      dst = Mongo.getByNS momonger, @options.dst
      dst.findOne
        _id: '宇宙開発'
      , (err, elem) =>
        expect(err).to.equal null
        console.log elem
        expect(elem.df).to.equal 7
        expect(elem.tf).to.equal 176
        expect(elem.n).to.equal 2
        expect(elem.c).to.equal 40
        expect(Math.floor elem.tcv).to.equal 120
        expect(Math.floor elem.dcv).to.equal 4
        expect(Math.floor elem.itf).to.equal 81
        expect(Math.floor elem.idf).to.equal 29
        expect(elem.ws[0]).to.equal '宇宙'
        expect(elem.ws[1]).to.equal '開発'
        done err
