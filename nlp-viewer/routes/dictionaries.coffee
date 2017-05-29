express = require 'express'
Dictionary = require '../models/dictionary'
mongodb = require 'mongodb'
router = express.Router()

router.get '/', (req, res)->
  res.render 'dictionaries/index',
    search: '',
    words: []

router.get '/update', (req, res)->
  dictionary = new Dictionary()
  if req.query.update_sy
    sy = req.query.val.split(' ')
    dictionary.updateById req.query.update_sy, {$set: {sy: sy}}, (err)->
      for s in sy
        dictionary.put s, null, ()->
  if req.query.update_boost
    i = req.query.val
    dictionary.updateById req.query.update_boost, {$set: {i: i}}, (err)->
  if req.query.del_word
    dictionary.remove {_id: mongodb.ObjectId req.query.del_word}, (err)->

  res.status 200
  res.render 'success'

router.get '/:search', (req, res)->
  search = req.params.search
  dictionary = new Dictionary()
  if req.query.id
    dictionary.get [req.query.id], (err, words)->
      res.render 'dictionaries/index',
        search: ''
        words: words
  else
    dictionary.search search, (err, words)->
      res.render 'dictionaries/index',
        search: search
        words: words

module.exports = router;
