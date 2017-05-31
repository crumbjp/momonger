'use strict'
_ = require 'underscore'
async = require 'async'
{JobControl, Job, MapJob, Mapper} = require 'momonger/job'

class Idf extends MapJob

  beforeFirstMap: (done)->
    @options.query.value =
      $gt: 1
    @srcMongo.getmeta (err, @meta)=>
      done err

  mapper: ->
    class IdfMapper extends Mapper
      beforeRun: (done)=>
        @results = []
        async.series [
          (done) =>
            @srcMongo.getmeta (err, @meta)=>
              done err
          (done) =>
            @dictionaryMongo = new Mongo @meta.dictionary.mongo
            done null
        ], done

      map: (doc, done)=>
        @dictionaryMongo.findOne {_id: doc._id}, (err, word) =>
          return done null unless word

          if @options.noun
            return done null unless '名詞' in word.t
            return done null if '非自立' in word.t # さま
            unless '固有名詞' in word.t
              return done null if '代名詞' in word.t
              return done null if '接尾' in word.t # 枚, 個, ワット,...
              return done null if '副詞可能' in word.t # あした, １月, こんど,...
              return done null if 'NUMBER' in word.t
          if @options.filterNoise
            if word.l <= 2
              return done null if 'NUMBER' in word.t
              conjugates = word.w
              conjugates = [word.w] if _.isString word.w
              isFilterOut = true
              for conjugate in conjugates
                filtered = _.filter conjugate, (char)->
                  code = char.charCodeAt 0
                  #  hira, kata or alpha
                  ( code >= 0x3000 && code <= 0x30ff ) or ( code >= 0xFF00 && code <= 0xFFFF)
                unless filtered.length
                  isFilterOut = false
                  break
              return done null if isFilterOut

          score = Math.log(@meta.num/doc.value)

          if @options.useDictionaryCoefficient
            score *= parseInt(word.i) if word.i? and word.i.length > 0

          @results.push {
            _id: doc._id
            value: score
          }
          done null

      afterRun: (done)->
        @dstMongo.bulkInsert @results, done

  afterLastMap: (done)->
    @meta.idf = @options.dst
    @dstMongo.insert @meta, done

  afterRun: (done) ->
    done null, @meta

module.exports = Idf
