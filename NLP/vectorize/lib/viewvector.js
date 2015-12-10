var _src         = utils.getCollection(_SRC);
var meta         = utils.getmeta(_src);
var _doc         = utils.getCollection(meta.doc);
var _dictionary  = utils.getCollection(meta.dic);

var _c_src = _src.find(utils.IGNORE_META());
while ( _c_src.hasNext() ) {
	var vector = _c_src.next();
	print('====== ' + vector._id + ' ) ======');
	var vs = [];
	for ( var i in vector.value ) {
		var l = vector.value[i];
		vs.push({id:i,s:l});
	}
	var vs = utils.sort(vs,function(a,b){ return (a.s > b.s); });
	for ( i = 0 ; i < _VERBOSE_LEN ; i++ ) {
		var o = utils.toObjectId(vs[i].id);
		var v = _dictionary.findOne({_id:o});
		print( vs[i].s + "\t : " + v._id + "\t : " + v.w );
	}
}
