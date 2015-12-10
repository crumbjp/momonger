function main(jobctl,org_options) {
  var options = utils.dup(org_options)
  options.args.O = org_options;
	jobctl.put( 'job',{
    print: 1,
		create_job : function(){
			return { ok:1 };
		},
		run : function(){
      printjson(jobctl);
	    var ret = jobctl.put( 'job',{
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
	    },this.ARGS.O);
      return {
        ok: 1,
        data: ret
      };
		},
	},options);
}
