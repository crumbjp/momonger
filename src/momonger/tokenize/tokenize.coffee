'use strict'

_ = require 'underscore'
async = require 'async'
Mongo = require 'momonger/mongo'
{JobControl, Job, MapJob, Mapper} = require 'momonger/job'

class Tokenize extends MapJob
  constructor: (@jobcontrol, @jobid, @config, @options)->
    super @jobcontrol, @jobid, @config, @options
    if @options.append
      @options.appendDst = true
      @options.query.a = @options.append
    @options.tokenizerOpts ||=
      includeUnknownToken: true
  mapper: ->
    class TokenizeMapper extends Mapper
      beforeRun: (done) =>
        @JPTokenizer = require 'momonger/node-jptokenizer'
        done null

      map: (doc, done)=>
        @emit '.meta', 1 unless @options.append?
        jptokenizer = new @JPTokenizer @options.dictionary, @options.tokenizerOpts
        jptokenizer.modifier = (result, candidate, done)->
          return done null, null if '不明' in candidate.t
          return done null, null if '記号' in candidate.t
          done null, result

        jptokenizer.init (err) =>
          return done err if err
          data = ''
          for field in @options.fields
            data += doc[field] + ' '
          jptokenizer.parse_doc data, (err, tokens)=>
            return done err if err
            synonyms = []
            results = []
            for token in tokens
              results.push {
                d: doc._id
                i: token.i
                p: token.p
                w: token.w
                c: token.c
                a: @options.append
              }
              if token.sy
                Array.prototype.push.apply synonyms, _.compact(token.sy)
            async.series [
              (done) =>
                return done null if synonyms.length == 0
                dic_by_w = {}
                async.eachSeries _.uniq(synonyms), (synonym, done) =>
                  jptokenizer.dictionary.findBest synonym, (err, word) =>
                    dic_by_w[synonym] = word
                    done null
                , (err) =>
                  cur_i = _.last(tokens).i
                  for synonym in synonyms
                    dic = dic_by_w[synonym]
                    if dic
                      cur_i++
                      results.push {
                        d: doc._id
                        i: cur_i
                        p: -1
                        w: dic.w
                        c: dic._id
                        a: @options.append
                      }
                  done err
              (done) =>
                return done null unless @options.append?
                @dstMongo.remove {d: doc._id}, done
              (done) => @dstMongo.bulkInsert results, done
            ], done


      reduce: (id, array, done)=>
        ret = 0
        for elem in array
          ret += elem
        done null, ret

      lastFormat: (value)=>
        {
          _id: '.meta'
          num: value.value
        }
  beforeFirstMap: (done) ->
    async.parallel [
      (done) => @dstMongo.createIndex {d: 1, i: 1}, {w: 1, j: 1, wtimeout: 3600000}, done
      (done) => @dstMongo.createIndex {a: 1}, {w: 1, j: 1, wtimeout: 3600000}, done
    ], done

  afterRun: (done)->
    JPTokenizer = require 'momonger/node-jptokenizer'
    jptokenizer = new JPTokenizer @options.dictionary
    meta =
      docs: @options.src
      token: @options.dst
      fields: @options.fields
      dictionary: @options.dictionary
    @dstMongo.update {_id: '.meta'}, {$set: meta}, {upsert: false}, (err) ->
      done err, meta

module.exports = Tokenize
