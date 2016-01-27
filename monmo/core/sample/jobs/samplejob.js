function main(jobctl,options) {
	jobctl.put( 'job',{
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
     * create job.
     *   The JOB will be halted when return { ok : 0 }
     */
		create_job : function(){
			return { ok:1 };
		},

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
    */
    /**
     * Run job
     *  Run on the all worker
     */
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
	},options);
}
