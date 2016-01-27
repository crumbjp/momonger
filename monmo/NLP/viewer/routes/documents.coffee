express = require 'express'
Data = require '../models/data'
Cluster = require '../models/cluster'
mongodb = require 'mongodb'
router = express.Router()

router.get '/:name', (req, res)->
  name = req.params.name
  res.render 'documents/index',
    name: name

router.get '/:name/search/:search', (req, res)->
  name = req.params.name
  search = req.params.search
  data = new Data name
  data.init (err)->
    data.find search, (err, documents)->
      res.render 'documents/list',
        meta: data.meta
        name: name
        search: search
        documents: documents

router.get '/:name/show', (req, res)->
  name = req.params.name
  id = req.query.id
  if /^\$oid:/.test id
    id = mongodb.ObjectId id[5..]
  data = new Data name
  data.init (err)->
    cluster = new Cluster data.meta.kmeans.cluster
    cluster.init (err)->
      cluster.getByDocument id, (err, document, dictionary)->
        res.render 'documents/show',
          meta: data.meta
          name: name
          id: id
          document: document
          dictionary: dictionary

module.exports = router
