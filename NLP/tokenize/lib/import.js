var col = utils.getWritableCollection(_DIC+'.ipadic');
col.drop();
var bulk = null;
for ( var i in ipadic ) {
  if ( !bulk ){
    bulk = col.initializeUnorderedBulkOp();
  }
  var elem = ipadic[i]
  bulk.insert(elem);
  if ( bulk.nInsertOps > 5000 ) {
    bulk.execute()
    bulk = null;
  }
}
if ( bulk ) {
  bulk.execute()
}
