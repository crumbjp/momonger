'use strict'
async = require 'async'
_ = require 'underscore'
Mongo = require './mongo'
Logger = require './logger'

DEFAULT_BULK_LIMIT = 5000
DEFAULT_OPLOG_CURSOR_TIMEOUT = 60000
class OplogReader
  constructor: (@config) ->
    @logger = new Logger @config.options.loglv

    @checkConfig()

    @oplogConfig = _.extend {}, @config.src, {
      database: 'local'
      collection: 'oplog.rs'
    }
    @oplogs = []
    @config.options.bulkLimit ||= DEFAULT_BULK_LIMIT
    @config.options.oplogCursorTimeout ||= DEFAULT_OPLOG_CURSOR_TIMEOUT

  checkConfig: ->
    # Validate
    error = false
    unless @config.name
      error = true
      @logger.error 'Config error: `name` is required'
    unless @config.src.type == 'replset'
      error = true
      @logger.error 'Config error: `src.type` must be `replset`'
    throw Error 'Config error' if error

  init: ->
    @oplogMongo = new Mongo @oplogConfig

  getTailTS: (done) ->
    @oplogMongo.findOne {}, {sort: {$natural:-1}}, done

  getCursor: (ts, done) ->
    query = {}
    if ts
      query
        ts:
          $gt: ts
    @logger.info 'OpLog query: ', query
    @oplogMongo.find query,
      tailable: true
      awaitdata: true
      timeout: false
      batchSize: (@config.options.bulkLimit * 2)
    , (err, cursor) =>
      return done err if err
      # TODO: how to set noCursorTimeout ?
      cursor.addCursorFlag 'noCursorTimeout', true
      done null, cursor

  clearLogs: ->
    logs = @oplogs
    @oplogs = []
    logs

  resume: ->
    @stream.resume() if @stream

  pause: ->
    @stream.pause() if @stream

  close: ->
    @stream.close() if @stream
    @stream = null

  length: ->
    @oplogs.length

  lastLog: ->
    @oplogs[@oplogs.length-1].ts

  start: (ts, eachCallback, bulkCallback, done) ->
    doneCalled = false
    @clearLogs()

    @getCursor ts, (err, cursor) =>
      done err if err
      @stream = cursor.stream()
      # Sometime tailable cursor freeze with no data, no close
      @lastDataTime = null
      clearInterval @interval if @interval
      @interval = setInterval =>
        if @lastDataTime
          now = Date.now()
          if (now - @lastDataTime) > @config.options.oplogCursorTimeout
            @logger.error 'Cursor broken ?'
            clearInterval @interval
            @interval = null
            @close()
            unless doneCalled # To care 'end' event
              doneCalled = true
              done null
      , 1000

      @stream.on 'data', (oplog) =>
        @lastDataTime = Date.now()
        @pause()
        eachCallback oplog, (err, filteredLog) =>
          if err
            @logger.error 'Error: eachCallback', err
            @resume()
            return
          @oplogs.push filteredLog if filteredLog
          if @oplogs.length >= @config.options.bulkLimit
            bulkCallback @oplogs, (err) =>
              if err
                @logger.error 'Error: bulkCallback', err
              @clearLogs()
              @resume()
              return
          @resume()

      @stream.on 'end', () =>
        unless doneCalled
          @logger.error 'Cursor closed'
          clearInterval @interval
          @interval = null
          doneCalled = true
          @close()
          done null



module.exports = OplogReader
