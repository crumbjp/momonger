MongoDictionary = require './mongo_dictionary'
FileDictionary = require './file_dictionary'

exports.get = (config) ->
  if config.type == 'mongo'
    return new MongoDictionary config[config.type], config['cache']
  else if config.type == 'file'
    return new FileDictionary config[config.type]
  null
