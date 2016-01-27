function main(jobctl,options) {
  var append = parseInt(options.args['A']);
  var resume = options.args['R'];
  var NS = '';
  var I  = 1;
  if( append ) {
    print('== APPEND ==');
    options.args['cluster'] = options.dst + '.fin.cluster';
    options.dst = options.dst + '.fin.data';
    options.args['meta'] =  utils.getmeta(utils.getCollection(options.dst));
    printjson(options);
    deploy_data(append);
    return;
  } else if( ! resume ) {
    print('== FIRST ==');
    var ret = first_job();
    if ( ret.ok !== 1 ) {
      return;
    }
    options.args['meta'] = ret.data.meta;
    NS = ret.dst;
  }else{
    print('== RESUME ==');
    return;
    // options.args['meta'] =  utils.getmeta(utils.getCollection(resume));
    // printjson(options.args['meta']);
    // NS = options.args['meta'].kmeans.ns;
    // I  = options.args['meta'].kmeans.it;
    // for (var i = I ; i <= 99 ; i++ ) {
    //   utils.cleanCollections(NS+'.it'+(i+1)+'\.');
    // }
    // utils.cleanCollections(NS+'.fin\.');
    // var prev_d = utils.getWritableCollection(NS+'.it'+I+'.data');
    // prev_d.update(utils.IGNORE_META(),
    //               {
    //                 $set:{
    //                   tm:0,
    //                   by:utils.EMP_NAME()
    //                 }},
    //               {multi:true});
    // var prev_c = utils.getWritableCollection(NS+'.it'+I+'.cluster');
    // prev_c.update(utils.IGNORE_META(),
    //               {
    //                 $set:{
    //                   tm:0,
    //                   by:utils.EMP_NAME()
    //                 }},
    //               {multi:true});
  }
  for (var i = I ; i <= 99 ; i++ ) {
    var PREV_C = NS+'.it'+i+'.cluster';
    var PREV_D = NS+'.it'+i+'.data';
    var CUR_C  = NS+'.it'+(i+1)+'.cluster';
    var CUR_D  = NS+'.it'+(i+1)+'.data';

    options.args['meta'].kmeans.it     = (i+1);
    options.args['meta'].kmeans.ns     = NS;
    options.args['meta'].kmeans.data   = CUR_D;
    options.args['meta'].kmeans.cluster= CUR_C;

    print('== '+i+' DATA ==');
    options.src = PREV_D;
    options.dst = CUR_D;
    options.args['prev_cluster'] = options.args['cluster'];
    options.args['cluster'] = PREV_C;

    ret = deploy_data();
    print(' DIFF : ' + ret.data.cdiff);
    if ( ret.ok === 2 ) {
      utils.getWritableCollection(options.dst).drop();
      break;
    }
    if ( ret.ok !== 1 ) {
      return;
    }

    print('== '+i+' CLUSTER ==');
    // cluster iterate
    options.src = PREV_C;
    options.dst = CUR_C;
    options.args['data'] = CUR_D;

    ret = move_center();
    if ( ret.ok !== 1 ) {
      return;
    }
  }

   var meta = options.args['meta'];
  meta.kmeans.data   = NS+'.fin.data';
  meta.kmeans.cluster= NS+'.fin.cluster';

  var pns = utils.parseCollection(NS);

  utils.getWritableCollection(options.args['data']).renameCollection(pns.col+'.fin.data');
  utils.getWritableCollection(options.args['cluster']).renameCollection(pns.col+'.fin.cluster');

  utils.resetmeta(utils.getWritableCollection(meta.kmeans.data),meta);
  utils.resetmeta(utils.getWritableCollection(meta.kmeans.cluster),meta);

  printjson(meta);
  return;

  function first_job() {
    return map(jobctl,options,{
      empty_dst : function(){
        return this.SRCCOL + '.kmeans'
      },
      prepare_create : function() {
        var pdst = utils.parseCollection(this.DSTCOL);
        utils.cleanCollections(this.DSTCOL+'\.');
        return {ok:1};
      },

      prepare_run : function(){
        this.initial_cluster = this.ARGS['I'];
        this.cluster_field   = this.ARGS['C'];
        this.field           = this.ARGS['F'];

        this.meta =  utils.getmeta(this.src);
        this.meta.vector = this.SRCCOL;
        this.meta.kmeans = {
          data    : this.DSTCOL + '.it1.data',
          cluster : this.DSTCOL + '.it1.cluster',
          field   : this.ARGS['F']
        };

        this.datacol    = utils.getWritableCollection(this.meta.kmeans.data);
        return {ok:1};
      },
      unique_pre_run : function(){
        this.cluster = utils.getWritableCollection(this.meta.kmeans.cluster);
        this.cluster.ensureIndex({tm:1});
        this.cluster.ensureIndex({s:1});
        var cs = utils.getClustersRaw(this.initial_cluster,this.cluster_field);
        for ( var c in cs ) {
          this.cluster.save({
              _id : c ,
            s : 0,
            loc : cs[c] ,
            tm: 0,
            by: utils.EMP_NAME()
          });
        }
        return {ok:1};
      },
      map : function(id,val){
        var loc  = utils.getField(val,this.field);
        if ( loc ) {
          this.datacol.save({
            _id:val._id,
            loc:loc,
             tm: 0,
            by: utils.EMP_NAME()
          });
        }
      },
      unique_post_run : function(){
        return { meta : this.meta };
      }
    });
  }

  function deploy_data(append){
    // data iterate
    options.args.A = append;
    return map(jobctl,options,{
      append: !!append,
      prepare_create : function(){
        this.dst.ensureIndex({'c':1});
        this.dst.ensureIndex({'a':1});
        return {ok:1};
      },
      prepare_run : function(){
        this.meta = this.ARGS['meta'];
        this.diffFunc   =  utils.diffVector;
        if ( this.meta.normalize ) {
          this.diffFunc   =  utils.diffAngle;
        }
        utils.setmeta(this.dst,this.meta);
        return {ok:1};
      },
      unique_pre_run : function(){
        if ( this.ARGS['prev_cluster'] ){
          this.cs = utils.getClusters(this.ARGS['cluster']);
          if ( ! this.cs ) {
            return {
              ok : 0,
              msg: 'Could not get cluster info',
              data:this.cs
            }
          }
          var cs_history = utils.getClusters(this.ARGS['prev_cluster']);
          this.cdiff = 0;

          for ( var c in this.cs ){
            this.cdiff += this.diffFunc(this.cs[c].loc,cs_history[c].loc);
          }
          this.meta.kmeans.cdiff = this.cdiff;
          utils.resetmeta(this.dst, this.meta);

          if ( this.cdiff < 1.0e-12 ) {
            return {
              ok : 2,
              msg: 'End of iteration',
              data: {cdiff: this.cdiff}
            }
          }
          return {
            ok : 1,
            msg: 'Next iteration',
            data: {cdiff: this.cdiff}
          }
        }
        return {ok:1};
      },
      pre_map : function(){
        if ( ! this.cs ){
          this.cs = utils.getClusters(this.ARGS['cluster']);
        }
      },
      map_query : function(){
        var ret = {};
        if ( this.ARGS['A'] ) {
          ret.a = parseInt(this.ARGS['A']);
        }
        return ret;
      },
      map : function(id,val){
        var cur = null;
        var min = null;
        var cssum     = 0;
        val = utils.dup(val);
        val.cs = [];
        for ( var c in this.cs ){
          var diff = this.diffFunc(val.loc , this.cs[c].loc);
          if ( min === null || min > diff ) {
            cur = c;
            min = diff;
          }
          var score = Number.MAX_VALUE;
          if ( diff ) {
            score = 1/diff;
          }
          val.cs.push({c:c,s:score});
          cssum += score;
        }

        val.c  = cur;
        for ( var i in val.cs ){
          val.cs[i].s /= cssum;
          val.cs[i].s = (val.cs[i].s<1.0e-12)?0:val.cs[i].s;
        }
        val.cs = utils.sort(val.cs,function(a,b){ return a.s > b.s;});
        val.tm = 0;
        val.by = utils.EMP_NAME();
        if ( this.ARGS['A'] ) {
          val.a = parseInt(this.ARGS['A']);
        }
        this.dst.save(val);
      },
      unique_post_run : function(){
        this.meta =  utils.getmeta(this.dst);
        return {
          cdiff : this.meta.kmeans.cdiff
        };
        return true;
      },
      direct : !append // Cannot use direct due to append should do a part of the data
    });
  }

  function move_center(){
    return map(jobctl,options,{
      prepare_create : function(){
        return { ok:1 };
      },
      prepare_run : function(){
        this.data = utils.getCollection(this.ARGS['data']);
        this.meta = this.ARGS['meta'];
        utils.setmeta(this.dst,this.meta);
        return { ok:1 };
      },
      map : function(id,val){
        var newc = {
          _id : id,
             s:0,
           loc:{},
            tm:0,
            by:utils.EMP_NAME()
        };
        var _c_data = this.data.find({'c':id}).addOption(DBQuery.Option.noTimeout);
        while(_c_data.hasNext()){
          var data = _c_data.next();
          newc.loc = utils.addVector(newc.loc,data.loc);
          newc.s++;
        }
        if ( newc.s > 0 ) {
          if ( this.meta.normalize ) {
            newc.loc = utils.normalize(newc.loc);
          }else{
            newc.loc = utils.normalize(newc.loc,newc.s);
          }
        }else{
          newc.loc = val.loc;
        }
        this.dst.save(newc);
      },
      direct : true
    });
  }
}
