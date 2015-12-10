function Jobctl(dbname){
  this.momonger = utils.getWritableCollection(dbname + '.' + 'momonger.jobs');
  this.done  = utils.getWritableCollection(dbname + '.' + 'momonger.done');
  if ( ! this.momonger.stats().ok ) {
    this.momonger.ensureIndex({tm:1});
  }
}

Jobctl.prototype.load = function(name,src,dst,files,args){

  var jobimpl='';
  try {
    for ( var i in files){
      if ( files[i] ) {
        print(' - Load : ' + files[i]);
        jobimpl += cat(files[i]) + '\n';
      }
    }
  }catch(e){
    throw e;
  }

  this.jobimpl = jobimpl;

  var jobctl = this;
  function momonger_ns(){
    eval(jobimpl);
    main( jobctl , {
      name    : name,
      src     : src,
      dst     : dst,
      args    : args
    });
  }
  momonger_ns();
}

JOB_TYPES = {
  'job'    : Job,
  'map'    : MapJob,
  'reduce' : ReduceJob,
}

Jobctl.prototype.local_jobs = {}

Jobctl.prototype.put_async = function(type,impl,options){
  var strimpl = tojson(impl);
  var job = new JOB_TYPES[type](impl);

  job.init(
    options.name,
    options.src,
    options.dst,
    options.args
  );
  {
    var ret = job.prepare_create();
    if ( ret.ok !== 1 ) {
      printjson(ret);
      return;
    }
  }
  {
    var ret = job.create_job();
    if ( ret.ok !== 1 ) {
      printjson(ret);
      return;
    }
  }
  var jobdoc = job.custom_jobdoc({
    _id   : ObjectId(),
    name    : job.j.JOBCOL,
    src     : job.j.SRCCOL,
    dst     : job.j.DSTCOL,
    args    : job.j.ARGS,
    timeout : job.j.TIMEOUT,
    type    : type,
    impl    : strimpl,
    jobimpl : this.jobimpl,
    start   : ISODate(),
    tm      : 0,
    by      : utils.EMP_NAME()
  });

  job.jobdoc = jobdoc;
  job.jobid = jobdoc._id;
  job.print = job.j.print;

  if (job.j.localrun){
    this.local_jobs[job.jobdoc._id.toString()] = 1
  } else {
    this.momonger.save(jobdoc);
  }
  return job;
}

Jobctl.prototype.waitall = function(jobs){
  var results = {};
  for ( var i in jobs ) {
    var job = jobs[i];
    if (!job){
      continue;
    }
    while ( true ) {
      var ret = this.wait(job);
      if ( ! ret ){
        sleep(300);
        continue;
      }
      ret = job.term(ret);
      results[i] = ret;
      break;
    }
  }
  if ( jobs instanceof Array ) {
    var arr = [];
    for ( var i = 0; i < jobs.length; i++ ){
      arr.push(results[i]);
    }
    return arr;
  }
  return results;
}

Jobctl.prototype.wait = function(job){
  if ( this.local_jobs[job.jobid.toString()] ) {
    delete this.local_jobs[job.jobid.toString()];
    print('== DO JOB local ( '+job.jobid+' ) ==');
    job.jobctl = jobctl;
    var jobdoc = utils.dup(job.jobdoc);
    var ret = job.prepare_run();
    if ( ret.ok !== 1 ) {
      return this.endjob(jobdoc, ret.ok, ret, true);
    }
    ret = job.run();
    return this.endjob(jobdoc, ret.ok, ret, true);
  }

  var ret = this.done.findOne({_id: job.jobid},{jobimpl:0,impl:0});
  if ( ret ) {
    if ( job.print || ret.ok !== 1 ) {
      printjson(ret);
    }
  }
  return ret;
}


Jobctl.prototype.put = function(type, impl, options){
  var job = this.put_async(type, impl, options);
  var results = this.waitall([job]);
  return results[0];
}

//--------------------------
Jobctl.prototype.getjob = function(){
  for ( var i = 0 ; i < 30 ; i++ ) {
    var jobdoc = this.momonger.findAndModify({
      query: {
        tm: 0
      },
      update:{ $set:{
        tm: Number(ISODate()),
        by: utils.getName()
      }},
      new:true
    });
    if ( jobdoc ){
      return jobdoc;
    }
    sleep(700 + Math.random()*300);
  }
  return null;
}

Jobctl.prototype.endjob = function(jobdoc, ok, ret, localrun){
  jobdoc.end = ISODate();
  jobdoc.time = (jobdoc.end - jobdoc.start) / 1000;
  utils.extend(jobdoc, ret);
  jobdoc.ok = ok;
  if ( !localrun ) {
    this.momonger.remove({_id:jobdoc._id});
    this.done.save(jobdoc);
  }
  return jobdoc;
}

Jobctl.prototype.job_lock = function( jobid ){
  print('*** LOCK *** : ' + jobid);
  var jobdoc = this.momonger.findAndModify({
    query: {
      _id: jobid,
      tm : 0
    },
    update: { $set : {
      tm: Number(ISODate()),
      by: utils.getName()
    } },
    new: true
  });
  if ( jobdoc ) {
    return true;
  }
  return false;
}

Jobctl.prototype.job_unlock = function(jobid){
  print('*** UNLOCK *** : ' + jobid);
  this.momonger.update(
    {_id: jobid},
    { $set : {
      tm: 0,
      by: utils.EMP_NAME()
    } }
  );
}

Jobctl.prototype.field_lock = function(jobid, field){
  var query = { _id: jobid };
  query[field] = 0;
  var update = { $set : {} };
  update['$set'][field] = Number(ISODate());
  var jobdoc = this.momonger.findAndModify({
    query: query,
    update: update,
    new: true
  });
  if ( jobdoc ) {
    return true;
  }
  return false;
}

Jobctl.prototype.run = function(){
  var jobdoc = this.getjob();
  if ( ! jobdoc ) {
    return;
  }

  var jobctl = this;
  print('== DO JOB ( '+ jobdoc._id +' ) ==');
  function momonger_ns() {
    try {
      eval(jobdoc.jobimpl);
      var type = jobdoc.type;
      eval('var impl = ' + jobdoc.impl);

      var job = new JOB_TYPES[type](impl);
      job.jobid = jobdoc._id;

      job.init(
        jobdoc.name,
        jobdoc.src,
        jobdoc.dst,
        utils.dup(jobdoc.args)
      );
      job.jobctl = jobctl;
      job.jobdoc = jobdoc;
      var ret = job.prepare_run();
      if ( ret.ok !== 1 ) {
        jobctl.endjob(jobdoc, ret.ok,ret);
        return;
      }

      var ret = job.run();
      if ( ret ) {
        jobctl.endjob(jobdoc, ret.ok,ret);
        return;
      }
    } catch (e){
      jobctl.endjob(jobdoc, -1,{msg : e.toString() , data: e } );
    }
  }
  momonger_ns();
  return;
}
