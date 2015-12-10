function main(jobctl,options) {
  return map(jobctl,options,{
			empty_dst : function(){
			  return this.SRCCOL + '.vector.idf'
			},

			prepare_create : function(){
				this.meta   = this.getmeta();
				if ( ! this.meta || 	this.meta.type !== 'DF' ) {
					return {
						ok:0,
						msg:'== Invalid collection : ' + this.SRCCOL + ' ==',
						reason:this.meta
					};
				}
				return { ok:1 };
			},

			post_create : function(){
				this.meta.type  = 'IDF';
				this.meta.idf    = this.DSTCOL;
				this.meta.idf_limit     = this.ARGS['L'];
				this.meta.idf_threshold = this.ARGS['T'];
				this.meta.idf_verb      = this.ARGS['V'];
				this.setmeta(this.meta);

				print('== IDF : ' + this.DSTCOL + ' ==');
				return { ok:1 };
			},

			map : function(id,val){
				var propotion = val.value / this.meta.docs;
				if ( val.value <= 1 || propotion >= this.ARGS['L'] || this.ARGS['T'] >= propotion ) {
				} else {
          var dic = this.dictionary.findOne({_id:utils.toObjectId(id)});
          if ( !dic ) {
            print(id + ' Not found in dictionary');
            return;
          }
          var score = Math.log(this.meta.docs/val.value);

          if ( this.ARGS['D'] ) {
            if ( typeof dic.i === 'number' ) {
              score *= dic.i;
            }
          }
          if ( this.ARGS['V'] ) {
            if ( dic.t.indexOf('名詞') < 0  ) {
              return;
            }
            if ( dic.t.indexOf('代名詞') >= 0  ) {
              return;
            }
            if ( dic.t.indexOf('接尾') >= 0 ) {
              if ( dic.t.indexOf('助数詞') < 0) { // ずつ,ちゃん,...
                return;
              }
              if ( dic.l <= 1 ) { // 個, 枚,...
                return;
              }
              // アンペア,...
            }
            if ( dic.t.indexOf('副詞可能') >= 0 ) { // あした, １月, こんど,...
              return;
            }
            if ( dic.t.indexOf('NUMBER') >= 0 && dic.l <= 2 ) {
              return;
            }
            if ( dic.l <= 2 ) {
              // 1 ~ 2 文字で、、
              var words = dic.w;
              if ( typeof dic.w === 'string' ) {
                words = [dic.w];
              }
              var isFilter = true;
              for ( var w in words ) {
                var word = words[w];
                for ( var p = 0; p < word.length; p++ ) {
		              var code = word.charCodeAt(p);
		              if ( code >= 0x3000 && code <= 0x30ff || // hira, kata
                       code >= 0xFF00 && code <= 0xFFFF) { // alpha
                    continue;
                  }
                  isFilter = false;
                }
                if ( !isFilter ) {
                  break;
                }
              }
              if ( isFilter ) {
                return;
              }
            }
          }
					this.dst.save({
							_id: id,
						value: val.value,
						    i: score,
					});
					print(id + ' : ' + val.value + ' => ' + Math.log(this.meta.docs/val.value));
				}
			},

			prepare_run : function(){
				this.meta = this.getmeta2();
				this.dictionary = utils.getCollection(this.meta.dic);
				return {ok:1};
			},

			unique_post_run : function(){
				return this.meta;
			}
	},options);
}
