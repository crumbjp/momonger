function main(jobctl, org_options) {
  var psrc = utils.parseCollection(org_options.src);
  if ( !org_options.dst ) {
    org_options.dst = psrc.db + '.id3.'   +psrc.col;
  }
  var destination_name = utils.parseCollection(org_options.dst).col;
  var treescol = utils.getWritableCollection(psrc.db + '.trees');
  treescol.remove({destination_name: destination_name});
  var options = utils.dup(org_options);

  var srccol = utils.getWritableCollection(options.src);
  var stats = srccol.stats();
  if ( stats.ok !== 1 ) {
    print('*** Stats error ' + stats.errmsg);
    return;
  }
  if ( stats.count < options.args['L'] ) {
    print('*** Number of data less than ' + options.args['L'] + ' ('+ srccol.stats().count +')' + ' : ' + destination_name);
    return;
  }
  var dstcol = utils.getWritableCollection(options.dst);
  dstcol.drop();

  var ret = get_fields_job(options);
  if ( ret.ok !== 1 ) {
    return;
  }

  options.args['Q'] = '{}';
  options.args['C'] = '';
  var fields = [];
  var ignore_fields = [];
  if (options.args['I']) {
    ignore_fields = options.args['I'].split(',');
  }
  for ( var i in ignore_fields ) {
    ignore_fields[i] = options.args['F'] + '.' + ignore_fields[i];
  }
  for ( var i in ret.data.fields) {
    if ( ignore_fields.indexOf(ret.data.fields[i]) < 0 ) {
      fields.push(ret.data.fields[i]);
    }
  }

  var top_fields = [];
  if ( options.args['T'] ) {
    top_fields = options.args['T'].split(',');
  }
  for ( var i in top_fields) {
    top_fields[i] = options.args['F'] + '.' + top_fields[i];
  }
  var real_fields = ret.data.real_fields;

  var meta = options.args['M'];
  meta.type = 'decision_tree';
  meta.goal = options.args['GF'];
  meta.source_name = psrc.col;
  meta.destination_name = destination_name;
  meta.tree = []

  utils.setmeta(dstcol, meta);
  if ( id3_iteration(options.dst, options, fields, [], '.tmp', top_fields, real_fields, 0) ) {
    treescol.save(meta);
  }
}
