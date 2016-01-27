function get_fields_job(org_options) {
  var options = utils.dup(org_options);
  options.dst += '.gf';
  var localrun = false;
  var single_worker = false;
  var count = utils.getCollection(options.src).stats().count;
  if ( count <= 5000 ){
    single_worker = true;
  }
  if ( count <= 10000 ){
    localrun = true;
  }
  return mapreduce(jobctl,options,{
    bulk: 5000,
    single_worker: single_worker,
    localrun: localrun,
    prepare_create : function() {
      eval("this.query = " + options.args['Q'] + ';');
      return {ok:1};
    },
    prepare_run : function(){
      this.field      = this.ARGS['F'];
      return {ok:1};
    },
    map_query: function() {
      return this.query;
    },
    map : function(id,val){
      var loc  = utils.getField(val, this.field);
      if ( loc ) {
        for (var i in loc) {
          var field_name = this.field + '.' + i;
          var type = typeof loc[i];
          var v = {}
          v[type] = 1;
          this.emit(field_name, v);
        }
      }
    },
    reduce : function(key, values,last){
      var merged = {};
      for ( var i in values ) {
        var value = values[i];
        for ( var type in value ) {
          if ( !merged[type] ) {
            merged[type] = 0;
          }
          merged[type] += value[type];
        }
      }
      return merged;
    },
    unique_post_run : function(){
      var fields = [];
      var real_fields = [];
      var cur = this.dst.find(utils.IGNORE_META());
      while(cur.hasNext()){
        var doc = cur.next();
        fields.push(doc._id);
        var max = null;
        for ( var type in doc.value){
          var n = doc.value[type];
          if ( !max || max.n < n ) {
            max = {
              type: type,
              n: n
            }
          }
        }
        if (max.type === 'number') {
          real_fields.push(doc._id);
        }
      }
      return { fields: fields, real_fields: real_fields };
    }
  });
}

function id3_mc(org_dst, org_options, fields, path, dst_ns, org_top_fields, org_real_fields, depth) {
  if ( ! fields.length || depth >= org_options.args['D'] ) {
    return null;
  }
  var top_fields = utils.dup(org_top_fields);
  var top_field = top_fields.shift();
  var options = utils.dup(org_options);
  var tmp_dst = options.dst + dst_ns;
  options.dst = tmp_dst;

  var range_queries = []
  if ( !top_field ) {
    range_queries = real_fields_job(options, fields, org_real_fields);
  }

  var ret = fields_job(options, fields, top_field, range_queries);
  if ( ret.ok !== 1 ) {
    return;
  }
  var meta = ret.data.meta;
  options.args['meta'] = meta;
  options.args['base'] = meta.id3.all.value['__BASE__'];
  options.args['count'] = meta.id3.all.value['__COUNT__'];
  options.args['mc'] = meta.id3.all.value['__MC__'];
  options.src = options.dst;
  options.dst = org_dst;
  options.args['P'] = path.join(',')
  ret = mc_job(options, fields, org_real_fields, range_queries);
  if ( options.args['R'] ) {
    utils.getWritableCollection(options.src).drop();
  }
  utils.getWritableCollection(tmp_dst).drop();
  return {
    ret: ret,
    top_fields: top_fields,
    range_queries: range_queries,
  };
}

function id3_mc_job(org_dst, org_options, fields, path, dst_ns, org_top_fields, org_real_fields, depth, num) {
  var options = {
    name: 'id3_mc_job_' + dst_ns,
    src: org_options.src,
    dst: org_options.dst,
    args: {
      org_dst: org_dst,
      org_options: org_options,
      fields: fields,
      path: path,
      dst_ns: dst_ns,
      org_top_fields: org_top_fields,
      org_real_fields: org_real_fields,
      depth: depth,
    }
  }

	return jobctl.put_async( 'job',{
		create_job : function(){
			return { ok:1 };
		},
		run : function(){
      var mc_result = id3_mc(
        this.ARGS.org_dst,
        this.ARGS.org_options,
        this.ARGS.fields,
        this.ARGS.path,
        this.ARGS.dst_ns,
        this.ARGS.org_top_fields,
        this.ARGS.org_real_fields,
        this.ARGS.depth
      );
      return {
        ok: mc_result.ret.ok,
        mc_result: mc_result
      }
    },
	}, options);
}


