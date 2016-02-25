Mongo = require '../mongo'

class MongoDictionary extends Mongo
  nheads: ->
    @meta.nheads

  findBest: (word, done)->
    @find
      w: word
    , (err, cursor)->
      return done err if err
      cursor.sort
        s: -1
      .limit 1
      .toArray (err, arr)->
        return done err if err
        done null, arr[0]

  findCandidates: (query, done)->
    @find query, (err, cursor)->
      return done err if err
      cursor.sort
        l: -1
        s: 1
      .toArray (err, arr)->
        done err, arr

  upsert: (doc, done)->
    @findAndModify
      w: doc.w
    ,
      {}
    ,
      $setOnInsert: doc
    ,
      upsert: true
      new: true
    , (err, doc)->
      done err, doc.value

module.exports = MongoDictionary
