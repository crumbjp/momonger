express = require 'express'
Phrase = require '../models/phrase'
router = express.Router()

router.get '/:name', (req, res)->
  name = req.params.name
  if name
    phrase = new Phrase name
    phrase.init (err)->
      if req.query.new_word
        phrase.put req.query.new_word, (err)->
          res.status 200
          res.render 'success'
      else if req.query.del_word
        phrase.del req.query.del_word, (err)->
          res.status 200
          res.render 'success'
      else
        phrase.get (err, phrases)->
          return res.render 'phrases/index',
            name: name
            phrases: phrases

router.get '/:name/:search', (req, res)->
  name = req.params.name
  search = req.params.search
  phrase = new Phrase name
  phrase.init (err)->
    phrase.search search, (err, phrases, dictionary)->
      res.render 'phrases/index',
        name: name
        search: search
        phrases: phrases

module.exports = router;
