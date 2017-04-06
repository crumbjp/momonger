express = require 'express'
Cluster = require '../models/cluster'
router = express.Router()

router.get '/:name', (req, res)->
  name = req.params.name
  if name
    cluster = new Cluster name
    cluster.clusters null, (err, clusters, dictionary)->
      return res.render 'clusters/index',
        name: name
        clusters: clusters
        dictionary: dictionary
        meta: cluster.meta

router.get '/:name/:cluster_id', (req, res)->
  name = req.params.name
  cluster_id = req.params.cluster_id
  if name && cluster_id
    cluster = new Cluster name
    cluster.cluster cluster_id, (err, c, documents, dictionary)->
      return res.render 'clusters/show',
        name: name
        cluster: c
        documents: documents
        dictionary: dictionary
        meta: cluster.meta

module.exports = router;
