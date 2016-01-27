var dictionary = new Dictionary(_DIC);

var dst = {
	save : function(token, candidate, done) {
		if ( token.c){
			token.c = dictionary.findOne({_id:token.c});
		}
		if ( _VERBOSE ) {
			print(token.i + ' : ' + utils.encode(token));
		}else{
			print(token.i + ' (' + token.l + '): ' + token.w);
		}
    done(null)
	},
	finish: function(done){
		print('=== end ===');
    done(null)
	},
};

var tokenizer = new JPTokenizer(dictionary, dst, _VERBOSE);
var docid = ISODate();
tokenizer.parse_doc(docid, _SENTENSE, function(err){
  print(err);
  print ( utils.encode(docid) + ' : ' + tokenizer.nquery + ' ( ' + tokenizer.nfetch + ' ) ');
});
