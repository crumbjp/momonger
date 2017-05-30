redis  = require 'redis'
_ = require 'lodash'
common = require '../common'

poolByKey = {}

getRedisClient = (config, done) ->
  key = common.encodeToString(config)
  if poolByKey[key]
    if _.isArray(poolByKey[key])
      return poolByKey[key].push(done)
    else
      return done null, poolByKey[key]
  poolByKey[key] = [done]
  redisClient = redis.createClient config.port, config.host
  poolByKey[key] = redisClient
  redisClient.select config.db, (err) ->
    callbacks = poolByKey[key]
    poolByKey[key] = redisClient
    for callback in callbacks
      callback err, redisClient

class Cache
  constructor: (@config) ->
    @setUp () ->

  setUp: (done) ->
    return done null, null if !@config
    return done null, @redisClient if @redisClient
    getRedisClient @config, (err, @redisClient) =>
      done null, @redisClient

  cacheFetch: (cacheKey, block, done) ->
    @setUp (err, redisClient) =>
      return block done if err or !redisClient
      key = common.encodeToString(cacheKey)
      redisClient.get key, (err, res) =>
        try
          decoded = common.decodeFromString(res) if res
        catch
          decodeError = true
          # Do nothing
        if err or !res or !decoded or decodeError
          return block (err, decoded) =>
            redisClient.setex key, (@config.expire || 600), common.encodeToString(decoded)
            done null, decoded
        done null, decoded

  cacheSet: (cacheKey, data, done) ->
    @setUp (err, redisClient) =>
      return done null if err or !redisClient
      redisClient.setex common.encodeToString(cacheKey), (@config.expire || 600),common.encodeToString(data), (err) ->
        done null

exports.Cache = Cache
