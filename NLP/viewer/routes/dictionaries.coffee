express = require 'express'
Dictionary = require '../models/dictionary'
router = express.Router()

router.get '/:name', (req, res)->
  name = req.params.name
  res.render 'dictionaries/index',
    name: name

router.get '/:name/:search', (req, res)->
  name = req.params.name
  search = req.params.search
  dictionary = new Dictionary name
  dictionary.init (err)->
    dictionary.find search, (err, words)->
      res.render 'dictionaries/find',
        name: name
        search: search
        words: words

module.exports = router;
