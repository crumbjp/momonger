function main(jobctl, org_options) {
  var psrc = utils.parseCollection(org_options.src);
  if ( !org_options.dst ) {
    org_options.dst = psrc.db + '.rf.'   +psrc.col;
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
    print('*** Number of data less than ' + options.args['L'] + ' : ' + destination_name);
    return;
  }

  var dstcol = utils.getWritableCollection(options.dst);
  dstcol.drop();

  var ret = get_fields_job(options);
  var fields = [];
  var ignore_fields = options.args['I'].split(',');
  for ( var i in ignore_fields ) {
    ignore_fields[i] = options.args['F'] + '.' + ignore_fields[i];
  }
  for ( var i in ret.data.fields) {
    if ( ignore_fields.indexOf(ret.data.fields[i]) < 0 ) {
      fields.push(ret.data.fields[i]);
    }
  }

  options.args['Q'] = '{}';
  options.args['C'] = '';
  var real_fields = ret.data.real_fields;

  var meta = options.args['M'];
  meta.type = 'random_forest';
  meta.goal = options.args['GF'];
  meta.source_name = psrc.col;
  meta.destination_name = utils.parseCollection(org_options.dst).col;
  meta.tree = []
  utils.setmeta(dstcol, meta);

  fields = utils.shuffle(fields);

  var used_fields = [];
  var num_tree = options.args['N'];
  var depth = options.args['D'];
  // var num_fields = depth + 1;
  var num_fields = depth * 2;
  if ( options.args['NF'] ) {
    num_fields = options.args['NF'];
  }
  var contexts = [];
  var uniq_check = {}
  var results;
  var reused = 0;
  for (var i = 0; i < num_tree; i++ ) {
    if ( fields.length < num_fields ) {
      if ( reused > 2 ) {
        break;
      }
      fields = fields.concat(utils.shuffle(used_fields));
      reused++;
    }
    var picked_fields = fields.splice(0, num_fields);
    used_fields = used_fields.concat(picked_fields);

    var uniq_name = picked_fields.join(',');
    if ( uniq_check[uniq_name] ) {
      i--;
      continue;
    }
    uniq_check[uniq_name] = 1;
    reused = 0;

    var ctx = build_context(options.dst, options, picked_fields, [], '.tmp'+i, [], real_fields, 0);
    contexts.push(ctx);
    if (contexts.length >= 5 ) {
      print('** RF bulk ' + contexts.length + ' ('+(i+1)+')');
      if ( !id3_iterations(contexts) ) {
        return false;
      }
      contexts = [];
    }
  }
  if ( contexts.length ) {
    print('** RF bulk ' + contexts.length + ' (last)');
    if ( !id3_iterations(contexts) ) {
      return false;
    }
  }
  print('** RF FINISHED ' + destination_name);
  treescol.save(meta);
}
