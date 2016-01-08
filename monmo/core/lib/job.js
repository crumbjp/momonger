function Job(j) {
  this.j = j;
  this.j._job = this;
}

Job.prototype.DEFAULT_TIMEOUT = 600000;
//Job.prototype.DEFAULT_TIMEOUT = 60000;

Job.prototype.init = function(jobcol,srccol,dstcol,args) {
  this.j.JOBCOL = jobcol;
  this.j.SRCCOL = srccol;
  this.j.DSTCOL = dstcol;
  this.j.ARGS   = args;

  this.j.TIMEOUT = this.DEFAULT_TIMEOUT;

  if ( ! this.j.DSTCOL ) {
    this.j.DSTCOL = this.j.empty_dst();
  }
  if ( ! this.j.JOBCOL ) {
    this.j.JOBCOL = this.j.DSTCOL + '.job';
  }

  this.j.src  = utils.getCollection(this.j.SRCCOL);
  this.j.dst  = utils.getWritableCollection(this.j.DSTCOL);
  this.j.wjob = utils.getWritableCollection(this.j.JOBCOL);
  this.j.rjob = utils.getCollection(this.j.JOBCOL);

  this.j.getmeta = function(){
    return utils.getmeta(this.src);
  };

  this.j.getmeta2 = function(){
    return utils.getmeta(this.dst);
  };

  this.j.setmeta = function(meta){
    return utils.setmeta(this.dst,meta);
  };
  this.j.resetmeta = function(meta){
    return utils.resetmeta(this.dst,meta);
  };
  return this;
}

Job.prototype.term = function(ret) {
  return ret;
}

Job.prototype.prepare_create = function() {
  if ( this.j.prepare_create ) {
    return this.j.prepare_create();
  }
  return {ok:1};
}
Job.prototype.create_job = function(){
  return this.j.create_job();
}

Job.prototype.custom_jobdoc = function(jobdoc){
  return jobdoc;
}

Job.prototype.prepare_run = function(){
  if ( this.j.prepare_run ) {
    return this.j.prepare_run();
  }
  return {ok:1};
}

Job.prototype.run = function(){
  var ret = this.j.run();
  return ret;
}
