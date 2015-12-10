var _src         = utils.getCollection(_SRC);
var meta         = utils.getmeta(_src);
var _dictionary  = utils.getCollection(meta.dic);

if ( !this.meta || this.meta.type !== 'IDF' ) {
  print('INVALID collection should be type=IDF');
  printjson(this.meta);
  quit();
}

var _idf = _src.findOne({_id: ObjectId(_ID)});
if ( ! _idf ) {
  print('WORD not found. $oid' + _ID);
  quit();
}

if ( ! _idf.oi ) {
  // Backup original value
  _idf.oi = _idf.i;
}
_idf.i = parseFloat(_VALUE);
_src.save(_idf);