function id3_iterations(contexts) {
  var mc_jobs = {};
  for ( var c in contexts ) {
    var ctx = contexts[c];
    if ( !ctx ) {
      continue;
    }
    print('  kick mc_job depth: ' + ctx.depth + ' path' + ctx.path.join(' > ') + ' : ' + ctx.num);
    mc_jobs[c] = id3_mc_job(ctx.dst, ctx.options, ctx.fields, ctx.path, ctx.dst_ns, ctx.top_fields, ctx.real_fields, ctx.depth, ctx.num);
  }
  var results = jobctl.waitall(mc_jobs);
  print('* waitall');
  var nextContexts = [];
  for ( var c in results ) {
    var result = results[c];
    var ctx = contexts[c];
    if ( result.ok !== 1 ) {
      return false;
    }
    var ret = result.mc_result.ret;
    var top_fields = result.mc_result.top_fields;
    var range_queries = result.mc_result.range_queries;
    ctx.path = ret.data.path;
    var more = ret.data.more;
    var nums = ret.data.nums;
    var current = ret.data.current;
    var org_query = utils.decode(ret.data.query);
    var org_fields = utils.dup(ctx.fields);
    ctx.fields = utils.diffArray(ctx.fields, ctx.path);
    var path_tail = ctx.path[ctx.path.length-1];

    var rangeQueriesByField = null;

    var index = false;
    for ( var i in more ){
      // child
      var num = nums[i];
      var typeVal = more[i];
      var val = utils.fromTypeValue(typeVal);
      var query = utils.dup(org_query);
      if ( typeVal[0] === 'r' ) {
        if ( !rangeQueriesByField ) {
          rangeQueriesByField = utils.toRangeQuery(range_queries);
        }
        query[path_tail] = rangeQueriesByField[path_tail][val].query;
      }else{
        query[path_tail] = val;
      }
      options = utils.dup(ctx.options);
      options.args['Q'] = utils.encode(query);
      options.args['C'] = current + '_' + path_tail + '_' + typeVal;
      var nextContext = build_context(ctx.dst, options, ctx.fields, ctx.path, ctx.dst_ns + '_' + i, top_fields, ctx.real_fields, ctx.depth+1);
      if ( !nextContext ) {
        continue;
      }
      nextContext.num = num;

      if ( !index ) {
        var idx = {}
        var indexPath = ctx.path.slice(1, 4);
        for ( var i in indexPath) {
          idx[indexPath[i]] = 1;
        }
        utils.getWritableCollection(ctx.options.src).ensureIndex(idx, { background: true });
        print(tojsononeline(idx));
        index = true;
      }

      nextContexts.push(nextContext);
      if ( nextContexts.length >= 20 ) {
        print('- bulk ' + nextContexts.length);
        if ( !id3_iterations(nextContexts) ) {
          return false;
        }
        nextContexts = [];
      }
    }
  }
  if ( nextContexts.length ) {
    print('- bulk ' + nextContexts.length);
    if ( !id3_iterations(nextContexts) ) {
      return false;
    }
  }
  return true;
}



function build_context(dst, options, fields, path, dst_ns, top_fields, real_fields, depth) {
  if ( ! fields.length || depth >= options.args['D'] ) {
    return null;
  }
  return {
    dst: dst,
    options: utils.dup(options),
    fields: utils.dup(fields),
    path: utils.dup(path),
    dst_ns: dst_ns,
    top_fields: utils.dup(top_fields),
    real_fields: utils.dup(real_fields),
    depth: depth,
  }
}

function id3_iteration(dst, options, fields, path, dst_ns, top_fields, real_fields, depth) {
  var startTime = new Date();
  var ctx = build_context(dst, options, fields, path, dst_ns, top_fields, real_fields, depth);
  var result = id3_iterations([ctx]);
  var diffTime = Math.floor((new Date() - startTime) / 1000);
  if ( result ) {
    print('***** SUCCESS ***** ' + ctx.dst + ' > ' + diffTime);
  } else {
    print('***** FAILED ***** ' + ctx.dst + ' > ' + diffTime);
  }
  return result;
}

