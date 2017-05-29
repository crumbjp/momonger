var mongoAsync = {
  during: function(test, fn, callback){
    for(;;){
      var continued = null;
      test(function(e, c){
        continued = c;
      });
      if ( !continued ) {
        return callback();
      }
      var err = 'no callback during';
      fn(function(e){
        err = e;
      });
      if ( err ) {
        return callback(err);
      }
    }
  },
  eachSeries: function(arr, iterator, callback){
    var results = [];
    for ( var i in arr) {
      var err = 'no callback eachSeries';
      iterator(arr[i], function(e, result){
        err = e;
        results.push(result);
      });
      if ( err ) {
        return callback(err, results);
      }
    }
    return callback(err, results);
  },
  series: function(tasks, callback){
    var results = [];
    for ( var i in tasks){
      var task = tasks[i];
      var err = 'no callback series';
      task(function(e, result){
        err = e;
        results.push(result);
      });
      if ( err ) {
        return callback(err, results);
      }
    }
    return callback(err, results);
  },
}

function array_in(arr, elem) {
  return (arr.indexOf(elem) >= 0);
}

function JPTokenizer (dictionary, _dst, options, lib) {
  if ( !options ) {
    options = {};
  }
  if ( !lib ) {
    lib = {};
  }
  this.dictionary = dictionary;
  this._dst = _dst;
  this.includeUnknownToken = options['includeUnknownToken'];
  this.separateLoanWord = options['separateLoanWord'];
  if ( lib.morpho ) {
    this.morpho      = lib.morpho;
  }else{
    this.morpho      = morpho; // TODO: require('./morpho.js')
  }
  if ( lib.async ) {
    this.async      = lib.async;
  }else{
    this.async      = mongoAsync;
  }
}

JPTokenizer.prototype.form = function(sentence, candidate, done) {
  var self = this;
  var result = null;
  self.async.eachSeries(
    candidate.w,
    function(word, done){
      var head = sentence.substring(0,word.length);
      if ( word !== head ) {
        return done(null);
      }
      if ( ! candidate.f[word] ) {
        // noum
        result = [candidate];
        return done('found');
      }
      // verb
      self.async.eachSeries(
        candidate.f[word],
        function(kind, done){
          if ( kind === 1 ) {
            candidate.l = word.length;
            result = [candidate];
            // next will be overwrote
          }else if ( kind === 4 ) {
            if ( result === null || result[0].l <= word.length ) {
              return self.parse_query(candidate,sentence.substring(word.length),{w:'*',t:{'$in':["名詞"]}}, function(err, follow){
                if ( !follow ) {
                  return done(null);
                }
                candidate.l = word.length;
                result = [candidate].concat(follow);
                done('found');
              });
            }
          }else if ( kind === 2 ) {
            if ( result === null || result[0].l <= word.length ) {
              return self.parse_query(candidate,sentence.substring(word.length),{w:'*',t:{'$in':["助動詞","助詞"]}}, function(err, follow){
                if ( !follow ) {
                  return done(null);
                }
                candidate.l = word.length;
                result = [candidate].concat(follow);
                done('found');
              });
            }
          }else if ( kind === 3 ) {
            if ( result === null || result[0].l <= word.length ) {
              return self.parse_query(candidate,sentence.substring(word.length),{w:'*',t:{'$in':["動詞"]}}, function(err, follow){
                if ( !follow ) {
                  candidate.l = word.length;
                  result = [candidate];
                } else {
                  candidate.l = word.length;
                  result = [candidate].concat(follow);
                }
                done('found');
              });
            }
          }
          return done(null);
        },
        function(err){
          return done(err);
        });
    },
    function(err){
      if ( err ) {
        if ( err === 'found' ){
          return done(null, result);
        }
      }
      return done(err, result);
    });
}

function ascii2multi(str){
  var ret = '';
  var code;
  while ( (code = str.charCodeAt(ret.length)) < 128 ) {
    if       ( code <= 0x20 ) {
      ret += ' ';
    }else if ( code <= 0x7f ) {
      ret += String.fromCharCode(0xff00 + code - 0x20);
    }else {
      ret += ' ';
    }
  }
  return ret + str.substring(ret.length);
}
function alphabet(str){
  var ret = '';
  var uriflg = false;
  while ( true ) {
    var code = str.charCodeAt(ret.length);
    if ( code === 0xff1a ) {
      if ( str.charCodeAt(ret.length+1) === 0xff0f && str.charCodeAt(ret.length+2) === 0xff0f ) {
        uriflg = true;
      }else {
        return ret;
      }
    }

    if ( uriflg && code >= 0xff01 && code <= 0xff5e) {
      ret += str[ret.length];
    }else if ( code >= 0xff21 && code <= 0xff3a ) {
      ret += str[ret.length];
    }else if ( code >= 0xff41 && code <= 0xff5a ) {
      ret += String.fromCharCode(code - 0x20); // to upper
    }else if ( !ret && code >= 0xff01 && code <= 0xff5e) {
      ret = str[ret.length];
      return ret;
    }else{
      return ret;
    }
  }
  return ret;
}

