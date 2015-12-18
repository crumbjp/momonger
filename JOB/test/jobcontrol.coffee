async = require 'async'

JobControl = require '../src/jobcontrol'
{Job} = require 'job'

describe 'js2String', ->

  before ->
    @options =
      runLocal: true
    @jobControl = new JobControl {}
    # Skip init to avoid connecting mongodb

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
