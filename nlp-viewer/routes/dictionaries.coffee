express = require 'express'
Dictionary = require '../models/dictionary'
router = express.Router()

router.get '/', (req, res)->
  res.render 'dictionaries/index'

router.get '/:search', (req, res)->
  search = req.params.search
  dictionary = new Dictionary()
  dictionary.search search, (err, words)->
    console.log '**', err, words
    res.render 'dictionaries/find',
      search: search
      words: words

module.exports = router;
