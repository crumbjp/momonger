// ------ DRY ---
var momonger = {
  parseNS: function(ns){
    var ns_split  = ns.split('\.');
    return {
      db  : ns_split.shift() ,
      col : ns_split.join('\.')
    };
  }
};
var LOGLV = {
  MSG : 10,
  CRIT: 20,
  ERR : 30,
  WARN: 40,
  INFO: 50,
  DBG : 60,
  DUMP: 90,
};
var STR_LOGLV = {}
for ( var i in LOGLV ) {
  STR_LOGLV[LOGLV[i]] = i;
}

function logger ( lv, msg, arg ){
  if ( config.options.loglv >= lv ) {
    var line = STR_LOGLV[lv] + ', ' + msg + ', ';
    if ( arg ) {
      line += tojson(arg);
    }
    print( line);
  }
}

function ReplSet( info ) {
  this.info = info;
  this.getConnection();
}

ReplSet.prototype = {
  ns: {},
  sns: {},
  primary: null,
  secondary: null,
  secondaries: [],
  s_momonger_dbs: [],
  getConnection: function () {
    this.ns = {};
    this.primary = null;
    var first_conn = null;
    for(var i in this.info.hosts){
      var host = this.info.hosts[i];
      try {
        first_conn = connect(host + '/' + this.info.basedb);
        if ( first_conn ) {
          if ( this.info.auth ) {
            first_conn.getSiblingDB(this.info.auth.db).auth(this.info.auth.user,this.info.auth.passwd);
          }
          isMaster = first_conn.isMaster();
          if ( isMaster.ok == 1 && isMaster.me == isMaster.primary ) {
            break;
          }
        }
      } catch (e) {
      }
    }
    logger(LOGLV.MSG, 'First connection', first_conn);
    rs_status = first_conn.adminCommand('replSetGetStatus');
    if ( rs_status.ok == 1 ) {
      for ( var i in rs_status.members ) {
        var member = rs_status.members[i];
        if ( member.state === 1 ) {
          try {
            this.momonger_db = connect(member.name + '/' + this.info.basedb);
            this.primary = this.momonger_db.getMongo();
            if ( this.info.auth ) {
              this.momonger_db.getSiblingDB(this.info.auth.db).auth(this.info.auth.user,this.info.auth.passwd);
            }
            logger(LOGLV.MSG, 'Primary', this.momonger_db);
          } catch (e) {
            logger(LOGLV.WARN, 'Connect error ' + host, e);
          }
        }else if ( member.state === 2 ) {
          try {
            var secondary_db = connect(member.name + '/' + this.info.basedb);
            if ( this.info.auth ) {
              secondary_db.getSiblingDB(this.info.auth.db).auth(this.info.auth.user,this.info.auth.passwd);
            }
            secondary_db.setSlaveOk(true);
            this.s_momonger_dbs.push(secondary_db);
            this.secondaries.push(secondary_db.getMongo());
            logger(LOGLV.MSG, 'Secondary', secondary_db);
          } catch (e) {
            logger(LOGLV.WARN, 'Connect error ' + host, e);
          }
        }
      }
      this.getSecondary();
    } else if ( rs_status.info == 'mongos' ) {
      this.momonger_db = first_conn;
      this.primary = this.momonger_db.getMongo();
    } else {
      this.momonger_db = first_conn;
      this.primary = this.momonger_db.getMongo();
    }
  },
  getSecondary: function(){
    if ( this.secondary ){
      return this.secondary;
    }
    var n = this.secondaries.length;
    var i = Math.floor(n * Math.random());
    this.secondary = this.secondaries[i];
    return this.secondary;
  },
  getDB: function (db) {
    if (!this.primary) {
      return null;
    }
    if ( this.ns[db] ) {
      return this.ns[db];
    }
    this.ns[db] = this.primary.getDB(db);
    return this.ns[db];
  },
  getDBForRead: function (db) {
    if (!this.secondary) {
      return null;
    }
    if ( this.sns[db] ) {
      return this.sns[db];
    }
    this.sns[db] = this.secondary.getDB(db);
    this.sns[db].setSlaveOk();
    return this.sns[db];
  },
  getCollection: function (ns) {
    if (!this.primary) {
      return null;
    }
    if ( this.ns[ns] ) {
      return this.ns[ns];
    }
    var parsed = momonger.parseNS(ns);
    var db = this.getDB(parsed.db);
    if (!db ){
      return null;
    }
    this.ns[ns] = db.getCollection(parsed.col);
    return this.ns[ns];
  },
  getCollectionForRead: function (ns) {
    if ( !this.secondary ){
      return this.getCollection(ns);
    }
    if ( this.sns[ns] ) {
      return this.sns[ns];
    }
    var parsed = momonger.parseNS(ns);
    var db = this.getDBForRead(parsed.db);
    if (!db ){
      return null;
    }
    this.sns[ns] = db.getCollection(parsed.col);
    return this.sns[ns];
  },
  getName: function() {
    return this.momonger_db.runCommand("whatsmyuri").you;
  },
  getConnInfo: function(name) {
    var ops = this.momonger_db.currentOp(true).inprog;
    for ( var i in ops ) {
      if ( ops[i].client === n ) {
        return {
          client : ops[i].client,
          connectionId: ops[i].connectionId
        };
      }
    }
    return null;
  },
}