function mc_job(org_options, fields, real_fields, range_queries){
  print('== mc_job ==');
  var options = utils.dup(org_options);
  options.args['F'] = fields.join(',');
  options.args['RF'] = real_fields.join(',');
  options.args['RQ'] = range_queries;
  options.args['RD'] = Math.random();
  return mapreduce(jobctl, options, {
    localrun: true,
    single_worker: true,
    append: true,
    direct: 1,
    field: '',
    prepare_run : function(){
      this.meta = this.getmeta();
      this.base = this.ARGS['base'];
      this.all_count = this.ARGS['count'];
      this.all_mc = this.ARGS['mc'];
      this.fields = this.ARGS['F'].split(',');
      this.real_fields = this.ARGS['RF'].split(',');
      this.query = utils.decode(this.ARGS['Q']);
      this.path = this.ARGS['P'].split(',')
      this.current = this.ARGS['C']
      this.query_by_real = utils.toRangeQuery(this.ARGS['RQ']);
      return {ok: 1};
    },
    map : function(id, doc){
      if ( id === '__ALL__' ) {
        return;
      }
      var all_mc = 0;
      for( var t in doc.value ){
        var count = doc.value[t]['__COUNT__'];
        var mc = utils.mc(this.base, count, doc.value[t]);
        doc.value[t]['__MC__'] = mc;
        all_mc += count / this.all_count * mc;
      }
      doc['__MC__'] = this.all_mc - all_mc;
      doc['__F__'] = id;
      this.emit('__ALL__', doc);
    },
    reduce : function(key, values,last){
      var max_value = null;
      for ( var i in values ) {
        var value = values[i];
        if ( !max_value || max_value.__MC__ < value.__MC__ ) {
          max_value = value;
        }
      }
      if ( last ) {
        this.path.push(max_value['__F__']);
        var rq = '[]';
        if ( this.query_by_real[max_value['__F__']] ) {
          rq = utils.encode(this.query_by_real[max_value['__F__']]);
        }
        var id = this.current;
        if ( !id ) {
          id = hex_md5(this.ARGS['RD']+this.fields.join(','));
        }
        var ret = { _id: id, p: this.path, c: utils.encode(this.query), f: this.fields, d:{}, m: [], n: [], rq: rq }
        for ( var val in max_value.value ) {
          if ( /^__/.test(val) ) {
            continue;
          }
          ret.d[val] = []
          var total = 0;
          for ( var t in max_value.value[val] ) {
            if ( /^__/.test(t) ) {
              continue;
            }
            ret.d[val].push({c: t, n: max_value.value[val][t]})
            total += max_value.value[val][t];
          }
          for ( var t in ret.d[val] ) {
            ret.d[val][t].p = ret.d[val][t].n / total;
          }
          ret.d[val] = utils.sort(ret.d[val], function(a,b){return a.n > b.n});
          if ( ret.d[val].length > 1 ) {
            ret.m.push(val);
            ret.n.push(total);
          }
        }
        return ret;
      }
      return max_value;
    },
    unique_post_run : function(){
      var is_root = false;
      var id = this.current;
      if ( !id ) {
        // TODO: DRI
        id = hex_md5(this.ARGS['RD']+this.fields.join(','));
        is_root = true;
      }
      var all = this.dst.findOne({_id: id });
      if ( is_root ) {
        meta_update = {
          $push: {
            tree: {
              fields: this.fields,
              real_fields: this.real_fields,
              path: all.p,
              root: id,
            }
          }
        }
        utils.resetmeta(this.dst, meta_update);
      }
      return { path : all.p, more: all.m, nums: all.n, query: utils.encode(this.query), current: id };
    }
  });
}

