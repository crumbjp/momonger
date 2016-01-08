'use strict'
_ = require 'underscore'

DEFAULT_PROPERTIES = [
  '__defineGetter__'
  '__defineSetter__'
  '__lookupGetter__'
  '__lookupSetter__'
  'constructor'
  'hasOwnProperty'
  'isPrototypeOf'
  'propertyIsEnumerable'
  'toLocaleString'
  'toString'
  'valueOf'
  'apply'
  'arguments'
  'bind'
  'call'
  'caller'
  'length'
  'name'
  '__super__'
  'prototype'
]
class Js2String
  constructor: (@js)->
    @random = Math.random() * 10000000000000000000
    @functionByName = {}
    @objects = []
    @strObjects = "var objects#{@random} = {}\n"

  convert: ->
    src = @js2String @js
    if _.isFunction(@js) and @js.name
      coffeeImpl = 'var extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },\n'
      coffeeImpl += 'hasProp = {}.hasOwnProperty,\n'
      coffeeImpl += 'bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },\n'
      coffeeImpl += 'indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };\n'
      "#{coffeeImpl}#{@strObjects}\n#{src}"
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
      for field, value of js
        continue if field in DEFAULT_PROPERTIES
        body += "#{js.name}['#{field}'] = #{@js2String value}\n"
      for field, value of js.prototype
        body += "#{js.name}.prototype['#{field}'] = #{@js2String value}\n"
    body

module.exports = (js)->
  js2string = new Js2String js
  js2string.convert()
