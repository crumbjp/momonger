function main(jobctl,options) {
  return mapreduce(jobctl,options,{
    print: 1,
    // ---------------------------------------
    //  Input phase

    /**
     * To complement DST collection name
     *   Required when DST is not specified from CMD.
     */
		/*
		empty_dst : function(){
		},
    */
    /**
     * Hook before create job.
     *   The JOB will be halted when return { ok : 0 }
     */
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

    /**
     * Hook after create job.
     */
		/*
		post_create : function(){
		},
    */

    /**
     * To custom the query for map.
     *
     * You can specify the cursor that is sorted by expected emit-key
     *   to reduce emit cost for performance.
     */
		map_cursor : function(){
			return this.src.find().sort({n:1});
		},

    /**
     * To custom the map key
     */
		/*
		map_field : function(){
      return '_id';
		},
    */

    // ---------------------------------------
    //  Run phase
    /**
     * Hook before map job
     *  Run on the all worker
     */
		/*
		prepare_run : function(){
				return {ok:1};
		},


    /**
     * To custom the data for map()
     *   Called before every map()
     */
		/*
		map_data : function(id){
			return this.src.findOne({_id:id});
		},
    */

    /**
     * MAP
     */
		map : function(id,doc){
      this.emit(doc.n,doc._id);
		},

    /**
     * REDUCE
     */
    reduce : function(key,values){
      var ret = 0;
      for ( var i in values ) {
        ret += values[i];
      }
      return ret;
    },

    /**
     * Hook before map job
     *  Run on a single worker before map()
     */
		/*
		unique_pre_run : function(){
		  return {ok:1};
  	},
    */

    /**
     * Hook after map job
     *   Run on a single worker after reduce()
     */
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
}
