'use strict'
Logger = require './logger'
OplogReader = require './oplog_reader'

class OpViewer
  constructor: (@config) ->
    @logger = new Logger @config.options.loglv

    @config.options.bulkLimit = 100000
    @oplogReader = new OplogReader @config

  start: ->
    @logger.info 'View mode interval=', @config.options.view_interval
    @oplogReader.init()
    @oplogReader.getTailTS (err, last) =>
      throw err if err
      @opsByNs = {}
      @all = 0
      @firstLog = false
      eachCallback = (oplog, done) =>
        @firstLog = true
        @opsByNs[oplog.ns] ||= {
          m: 0
          c: 0
          i: 0
          u: 0
          d: 0
        }
        ops = @opsByNs[oplog.ns]
        if oplog.fromMigrate
          ops.m++
        else if  oplog.op == 'n'
        else if  oplog.op == 'c'
          ops.c++
        else if  oplog.op == 'i'
          ops.i++
        else if  oplog.op == 'u'
          ops.u++
        else if  oplog.op == 'd'
          ops.d++
        @all++
        done null, oplog

      bulkCallback = (oplogs, done) -> done null
      setInterval =>
        unless @firstLog
          @logger.info 'Waiting for moving cursor to tail'
          return
        time = new Date().toISOString()
        @logger.info "#{time}: ALL: #{@all}"
        for ns, ops of @opsByNs
          @logger.info " #{ns} : i: #{ops.i}, u: #{ops.u}, d: #{ops.d}, c: #{ops.c}, m: #{ops.m}"
        @opsByNs = {}
        @all = 0
      , @config.options.view_interval
      @oplogReader.start last.ts, eachCallback, bulkCallback, (err) ->

module.exports = OpViewer
