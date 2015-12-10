_ = require 'underscore'
Mongo = require 'mongo'

config = require 'settings'
mongoConfig =
  host: config.mongo.hosts[0].split(':')[0]
  port: config.mongo.hosts[0].split(':')[1]
  collection: config.mongo.basedb
  authdbname: config.mongo.auth?.db
  user: config.mongo.auth?.user
  password: config.mongo.auth?.password

class Base extends Mongo
  constructor: (@ns)->
    nss = @ns.split '\.'
    database = nss.shift()
    collection = nss.join '\.'
    super(_.extend {}, mongoConfig, { database, collection })

module.exports = Base
