_ = require 'underscore'
async = require 'async'
Mongo = require 'mongo'

JobControl = require 'jobcontrol'
{Job, MapJob, Mapper} = require 'job'

it 'init', (done)->
  @options.chunkSize = 3

  @jobControl = new JobControl @config
  @jobControl.init =>
    @options.src = 'momongertest.src'
    @options.dst = 'momongertest.dst'
    async.series [
      (done) =>
        src = Mongo.getByNS @config, @options.src
        src.drop ->
          src.insert [
            {key: 1, val: 1}
            {key: 2, val: 2}
            {key: 2, val: 2}
            {key: 3, val: 3}
            {key: 3, val: 3}
            {key: 3, val: 3}
            {key: '4', val: 4}
            {key: '4', val: 4}
            {key: '4', val: 4}
            {key: '4', val: 4}
          ], done
    ,
      (done) =>
        dst = Mongo.getByNS @config, @options.dst
        dst.drop (err)->
          done null
    ], done

it 'simple function', (done)->
  main = (config, options, done)->
    class TestJob
      m:
        b: 1.999
        c:
          a: [1,2]
          n: null
          b: true
          u: undefined
        d: new Date()
      constructor: (@config, @options)->
        @member = @options
      run: (done)->
        done null, 'simple function'

    testJob = new TestJob config, options
    testJob.run done
  @jobControl.put main, @options, (err, jobid)=>
    @jobControl.wait jobid, (err, result)->
      expect(result).to.equal 'simple function'
      done null

it 'Job class', (done)->
  class MyJob extends Job
    run: (done)->
      done null, 'MyJob'

  @jobControl.put MyJob, @options, (err, jobid)=>
    @jobControl.wait jobid, (err, result)->
      expect(result).to.equal 'MyJob'
      done null

it 'MapJob class', (done)->
  class MyMapJob extends MapJob
    mapper: ->
      class MyMapper extends Mapper
        map: (value, done)=>
          @dstMongo.insert value
          setTimeout done, 1000

    afterRun: (done)->
      @dstMongo.find().count (err, count)=>
        done null, "MyMapJob::afterRun:#{count}"

  @jobControl.put MyMapJob, @options, (err, jobid)=>
    @jobControl.wait jobid, (err, result)->
      expect(result).to.equal 'MyMapJob::afterRun:10'
      done null

it 'MapReduceJob class', (done)->
  class MyMapReduceJob extends MapJob
    mapper: ->
      class MyMapper extends Mapper
        map: (value, done)=>
          @emit value.key, (value.val * @options.ALPHA)
          setTimeout done, 1000
        reduce: (id, values, done)=>
          ret = 0
          for value in values
            ret += value
          done null, [ret]

    beforeFirstMap: (done)->
      @options.ALPHA = 2
      done null

    afterLastMap: (done)->
      async.series [
        (done) =>
          @emitMongo.find().toArray (err, result)=>
            emitById = _.groupBy result, 'id'
            expect(emitById[1].length).to.equal 1
            expect(emitById[2].length).to.equal 1
            expect(emitById[3].length).to.equal 1
            expect(emitById['4'].length).to.equal 2
            done null
        (done) =>
          @emitidsMongo.find().toArray (err, result)=>
            emitidsById = _.indexBy result, '_id'
            expect(emitidsById['n,1'].ids.length).to.equal 1
            expect(emitidsById['n,2'].ids.length).to.equal 1
            expect(emitidsById['n,3'].ids.length).to.equal 1
            expect(emitidsById['s,4'].ids.length).to.equal 2
            done null
      ], done

    afterRun: (done)->
      @dstMongo.find().toArray (err, result)=>
        resultById = _.indexBy result, 'id'
        expect(resultById[1].value).to.equal 2
        expect(resultById[2].value).to.equal 8
        expect(resultById[3].value).to.equal 18
        expect(resultById['4'].value).to.equal 32
        done null, 'MyMapReduceJob::afterRun'

  @jobControl.put MyMapReduceJob, @options, (err, jobid)=>
    @jobControl.wait jobid, (err, result)->
      expect(result).to.equal 'MyMapReduceJob::afterRun'
      done null