function deviation_job(org_options, fields, real_fields, prev) {
  print('== deviation_job ==');
  var options = utils.dup(org_options);
  options.args['F'] = fields.join(',');
  options.args['RF'] = real_fields.join(',');
  options.args['PREV'] = prev;
  var localrun = false;
  var single_worker = false;
  var count = utils.getCollection(options.src).stats().count;
  if ( count <= 1000 ){
    single_worker = true;
  }
  if ( count <= 2000 ){
    localrun = true;
  }
  return mapreduce(jobctl, options, {
    localrun: localrun,
    single_worker: single_worker,
    bulk: 1000,
    prepare_create : function() {
      this.query = utils.decode(options.args['Q']);
      var meta = { deviation: {}}
      if ( this.ARGS['PREV'] ) {
        this.prevCollection = utils.getCollection(this.ARGS['PREV']);
        var prevMeta = this.prevCollection.findOne(utils.META());
        var cur = this.prevCollection.find(utils.IGNORE_META());
        while (cur.hasNext()){
          var doc = cur.next();
          var deviationField = utils.escapeField(doc._id.field)+'_'+doc._id.goal;
          if ( prevMeta && prevMeta.deviation[deviationField] && prevMeta.deviation[deviationField].failed ) {
            meta.deviation[deviationField] = prevMeta.deviation[deviationField];
            continue;
          }
          if ( doc._id.type === 'd' ) {
            if ( ! meta.deviation[deviationField] ) {
              meta.deviation[deviationField] = {max: 0, field: doc._id.field, goal: doc._id.goal};
            }
            if ( meta.deviation[deviationField].max < doc.value.d ) {
              meta.deviation[deviationField].max = doc.value.d;
            }
          }
        }
      }
      this.setmeta(meta);
      return {ok:1};
    },
    unique_pre_run : function(){
      return {ok:1};
    },
    prepare_run : function(){
      this.goal_field = this.ARGS['GF'];
      this.fields = this.ARGS['F'].split(',');
      this.real_fields = this.ARGS['RF'].split(',');
      this.averagesByFieldByGoal = {}

      if ( this.ARGS['PREV'] ) {
        this.prevCollection = utils.getCollection(this.ARGS['PREV']);
        var prevMeta = this.prevCollection.findOne(utils.META());
        var cur = this.prevCollection.find(utils.IGNORE_META());
        while (cur.hasNext()){
          var doc = cur.next();
          var deviationField = utils.escapeField(doc._id.field)+'_'+doc._id.goal;
          if ( prevMeta && prevMeta.deviation[deviationField] && prevMeta.deviation[deviationField].failed ) {
            continue;
          }
          if ( doc._id.type === 'a' ) {
            if ( ! this.averagesByFieldByGoal[doc._id.field] ) {
              this.averagesByFieldByGoal[doc._id.field] = {}
            }
            if ( ! this.averagesByFieldByGoal[doc._id.field][doc._id.goal] ) {
              this.averagesByFieldByGoal[doc._id.field][doc._id.goal] = []
            }
            this.averagesByFieldByGoal[doc._id.field][doc._id.goal].push(doc);
          }
        }
      }
      return {ok:1};
    },
    map_query: function() {
      return this.query;
    },
    map : function(id, doc){
      var res = {}
      var goal = utils.toTypeValue(utils.getField(doc, this.goal_field))
      for (var i in this.fields) {
        var field = this.fields[i];
        if ( this.real_fields.indexOf(field) < 0 ) {
          continue;
        }
        var value = utils.getField(doc, field);
        if ( value === null || isNaN(value) || value === Infinity || value === -Infinity) {
          continue;
        }
        var averages = null;
        var averagesByGoal = this.averagesByFieldByGoal[field];
        if ( averagesByGoal ) {
          averages = averagesByGoal[goal];
        }
        if ( !averages ) {
          this.emit({type: 'a', goal: goal, field: field, cond: {} }, {n: 1, v: value, max: value, min: value});
          continue;
        }
        for ( var j in averages ) {
          var average = averages[j];
          var matched = {};
          if ( average._id.cond !== {} ){
            matched = average._id.cond;
            for ( var op in average._id.cond ) {
              if ( op === '<' ) {
                if ( value >= average._id.cond[op] ) {
                  matched = false;
                  break;
                }
              } else if ( op === '>=' ) {
                if ( value < average._id.cond[op] ) {
                  matched = false;
                  break;
                }
              }
            }
          }
          if ( matched ) {
            this.emit({type: 'd', goal: goal, field: field, cond: matched }, {n: 1, v: value, d: value - average.value.v, a: average.value.v, max: average.value.max, min: average.value.min});
            var cond = utils.dup(matched);
            if ( value < average.value.v ) {
              cond['<'] = average.value.v;
            }else{
              cond['>='] = average.value.v;
            }

            this.emit({type: 'a', goal: goal, field: field, cond: cond }, {n: 1, v: value, max: value, min: value});
          }
        }
      }
    },
    reduce : function(key, values,last){
      if ( key.type === 'a'){
        var merged = {n: 0, v: 0, max: null, min: null};
        for( var i in values ) {
          var value = values[i];
          if ( merged.max === null || merged.max < value.max ) {
            merged.max = value.max;
          }
          if ( merged.min === null || merged.min > value.min ) {
            merged.min = value.min;
          }
          merged.v = merged.v * merged.n + value.v * value.n;
          merged.n += value.n;
          merged.v /= merged.n;
        }
        return merged;
      } else if ( key.type === 'd'){
        var merged = {n: 0, d: 0, a: 0, max: null, min: null};
        for( var i in values ) {
          var value = values[i];
          if ( merged.max === null || merged.max < value.max ) {
            merged.max = value.max;
          }
          if ( merged.min === null || merged.min > value.min ) {
            merged.min = value.min;
          }
          merged.a = value.a;
          merged.d = Math.pow(merged.d, 2) * merged.n + Math.pow(value.d,2) * value.n;
          merged.n += value.n;
          merged.d /= merged.n;
          merged.d = Math.pow(merged.d, 0.5);
        }
        return merged;
      }
    },
    unique_post_run : function(){
      var meta = this.getmeta2();
      var dstQuery = utils.IGNORE_META();
      dstQuery['_id.type'] = 'd';
      var cur = this.dst.find(dstQuery);
      while(cur.hasNext()){
        var doc = cur.next();
        var deviationField = utils.escapeField(doc._id.field)+'_'+doc._id.goal;
        if ( meta.deviation[deviationField] ) {
          if ( meta.deviation[deviationField].max <= doc.value.d || doc.value.n <= 1) {
            meta.deviation[deviationField].failed = true;
          }
        }
      }
      for ( var deviationField in meta.deviation) {
        if ( meta.deviation[deviationField].failed ) {
          if ( this.prevCollection ) {
            var query = {
              '_id.type': 'd',
              '_id.goal': meta.deviation[deviationField].goal,
              '_id.field': meta.deviation[deviationField].field
            }
            this.dst.update(query, {$set: {ignore: true}}, {multi: true});
            query.ignore = {$ne: true};
            var cur = this.prevCollection.find(query);
            while( cur.hasNext() ) {
              var doc = cur.next();
              this.dst.insert(doc);
            }
          }
        }
      }
      this.resetmeta(meta);
      return { };
    }
  });
}

