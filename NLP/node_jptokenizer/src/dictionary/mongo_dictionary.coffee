Mongo = require '../mongo'

class MongoDictionary extends Mongo
  nheads: ->
    @meta.nheads

  findBest: (word, done)->
    @col().find
      w: word
    .sort
      s: -1
    .limit 1
    .toArray (err, arr)->
      return done err if err
      done null, arr[0]

  findCandidates: (query, done)->
    @col().find query
    .sort
      l: -1
      s: 1
    .toArray (err, arr)->
      done err, arr

  upsert: (doc, done)->
    @col().findAndModify
      w: doc.w
    ,
      {}
    ,
      $setOnInsert: doc
    ,
      upsert: true
      new: true
    , (err, doc)->
      console.log doc
      done err, doc.value

module.exports = MongoDictionary
