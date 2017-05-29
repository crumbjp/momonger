'use strict'
Dictionary = require './dictionary'
mongolib = require './mongolib'

class JPTokenizer
  constructor: (config, options)->
    options ||= {includeUnknownToken: true}
    @dictionary = Dictionary.get config
    self = this
    dst = {
      save: (token, candidate, done)->
        self.modifier token, candidate, (err, result)->
          return done null if err or !result
          self.results.push result
          done null
      finish: (done)->
        done null
    }
    @impl = new mongolib.JPTokenizer @dictionary, dst, options,
      async: require 'async'
      morpho: mongolib.morpho

  init: (done)->
    @dictionary.init (err) =>
      @dictionary.getmeta done

  modifier: (result, candidate, done)->
    result.candidate = candidate
    done null, result

  parse_doc: (sentence, done)->
    @results = []
    @impl.parse_doc null, sentence, (err)=>
      done err, @results

  term: (done)->
    unless done
      done = ->

    @dictionary.term done

module.exports = JPTokenizer
