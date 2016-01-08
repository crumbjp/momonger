'use strict'
{Mongo, Config, JobControl, Job, MapJob, Mapper, Worker} = require 'momonger-core'

jobcontrol_test = require './_jobcontrol'

context 'worker', ->
  options =
    runLocal: false
  {momonger} = Config.load 'config/test.conf'
  before (done)->
    job = Mongo.getByNS momonger, "#{momonger.database}.#{momonger.collection}"
    job.drop =>
      Worker.start(momonger)
      Worker.start(momonger)
      Worker.start(momonger)
    done null
  jobcontrol_test.test options, momonger
