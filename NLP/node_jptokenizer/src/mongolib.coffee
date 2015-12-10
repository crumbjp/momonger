fs = require 'fs'
path = require 'path'

libpath = path.resolve(__dirname + '/mongolib')

eval fs.readFileSync("#{libpath}/morpho.js").toString()
exports.morpho = morpho

eval fs.readFileSync("#{libpath}/jptokenizer.js").toString()
exports.JPTokenizer = JPTokenizer
