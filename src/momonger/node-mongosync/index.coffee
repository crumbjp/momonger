configPath = opts.get('config')
force_tail = opts.get('force-tail')
dryrun = opts.get('dry-run')
loglv = opts.get('loglv')

Sync =
Config = require './config'
config = Config.load configPath


exports.Sync = require './sync'
exports.OplogReader = require './oplog_reader'
