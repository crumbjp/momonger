
function main(jobctl,options) {
  print('== FIRST  ==');
  var ret = first_job();
  options.args['meta'] = ret.data.meta;

  print('== T2 sampling  ==');
  options.src = ret.data.meta.canopy.data
  options.dst = ret.data.meta.canopy.tmp_t2;

  ret = t2sampling_job();
  options.args['meta'] = ret.data.meta;
  printjson(ret.data.meta);

  print('== T1 sampling  ==');

  options.src = ret.data.meta.canopy.data;
  options.dst = ret.data.meta.canopy.tmp_t1;

  ret = t1sampling_job();
  options.args['meta'] = ret.data.meta;
  printjson(ret.data.meta);

  print('== Reduce minor  ==');
  if ( options.args['C'] ) {
    options.src = ret.data.meta.canopy.tmp_t1;
    options.dst = ret.data.meta.canopy.tmp_t1n;

    ret = reduce_minor_job();
    options.args['meta'] = ret.data.meta;
    printjson(ret.data.meta);

    print('== Reduce closed  ==');
    options.src = ret.data.meta.canopy.tmp_t1n;
    options.dst = ret.data.meta.canopy.cluster;

    ret = t2sampling_job();
    printjson(ret.data.meta);
  } else {
    options.src = ret.data.meta.canopy.tmp_t1;
    options.dst = ret.data.meta.canopy.cluster;

    ret = reduce_minor_job();
    printjson(ret.data.meta);
  }


  function first_job() {
    return map(jobctl,options,{
      empty_dst : function(){
        return this.SRCCOL + '.canopy'
      },
      prepare_create : function() {
        utils.cleanCollections(this.DSTCOL+'\.');
        return {ok:1};
      },

      prepare_run : function(){
        this.meta   = utils.getmeta(this.src);
        if ( this.ARGS['N'] ) {
          this.meta.normalize = true;
        }
        this.meta.vector = this.SRCCOL;
        this.meta.canopy = {
          tmp_t2 :  this.DSTCOL + '.tmp_t2',
          tmp_t1 :  this.DSTCOL + '.tmp_t1',
          tmp_t1n:  this.DSTCOL + '.tmp_t1n',
          cluster:  this.DSTCOL + '.cluster',
          data:this.DSTCOL + '.data',
          t2:  this.ARGS['T2'],
          t1:  this.ARGS['T1'],
          threshold:this.ARGS['T'],
          field:this.ARGS['F'],
          c : [],
        }

        this.datacol = utils.getWritableCollection(this.meta.canopy.data);

        return {ok:1};
      },

      map : function(id,val){
        var loc  = utils.getField(val,this.meta.canopy.field);
        if ( loc ) {
          this.datacol.save({
              _id:val._id,
            loc:loc,
            tm: 0,
            by: utils.EMP_NAME()
          });
        }
      },

      unique_post_run : function(){
        return { meta : this.meta };
      }
    });
  } // first_job

  function t2sampling_job() {
    return map(jobctl,options,{
      prepare_run : function(){
        this.meta = this.ARGS['meta'];
        this.diffFunc   =  utils.diffVector;
        if ( this.ARGS['N'] ) {
          this.meta.normalize = true;
        }
        if ( this.meta.normalize ) {
          this.diffFunc   =  utils.diffAngle;
        }
        this.cs = utils.getClusters(this.DSTCOL);
        return {ok:1};
      },
      map : function(id,val){
        val.loc = utils.dup(val.loc);
        for ( var c in this.cs ){
          var cluster = this.cs[c];
          var diff = this.diffFunc(val.loc,cluster.loc);
          if ( diff < this.meta.canopy.t2 ) {
            return;
          }
        }
        // re-check before create new cluster
        this.cs = utils.getClusters(this.DSTCOL);
        for ( var c in this.cs ){
          var cluster = this.cs[c];
          var diff = this.diffFunc(val.loc,cluster.loc);
          if ( diff < this.meta.canopy.t2 ) {
            return;
          }
        }

        var c = { s : 1, loc : val.loc };
        c._id = ObjectId().valueOf();
        this.cs[c._id.valueOf()] = c;

        this.dst.save(c);
      },

      unique_post_run : function(){
        this.meta.canopy.c.push(this.dst.stats().count);
        this.wjob.update(
                         utils.IGNORE_META(),
                         {$set:{
                           tm:0,
                           by:utils.EMP_NAME()
                         }},
                         {multi:true} );
        utils.setmeta(this.dst,this.meta);
        return { meta : this.meta };
      },
      direct : true

    });
  } // t2sampling_job

  function t1sampling_job(){
    return mapreduce(jobctl,options,{
      prepare_run : function(){
        this.meta = this.ARGS['meta'];
        this.diffFunc   =  utils.diffVector;
        if ( this.meta.normalize ) {
          this.diffFunc   =  utils.diffAngle;
        }
        this.cs = utils.getClusters(this.meta.canopy.tmp_t2);
        return {ok:1};
      },
      map : function(id,val){
        val.loc = utils.dup(val.loc);
        for ( var c in this.cs ){
          var diff = this.diffFunc(val.loc,this.cs[c].loc);
          if ( diff < this.meta.canopy.t1 ) {
            this.emit(c,{loc:val.loc,s:1});
          }
        }
      },
      reduce : function(key,values){
        var ret = {loc:{},s:0};
        for ( var i in values ) {
          var value = values[i];
          ret.s += value.s;
          ret.loc = utils.addVector(ret.loc,value.loc);
        }
        return ret;
      },
      unique_post_run : function(){
        this.dst.update(
                        utils.IGNORE_META(),
                        {$set:{
                          tm:0,
                          by:utils.EMP_NAME()
                        }},
                        {multi:true} );
        utils.setmeta(this.dst,this.meta);
        return { meta : this.meta };
      },
      field : '',
      direct : true
    });
  }

  function reduce_minor_job() {
    return map(jobctl,options,{
      prepare_run : function(){
        this.meta = this.ARGS['meta'];
        this.diffFunc   =  utils.diffVector;
        if ( this.ARGS['N'] ) {
          this.meta.normalize = true;
        }
        if ( this.meta.normalize ) {
          this.diffFunc   =  utils.diffAngle;
        }
        this.threshold = Math.ceil(this.meta.docs / this.meta.canopy.c[0] * this.meta.canopy.threshold);
        return {ok:1};
      },
      map : function(id,val){
        val.loc = utils.dup(val.loc);
        if ( val.s <= this.threshold ) {
          return;
        }
        if ( this.meta.normalize ) {
          val.loc = utils.normalize(val.loc);
        }else{
          val.loc = utils.normalize(val.loc,val.s);
        }
        this.dst.save(val);
      },
      unique_post_run : function(){
        this.meta.canopy.threshold_val = this.threshold;
        this.meta.canopy.c.push(this.dst.stats().count);
        utils.setmeta(this.dst,this.meta);
        return { meta : this.meta };
      },
      direct : true
    });
  }
/*
  function reduce_closed_job() {
    return map(jobctl,options,{
      prepare_run : function(){
        this.meta = this.ARGS['meta'];
        this.diffFunc   =  utils.diffVector;
        if ( this.ARGS['N'] ) {
          this.meta.normalize = true;
        }
        if ( this.meta.normalize ) {
          this.diffFunc   =  utils.diffAngle;
        }
        return {ok:1};
      },
      map : function(id,val){
        val.loc = utils.dup(val.loc);
        var _cursor = this.src.find({_id:{$gt:id}}).sort({_id:1});
        while(_cursor.hasNext()){
          var cluster = _cursor.next();
//          cluster = utils.dup(cluster);
          var diff = this.diffFunc( val.loc, cluster.loc );
          if ( diff <= this.meta.canopy.t2 ) {
            return;
          }
        }
        this.dst.save(val);
      },

      unique_post_run : function(){
        this.meta.canopy.c3 = this.dst.stats().count;
        utils.setmeta(this.dst,this.meta);
        return { meta : this.meta };
      },
      direct : true
    });
  } // reduce_closed_job
*/
}