function isIgnore(str){
  var code = str.charCodeAt(0);
  if ( code === 0x3000 || code >= 0x3041 && code <= 0x3094) {
    return false; // hiragana or katakana range
  }
  if ( code >= 0x4e00 && code <= 0x9fa5) {
    return false; // chinese in JP
  }
  if ( code >= 0xf900 && code <= 0xfa2d) {
    return false; // Full alphabet and half kana
  }
//  if ( code >= 0xff10 || code >= 0x3040 && code <= 0xff5a) {
//    return false;
//  }
  return true;
}

function katakana(str) {
  var ret = '';
  while ( true ) {
    var code = str.charCodeAt(ret.length);
    if ( code >= 0x30a1 && code <= 0x30fe && code != 0x30fb) {
      ret += str[ret.length];
    }else {
      return ret;
    }
  }
}

JPTokenizer.prototype.search_follows = function(candidate, sentence, done){
  var self = this;
  var results = [candidate];
  self.async.series([
    function(done){
      if ( !array_in(candidate.t,"名詞") ) {
        return done(null);
      }
      self.parse_query(candidate,sentence,{w:"*",t:{'$in':["助動詞"]}}, function(err, follow){
        if ( !follow ) {
          return done(null);
        }
        results = [candidate].concat(follow);
        return done('found');
      });
    },
    function(done){
      if ( !array_in(candidate.t,"名詞接続") ) {
        return done(null);
      }
      self.parse_query(candidate,sentence,{w:"*",t:{'$in':["名詞"]}}, function(err, follow){
        if ( !follow ) {
          return done(null);
        }
        results = [candidate].concat(follow);
        return done('found');
      });
    },
    function(done){
      if ( !array_in(candidate.t,"形容動詞語幹") ) {
        return done(null);
      }
      self.parse_query(candidate,sentence,{w:"だ",t:{'$in':["助動詞"]}}, function(err, follow){
        if ( !follow ) {
          return done(null);
        }
        results = [candidate].concat(follow);
        return done('found');
      });
    },
    function(done){
      if ( !array_in(candidate.t,"サ変接続") ) {
        return done(null);
      }
      self.parse_query(candidate,sentence,{w:{'$in':["できる","する"]},t:{'$in':["動詞"]}}, function(err, follow){
        if ( !follow ) {
          return done(null);
        }
        results = [candidate].concat(follow);
        return done('found');
      });
    },
    function(done){
      if ( !array_in(candidate.t,"副詞可能") ) {
        return done(null);
      }
      self.parse_query(candidate,sentence,{w:"*",t:adverb}, function(err, follow){
        if ( !follow ) {
          return done(null);
        }
        results = [candidate].concat(follow);
        return done('found');
      });
    },
    // function(done){
    //   if ( !array_in(candidate.t,"名詞") ) {
    //     return done(null)
    //   }
    //   self.parse_query(candidate,sentence,{w:"*",t:{'$in':["助詞","名詞"]}}, function(err, follow){
    //     if ( !follow ) {
    //       return done(null)
    //     }
    //    results = [candidate].concat(follow);
    //     return done('found')
    //   });
    // },
    // function(done){
    //   if ( !array_in(candidate.t,"NUMBER") ) {
    //     return done(null)
    //   }
    //   self.parse_query(candidate,sentence,{w:'*',t:{'$in':["助数詞"]}}, function(err, follow){
    //     if ( !follow ) {
    //       return done(null)
    //     }
    //    results = [candidate].concat(follow);
    //     return done('found')
    //   });
    // },
  ], function(err){
    return done(err, results);
  });
};

