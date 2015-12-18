'use strict'
_ = require 'underscore'

class Js2String
  constructor: (@js)->
    @random = Math.random() * 10000000000000000000
    @functionByName = {}
    @objects = []
    @strObjects = "var objects#{@random} = {}\n"

  convert: ->
    src = @js2String @js
    if _.isFunction(@js) and @js.name
      "#{@strObjects}\n#{src}"
    else
      "function(){#{@strObjects}\nreturn #{src}}()"


  js2String: (current)->
    if _.isFunction current
      if current.name
        if @functionByName[current.name]
          current.name
        else
          @functionByName[current.name] = current
          @function2String current
      else
        @function2String current
    else if _.isUndefined current
      'undefined'
    else if _.isNull current
      'null'
    else if _.isDate current
      "new Date(#{current.valueOf()})"
    else if _.isString current
      "'#{current}'"
    else if _.isNumber current
      current.toString()
    else if _.isBoolean current
      current.toString()
    else if _.isObject current
      idx = @objects.indexOf(current)
      if idx < 0
        idx = @objects.length
        @objects.push current
        str = @object2String current
        @strObjects += "objects#{@random}[#{idx}] = #{str}\n"
      "objects#{@random}[#{idx}]"

  object2String: (js)->
    if _.isArray js
      body = '['
      for v in js
        body += "#{@js2String v},"
      body += ']'
      body
    else
      body = '{'
      for k, v of js
        body += "#{k}: #{@js2String v},"
      body += '}'
      body

  function2String: (js)->
    body = "#{js.toString()}"
    # for coffee class
    if js.__super__
      body += '\n'
      body += @function2String js.__super__.constructor
      body += "#{js.name}.__super__ = #{@object2String js.__super__}\n"
      body += "#{js.name}.__super__.constructor = #{@function2String js.__super__.constructor.name}\n"
    # TODO: How to treat nameless function's prototype ? Impossible maybe..
    if js.name
      for field, value of js.prototype
        body += "#{js.name}.prototype['#{field}'] = #{@js2String value}\n"
    body



module.exports = (js)->
  js2string = new Js2String js
  js2string.convert()
