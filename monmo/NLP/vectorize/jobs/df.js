function main(jobctl,options) {
  return map(jobctl,options,{
			empty_dst : function(){
			  return this.SRCCOL + '.vector.df'
			},

			prepare_create : function(){
				this.meta   = this.getmeta();
				if ( ! this.meta || 	this.meta.type !== 'TF' ) {
					return {
						ok:0,
						msg:'== Invalid collection : ' + this.SRCCOL + ' ==',
						reason:this.meta
					};
				}
				return { ok:1 };
			},

			post_create : function(){
				this.meta.type  = 'DF';
				this.meta.df    = this.DSTCOL;
				this.setmeta(this.meta);

				print('== DF : ' + this.DSTCOL + ' ==');
				return { ok:1 };
			},

			map : function(id,val){
				var ndim = 0;
				for ( var i in val.value ) {
					var w = val.value[i].w;
					this.dst.update(
													{_id:w},
													{ $inc : {value:1}},
													{ upsert:true }
													);
					ndim++;
				}
				print(id + ' : ' + ndim);
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
