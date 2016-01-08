fs = require 'fs'

exports.load = (file_path)->
  body = fs.readFileSync(file_path).toString()
  JSON.parse(body)
