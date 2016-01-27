function map ( jobctl , org_options , j ) {
  var options = utils.dup(org_options);
  var ret = jobctl.put( 'map',j ,options);
  var col = null;
  if ( ! j.direct ) {
    col = utils.getWritableCollection(ret.job);
    if ( col ) { col.drop(); }
  }
  col = utils.getWritableCollection(ret.emit);
  if ( col ) { col.drop(); }
  col = utils.getWritableCollection(ret.emitjob);
  if ( col ) { col.drop(); }
  return ret;
}

function MapJob (j) {
  var MAX_VALUES = 20;
  var SUBJOB_COMMIT = 1000;
  var MAX_TMP    = 500;
  if (j.localrun){
    j.single_worker = true;
  }
  var mapjob = new Job(j);
  mapjob.prepare_create = function(){
    if ( ! j.append ) {
      this.j.dst.drop();
    }

    if ( j.direct ) {
      this.j.JOBCOL = this.j.SRCCOL;
    }

    if ( this.j.prepare_create ) {
      return this.j.prepare_create();
    }
    return {ok:1};
  }

  mapjob.create_job = function(){
    // Initialize JOB collections
    if ( j.direct ) {
      this.j.wjob = utils.getWritableCollection(this.j.JOBCOL);
      this.j.rjob = utils.getCollection(this.j.JOBCOL);
    }else{
      this.j.wjob.drop();
    }
    this.j.wjob.ensureIndex({tm:1});
    // Initialize EMIT collections
    this.jobcol = this.j.JOBCOL;
    this.emitcol = this.j.JOBCOL+'.emit';
    this.j.wemit = utils.getWritableCollection(this.emitcol);
    this.j.wemit.drop();
    this.j.wemit.ensureIndex({k:1});
    this.emitjobcol = this.j.JOBCOL+'.emit.job';

    this.j.wkeys = utils.getWritableCollection(this.emitjobcol);
    this.j.wkeys.drop();

    // Create job
    if ( ! j.direct ) {
      var _cursor = this.map_cursor().addOption(DBQuery.Option.noTimeout);
      var wjobBulk = null;
      var bulkDoc = null;
      while ( _cursor.hasNext()){
        var doc = _cursor.next();
        var _id = utils.getField(doc,this.map_field());
        // this.j.wjob.insert(doc);
        if ( this.j.bulk ) {
          if ( ! bulkDoc ){
            bulkDoc = {
              _ids: [],
              by: utils.EMP_NAME(),
              tm: 0
            }
          }
          bulkDoc._ids.push(_id);
          if ( bulkDoc._ids.length > this.j.bulk ) {
            this.j.wjob.insert(bulkDoc);
            bulkDoc = null
          }
        } else {
          if ( ! wjobBulk ){
            wjobBulk = this.j.wjob.initializeOrderedBulkOp();
          }
          wjobBulk.find({_id: _id}).upsert().replaceOne({
            _id: _id,
            by: utils.EMP_NAME(),
            tm: 0
          });
          if ( wjobBulk.nInsertOps > 1000 ) {
            wjobBulk.execute({w:0});
            wjobBulk = null;
          }
        }
      }
      if ( wjobBulk ) {
        wjobBulk.execute({w:0});
        wjobBulk = null;
      }
      if ( bulkDoc ) {
        this.j.wjob.save(bulkDoc);
        bulkDoc = null
      }
    }
    if ( this.j.post_create ) {
      return  this.j.post_create();
    }
    return {ok:1};
  }

  mapjob.custom_jobdoc = function(jobdoc){
    jobdoc['unique_pre_run']  = 0;
    jobdoc['unique_post_run'] = 0;
    jobdoc['job']      = this.jobcol;
    jobdoc['emit']     = this.emitcol;
    jobdoc['emitjob']  = this.emitjobcol;
    return jobdoc;
  }

  mapjob._reset_tmp = function () {
    this.j._ntmp = 0;
    this.j._tmp = {};
  }

  mapjob.prepare_run = function(){
    this.j.wemit = utils.getWritableCollection(this.jobdoc.emit);
    this.j.remit = utils.getCollection(this.jobdoc.emit);
    this.j.wkeys = utils.getWritableCollection(this.jobdoc.emitjob);

    var THIS = this;
    this.j.emit    = function( k,v) {
      THIS.emit(k,v);
    }
    this._reset_tmp();

    if ( this.j.prepare_run ) {
      return this.j.prepare_run();
    }
    return {ok:1};
  }

  mapjob.emit = function ( orgK, v ) {
    var k = utils.encode(orgK);
    if ( ! this.j._tmp[k] ) {
      this.j._tmp[k] = [];
      this.j._ntmp++;
    }
    this.j._tmp[k].push(v);
    if ( !this.j.single_worker && this.j._ntmp >= MAX_TMP ) {
      this._comb();
    }else if ( this.j._tmp[k].length >= MAX_VALUES ) {
      this.j._tmp[k] = [this.j.reduce(orgK, this.j._tmp[k])];
    }
  }

  mapjob._comb = function (last ) {
    for( var k in this.j._tmp ) {
      var orgK = utils.decode(k);
      if ( this.j._tmp[k].length > 1 ) {
        this.j._tmp[k] = [this.j.reduce(orgK, this.j._tmp[k])];
      }
      if ( this.j.single_worker ) {
        continue;
      }

      if ( ! this.wemitBulk ) {
        this.wemitBulk = this.j.wemit.initializeOrderedBulkOp();
      }
      this.wemitBulk.insert({
        k: orgK,
        v: this.j._tmp[k]
      });
      if ( last || this.wemitBulk.nInsertOps > 1000 ) {
        this.wemitBulk.execute({w:0});
        this.wemitBulk = null;
      }

      if ( ! this.wkeysBulk ) {
        this.wkeysBulk = this.j.wkeys.initializeUnorderedBulkOp();
      }
      this.wkeysBulk.insert({
        _id : orgK,
        tm : 0,
        by : utils.EMP_NAME(),
      });
      if ( last || this.wkeysBulk.nInsertOps > 1000 ) {
        this.wkeysBulk.execute({w:0});
        this.wkeysBulk = null;
      }
    }
    if ( this.j.single_worker && last ) {
      var bulk  = this.j.dst.initializeOrderedBulkOp();
      for( var k in this.j._tmp ) {
        var doc = {}
        var orgK = utils.decode(k);
        if ( this.j.reduce_field === '' ) {
          doc = this.j.reduce(orgK, this.j._tmp[k], true);
          if ( ! doc._id ) {
            doc._id =  orgK;
          }
        } else {
          doc[this.j.reduce_field] = this.j.reduce(orgK, this.j._tmp[k], true);
          doc._id = orgK;
        }
        doc.tm  = 0;
        bulk.insert(doc);
      }
      bulk.execute({w:0});
    }
    if ( !this.j.single_worker || last ) {
      this._reset_tmp();
    }
  }

  mapjob.job_lock = function(){
    return this.jobctl.job_lock(this.jobid);
  }

  mapjob.job_unlock = function(){
    return this.jobctl.job_unlock(this.jobid);
  }

  mapjob.run = function(){
    if ( this.j.single_worker ) {
      print('*** single worker mode');
      this.waitfor = function() { }
      this.job_unlock = function() { }
      this.job_lock = function() { return true; }
      this.jobctl.field_lock = function() { return true; }
    }
    if ( this.jobctl.field_lock(this.jobid, 'unique_pre_run') ) {
      if ( this.j.unique_pre_run ) {
        var ret = this.j.unique_pre_run();
        if ( ret.ok !== 1 ) {
          return ret;
        }
      }
    }
    this.job_unlock();

    var subids = [];
    while (true){
      var subjob = this.getsub();
      if ( ! subjob ) {
        break;
      }
      if ( this.j.pre_map ) {
        this.j.pre_map();
        this.j.pre_map = null;
      }

      if ( !this.j.direct && this.j.bulk ) {
        var q = {};
        q[this.map_field()] = { $in: subjob._ids }
        var vals = this.j.src.find(q).toArray();
        for ( var i in vals ) {
          var val = vals[i];
          this.j.map(val[this.map_field()], val);
        }
      } else {
        var val = this.map_data(subjob._id,subjob);
        this.j.map(subjob._id,val);
      }

      if ( subids.length >= SUBJOB_COMMIT ) {
        this.endsubs(subids);
        subids = [];
      }
      subids.push(subjob._id);
    }
    this._comb(true);
    this.endsubs(subids);

    if ( this.job_lock() ) {
      if ( this.jobctl.field_lock(this.jobid, 'unique_post_run') ) {
        this.waitfor();

        var ret = {};
        if ( this.j.unique_post_run ) {
          ret = this.j.unique_post_run();
        }
        return {
          ok:1,
          msg: 'success',
          data : ret
        };
      }
    }
  }

  mapjob.getsub = function(){
    return this.j.wjob.findAndModify({
      query: {
        tm: 0
      },
      update:{ $set:{
        tm: ( Number(ISODate())),
        by: utils.getName()
      }}
    });
  }

  mapjob.endsubs = function(ids){
    this.j.wjob.update(
      {_id: { $in : ids }},
      { $set:{
        tm: Number.MAX_VALUE
      }},
      { multi : true }
    );
    if ( this.j.endsubs ) {
      this.j.endsubs(ids);
    }
  }

  mapjob.waitfor = function(){
    var start = ISODate();
    var query = utils.IGNORE_META();
    query.tm = { $ne : Number.MAX_VALUE };
    while(true){
      if ( (this.j.rjob.find(query).limit(1).count() === 0) ) {
        break;
      }
      sleep(300);
    }
    return true;
  }

  mapjob.map_query = function(){
    if ( this.j.map_query ) {
      return this.j.map_query();
    }
    return null;
  }

  mapjob.map_cursor = function(){
    if ( this.j.map_cursor ) {
      return this.j.map_cursor();
    }
    var f = {};
    f[this.map_field()] = 1;
    var query = utils.dup(utils.IGNORE_META());
    var mapQuery = this.map_query();
    if ( mapQuery ) {
      query = { '$and': [ query, mapQuery ]}
    }
    return this.j.src.find(query,f);
  }

  mapjob.map_field = function(){
    if ( this.j.map_field ) {
      return this.j.map_field();
    }
    return '_id';
  }

  mapjob.map_data = function(id, subjob){
    if ( this.j.direct ) {
      return subjob;
    }
    if ( this.j.map_data ) {
      return this.j.map_data(id,subjob);
    }
    var q = {};
    q[this.map_field()] = id;
    return this.j.src.findOne(q);
  }

  return mapjob;
}
