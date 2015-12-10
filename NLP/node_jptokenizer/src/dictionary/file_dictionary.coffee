fs = require 'fs'
sift = require 'sift'
_ = require 'underscore'

groupBy = (elements, field)->
  ret = {}
  for element in elements
    if _.isArray element[field]
      for key in element[field]
        ret[key] ||= []
        ret[key].push element
    else
      ret[element[field]] ||= []
      ret[element[field]].push element
  ret

class FileDictionary
  constructor: (@config)->

  init: (done)->
    body = fs.readFileSync(@config.path).toString()
    @elements = JSON.parse(body)
    for @element in @elements
      if @element._id == '.meta'
        @meta = @element
        break
    unless @meta
      throw Error 'Invalid dictionary: .meta not found'

    @elementsbyW = groupBy @elements, 'w'
    @elementsbyH = groupBy @elements, 'h'
    done null

  nheads: ->
    @meta.nheads

  findBest: (word, done)->
    arr = @elementsbyW[word] || []
    bests = arr.sort (a, b)->
      b.s - a.s
    done null, bests[0]

  findCandidates: (query, done)->
    arr = []
    if query.h
      arr = @elementsbyH[query.h] || []
    else if query.w
      if query.w.$in
        for w in query.w.$in
          arr = arr.concat (@elementsbyW[w] || [])
      else
        arr = @elementsbyW[query.w] || []

    done null, sift(query, arr).sort (a, b)->
      byL = b.l - a.l
      unless byL == 0
        return byL
      a.s - b.s

  upsert: (doc, done)->
    done null, doc

  term: (done)->
    done null

module.exports = FileDictionary
