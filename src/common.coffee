'use strict'
_ = require 'underscore'
Mongo = require 'mongo'

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
