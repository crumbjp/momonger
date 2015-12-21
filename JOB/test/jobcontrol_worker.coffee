'use strict'
Mongo = require 'mongo'
Worker = require 'worker'

jobcontrol_test = require './_jobcontrol'

context 'worker', ->
  options =
    runLocal: false

  config =
    host        : "localhost"
    port        : 27017
    authdbname  : null
    user        : null
    password    : null
    database    : "momongertest"
    collection  : "job"
  job = Mongo.getByNS config, 'momongertest.job'
  job.drop =>
    Worker.start(config)
    Worker.start(config)
    Worker.start(config)
  jobcontrol_test.test options, config
