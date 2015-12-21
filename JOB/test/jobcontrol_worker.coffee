'use strict'
Mongo = require 'mongo'
Worker = require 'worker'

describe 'worker run', ->
  before (done)->
    @options =
      runLocal: false

    @config =
      host        : "localhost"
      port        : 27017
      authdbname  : null
      user        : null
      password    : null
      database    : "momongertest"
      collection  : "job"
    job = Mongo.getByNS @config, 'momongertest.job'
    job.drop =>
      Worker.start(@config)
      Worker.start(@config)
      Worker.start(@config)
      done null


  require './run_job'
