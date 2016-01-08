function main(jobctl,options) {
	print('== FIRST  ==');
  var ret = first_job();
	options.args['meta'] = ret.data.meta;

	print('== T2 sampling  ==');
	options.dst = ret.dst;
  ret = t2sampling_job();
	options.args['meta'] = ret.data.meta;

	print('== T1 sampling  ==');

	options.src = ret.data.meta.canopy.data
	options.dst = ret.data.meta.canopy.cluster;

  t1sampling_job();

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
        this.diffFunc   =  utils.diffVector;
				if ( this.ARGS['N'] ) {
					this.meta.normalize = true;
				}
        if ( this.meta.normalize ) {
          this.diffFunc   =  utils.diffAngle;
        }
				this.meta.vector = this.SRCCOL;
				this.meta.canopy = {
					tmp    :  this.DSTCOL + '.tmp',
					cluster:  this.DSTCOL + '.cluster',
          data:this.DSTCOL + '.data',
					t2:  this.ARGS['T2'],
					t1:  this.ARGS['T1'],
					threshold:this.ARGS['T'],
					field:this.ARGS['F']
				}

				this.datacol = utils.getWritableCollection(this.meta.canopy.data);
				this.tmp     = utils.getWritableCollection(this.meta.canopy.tmp);

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
	  return jobctl.put( 'job', {
			prepare_create : function() {
				return {ok:1};
			},
			create_job : function() {
				return {ok:1};
			},

			prepare_run : function(){
				this.meta = this.ARGS['meta'];
				this.tmp  = utils.getWritableCollection(this.meta.canopy.tmp);
        this.diffFunc   =  utils.diffVector;
				if ( this.ARGS['N'] ) {
					this.meta.normalize = true;
				}
        if ( this.meta.normalize ) {
          this.diffFunc   =  utils.diffAngle;
        }
				this.datacol = utils.getWritableCollection(this.meta.canopy.data);
				return {ok:1};
      },
			run : function() {
				var cs = [];
				var _c_data = this.datacol.find().addOption(DBQuery.Option.noTimeout);
				while ( _c_data.hasNext() ){
					var data = _c_data.next();
					var n = 0;
					for ( var c in cs ){
						var cluster = cs[c];
						var diff = this.diffFunc(cluster.loc,data.value.loc);
						if ( diff < this.meta.canopy.t2 ) {
							n++;
							break;
						}
					}
					if ( n === 0 ) {
            var c = { s : 1, loc : data.value.loc, newloc:{} };
            c._id = ObjectId().valueOf();
						cs.push(c);
            this.tmp.save(c);
					}
				}
        this.meta.canopy.first = cs.length;
				return {
					ok : 1,
					msg : '',
					data : { meta : this.meta }
				}
      }
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
				this.cs = utils.getClusters(this.meta.canopy.tmp);
				return {ok:1};
      },
			map : function(id,val){
				for ( var c in this.cs ){
				  var diff = this.diffFunc(this.cs[c].loc,val.value.loc);
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
				var threshold = this.meta.docs / this.meta.canopy.first * this.meta.canopy.threshold;

        this.cs = {};
        var minor = 0;
        var _cursor = this.dst.find(utils.IGNORE_META());
        while(_cursor.hasNext()){
          var cluster = _cursor.next();
					if ( cluster.s <= threshold ) {
						continue;
					}
          minor++;
				  if ( this.meta.normalize ) {
            cluster.loc = utils.normalize(cluster.loc);
				  }else{
            cluster.loc = utils.normalize(cluster.loc,cluster.s);
					}
          this.cs[cluster._id] = cluster;
        }

				print('== Reduce closed clusters  ==');
        var closed = [];
        var last = 0;
        this.dst.drop();
				for ( var c in this.cs ) {
					var cluster = this.cs[c];
          this.cs[c] = null;
					if ( cluster ) {
						var best = cluster;
						for ( var i in this.cs ) {
							var cmp = this.cs[i];
							if ( cmp ) {
								var diff = this.diffFunc( cluster.loc, cmp.loc );
								if ( diff < this.meta.canopy.t2 ) {
									if ( best.s < cmp.s ) {
										best = cmp;
									}
									if ( diff > 0 ){
										closed.push(diff);
									}
									this.cs[i] = null;
								}
							}
						}
            last++
            this.dst.save(best);
					}
				}

				this.meta.canopy.threshold_val = threshold;
				this.meta.canopy.minor         = minor;
				this.meta.canopy.last          = last;
				this.meta.canopy.closed        = closed;

				utils.setmeta(this.dst,this.meta);

        return  { meta : this.meta };
      },
      field : '',
      direct : true
    });
  }
}
