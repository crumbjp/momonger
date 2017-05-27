express = require 'express'
router = express.Router()
Base = require 'models/base'

router.get '/', (req, res) ->
  unless req.query.name
    return res.render 'index', {
      name: null
      meta: null
    }

  base = new Base req.query.name
  base.getmeta (err, meta) =>
    console.log meta
    res.render 'index', {
      name: req.query.name
      meta: meta
    }

module.exports = router
