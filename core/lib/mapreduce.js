function async_mapreduce ( jobctl , org_options , j ) {
  var options = utils.dup(org_options);
  var unique_post_run = j.unique_post_run;
  if ( ! ('field' in j) ) {
    j.field = 'value';
  }
  j.reduce_field = j.field

  if (j.localrun){
    j.single_worker = true;
  }
  if ( j.single_worker ) {
    var job = jobctl.put_async( 'map',j ,options);
    return job;
  } else{
    delete(j.unique_post_run);
    var job = jobctl.put_async( 'map',j ,options);
    job._options = options;
    job._unique_post_run = unique_post_run;
    job._reduce = function (r) {
      this._options.dst = r.dst;
      this._options.src = r.emitjob;
      this._options.args.emit = r.emit;
      return jobctl.put_async( 'reduce',{
        print: j.print,
        single_worker: j.single_worker,
        localrun: j.localrun,
        prepare_run : this.j.prepare_run,
        reduce : this.j.reduce,
        unique_post_run : this._unique_post_run,
        field : this.j.field,
      } ,this._options);
    }
    return job;
  }
}

function wait_mapreduce ( jobctl , jobs ) {
  var single_workers = {}
  var reduce_jobs = {};
  for ( var i in jobs ) {
    var job = jobs[i];
    if (!job){
      continue;
    }
    while ( true ) {
		  var ret = jobctl.wait(job);
      if ( ! ret ) {
        sleep(300);
        continue;
      }
      job._ret = job.term(ret);
      if (job._reduce ) {
        reduce_jobs[i] = job._reduce(ret);
      } else {
        single_workers[i] = ret;
      }
      break;
    }
  }
  var results = jobctl.waitall(reduce_jobs);

  var col = null;
  for ( var i in jobs ) {
    var job = jobs[i];
	  if ( ! job.j.direct ) {
      col = utils.getWritableCollection(job._ret.job);
      if ( col ) { col.drop(); }
    }
    col = utils.getWritableCollection(job._ret.emitjob);
    if ( col ) { col.drop(); }
    col = utils.getWritableCollection(job._ret.emit);
    if ( col ) { col.drop(); }
  }

  for ( var i in results ) {
    var result = results[i];
    col = utils.getWritableCollection(result.emit);
    if ( col ) { col.drop(); }
    col = utils.getWritableCollection(result.emitjob);
    if ( col ) { col.drop(); }
  }
  for ( var i in single_workers ) {
    results[i] = single_workers[i];
  }
  return results;
}

function mapreduce ( jobctl , org_options , j ) {
  var job = async_mapreduce(jobctl, org_options, j );
  var ret = wait_mapreduce(jobctl, {j: job});
  return ret.j;
}

function ReduceJob(j) {
  var MAX_VALUES = 1000;
	var reducejob = new MapJob({
    print: j.print,
    single_worker: j.single_worker,
    localrun: j.localrun,
    append: true,
    _prepare_run: j.prepare_run,
		prepare_run : function(){
      this.remit = utils.getCollection(this.ARGS.emit);
      if ( this._prepare_run ) {
        return this._prepare_run();
      }
      return {ok:1};
		},
		map : function(id,doc){
      var _cursor = this.remit.find({ k : id }).addOption(DBQuery.Option.noTimeout);
      var curK = null;
      var curV = null;
		  while ( _cursor.hasNext()){
        var m = _cursor.next();
        if ( curK === null ) {
          curK = m.k;
          curV = m.v;
        }else {
          curV = curV.concat(m.v)
          if ( curV.length >= MAX_VALUES ) {
            curV = [this.reduce(curK,curV)];
          }
        }
      }
      var doc = {};
      if ( this.reduce_field === '' ) {
        doc = this.reduce(curK,curV,true);
        if ( ! doc._id ) {
          doc._id =  curK;
        }
      }else {
        doc[this.reduce_field] = this.reduce(curK,curV,true);
        doc._id =  curK;
      }
      doc.tm  = 0;
      this.dst.save(doc);
		},
    reduce : j.reduce,
    unique_post_run : j.unique_post_run,
    reduce_field : j.field,
    direct : true
  });
  return reducejob;
}
