_ = require 'underscore'
express = require 'express'
path = require 'path'
cookieParser = require 'cookie-parser'
bodyParser = require 'body-parser'

routes = require './routes/index'

app = express()

# view engine setup
views_path = path.join(__dirname, 'views')
app.set 'views', views_path
app.set 'view engine', 'ejs'

app.use bodyParser.json()
app.use bodyParser.urlencoded({ extended: false })
app.use cookieParser()
app.use express.static(path.join(__dirname, 'public'))

app.use '/', routes
app.use '/clusters', require('./routes/clusters')
app.use '/phrases', require('./routes/phrases')
app.use '/dictionaries', require('./routes/dictionaries')
app.use '/documents', require('./routes/documents')
app.use '/idfs', require('./routes/idfs')


fs = require 'fs'
ejs = require 'ejs'

app.locals.render_partial = (partial, args)->
  data = fs.readFileSync "#{views_path}/#{path.dirname(partial)}/_#{path.basename(partial)}.ejs", 'utf8'
  ejs.render data, args

app.locals._id_link = (_id)->
  return "$oid:#{_id}" if _id._bsontype == 'ObjectID'
  _id

# catch 404 and forward to error handler
app.use (req, res, next)->
  err = new Error 'Not Found'
  err.status = 404
  next err

# error handlers

# development error handler
# will print stacktrace
if app.get 'env' == 'development'
  app.use (err, req, res, next)->
    res.status err.status || 500
    res.render 'error', {
      message: err.message
      error: err
    }

# production error handler
# no stacktraces leaked to user
app.use (err, req, res, next)->
  res.status err.status || 500
  res.render 'error', {
    message: err.message
    error: {}
  }

process.on 'uncaughtException', (err) ->
  console.log 'Caught exception: ' + err

module.exports = app
console.log 'START viewer'
