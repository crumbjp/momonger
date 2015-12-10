express = require 'express'
Idf = require 'models/idf'
router = express.Router()

router.get '/:name', (req, res)->
  name = req.params.name
  idf = new Idf name
  idf.init (err)->
    if req.query.del_word
      idf.update req.query.del_word, {$set: {i: 0}}, (err)->
        res.status 200
        res.render 'success'
    else if req.query.del_dic
      idf.update_dictionary req.query.del_dic, {$set: {i: 0}}, (err)->
        res.status 200
        res.render 'success'
    else
      query = {}
      if req.query.deleted
        query = {i: 0}
      idf.list query, (err, idfs, dictionary)->
        res.render 'idfs/index',
          name: name
          search: ''
          idfs: idfs
          dictionary: dictionary

router.get '/:name/:search', (req, res)->
  name = req.params.name
  search = req.params.search
  idf = new Idf name
  idf.init (err)->
    idf.find search, (err, idfs, dictionary)->
      res.render 'idfs/index',
        name: name
        search: search
        idfs: idfs
        dictionary: dictionary

module.exports = router;