var REAL_FIELD_DEPTH = 4;
function real_fields_job(org_options, fields, real_fields) {
  print('== real_fields_job ==');
  var options = utils.dup(org_options);
  var prev = null;
  var collectionNames = [];
  for ( var i = 0; i < REAL_FIELD_DEPTH; i++ ) {
    options.dst = org_options.dst + '.dev_'+i;
    deviation_job(options, fields, real_fields, prev);
    prev = options.dst;
    collectionNames.push(prev);
  }

  var field = null;
  var rangesByField = {};
  var cur = utils.getCollection(options.dst).find({
    '_id.type': 'd',
    ignore: {$ne: true}
  }).sort({
    '_id.field': 1, 'value.a': 1
  });
  while( cur.hasNext() ) {
    var doc = cur.next();
    if ( !rangesByField[doc._id.field]){
      rangesByField[doc._id.field] = [];
    }
    var range = rangesByField[doc._id.field].pop();
    if ( !range ) {
      doc.query = {};
      rangesByField[doc._id.field].push(doc);
    }else if (range._id.goal != doc._id.goal ){
      var at = 0
      if ( range.value.d + doc.value.d ) {
        var delta = (doc.value.a - range.value.a) * range.value.d / (range.value.d + doc.value.d);
        at = range.value.a + delta;
      }
      if ( at > range.value.max ) {
        range.query.$lte = range.value.max;
        doc.query = {$gt: range.value.max}
      } else if ( at < doc.value.min ) {
        range.query.$lt = doc.value.min;
        doc.query = {$gte: doc.value.min}
      }else{
        range.query.$lt = at;
        doc.query = {$gte: at}
      }
      rangesByField[doc._id.field].push(range);
      rangesByField[doc._id.field].push(doc);
    }else{
      doc.query = range.query
      rangesByField[doc._id.field].push(doc);
    }
  }
  var ret = [];
  for ( var field in rangesByField ){
    if ( rangesByField[field].length <= 1 ) {
      var cur = utils.getCollection(options.dst).find({
        '_id.type': 'd',
        '_id.field': field,
        ignore: {$ne: true}
      });
      while( cur.hasNext() ) {
        var doc = cur.next();
      }
      rangesByField[field][0].query = { $type: 1 } // BISON Double
    }
    for ( var i in rangesByField[field] ) {
      ret.push({
        field: field,
        query: utils.encode(rangesByField[field][i].query)
      });
    }
  }
  for ( var i in collectionNames ) {
    utils.getWritableCollection(collectionNames[i]).drop();
  }
  return ret;
}

