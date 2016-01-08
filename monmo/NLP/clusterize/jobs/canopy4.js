function main(jobctl,options) {
	print('== FIRST  ==');
  var ret = first_job();
	options.args['meta'] = ret.data.meta;

	print('== T2 sampling  ==');
	options.src = ret.data.meta.canopy.data
	options.dst = ret.dst;
  ret = t2sampling_job();
	options.args['meta'] = ret.data.meta;

	print('== T1 sampling  ==');

	options.src = ret.data.meta.canopy.data;
	options.dst = ret.data.meta.canopy.tmp_t1;

  ret = t1sampling_job();
	options.args['meta'] = ret.data.meta;

	print('== Reduce closed  ==');
	options.src = ret.data.meta.canopy.tmp_t1n;
	options.dst = ret.data.meta.canopy.cluster;

  ret = reduce_job();

  function first_job() {
	  return jobctl.put( 'job', {
			empty_dst : function(){
				var psrc = utils.parseCollection(this.SRCCOL);
				return psrc.db + '.canopy.'   +psrc.col;
			},
			prepare_create : function() {
        utils.cleanCollections(this.DSTCOL+'\.');
				return {ok:1};
			},
			create_job : function() {
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
					field:this.ARGS['F']
				}

				this.datacol = utils.getWritableCollection(this.meta.canopy.data);
				this.tmp_t2     = utils.getWritableCollection(this.meta.canopy.tmp_t2);

				return {ok:1};
			},

			run : function() {
				var _c_src= this.src.find(utils.IGNORE_META());
				while(_c_src.hasNext()){
					var data = _c_src.next();
					var loc  = utils.getField(data,this.meta.canopy.field);
					if ( loc ) {
						this.datacol.save({
								_id:data._id,
							value:{loc:loc},
							st: 0
						});
					}
				}
				return {
					ok : 1,
					msg : '',
					data : { meta : this.meta }
				}
			}
	  },options);
  } // first_job

  function t2sampling_job() {
    return map(jobctl,options,{
			prepare_run : function(){
				this.meta = this.ARGS['meta'];
				this.tmp_t2  = utils.getWritableCollection(this.meta.canopy.tmp_t2);
        this.diffFunc   =  utils.diffVector;
				if ( this.ARGS['N'] ) {
					this.meta.normalize = true;
				}
        if ( this.meta.normalize ) {
          this.diffFunc   =  utils.diffAngle;
        }
				this.cs = utils.getClusters(this.meta.canopy.tmp_t2);
				return {ok:1};
      },
			map : function(id,val){
        val.value.loc = utils.dup(val.value.loc);
				for ( var c in this.cs ){
					var cluster = this.cs[c];
					var diff = this.diffFunc(val.value.loc,cluster.loc);
					if ( diff < this.meta.canopy.t2 ) {
						return;
					}
				}
        // re-check before create new cluster
				this.cs = utils.getClusters(this.meta.canopy.tmp_t2);
				for ( var c in this.cs ){
					var cluster = this.cs[c];
					var diff = this.diffFunc(val.value.loc,cluster.loc);
					if ( diff < this.meta.canopy.t2 ) {
						return;
					}
				}

        var c = { s : 1, loc : val.value.loc };
        c._id = ObjectId().valueOf();
			  this.cs[c._id.valueOf()] = c;

        this.tmp_t2.save(c);

      },

		  unique_post_run : function(){
        this.meta.canopy.c1 = this.tmp_t2.stats().count;
        utils.getCollection(this.SRCCOL).update(
                                                {},
                                                {$set:{st:0}},
                                                {multi:true} );
				return { meta : this.meta };
      },
      direct : true

	  },options);
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
        val.value.loc = utils.dup(val.value.loc);
				for ( var c in this.cs ){
				  var diff = this.diffFunc(val.value.loc,this.cs[c].loc);
				  if ( diff < this.meta.canopy.t1 ) {
            this.emit(c,{loc:val.value.loc,s:1});
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
				var threshold = Math.ceil(this.meta.docs / this.meta.canopy.c1 * this.meta.canopy.threshold);
				tmp_t1n  = utils.getWritableCollection(this.meta.canopy.tmp_t1n);

        var _cursor = this.dst.find(utils.IGNORE_META());
        while(_cursor.hasNext()){
          var cluster = _cursor.next();
          cluster = utils.dup(cluster);
					if ( cluster.s <= threshold ) {
						continue;
					}
				  if ( this.meta.normalize ) {
            cluster.loc = utils.normalize(cluster.loc);
				  }else{
            cluster.loc = utils.normalize(cluster.loc,cluster.s);
					}
          cluster.st = 0;
          tmp_t1n.save(cluster);
        }
        this.meta.canopy.c2 = tmp_t1n.stats().count;
				this.meta.canopy.threshold_val = threshold;
        return  {
          meta : this.meta
        }
      },
      field : '',
      direct : true
    });
  }

  function reduce_job() {
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
				return { meta : this.meta };
      },
      direct : true

	  },options);
  } // reduce_job
}
