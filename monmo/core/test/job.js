var jobctl = new Jobctl(config.mongo.basedb);
UnitTest({
  setUp : function(){
    utils.cleanCollections('momongertest.J')
    utils.cleanCollections('momongertest.M')
  },
  job: function(){
  	var ret = jobctl.put( 'job',{
      localrun: 1,
  		prepare_create : function(){
  			this.src = utils.getWritableCollection(this.SRCCOL);
  			this.src.drop();
  			this.src.save({_id: 1,n:1});
  			this.src.save({_id: 2,n:1});
  			this.src.save({_id: 3,n:1});
  			this.src.save({_id: 4,n:1});
  			this.src.save({_id: 5,n:1});
  			this.src.save({_id: 6,n:2});
  			this.src.save({_id: 7,n:2});
  			this.src.save({_id: 8,n:2});
  			this.src.save({_id: 9,n:2});
  			this.src.save({_id:10,n:2});
  			return { ok:1 };
  		},
  		create_job : function(){
  			return { ok:1 };
  		},
  		run : function(){
  			var data = {i:0,n:0};
  			this.src.find().forEach(function(doc){
  				data.i += doc._id;
  				data.n += doc.n;
  			});
  				return {
  					ok:1,
  					msg: 'success',
  					data: data
  				};
  		},
  	},{
      name: null,
      src: 'momongertest.JOBSRC',
      dst: 'momongertest.JOBDST',
      args: {}
    });
    assertEq(tojsononeline({ i: 55, n: 15 }), tojsononeline(ret.data));
  },
  map: function(){
    var ret = map(jobctl, {
      name: null,
      src: 'momongertest.MAPSRC',
      dst: 'momongertest.MAPDST',
      args: {}
    }, {
      localrun: 1,
  		prepare_create : function(){
  			this.src = utils.getWritableCollection(this.SRCCOL);
  			this.src.drop();
  			this.src.save({_id: 1,n:1});
  			this.src.save({_id: 2,n:1});
  			this.src.save({_id: 3,n:1});
  			this.src.save({_id: 4,n:1});
  			this.src.save({_id: 5,n:1});
  			this.src.save({_id: 6,n:2});
  			this.src.save({_id: 7,n:2});
  			this.src.save({_id: 8,n:2});
  			this.src.save({_id: 9,n:2});
  			this.src.save({_id:10,n:2});
  			return { ok:1 };
  		},
  		map : function(id,doc){
  			this.dst.update(
  											{_id:'sum'},
  											{
  													$inc : {
  														i : doc._id,
  														n : doc.n
  													}
  											},
  											{ upsert:true }
  											);
  		},
  		unique_post_run : function(){
  			return this.dst.findOne({_id:'sum'});
  		}
  	});
    assertEq(tojsononeline({ _id: "sum", i: 55, n: 15 }), tojsononeline(ret.data));
  },
  mapreduce: function(){
    var ret = mapreduce(jobctl,{
      name: null,
      src: 'momongertest.MAPREDUCESRC',
      dst: 'momongertest.MAPREDUCEDST',
      args: {}
    }, {
      localrun: 1,
		  prepare_create : function(){
			  this.src = utils.getWritableCollection(this.SRCCOL);
			  this.src.drop();
        for ( var i = 1; i <= 1000; i++ ) {
          var n = Math.floor(Math.random() * 10);
			    this.src.save({_id: i,n:n});
        }
        this.src.ensureIndex({n:1})
			  return { ok:1 };
		  },
		  map_cursor : function(){
			  return this.src.find().sort({n:1});
		  },
		  map : function(id,doc){
        this.emit(doc.n,doc._id);
		  },
      reduce : function(key,values){
        var ret = 0;
        for ( var i in values ) {
          ret += values[i];
        }
        return ret;
      },
		  unique_post_run : function(){
        var n   = 0;
        var sum = 0;
        var _cursor = this.dst.find();
        while(_cursor.hasNext()){
          n++;
          sum += _cursor.next().value;
        }
        return { keys : n , sum : sum };
		  }
	  });
    assertEq(tojsononeline({ keys: 10, sum: 500500 }), tojsononeline(ret.data));
  }
});
