'use strict'

describe 'local run', ->
  before ->
    @options =
      runLocal: true
    @config =
      host        : "localhost"
      port        : 27017
      authdbname  : null
      user        : null
      password    : null
      database    : "momongertest"
      collection  : "job"

  require './run_job'
