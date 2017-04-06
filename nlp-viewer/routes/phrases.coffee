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

module.exports = router;