var RS = new ReplSet(config.mongo);
// ------
var utils = {
  META : function(){
    return {_id:'.meta'};
  },
  IGNORE_META : function(){
    return {_id:{'$ne':'.meta'}};
  },
  EMP_NAME:function(){
    return '                      ';
  },
  getName: function() {
    RS.getName();
  },
  getmeta: function(col){
    var meta = col.findOne(utils.META(),{_id:0});
    if ( ! meta ){
      meta = {};
    }
    return meta;
  },
  setmeta:  function(col,meta){
    return col.findAndModify({
      query: utils.META(),
      update:{ $set:meta},
      upsert:true,
      new: true
    });
  },
  resetmeta:  function(col,meta){
    col.update(utils.META(),meta);
  },
  _cleanCollections : function (db,cond){
    var collections = RS.primary.getDB(db).getCollectionNames();
    var re = new RegExp(cond);
    for ( var c in collections ) {
      var name = collections[c];
      if ( name.match(re) ){
        RS.primary.getDB(db).getCollection(name).drop();
      }
    }
  },
  cleanCollections : function (ns){
    var pns = utils.parseCollection(ns);
    utils._cleanCollections(pns.db,'^' + pns.col);
  },
  getCollection : function(ns){
    return RS.getCollectionForRead(ns);
  },
  getWritableCollection : function(ns){
    return RS.getCollection(ns);
  },
  katakana: function(str) {
    var ret = '';
    for ( var i = 0;i<str.length;i++ ){
      var c = str.charCodeAt(i);
      if ( c>=0x3040 && c<=0x309f ){
        c += 0x60
      }
      ret += String.fromCharCode(c);
    }
    return ret;
  },
  unique : function(arr){
    var u = {};
    var ret = [];
    for ( var i in arr ){
      if ( ! u[arr[i]] ) {
        u[arr[i]] = 1;
        ret.push(arr[i]);
      }
    }
    return ret;
  },
  //  reduce : function(arr){
  //    var u = {};
  //    for ( var i in arr ){
  //      var heads = utils.heads(arr[i],arr[i].length);
  //      for ( var h in heads ) {
  //        var head = heads[h];
  //        if ( head.length===arr[i].length ) {
  //          u[head] = 2;
  //        }else  {
  //          u[head] = 1;
  //        }
  //      }
  //    }
  //    var ret = [];
  //    for ( var w in u ){
  //      if ( u[w] === 2 ) {
  //        ret.push(w);
  //      }
  //    }
  //    return ret;
  //  },
  // @@@ Array.sort seems like work well...
  sort : function(arr,comparator){
    if ( arr.length < 1 ) {
      return arr;
    }
    var c=arr.shift();
    var b=[];
    var a=[];
    for ( var i in arr ) {
      if ( comparator(arr[i],c) ) {
        b.push(arr[i]);
      }else{
        a.push(arr[i]);
      }
    }
    return utils.sort(b,comparator).concat([c]).concat(utils.sort(a,comparator));
  },
  shuffle: function(arr) {
    var ret = [];
    while (arr.length) {
      var i = Math.floor(Math.random() * arr.length);
      ret.push(arr[i]);
      arr.splice(i,1);
    }
    return ret;
  },
  extend : function(  ) {
    var ret = null;
    for ( var i in arguments ) {
      var arg = arguments[i];
      if ( ret === null ) {
        ret = arg;
      }else{
        for ( var j in arg ) {
          ret[j] = arg[j];
        }
      }
    }
    return ret;
  },
  array_in : function (arr,t){
    for ( var i in arr ) {
      if ( arr[i] === t ) {
        return true;
      }
    }
    return false;
  },
  array_all : function (arr,ts){
    for ( var j in ts ) {
      var flg = 0;
      for ( var i in arr ) {
        if ( arr[i] === ts[j] ) {
          flg = 1;
          break;
        }
      }
      if ( ! flg ) {
        return false;
      }
    }
    return true;
  },
  heads : function ( arr, n ) {
    var ret = [];
    for ( var i = ((arr.length<n)?arr.length:n) ; i >= 1 ; i-- ){
      ret.push(arr.slice(0,i));
    }
    return ret;
  },
  //  hash_count: function (a) {
  //    var n = 0;
  //    for ( var i in a ) {
  //      n++;
  //    }
  //    return n;
  //  },
  getField : function(data,field) {
    if ( ! field ) {
      return data;
    }
    function get(d,f){
      if ( typeof d !== 'object' || !d ) {
        return null;
      }
      var k = f.shift();
      var c = d[k];
      if ( f.length === 0 ) {
        return c;
      }
      return get(c,f);
    }
    return get(data,field.split('\.'));
  },
  setField : function(data,field,val) {
    function set(d,f){
      var k = f.shift();
      if ( f.length === 0 ) {
        d[k] = val;
        return;
      }
      return set(d[k],f);
    }
    return set(data,field.split('\.'));
  },
  // Simple add
  addVector: function (loc1,loc2){
    for( var d in loc2 ) {
      if ( !(d in loc1) ) {
        loc1[d] = 0;
      }
      loc1[d] += loc2[d];
    }
    return loc1;
  },
  // Returns Euclid difference
  diffVector: function (loc1,loc2){
    function pow2(v){
      return v * v;
    }
    var dist = 0;
    for( var d in loc1 ) {
      dist += pow2(loc1[d]-((loc2[d])?loc2[d]:0));
    }
    for( var d in loc2 ) {
      if ( !(d in loc1) ) {
        dist += pow2(loc2[d]);
      }
    }
    return Math.sqrt(dist);
  },
  // Returns 1 - Cos difference
  diffAngle: function (loc1,loc2){
    var dist = 0;
    for( var d in loc1 ) {
      dist += (loc1[d]*((loc2[d])?loc2[d]:0));
    }
    return 1-dist;
  },
  normalize: function(vec,div){
    if ( ! div ) {
      var diff = 0;
      for ( var v in vec ) {
        diff += vec[v]*vec[v];
      }
      div = Math.sqrt(diff);
    }
    for ( var v in vec ) {
      vec[v] /= div;
    }
    return vec;
  },
  trimSpace : function(str,n){
    return str.split(/[ \t]+/).join(' ');
  },
  parseCollection : function(ns){
    var ns_split  = ns.split('\.');
    return {
      db  : ns_split.shift() ,
      col : ns_split.join('\.')
    };
  },


  //  callIfValid : function( obj , member , arg ){
  //    var type = typeof obj[member];
  //    if ( type === 'function' ) {
  //      return obj[member](arg);
  //    }
  //  },
  //  getVal : function( def , obj, member , arg ){
  //    var type = typeof obj[member];
  //    if ( type === 'function' ) {
  //      return obj[member](arg);
  //    } else if ( type !== 'undefined' ) {
  //      return obj[member];
  //    }else{
  //      return def;
  //    }
  //  }
  // Temporary ... Where it should be located ? ...
  dup : function(obj) {
    return utils.decode(utils.encode(obj));
  },
  getClusters : function (ns,field) {
    return utils.getClustersRaw(ns,field,utils.dup); // Convert from BSON to JS for v8 optimize
  },
  getClustersRaw : function (ns,field,callback) {
    if ( ! callback ) {
      callback = function(d) { return d; };
    }
    var cs = {};
    var _c_cluster = utils.getCollection(ns).find(utils.IGNORE_META()).addOption(DBQuery.Option.noTimeout);
    while (_c_cluster.hasNext()){
      var cluster = _c_cluster.next();
      cs[cluster._id.valueOf()] = callback(utils.getField(cluster,field));
    }
    return cs;
  },
  copyCollection : function(srccol,dstcol,cond){
    if ( ! cond ){
      cond = function(a){ return true; }
    }
    var src = utils.getCollection(srccol);
    var dst = utils.getWritableCollection(dstcol);
    var _c_src= src.find(utils.IGNORE_META());
    var bulk = null;
    while(_c_src.hasNext()){
      var data = _c_src.next();
      if ( cond(data) ) {
        if ( !bulk ) {
          bulk = dst.initializeOrderedBulkOp();
        }
        bulk.insert(data);
        if ( bulk.nInsertOps > 1000 ) {
          bulk.execute({w:0});
          bulk = null;
        }
        // dst.save(data);
      }
    }
    if ( bulk ) {
      bulk.execute({w:0});
      bulk = null;
    }
  },
  toObjectId : function(oid){
    try {
      return ObjectId(oid);
    }catch(e){
      return oid;
    }
  },
  ln: function(base, number){
    return Math.log(number) / Math.log(base);
  },
  mc: function(base, count, hash){
    var mc = 0;
    if ( ! count ) {
      return 0;
    }
    if ( base === 1 ) {
      return 1;
    }
    for ( var i in hash ) {
      var v = hash[i] / count;
      mc -= v * utils.ln(base, v);
    }
    return mc;
  },
  diffArray: function(src, arr) {
    return src.filter(function(a){
      return arr.indexOf(a) < 0;
    });
  },
  escapeField: function(str){
    return (''+str).split('.').join('/');
  },
  toField: function(escaped){
    return escaped.split('/').join('.')
  },
  toTypeValue: function(value) {
    if ( value === undefined ) {
      value = null
    }
    var type = typeof value;
    if (type === 'number') {
      value = utils.escapeField(value);
    }
    return type[0]+','+value;
  },
  fromTypeValue: function(str) {
    var vals = str.split(',');
    var type = vals.shift();
    var val = vals.join(',');
    if ( type === 'n' ) {
      val = parseFloat(utils.toField(val));
    }else if ( type === 'b') {
      val = val === 'true';
    // }else if ( type === 'u') {
    //   val = null;
    }else if ( type === 'o' && val === 'null') {
      val = null;
    }else if ( type === 'r') {
      val = parseFloat(val);
    }
    return val;
  },
  toRangeQuery: function (rangeQueries) {
    var queryByReal = {}
    if ( rangeQueries ) {
      for ( var i in rangeQueries ) {
        var range = utils.dup(rangeQueries[i]);
        if ( !queryByReal[range.field] ) {
          queryByReal[range.field] = []
        }
        if ( typeof range.query === 'string' ) {
          range.query = utils.decode(range.query);
        }
        queryByReal[range.field].push(range);
      }
    }
    return queryByReal;
  },
  encode: function (val) {
    return tojsononeline(val);
  },
  decode: function (str){
    eval('var ret='+str);
    return ret;
  }
}
