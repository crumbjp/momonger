'use strict'
_ = require 'underscore'
fs = require 'fs'
async = require 'async'
Mongo = require 'momonger/mongo'

exports.importDocs = (filename, collection, done)->
  json = fs.readFileSync filename, 'utf-8'
  elements = JSON.parse(json)
  for element in elements
    element._id = Mongo.ObjectId element._id.$oid if element._id.$oid
  async.series [
    (done) => collection.drop ->
      done null
    (done) =>
      collection.bulkInsert elements, done
  ], done

exports.toTypeValue = (value) ->
  type = typeof value
  "#{type[0]},#{value}"

exports.encodeToString = encodeToString = (val)->
  if _.isUndefined val
    "U,0,"
  else if _.isNull val
    "N,0,"
  else if _.isDate val
    "D,#{val.valueOf().toString().length},#{val.valueOf().toString()}"
  else if _.isString val
    "S,#{val.valueOf().toString().length},#{val.valueOf().toString()}"
  else if _.isNumber val
    "F,#{val.valueOf().toString().length},#{val.valueOf().toString()}"
  else if _.isBoolean val
    "B,#{val.valueOf().toString().length},#{val.valueOf().toString()}"
  else if _.isObject val
    if _.isArray val
      body = ''
      for v in val
        body += encodeToString v
      "A,#{body.length},#{body}"
    else if val instanceof Mongo.ObjectId
      "O,#{val.toString().length},#{val.toString()}"
    else
      body = ''
      for k, v of val
        unless _.isFunction v
          body += encodeToString [k, v]
      "H,#{body.length},#{body}"

exports.decodeFromString = decodeFromString = (str, returnIndex)->
  return unless str
  ret = undefined

  [type, len] = str.split ',', 2
  len = parseInt(len)
  head = 1 + str.indexOf ',', 2
  pos = head + len
  body = str[head..(pos-1)]

  if type == 'U'
    ret = undefined
  else if type == 'N'
    ret = null
  else if type == 'D'
    ret = new Date(parseInt(body))
  else if type == 'S'
    ret = body
  else if type == 'F'
    ret = parseFloat body
  else if type == 'B'
    ret = body == 'true'
  else if type == 'A'
    ret = []
    while body.length
      [v, i] = decodeFromString body, true
      body = body[i..]
      ret.push v
  else if type == 'O'
    ret = Mongo.ObjectId body
  else if type == 'H'
    ret = {}
    while body.length
      [tuple, i] = decodeFromString body, true
      body = body[i..]
      ret[tuple[0]] = tuple[1]
  else
    throw "decodeFromString error #{str[0..10]}"

  if returnIndex
    [ret, pos]
  else
    ret

exports.addVector = addVector = (vec1, vec2)->
  ret = {}
  for k, v of vec1
    ret[k] = v
  for k, v of vec2
    if ret[k]?
      ret[k] += v
    else
      ret[k] = v
  ret

exports.divVector = divVector = (vec1, div)->
  ret = {}
  for k, v of vec1
    ret[k] = v / div
  ret

exports.multiVector = multiVector = (vec1, multi)->
  ret = {}
  for k, v of vec1
    ret[k] = v * multi
  ret

exports.diffVector = diffVector = (vec1, vec2)->
  pow2 = (v)->
    v * v
  dist = 0
  for k, v of vec1
    if vec2[k]
      dist += pow2(v - vec2[k])
    else
      dist += pow2(v)
  for k, v of vec2
    unless vec1[k]
      dist += pow2(v)
  Math.sqrt dist

exports.diffAngle = diffAngle = (vec1, vec2)->
  dist = 0
  for k, v of vec1
    if vec2[k]
      dist += v * vec2[k]
  1 - dist

exports.normalVector = normalVector = (vec) ->
  distance = 0
  for k, v of vec
    distance += v * v
  normal = Math.sqrt distance
  divVector vec, normal
