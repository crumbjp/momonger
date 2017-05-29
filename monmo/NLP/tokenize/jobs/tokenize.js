function main(jobctl,options) {
  return map(jobctl,options,{
    append: !!options.args['A'],
		empty_dst : function(){
			var psrc = utils.parseCollection(this.SRCCOL);
			return this.SRCCOL + '.' + this.ARGS['F']
		},

		prepare_create : function(){
			this.dst.ensureIndex({d: 1, i:1 }, {unique: 1});
			this.dst.ensureIndex({i: 1, a:1});
			this.dst.ensureIndex({w: 1});

			return { ok:1 };
		},

		post_create : function(){
			var meta = {
				type: 'TOKEN',
				token: this.DSTCOL,
				doc:   this.SRCCOL,
				doc_field: this.ARGS['F'],
				dic: this.ARGS['D'],
        append: parseInt(this.ARGS['A']),
			};
      this.setmeta(meta);

			print('== TOKENIZE : ' + this.DSTCOL + ' ==');
			return { ok:1 };
		},

		map_query : function(){
      var ret = {};
      if ( this.ARGS['Q'] ) {
        eval('ret = ' + this.ARGS['Q'] + ';');
      } else if (this.ARGS['A']) {
        ret = { a: parseInt(this.ARGS['A']) }
      }
      return ret;
    },

		map : function(id,val){
			this.tokenizer.parse_doc(val._id,utils.getField(val,this.ARGS['F']), function(){});
			print ( id.toString() + ' : ' + this.tokenizer.nquery + ' ( ' + this.tokenizer.nfetch + ' ) ');
		},

		prepare_run : function(){
			this.meta = this.getmeta2();
      var _meta = this.meta;
			var dictionary = new Dictionary(this.ARGS['D']);
      var dst = {
        dst: this.dst,
        _dstBulk: null,
        save: function(doc, candidate, done){
          doc.a = _meta.append;
          if ( ! dst._dstBulk ) {
            dst._dstBulk = dst.dst.initializeOrderedBulkOp();
          }
          dst._dstBulk.find({d: doc.d, i: doc.i}).upsert().replaceOne(doc);
          if ( dst._dstBulk.nInsertOps > 1000 ) {
            dst._dstBulk.execute({w:0});
            dst._dstBulk = null;
          }
          done(null)
        },
        finish: function(done){
          if ( dst._dstBulk ) {
            dst._dstBulk.execute({w:0});
            dst._dstBulk = null;
          }
          done(null)
        }
      };
			this.tokenizer = new JPTokenizer(dictionary, dst, {} );

			return {ok:1};
		},

		unique_post_run : function(){
			return this.meta;
		}
	},options);
}