JPTokenizer.prototype.parse_original = function(sentence, word, type, done) {
  var self = this;
  this.dictionary.findBest(word, function(err, candidate){
    function getCandidate(candidate, done) {
      if ( candidate ) {
        return done(null, candidate);
      }
      //candidate = this.morpho.forms(self.dictionary.nheads(),{w:word,l:word.length,c:0,s:300,t:["名詞","ORG",type],h:word[0]});
      candidate = self.morpho.forms(self.dictionary.nheads(),{w:word,l:word.length,c:0,s:300,t:["名詞","ORG",type]});
      self.dictionary.upsert(candidate, done);
    };
    getCandidate(candidate, function(err, candidate){
      candidate.l = word.length;
      self.search_follows(candidate,sentence.substring(word.length), done);
    });
  });
};

JPTokenizer.prototype.original_candidate = function(sentence, done){
  var self = this;
  var match;
  if ( (match = sentence.match(this.morpho.re_date1)) ||  (match = sentence.match(this.morpho.re_date2)) ) {
    return done(null, { match: match[0], type: 'DATE'});
  }else if ( match = sentence.match(this.morpho.re_number1) ) {
    return done(null, { match: match[0], type: 'NUMBER'});
  }else if ( match = alphabet(sentence) ) {
    return done(null, { match: match, type: 'EN'});
  }else if ( match = katakana(sentence) ) {
    if (!this.separateLoanWord){
      return done(null, { match: match, type: '外来'});
    }
    var pos = 0;
    var results = [];
    self.async.during(
      function(done){
        done(null, pos < match.length);
      },
      function(done){
        var query = {
          h: match.substring(pos, pos+self.dictionary.nheads()),
          l: { $gte: 2 }
        };
        self.dictionary.findCandidates(query, function(err, candidates){
          for ( var candidate of candidates ) {
            if ( typeof candidate.w != 'string' ){
              continue;
            }
            var head = match.substring(pos,pos+candidate.w.length);
            if ( candidate.w === head ) {
              pos += candidate.w.length;
              results.push(candidate.w);
              return done(null);
            }
          }
          return done('unmatch');
        });
      },
      function(err) {
        if(err){
          return done(null, { match: match, type: '外来'});
        }
        return done(null, { match: results[0], type: '外来'});
      });
  } else if ( isIgnore(sentence) ) {
    return done(null, null);
  } else {
    return done(null, { match: '', type: null});
  }
}

JPTokenizer.prototype.parse_query = function(current, sentence, query, done){
  var self = this;
  if ( sentence.charCodeAt(0) < 128 ) {
    sentence = ascii2multi(sentence);
  }
  this.original_candidate(sentence, function(err, original_candidate){
    if (err) {
      return done(err);
    }
    if ( original_candidate === null ) {
      return done(null);
    }
    if ( query.w === '*' ) {
      delete query.w;
      query.h = sentence.substring(0,self.dictionary.nheads());
      //      query.w = { '$regex':'^'+sentence[0]};
    }
    query.l = {$gt: original_candidate.match.length };
    var finished = false;
    var result = null;
    self.async.during(
      function(done){
        done(null, !finished);
      },
      function(done){
        self.nquery++;
        self.dictionary.findCandidates(query, function(err, candidates){
          self.async.eachSeries(
            candidates,
            function(candidate, done){
              self.nfetch++;
              if ( typeof candidate.w === 'string' ){
                var head = sentence.substring(0,candidate.w.length);
                if ( candidate.w !== head ) {
                  return done(null);
                }
                return self.search_follows(candidate, sentence.substring(candidate.w.length), function(err, ret){
                  result = ret;
                  done('found');
                });
              }else{
                return self.form(sentence, candidate, function(err, ret){
                  result = ret;
                  if ( !result ) {
                    return done(null);
                  }
                  return done('found');
                });
              }
            },
            function(err){
              if ( err ) {
                finished = true;
                if ( err === 'found' ) {
                  return done(null);
                }
                return done(err);
              }
              if ( original_candidate.match ) {
                finished = true;
                return self.parse_original(sentence, original_candidate.match, original_candidate.type, function(err, ret){
                  result = ret;
                  done(err);
                });
              }
              if ( query.h && query.h.length > 1 ) {
                query.h = query.h.substring(0,query.h.length-1);
                return done(null);
              }
              return done('found'); // null
            });
        });
      },
      function(err){
        if (done) { // @@@
          return done(err, result);
        }
      });
    return result; // **** @@@@
  });
}

