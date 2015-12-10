function main(jobctl,options) {
  return map(jobctl,options,{
		empty_dst : function(){
			return this.SRCCOL + '.phrase'
		},

		prepare_create : function(){
			this.dst.ensureIndex({n:1,df:1});
			this.dst.ensureIndex({cv:1});
			this.dst.ensureIndex({st:1});

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
			this.meta.type  = 'PHRASE';
			this.meta.phrase           = this.DSTCOL;
			this.meta.docs = this.rjob.stats().count;
			this.meta.phrase_ngram     = this.ARGS['N'];
			this.meta.phrase_threshold = this.ARGS['T'];
			this.setmeta(this.meta);

			print('== PHRASE : ' + this.DSTCOL + ' ==');
			return { ok:1 };
		},

		map_cursor : function(){
			return this.src.find({i:1},{d:1});
		},

		map_field : function(){
			return 'd'
		},

		map_data : function(id){
			var prev = null;
			var cur = null;

			var df_filter = {};
			var analysises = [];
			for ( var i = this.ARGS['N']; i >= 2; i-- ) {
				analysises.push(new PhraseAnalysis(i,df_filter,this.dst,this.dic));
			}
			var _c_token = this.src.find({d:id}).sort({i:1})
			var ret = _c_token.count();
			while ( _c_token.hasNext()){
				var t  = _c_token.next();
				for ( var i in analysises ) {
					analysises[i].do_process(t);
				}
			}
			return ret;
		},
		map : function(id,val){
			print ( id.toString() + ' : ' + val );
		},

		prepare_run : function(){
			this.meta = this.getmeta2();

			this.dic  = new Dictionary(this.meta.dic);

			return {ok:1};
		},

		unique_post_run : function(){
			// C-VALUE
			print('== DO ( '+this.meta.docs+' => '+Math.log(this.meta.docs)+' ) ==');
			var threshold = Math.log(this.meta.docs) * this.ARGS['T'];
			var field = 'df';
			var dst = this.dst;
			function subs(sw,phr){
				var tf = phr[field];
				var n = sw.length;
				if ( n > 2 ) {
					var heads = sw.slice(0,n-1);
					dst.update(
						{_id:heads.join('') },
						{
							$inc : {
								c : 1,
								t : tf
							}
						}
					);
					var tails = sw.slice(1,n)
					dst.update(
						{_id:tails.join('') },
						{
							$inc : {
								c : 1,
								t : tf
							}
						}
					);
					subs(heads,phr);
					subs(tails,phr);
				}
			}
			for ( var i = this.ARGS['N']; i >= 2; i-- ) {
				var _c_phr = this.dst.find({n:i , df:{ $gte: threshold }});
				while ( _c_phr.hasNext()){
					var phr = _c_phr.next();
			    // Tuned C-VALUE
					var tf = phr[field];
					phr.cv = tf / this.meta.docs;
			    // phr.cv = Math.log(phr.n - 1) * tf;
			    // phr.cv = (phr.n - 1) * tf;
					if ( phr.c ) {
						phr.cv = ( tf - phr.t / phr.c) / this.meta.docs;
				    // phr.cv = Math.log(phr.n - 1) * ( tf - phr.t / phr.c);
				    // phr.cv = (phr.n - 1) * ( tf - phr.t / phr.c);
					}
					this.dst.update(
						{_id:phr._id},
						{$set : { cv : phr.cv } }
					);
					subs(phr.sw,phr);
				}
			}

			return this.meta;
		}
	},options);
}

function PhraseAnalysis(n,df_filter,dst,dic){
	this.ngram = Array(n);
	this.df_filter = df_filter;
	this.dst       = dst;
	this.dic       = dic;
}
PhraseAnalysis.prototype.is_continuous = function(){
	var prev = true;
	var cur  = true;
	var w  = '';
	var sw = [];
	var n  = 0;
	for ( var i = 0; i <  this.ngram.length ; i++ ) {
		prev = cur;
		cur = this.ngram[i];
		if ( ! prev || ! cur || cur.i - prev.i > 1 ){
			return null;
		}
		w += cur.w;
		n++;
		sw.push(cur.w);
	}
	return {w:w,n:n,sw:sw };
}
PhraseAnalysis.prototype.do_process = function(t){
	this.ngram.shift();
	this.ngram.push(t);

	var ret = this.is_continuous();
	if ( ! ret ) {
		return;
	}
	if( ret.w in this.df_filter ) {
		this.dst.update(
			{_id:ret.w},
			{ $inc : {tf:1} },
			{ upsert:true }
		);
		return;
	}
	// Filter : head or tail is HIRA
	var head = ret.w.charCodeAt(0)
	var tail = ret.w.charCodeAt(ret.w.length-1)
	if (0x3040 <= head && head <= 0x309f ||
			0x3040 <= tail && tail <= 0x309f ){
		return;
	}
	if ( this.dic.find(
		{
			_id:{
				$in: [
					this.ngram[0].c,
					this.ngram[this.ngram.length-1].c
				]},
			t  :{ $in : ['記号','NUMBER','EN','外来','DATE']}})
			 .limit(1).count() ) {
		return;
	}

	this.dst.update(
		{_id:ret.w},
		{
			$setOnInsert: {
				st : 2,
				n : ret.n,
				sw : ret.sw,
				t : 0,
				c : 0,
				cv : -1
			},
			$inc        : {df:1,tf:1} },
		{ upsert:true }
	);
	this.df_filter[ret.w] = 1;
}
