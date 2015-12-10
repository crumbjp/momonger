var _src         = utils.getCollection(_SRC);
var meta         = utils.getmeta(_src);
var _dictionary  = utils.getCollection(meta.dic);

var cond = utils.IGNORE_META();
cond.value = { $gt : 1 };

var _c_src = _src.find(cond).sort({value:-1});
while ( _c_src.hasNext() ) {
	var df = _c_src.next();
	var word = _dictionary.findOne({_id:utils.toObjectId(df._id)});
	print( ' ' + df.value + "\t dic: " + word._id + ' \ti: ' + df.i + ' \t: ' + word.w );
}
