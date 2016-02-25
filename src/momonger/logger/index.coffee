class Logger
  constructor: (loglv) ->
    @definition =
      error:   20
      info:    40
      verbose: 60
      trace:   80
      debug:   100
    @setLoglv loglv

  setLoglv:  (loglv) ->
    @lv = @definition[loglv]
    @lv ||= @definition['info']

  log: (loglv, args...)->
    return if @definition[loglv] > @lv
    console.log "[#{loglv}]:", args...

  error: (args...)->
    @log 'error', args...
  info: (args...)->
    @log 'info', args...
  verbose: (args...)->
    @log 'verbose', args...
  trace: (args...)->
    @log 'trace', args...
  debug: (args...)->
    @log 'debug', args...

module.exports = Logger
