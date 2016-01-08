if ( typeof utils === 'undefined' ) {
  utils = {
    array_in: function (arr, elem) {
      return (arr.indexOf(elem) >= 0)
    },
    array_all: function (arr, ts){
      for ( var i in ts ) {
        if ( !array_in(arr, ts[i]) ) {
          return false;
        }
      }
      return true;
    }
  }
}

var morpho = {
	re_date1   : /^([０１２３４５６７８９一二三四五六七八九〇十]+[年月日時分秒])/,
	re_date2   : /^[０１２３４５６７８９]+([：／－　 ][０１２３４５６７８９]+)+/,
	re_number1 : /^[＋－]?[０１２３４５６７８９][０１２３４５６７８９十百千万億兆，．]*/,
  //re_number2 : /^[一二三四五六七八九〇十百千][一二三四五六七八九〇十百千万億兆，．]*/,
	re_suru : /する$/,
	re_zuru : /ずる$/,
	forms   : function(nheads,val){
		function gen(val,n,arr1,arr2,arr3){
			var base = val.w.substring(0,val.w.length-n);
			val.h = [val.w.slice(0,nheads)];
			val.w = [val.w];
			// default
			if ( ! val.f[val.w] ) {
				val.f[val.w] = [];
			}
			val.f[val.w].push(1);
			if ( utils.array_in(val.t,"動詞") ) {
				val.f[val.w].push(4);
			}
			// endable
			for ( var i in arr1 ) {
				var w = base + arr1[i];
				val.h.push(w.slice(0,nheads));
				val.w.push(w);
				if ( ! val.f[w] ) {
					val.f[w] = [];
				}
				val.f[w].push(1);
				val.f[w] = utils.unique(val.f[w]);
			}
			// follow ppp
			for ( var i in arr2 ) {
				var w = base + arr2[i];
				val.h.push(w.slice(0,nheads));
				val.w.push(w);
				if ( ! val.f[w] ) {
					val.f[w] = [];
				}
				val.f[w].push(2);
				val.f[w] = utils.unique(val.f[w]);
			}
			// follow verb
			for ( var i in arr3 ) {
				var w = base + arr3[i];
				val.h.push(w.slice(0,nheads));
				val.w.push(w);
				if ( ! val.f[w] ) {
					val.f[w] = [];
				}
				val.f[w].push(3);
				val.f[w] = utils.unique(val.f[w]);
			}
			val.h = utils.unique(val.h);
			val.h = (val.h.length===1?val.h[0]:val.h);
			val.w = utils.unique(val.w);
			val.w = (val.w.length===1?val.w[0]:val.w);
			delete val.p;
			return val;
		}
		var len = val.w.length;
		if ( utils.array_in(val.t,"動詞") ) {
			if        (  val.w === "ける" ) {
			}	else if ( val.w === "げる" ) {
			}	else if ( val.w === "たす" ) {
			}	else if ( val.w === "ねる" ) {
			}	else if ( val.w === "ばる" ) {
			}	else if ( val.w === "める" ) {
			}	else if ( val.w === "らす" ) {
			}	else if ( val.w === "くる" ) {
				return gen(val,2,["こい"],["くれ","き"],["き"]);
			}	else if ( val.w === "来る" ) {
				return gen(val,1,["い"],["れ",""],[""]);
			} else if ( val.w.match(this.re_suru) ) {
				return gen(val,2,["しろ","せよ"],["する","すれ","さ","し","せ"],["し"]);
			} else if ( val.w.match(this.re_zuru) ) {
				return gen(val,2,["じろ","ぜよ"],["ずる","ずれ","じ","ぜ"],["じ"]);
			}	else if (len > 1 && val.w[len-1] === "る" &&
								 utils.array_in(["イ","キ","ギ","ジ","チ","ニ","ヒ","ビ","ミ","リ","エ","ケ","セ","ゼ","テ","デ","ネ","ヘ","ベ","メ","レ"],val.p[0][val.p[0].length-2]) ){
				return gen(val,1,["ろ","よ"],["る","れ",""],[""]);
			}	else if ( len > 1 && val.w[len-1] === "う" ) {
				return gen(val,1,["える","え"],["お","わ","い","っ","う","え"],["い"]);
			}	else if ( len > 1 && val.w[len-1] === "く" ) {
				return gen(val,1,["ける","け"],["こ","か","き","い","く","け"],["き"]);
			}	else if ( len > 1 && val.w[len-1] === "ぐ" ) {
				return gen(val,1,["げる","げ"],["ご","が","ぎ","い","ぐ","げ"],["ぎ"]);
			}	else if ( len > 1 && val.w[len-1] === "す" ) {
				return gen(val,1,["せる","せ"],["そ","さ","し","す","せ"],["し"]);
			}	else if ( len > 1 && val.w[len-1] === "つ" ) {
				return gen(val,1,["てる","て"],["と","た","ち","っ","つ","て"],["ち"]);
			}	else if ( len > 1 && val.w[len-1] === "ぬ" ) {
				return gen(val,1,["ねる","ね"],["の","な","に","ん","ぬ","ね"],["に"]);
			}	else if ( len > 1 && val.w[len-1] === "ぶ" ) {
				return gen(val,1,["べる","べ"],["ぼ","ば","び","ん","ぶ","べ"],["び"]);
			}	else if ( len > 1 && val.w[len-1] === "む" ) {
				return gen(val,1,["める","め"],["も","ま","み","ん","む","め"],["み"]);
			}	else if ( len > 1 && val.w[len-1] === "る" ) {
				return gen(val,1,["れる","れ"],["ろ","ら","り","っ","る","れ"],["り"]);
			}
		}	else if ( utils.array_in(val.t,"助動詞") ) {
			if        ( val.w === "ます" ){
				return gen(val,1,[],["すれ","しょ","し","せ"],[]);
			} else if ( val.w === "です" ){
				return gen(val,1,[],["しょ","し"],[]);
			} else if ( val.w === "たがる" ){
    		return gen(val,1,["り"],["ら","り","っ","れ"],[]);
			} else if ( val.w === "ぬ" ){
    		return gen(val,1,["ず","ん"],["ね"],[]);
			} else if ( len > 1 && val.w[len-1] === "る" ) {
				return gen(val,1,["れ",""],["れ","ろ","よ",""],[]);
			} else if (val.w === "ない" ||
								 val.w === "たい" ||
								 val.w === "らしい" ) {
    		return gen(val,1,[],["かろ","かっ","けれ"],["く"]);
			} else if ( val.w === "た" ){
				return gen(val,1,[],["たろ","たら"],[]);
			} else if ( val.w[len-1] === "だ" ) {
				return gen(val,1,["です","で","な"],["だろ","だっ","なら","だら"],["に"]);
			}
		}	else if ( utils.array_in(val.t,"形容詞") ) {
			if        ( val.w[len-1] === "い" ) {
				return gen(val,1,[],["かろ","かっ","けれ"],["く"]);
			}
		}	else if ( utils.array_all(val.t,["名詞","一般"]) && ! utils.array_in(val.t,"固有名詞")) {
//      val.w = [val.w,utils.katakana(val.w)].concat(val.p);
//			val.w = utils.unique(val.w);
//      val.h = [];
//      for ( var i in val.w ) {
//        val.h.push(val.w[i].slice(0,nheads));
//      }
//			val.w = utils.sort(val.w,function(a,b){
//        return a.length > b.length;
//      });
//			val.w = (val.w.length===1?val.w[0]:val.w);
//
//			val.h = utils.unique(val.h);
//			val.h = (val.h.length===1?val.h[0]:val.h);
//			delete val.p;
//			return val;
		}
		val.h = val.w.slice(0,nheads);
		delete val.p;
		return val;
	}
}
