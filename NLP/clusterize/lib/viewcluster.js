var _src         = utils.getCollection(_SRC);
var meta         = utils.getmeta(_src);

printjson(meta);
var _c_src = _src.find({_id:{'$ne':'.meta'}});
while ( _c_src.hasNext() ) {
	var cluster = _c_src.next();
	print('====== ' + cluster._id + ' ( ' + cluster.s + ' ) ======');
	var ls = [];
	for ( var i in cluster.loc ) {
		var l = cluster.loc[i];
		ls.push({id:i,s:l});
	}
	var _dictionary;
	if ( meta.dic ) {
		_dictionary  = utils.getCollection(meta.dic);
	}
	var ls = utils.sort(ls,function(a,b){ return (a.s > b.s); });
	for ( i = 0 ; i < ls.length ; i++ ) {
		if( ! _VERBOSE && i >= 10 ) {
			break;
		}
		if( _VERBOSE && i >= 20 ) {
			break;
		}
		if ( meta.dic ) {
			var o = utils.toObjectId(ls[i].id);
			var v = _dictionary.findOne({_id:o});
			print(ls[i].s + "\t : " + v.w );
		}else {
			printjson(ls[i]);
		}
	}
	if ( _VERBOSE && meta.kmeans ) {
		var filter  = {id:1};
		filter[meta.doc_field] = 1;
		var _doc         = utils.getCollection(meta.doc);
		var _data        = utils.getCollection(meta.kmeans.data);
		var _c_data = _data.find({c:cluster._id});
    var oid = true;
		while(_c_data.hasNext()){
			var data = _c_data.next();
      var id = '';
      try { 
        id = utils.toObjectId(data._id);
      }catch(e){
        id = data._id;
      }
			var doc = _doc.findOne({_id:id},filter);
			print('_id:('+ doc._id + ') : ' + utils.trimSpace(doc[meta.doc_field]).slice(0,_VERBOSE_LEN));		
		}
	}
}