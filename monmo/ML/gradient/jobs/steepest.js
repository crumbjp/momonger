function main(jobctl, org_options) {
  var options = utils.dup(org_options);

  if ( !options.dst ) {
    var psrc = utils.parseCollection(options.src);
    options.dst = psrc.db + '.steepest.'   +psrc.col;
  }

  var dstcol = utils.getWritableCollection(options.dst);
  var meta = null;
  var resume = options.args['R'];
  var proportions = null;
  if ( !resume ) {
    print('== FIRST ==');
    var ret = first_alpha_job(options);
    meta = ret.data.meta;
    utils.setmeta(dstcol, meta);
    var diff = eval_alpha(options,0);
    var alpha = utils.dup(dstcol.findOne({_id: '' +0}));
    proportions = {
      alpha: alpha.alpha.proportion,
      beta: alpha.beta.proportion,
    }
    alpha.diff = diff;
    dstcol.save(alpha);
  } else {
    meta = utils.getmeta(dstcol);
    var alpha = utils.dup(dstcol.findOne({_id: '' +resume}));
    proportions = {
      alpha: alpha.alpha.proportion,
      beta: alpha.beta.proportion,
    }
  }

  var max_it = options.args['M'];
  var threshold = options.args['T'];
  var threshold_count = 0;
  var prev_diff = null;
  var cap_modes = {
    alpha: 0,
    beta: 0,
  };
  var parts = ['alpha']
  if ( options.args['B'] ) {
    parts = ['alpha', 'beta']
  }
  for ( var i = resume; i < max_it; i++ ) {
    var part = parts[i%parts.length];
    var diff = next_alpha(options, i, part);
    if ( ! diff ) {
      break;
    }
    if ( cap_modes[part] > 0 ) {
      cap_modes[part]--;
    }
  }

  function eval_alpha(org_options, i) {
    var options = utils.dup(org_options);
    options.args.alpha_col_name = options.dst;
    options.args.alpha_name = '' + i;
    options.dst = options.dst + '.g' + i;
    var job = difference_job(options);
    var differences = wait_mapreduce(jobctl, {j: job});
    return differences.j.data.meta.diff;
  }

  function next_alpha(org_options, I, part){
    print('== IT == ' + I + ' : ' + part);
    var options = utils.dup(org_options);
    var delta = options.args['D'];
    var alpha = utils.dup(dstcol.findOne({_id: '' +I}));
    var cur_diff = alpha.diff;

    var it_name = options.dst + '.it' +I;
    var it_alpha_col = utils.getWritableCollection(it_name)
    var jobs = [];

    for ( var f in alpha[part].loc ) {
      partial_differentiation(part + '.loc.' + f);
    }
    function partial_differentiation(alpha_name){
      var dup_alpha = utils.dup(alpha);
      var elem = utils.getField(dup_alpha, alpha_name);
      utils.setField(dup_alpha, alpha_name, elem + delta);
      dup_alpha._id = alpha_name;
      it_alpha_col.save(dup_alpha)

      options.dst = it_name + '.' + alpha_name;
      options.args.alpha_col_name = it_name;
      options.args.alpha_name = alpha_name;
      jobs.push(difference_job(options));
    }

    var diff_vector = { }
    var differences = wait_mapreduce(jobctl, jobs);
    for ( var i in differences ) {
      var difference = differences[i];
      diff_vector[difference.data.meta.steepest.alpha_name] = difference.data.meta.diff;
    }
    it_alpha_col.drop();

    alpha._id = '' + (I + 1);
    while ( true ) {
      var newalpha = utils.dup(alpha);
      for ( var f in diff_vector ) {
        var diff = diff_vector[f];
        var elem = utils.getField(newalpha, f);
        utils.setField(newalpha, f, elem + (alpha.diff - diff) / delta  * proportions[part]);
      }

      delete(newalpha.diff);
      dstcol.save(newalpha);


      var diff = eval_alpha(org_options,(I+1));
      newalpha.diff = diff;
      // -----
      printjson('------------DELTA---------------');
      newalpha[part].proportion = proportions[part];
      printjson(newalpha);
      // -----
      if ( cur_diff ) {
        if ( cur_diff === newalpha.diff ) {
          throw 'Equal diff P:' + cur_diff + ' == A:' + newalpha.diff;
        }
        move = newalpha.diff/(cur_diff - newalpha.diff);

        if ( move > 5 ) {
          if ( !cap_modes[part] ) {
            proportions[part] *= Math.log(move);
          }
        } else if ( move < 0) {
          if ( newalpha.diff / cur_diff < 2 ) {
            proportions[part] /= 2;
          }else{
            proportions[part] /= (newalpha.diff / cur_diff);
          }
          print('Inappropreate delta !!!');
          cap_modes[part] = 5;
          continue;
        } else if ( move < 2) {
          proportions[part] /= move;
        }

        if ( 1 / move  < threshold ) {
          threshold_count++;
        } else {
          threshold_count = 0;
        }
        newalpha.threshold_count = threshold_count;
        if ( threshold_count > 5 ) {
          dstcol.save(newalpha);
          return null;
        }
      }
      newalpha[part].proportion = proportions[part];
      dstcol.save(newalpha);
      return diff;
    }
  }


  function first_alpha_job(options) {
    return map(jobctl,options,{
      prepare_create : function() {
        var pdst = utils.parseCollection(this.DSTCOL);
        utils.cleanCollections(this.DSTCOL+'\.');
        eval("this.query = " + options.args['Q'] + ';');

        return {ok:1};
      },
      prepare_run : function(){
        this.field      = this.ARGS['F'];
        this.goal       = this.ARGS['G'];
        this.goal_field = this.ARGS['GF'];
        this.delta      = this.ARGS['D'];
        this.proportion = this.ARGS['P'];
        this.initial_alpha = this.ARGS['I'];
        this.alpha_name = '0';

        this.meta =  utils.getmeta(this.src);
        this.meta.teach = this.SRCCOL;
        this.meta.steepest = {
          field     : this.field,
          goal      : this.goal,
          goal_field: this.goal_field,
          delta     : this.delta,
          alpha_name: this.alpha_name,
        };
        this.alpha_vector = {};
        if ( this.initial_alpha ) {
          var initial_vector = utils.getCollection(this.initial_alpha).findOne();
          for (var i in initial_vector.alpha.loc) {
            var alpha_key = 'alpha.loc.' + i;
            this.alpha_vector[alpha_key] = initial_vector.alpha.loc[i];
          }
          for (var i in initial_vector.beta.loc) {
            var beta_key = 'beta.loc.' + i;
            this.alpha_vector[beta_key] = initial_vector.beta.loc[i];
          }
          if ( ! this.alpha_vector ) {
            return {ok: -1, msg: 'Not found', initial: this.initial_alpha};
          }
        }
        return {ok:1};
      },
      map_query: function() {
        return this.query;
      },
      unique_pre_run : function(){
        return {ok:1};
      },
      map : function(id,val){
        var loc  = utils.getField(val,this.field);
        if ( loc ) {
          for (var i in loc) {
            var alpha_key = 'alpha.loc.' + i;
            if ( ! alpha_key in this.alpha_vector ) {
              this.alpha_vector[alpha_key] = 0;
            }
            var beta_key = 'beta.loc.' + i;
            if ( ! beta_key in this.alpha_vector ) {
              this.alpha_vector[beta_key] = 0;
            }
          }
        }
      },
      endsubs: function(){
        printjson(this.alpha_vector);
        this.dst.update({
          _id: this.alpha_name,
        },{
          $set: this.alpha_vector,
          $setOnInsert: {
            'alpha.proportion': this.proportion,
            'beta.proportion': this.proportion,
          }
        },{
          upsert: 1
        });
      },
      unique_post_run : function(){
        return { meta : this.meta };
      }
    });
  }


  function difference_job(options){
    return async_mapreduce(jobctl,options,{
      field: 'diff',
      prepare_create : function() {
        eval("this.query = " + options.args['Q'] + ';');
        return {ok:1};
      },
      prepare_run : function(){
        this.field      = this.ARGS['F'];
        this.goal       = this.ARGS['G'];
        this.goal_field = this.ARGS['GF'];
        this.alpha_col_name = this.ARGS['alpha_col_name'];
        this.alpha_name     = this.ARGS['alpha_name'];

        this.meta =  utils.getmeta(this.src);
        this.meta.teach = this.SRCCOL;
        this.meta.steepest = {
          goal      : this.goal,
          field     : this.field,
          alpha_col : this.alpha_col_name,
          alpha_name: this.alpha_name,
        };
        this.goal_col = utils.getCollection(this.goal);
        this.alpha_col = utils.getWritableCollection(this.alpha_col_name);
        this.alpha = this.alpha_col.findOne({_id: this.alpha_name});
        this.alpha_vector = utils.dup(this.alpha.alpha.loc);
        this.beta_vector = utils.dup(this.alpha.beta.loc);
        return {ok:1};
      },
      map_query: function() {
        return this.query;
      },
      unique_pre_run : function(){
        return {ok:1};
      },
      map : function(id,val){
        var value = 0;
        var loc  = utils.getField(val,this.field);
        utils.addVector(loc, this.beta_vector);
        if ( loc ) {
          for (var i in this.alpha_vector) {
            value += loc[i] * this.alpha_vector[i];
          }
        }
        var g = this.goal_col.findOne({_id: id});
        var gscore = 0;
        if ( g ) {
          gscore = utils.getField(g,this.goal_field);
        }
        var diff = value - gscore;
        this.emit(this.alpha_name, diff * diff);
      },
      reduce : function(key,values){
        var ret = 0;
        for ( var i in values ) {
          ret += values[i];
        }
        return ret;
      },
      unique_post_run : function(){
        var diff = this.dst.findOne({_id: this.alpha_name})
        this.meta.diff = diff.diff;
        this.dst.drop();
        return { meta : this.meta };
      }
    });
  }
}
