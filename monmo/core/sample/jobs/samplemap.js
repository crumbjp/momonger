function main(jobctl,options) {
  return map(jobctl,options,{
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

    /**
     * Hook after create job.
     */
		/*
		post_create : function(){
		},
    */

    /**
     * To custom the query for map.
     */
		/*
		map_cursor : function(){
			return this.src.find();
		},
    */

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

    /**
     * Hook before map job
     *  Run on a single worker
     */
		/*
		unique_pre_run : function(){
		  return {ok:1};
  	},
    */

    /**
     * Hook after map job
     *   Run on a single worker
     */
		unique_post_run : function(){
			return this.dst.findOne({_id:'sum'});
		}
	});
}
