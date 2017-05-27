'use strict'
_ = require 'underscore'
async = require 'async'
Config = require 'momonger/config'
Mongo = require 'momonger/mongo'
{JobControl, Job, MapJob, Mapper} = require 'momonger/job'

class Phrase extends Job
  beforeRun: (done)->
    async.series [
      (done) => @_dropDestination done
      (done) => @dstMongo.createIndex {n: 1}, {w: 1, j: 1, wtimeout: 3600000}, done
      (done) => @dstMongo.createIndex {ws: 1}, {w: 1, j: 1, wtimeout: 3600000}, done
    ], done

  run: (done)->
    class PhraseCandidate extends Job
      beforeRun: (done)->
        @srcMongo.getmeta (err, @meta)=>
          @dictionaryMongo = new Mongo @meta.dictionary.mongo
          done null
      getSource: (done)->
        @srcMongo.find @options.query, (err, cursor) =>
          cursor.sort
            i:1
          .toArray done
      getElement: (words, done)->
        @dictionaryMongo.findAsArray
          _id:
            $in: _.map(words, (w)-> w.c)
        , done

      buildPhrase: (arr)=>
        return unless arr.length >= 2
        _id = ''
        phrase =
          $inc:
            df: 1
            tf: 1
          $set:
            n: arr.length
            tcv: 0  # C-Value
            dcv: 0  # C-Value
            itf: 0
            idf: 0
            c: 0
            ws: []
            cs: []
        for a in arr
          phrase.$set.ws.push a.w
          phrase.$set.cs.push a.c
          _id += a.w

        head = _id.charCodeAt(0)
        tail = _id.charCodeAt(_id.length - 1)
        return if (0x3040 <= head) and (head <= 0x309f) or (0x3040 <= tail) and (tail <= 0x309f)
        if @updatePhraseById[_id]
          @updatePhraseById[_id][1].$inc.tf += 1
        else
          @updatePhraseById[_id] = [{_id}, phrase]

      run: (done)->
        @updatePhraseById = {}
        current = []
        @getSource (err, words)=>
          return done err if err
          @getElement words, (err, elements) =>
            return done err if err
            elementById = _.indexBy elements, '_id'
            for word in words
              word.dic = elementById[word.c]

              if (_.intersection word.dic.t, ['記号','NUMBER','EN','外来','DATE']).length
                current = []
                continue
              if current.length == 0
                current.push word
              else if current[(current.length - 1)].i == (word.i - 1)
                current.push word
              else
                current = [word]
              if current.length > @options.n
                current.shift()
              if current.length >= 2
                for i in [1..(@options.n-2)]
                  @buildPhrase current[i..-1]
                @buildPhrase current
            @dstMongo.bulkUpdate _.values(@updatePhraseById) , (err)->
              done err

    class PhraseCValue extends MapJob
      mapper: ->
        class PhraseCValueMapper extends Mapper
          map: (doc, done)=>
            c = doc.c || 1
            tfVal = doc.tf - doc.itf / c
            dfVal = doc.df - doc.idf / c
            tcv = Math.log(doc.n) * tfVal if doc.tf > 1
            dcv = Math.log(doc.n) * dfVal if doc.df > 1
            @emit doc._id,
              tcv: tcv
              dcv: dcv
            if doc.n > 2
              for _id in [doc.ws[0..-2].join(''), doc.ws[1..].join('')]
                @emit _id,
                  c: 1
                  itf: tfVal
                  idf: dfVal
            done null

          reduce: (id, array, done)->
            value = {
              c: 0
              itf: 0
              idf: 0
            }
            for a in array
              if a.tcv
                value.tcv ||= a.tcv
                value.dcv ||= a.dcv
              if a.c
                value.c += a.c
                value.itf += a.itf
                value.idf += a.idf
            done null, value

          lastFormat: (value)=>
            if value.value.tcv?
              value.$set ||=
                tcv: value.value.tcv
                dcv: value.value.dcv
            if value.value.c
              value.$inc ||=
                c: value.value.c
                itf: value.value.itf
                idf: value.value.idf
            delete value.value
            _id = value.id
            delete value.id
            [{_id}, value, true]

    @srcMongo.distinct 'd', (err, ds)=>
      jobids = null
      #ds = [ds[1], ds[2], ds[3]] #TODO: ***
      async.series [
        (done) =>
          jobids = []
          async.each ds, (d, done)=>
            return done null unless d
            options = _.extend {}, @options, {
              query: {d}
            }
            @jobcontrol.put PhraseCandidate, options, (err, jobid)=>
              return err if err
              jobids.push jobid
              done null
          , done
        (done) =>
          async.eachSeries jobids, (jobid, done)=>
            @jobcontrol.wait jobid, done
          , done
        (done) =>
          async.eachSeries [@options.n..2], (n, done) =>
            options = _.extend {}, @options, {
              src: @options.dst
              query: {n}
              appendDst: true
            }
            @jobcontrol.put PhraseCValue, options, (err, jobid)=>
              return err if err
              @jobcontrol.wait jobid, done
          , done
      ], (err) =>
        return done err if err
        @srcMongo.getmeta (err, meta)=>
          meta.phrase =
            n: @options.n
            ns: @options.dst
          @dstMongo.insert meta, (err)->
            done err, meta


module.exports = Phrase
