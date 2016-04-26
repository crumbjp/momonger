'use strict'
async = require 'async'
_ = require 'underscore'
Mongo = require './mongo'
Logger = require './logger'

DEFAULT_BULK_LIMIT = 2000
DEFAULT_BULK_INTERVAL = 1000
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
    @config.options.bulkInterval ||= DEFAULT_BULK_INTERVAL

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

  getQuery: (ts, done) ->
    if ts
      return done null, {
        ts:
          $gt: ts
      }
    @getTailTS (err, oplog)->
      done null, {
        ts:
          $gt: oplog.ts
      }

  getCursor: (ts, done) ->
    @getQuery ts, (err, query)=>
      @lastTS = query.ts.$gt
      @logger.info 'OpLog query: ', query
      @oplogMongo.find query,
        sort:
          $natural: 1
        tailable: true
        awaitdata: true
        timeout: false
        # batchSize: (@config.options.bulkLimit * 2)
      , (err, cursor) =>
        return done err if err
        # TODO: how to set noCursorTimeout ?
        cursor.addCursorFlag 'noCursorTimeout', true
        done null, cursor

  getTailOplogs: (ts, done) ->
    @logger.info 'getTailOplogs: ', ts
    @oplogMongo.find {},
      sort:
        $natural: -1
      # batchSize: @config.options.bulkLimit
    , (err, cursor) =>
      return done err if err
      oplogs = []
      tailStream = cursor.stream()
      closed = false
      tailStream.on 'data', (oplog)=>
        return if closed
        if oplog and oplog.ts > ts
          oplogs.push oplog
          return
        closed = true
        # console.log '## CLOSE', ts
        tailStream.close()

      tailStream.on 'end', (oplog)=>
        @lastTS = oplogs[0].ts if oplogs.length
        done null, oplogs.reverse()

      tailStream.on 'error', (err)=>
        console.log '##### cursor error', err

  clearLogs: ->
    logs = @oplogs
    @oplogs = []
    logs

  resume: ->
    if @stream and @stream.connection
      @stream.resume()

  pause: ->
    if @stream and @stream.connection
      @stream.pause()

  close: ->
    @stream.close() if @stream
    @stream = null

  length: ->
    @oplogs.length

  processBulk: (bulkCallback, done) ->
    bulkCallback @oplogs, (err) =>
      if err
        @logger.error 'Error: bulkCallback', err
      @clearLogs()
      @resume()
      done? err

  start: (ts, eachCallback, bulkCallback, done) ->
    @run ts, eachCallback, bulkCallback, (err) ->
      clearInterval @tailOplogInterval
      @tailOplogInterval = null
      clearInterval @bulkInterval
      @bulkInterval = null
      @close()
      done err

  run: (ts, eachCallback, bulkCallback, done) ->
    doneCalled = false
    @clearLogs()

    @getCursor ts, (err, cursor) =>
      done err if err
      @stream = cursor.stream()
      # Sometime tailable cursor freeze with no data, no close
      @lastDataTime = null
      @lastBulkCallbackTime = null

      # Until getting first data by tailable-cursor
      clearInterval @tailOplogInterval if @tailOplogInterval
      @tailOplogInterval = setInterval =>
        if @tailOplogIntervalProcessing
          @logger.error 'Delay tailOplogInterval'
          return
        @tailOplogIntervalProcessing = true
        if @lastDataTime
          clearInterval @tailOplogInterval
          return
        @pause()
        @getTailOplogs @lastTS, (err, oplogs) =>
          if err
            @logger.error 'Error: getTailOplogs', err
            @resume()
            return done err
          async.eachSeries oplogs, (oplog, done) =>
            eachCallback oplog, (err, filteredLog) =>
              return done err if err
              @oplogs.push filteredLog if filteredLog
              done null
          , (err) =>
            if err
              @logger.error 'Error: eachSeries', err
            @resume()
            @tailOplogIntervalProcessing = false
      , 1000
      # Bulk interval
      clearInterval @bulkInterval if @bulkInterval
      @bulkIntervalProcessing = false
      @bulkInterval = setInterval =>
        if @bulkIntervalProcessing
          @logger.error 'Delay bulkInterval'
          return
        @bulkIntervalProcessing = true
        now = Date.now()
        if @lastDataTime and (now - @lastDataTime) > @config.options.oplogCursorTimeout
          @logger.error 'Cursor broken ?'
          @close()
          unless doneCalled # To care 'end' event
            doneCalled = true
            done null
          return

        if @oplogs.length and (!@lastBulkCallbackTime or (now - @lastBulkCallbackTime) >= @config.options.bulkInterval or @oplogs.length >= @config.options.bulkLimit)
          @lastBulkCallbackTime = now
          @pause()
          @processBulk bulkCallback, (err) =>
            @bulkIntervalProcessing = false
        else
          @bulkIntervalProcessing = false
      , (@config.options.bulkInterval / 10)

      @stream.on 'data', (oplog) =>
        @lastDataTime = Date.now()
        return if @lastTS >= oplog.ts
        @lastTS = oplog.ts
        @pause()

        eachCallback oplog, (err, filteredLog) =>
          if err
            @logger.error 'Error: eachCallback', err
            @resume()
            return
          @oplogs.push filteredLog if filteredLog
          if @oplogs.length >= @config.options.bulkLimit
            @lastBulkCallbackTime = @lastDataTime
            bulkCallback @oplogs, (err) =>
              if err
                @logger.error 'Error: bulkCallback', err
              @clearLogs()
              @resume()
              return
          else
            @resume()

      @stream.on 'end', () =>
        unless doneCalled
          @logger.error 'Cursor closed'
          doneCalled = true
          @close()
          done null

      @stream.on 'error', () =>
        console.log 'stream error'

module.exports = OplogReader
