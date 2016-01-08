'use strict'
jobcontrol_test = require './_jobcontrol'

context 'local', ->
  options =
    runLocal: true
  config =
    host        : "localhost"
    port        : 27017
    authdbname  : null
    user        : null
    password    : null
    database    : "momongertest"
    collection  : "job"

  jobcontrol_test.test options, config
