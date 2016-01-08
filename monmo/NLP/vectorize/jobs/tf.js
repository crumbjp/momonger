function main(jobctl,options) {

  return map(jobctl,options,{
    append: !!options.args['A'],
		empty_dst : function(){
			return this.SRCCOL + '.vector.tf'
    },

		prepare_create : function(){
			this.dst.ensureIndex({'value.w':1});
			this.dst.ensureIndex({'a':1});

			this.meta   = this.getmeta();
			if ( ! this.meta || 	this.meta.type !== 'TOKEN' ) {
				return {
					ok:0,
					msg:'== Invalid collection : ' + this.SRCCOL + ' ==',
					reason:this.meta
				};
			}
			return { ok:1 };
		},

		post_create : function(){
			this.meta.type  = 'TF';
			this.meta.tf    = this.DSTCOL;
			this.meta.normalize = true;
			this.meta.docs = this.rjob.stats().count;
			this.setmeta(this.meta);

			print('== TF : ' + this.DSTCOL + ' ==');
			return { ok:1 };
		},

		map_cursor : function(){
			var f = {_id:0};
			f[this.map_field()]= 1;
			var q = this.ARGS['Q'];
      if ( this.ARGS['A'] ) {
        q.a = parseInt(this.ARGS['A']);
      }
			return this.src.find(q,f);
		},

		map_field : function(){
			return this.ARGS['K'];
		},

		map_data : function(id){
			var vec = {};
			var q = {};
			q[this.map_field()] = id;
			var f = {_id:0};
			f[this.ARGS['W']]= 1;
			var _c_src = this.src.find(q,f);
			this.ndim = 0;
			while(_c_src.hasNext()){
				var val = _c_src.next();
				var w = utils.getField(val,this.ARGS['W']).valueOf();
				if ( !( w in vec ) ){
					vec[w] = 0;
					this.ndim++;
				}
				vec[w]++;
			}
			return vec;
		},


		map : function(id,val){
			var value = [];
			for ( var e in val ) {
				value.push({w:e,c:val[e]});
			}
			this.dst.save({
				_id : id,
				value:value,
        a: parseInt(this.ARGS['A']),
			});
			print(id + ' : ' + this.ndim);
		},

		prepare_run : function(){
			this.meta = this.getmeta2();
			return {ok:1};
		},

		unique_post_run : function(){
			return this.meta;
		}
	},options);
}
