express = require 'express'
Dictionary = require '../models/dictionary'
router = express.Router()

router.get '/', (req, res)->
  res.render 'dictionaries/index',
    search: '',
    words: []

router.get '/update', (req, res)->
  sy = req.query.sy.split(' ')
  dictionary = new Dictionary()
  dictionary.updateById req.query.update_dic, {$set: {sy: sy}}, (err)->
    res.status 200
    res.render 'success'
    for s in sy
      dictionary.put s, null, ()->

router.get '/:search', (req, res)->
  search = req.params.search
  dictionary = new Dictionary()
  dictionary.search search, (err, words)->
    res.render 'dictionaries/index',
      search: search
      words: words

module.exports = router;
