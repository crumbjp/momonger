express = require 'express'
router = express.Router()

router.get '/', (req, res) ->
	res.render 'index', {
    name: req.query.name
  }

module.exports = router
