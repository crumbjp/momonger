_ = require 'underscore'
Config = require 'momonger/config'
Mongo = require 'momonger/mongo'

# TODO: how to give this
configPath = 'config/momonger.conf'
momonger = Config.load configPath

class Base extends Mongo
  constructor: (@ns)->
    # TODO: The case of different instance.
    nss = @ns.split '\.'
    database = nss.shift()
    collection = nss.join '\.'
    super(_.extend {}, momonger, { database, collection })

module.exports = Base