function fields_job(org_options, fields, top_field, range_queries) {
  print('== fields_job ==');
  var options = utils.dup(org_options);
  options.args['F'] = fields.join(',');
  options.args['T'] = top_field;
  options.args['RQ'] = range_queries;
  var localrun = false;
  var single_worker = false;
  var count = utils.getCollection(options.src).stats().count;
  if ( count <= 1000 ){
    single_worker = true;
  }
  if ( count <= 2000 ){
    localrun = true;
  }
  return mapreduce(jobctl, options, {
    localrun: localrun,
    single_worker: single_worker,
    bulk: 1000,
    prepare_create : function() {
      this.query = utils.decode(options.args['Q']);
      return {ok:1};
    },
    prepare_run : function(){
      this.goal_field = this.ARGS['GF'];
      this.fields = this.ARGS['F'].split(',');
      this.top_field = this.ARGS['T'];
      this.query_by_real = utils.toRangeQuery(this.ARGS['RQ']);
      return {ok:1};
    },
    map_query: function() {
      return this.query;
    },
    unique_pre_run : function(){
      return {ok:1};
    },
    map : function(id, doc){
      var res = {}
      res[utils.toTypeValue(utils.getField(doc, this.goal_field))] = 1;
      this.emit('__ALL__', res);
      if ( this.top_field ) {
        var field = this.top_field;
        var value = utils.getField(doc, field);
        var r = {}
        r[utils.toTypeValue(value)] = res;
        this.emit(field, r);
      } else {
        for (var i in this.fields) {
          var field = this.fields[i];
          var value = utils.getField(doc, field);
          var r = {}
          if ( typeof value === 'number' &&
               !isNaN(value) && value !== Infinity && value !== -Infinity &&
               this.query_by_real[field]) {
            for ( var j in this.query_by_real[field] ) {
              var range = this.query_by_real[field][j];
              var matched = true
              for ( var op in range.query){
                var cond = range.query[op];
                if ( op === '$lt' ) {
                  if ( ! (value < cond) ) { matched = false; break; }
                }else if ( op === '$lte' ) {
                  if ( ! (value <= cond) ) { matched = false; break; }
                }else if ( op === '$gt' ) {
                  if ( ! (value > cond) ) { matched = false; break; }
                }else if ( op === '$gte' ) {
                  if ( ! (value >= cond) ) { matched = false; break; }
                }
              }
              if ( matched ) {
                r['r,'+j] = res;
                break;
              }
            }
          }else{
            r[utils.toTypeValue(value)] = res;
          }
          this.emit(field, r);
        }
      }
    },
    reduce : function(key, values,last){
      var merged = {}
      for( var i in values ) {
        var value = values[i];
        for( var j in value ) {
          if ( typeof value[j] === 'number' ) {
            utils.addVector(merged, value);
            break;
          } else {
            if ( !merged[j] ) {
              merged[j] = {}
            }
            utils.addVector(merged[j], value[j]);
          }
        }
      }
      if ( last ) {
        if ( key === '__ALL__' ) {
          var count = 0;
          var base = 0;
          for ( var i in merged ) {
            base++;
            count += merged[i];
          }
          var mc = utils.mc( base, count, merged );
          merged['__COUNT__'] = count;
          merged['__BASE__'] = base;
          merged['__MC__'] = mc;
          merged['__FIELDS__'] = this.fields;
        }else{
          for ( var i in merged ) {
            var count = 0;
            for ( var j in merged[i] ) {
              count += merged[i][j];
            }
            merged[i]['__COUNT__'] = count;
          }
        }
      }
      return merged;
    },
    unique_post_run : function(){
      var all = this.dst.findOne({_id: '__ALL__'});
      this.meta = {
        src: this.SRCCOL,
        dst: this.DSTCOL,
        id3: {
          goal_field: this.goal_field,
          fields: this.fields,
          all: all
        }
      }
      this.setmeta(this.meta);
      return { meta : this.meta };
    }
  });
}