//var all      = {$in:["名詞","接頭詞","連体詞","形容詞","動詞","副詞","接続詞","助動詞","助詞","その他","記号","フィラー"]};
var all      = {$in:["名詞","接頭詞","連体詞","形容詞","動詞","副詞","接続詞","助動詞","助詞","フィラー","その他"]};
var first    = {$in:["名詞","接頭詞","連体詞","形容詞","動詞","副詞","接続詞","感動詞","フィラー"]};
var noun     = {$in:["名詞","接頭詞","連体詞","形容詞","助詞","感動詞"]};
var verb     = {$in:["名詞","接頭詞","連体詞","形容詞","助動詞","助詞"]};
//var noun     = {$in:["名詞","接頭詞","連体詞","形容詞","助詞"],$nin:["終助詞"]};
//var verb     = {$in:["名詞","接頭詞","連体詞","形容詞","助動詞","助詞"],$nin:["終助詞"]};
var adjective= {$in:["名詞","接頭詞","連体詞","形容詞"]};
var adverb   = {$in:["動詞","副詞","形容詞","形容動詞語幹","接続詞","サ変接続"]};
var ppp      = {$in:["名詞","接頭詞","連体詞","形容詞","動詞","副詞","接続詞","助動詞","助詞","フィラー","その他"]};
var auxverb  = {$in:["名詞","接頭詞","連体詞","形容詞","動詞","副詞","接続詞","助動詞","助詞","フィラー","その他"]};

JPTokenizer.prototype.parse_token = function(current, sentence, done){
  var cond = {$in:[]};
  if      ( current === null ){
    cond = first;
  }else if ( array_in(current.t,"不明" )){
    cond = all;
  }else  if ( array_in(current.t,"助動詞" )){
    cond = auxverb;
  }else  if ( array_in(current.t,"助詞" )){
    cond = ppp;
  }else{
    if ( array_in(current.t,"接続詞" )){
      cond['$in'] = cond['$in'].concat(first['$in']);
    }
    if ( array_in(current.t,"動詞") ){
      cond['$in'] = cond['$in'].concat(verb['$in']);
    }
    if ( array_in(current.t,"名詞")  ){
      cond['$in'] = cond['$in'].concat(noun['$in']);
    }
    if ( array_in(current.t,"副詞" )){
      cond['$in'] = cond['$in'].concat(adverb['$in']);
    }
    if ( array_in(current.t,"形容詞") || array_in(current.t,"接頭詞" ) || array_in(current.t,"連体詞" ))  {
      cond['$in'] = cond['$in'].concat(adjective['$in']);
    }
    if ( array_in(current.t,"感動詞" )){
      cond['$in'] = cond['$in'].concat(first['$in']);
    }
    if ( cond['$in'].length === 0 ) {
      cond = first;
    }
  }
  this.parse_query(current,sentence, {w:'*',t:cond}, done);
};

JPTokenizer.prototype.result = function(pos, word, candidate, done) {
  // printjson({s:word,d:candidate.w,t:candidate.t,p:candidate.p,c:candidate});
  this._dst.save({
    d:this.docid,
    i: ++this.idx,
    p:pos,
    w:word,
    l:candidate.l,
    c:candidate._id,
    sy:candidate.sy
  }, candidate, done);
};

JPTokenizer.prototype.parse_doc = function(docid, doc, done){
  var self = this;
  this.nquery = 0;
  this.nfetch = 0;
  this.docid = docid;
  this.idx = 0;

  var current = null;
  var pos = 0;
  var len = doc.length;
  self.async.during(
    function(done){
      done(null, pos < len);
    },
    function(done){
      self.parse_token(current, doc.substring(pos,len), function(err, candidates){
        if ( candidates ) {
          return self.async.eachSeries(
            candidates,
            function(candidate, done){
              var word = doc.substring(pos,pos+candidate.l);
              pos += candidate.l;
              current = candidate;
              return self.result(pos, word, candidate, done);
            },
            done);
        }
        if ( !self.includeUnknownToken ) {
          var word = doc[pos];
          var candidate = {w:word,l:1,s:9999,t:["不明"]};
          pos++;
          current = candidate;
          self.idx++; // TODO: How to save result ? Is it correct to increment index ?
          return done(null);
        }
        var word = doc[pos];
        var matches = doc.substring(pos,len).match(/^\s+/);
        if ( matches ) {
          word = matches[0];
          candidate = {w:word,l:word.length,s:9999,t:["不明"]};
          pos+= candidate.l;
          current = candidate;
          return self.result(pos,word,candidate, done);
        }else{
          self.dictionary.findBest(ascii2multi(word), function(err, candidate){
            if ( !candidate ) {
              candidate = {w:word,l:word.length,s:9999,t:["不明"]};
            }
            pos+= candidate.l;
            current = candidate;
            return self.result(pos,word,candidate, done);
          });
        }
      });
    },
    function (err) {
      self._dst.finish(done);
    }
  );
};
