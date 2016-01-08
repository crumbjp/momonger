# node-jptokenizer
Pure JS Japanese tokenizer.

## 特徴
mecabに色々不満があって作ったので、殆どの特徴はmecabに対する不満そのものです。

### Pure JS の形態素解析器
npm install 一発でインストールでき、JITのパフォーマンスを期待した作りになっています。

### 辞書に忠実
mecabで一番厄介なのは、辞書のカスタマイズです。
mecabは複雑な接続スコアにより精度を上げているため、辞書を編集しても意図した結果を得る事が困難なのです。

当tokenizerは辞書をカスタマイズした際に結果が想像し易い事を目指して作られています。

1. 基本的には最長マッチ
2. 多少の接続パターンは実装しているが、助詞や接続詞等の最小限の判別のみ
3. Ascii文字は全てunicodeの日本語領域に寄せて扱われます。（AはＡとみなされる）

結果として品詞判定の精度は悪くなりますがトレードオフです。

### 辞書の種類
#### JSONファイル
スタンドアローン用にはJSONファイルによる辞書が使えます。

https://raw.githubusercontent.com/crumbjp/momonger/master/NLP/tokenize/dictionary.json

#### MongoDB baseの辞書
collection そのものを辞書として使う事が出来ます。

MongoDB baseの辞書では単語毎にユニークなID(_id field)が振られます。
そのため、通常必要な、単語 => IDの変換処理をせずに辞書のIDをそのまま使ってベクトル化できます。

よって同じ辞書を使ってtokenizeした結果は、いつでも互換性を保ったID化が出来ます。

※ 詳細は後述

### 未知語の扱い
カタカナ・アルファベット・数値・日付は自動的に単語（未知語）として扱われます。

MongoDB baseの辞書の場合は未知語として保存され、以降のtokenizeで利用されます。
これにより、tokenize結果に未知語を含めたベクトルが生成できます。

※ JSON辞書を使用している場合は、このような更新処理はしません。

## クイックスタート
```
mkdir -p /tmp/jptokenizer
cd /tmp/jptokenizer
npm install node-jptokenizer
wget https://raw.githubusercontent.com/crumbjp/momonger/master/NLP/tokenize/dictionary.json
echo 'var JPTokenizer = require("node-jptokenizer");
var tokenizer = new JPTokenizer({
  type: "file",
  file: {
    path: "dictionary.json"
  }
});
tokenizer.modifier = function(token, candidate, done) {
  if ( candidate.t.indexOf("名詞") >= 0 ) {
    return done(null, token);
  }
  done(null, null);
}
tokenizer.init(function(){
 tokenizer.parse_doc("本日は晴天なり", function(err, tokens){
    for (var i in tokens) {
      var token = tokens[i];
      console.log(token.i + " : " + token.w);
    }
  });
});' > test.js
node test.js
```

## Reference
### constructor ( config )
```
config:
  type          : <string>: "file" or "mongo"
  file          : when specify type == "file"
    path        : <path to JSON dictionary>
  mongo         : when specify type == "mongo"
    host        :
    port        :
    authdbname  : specify null when no auth
    user        :
    password    :
    database    : dictionary DB
    collection  : dictionary Collection
```

### init
Must call before calling `parse_doc`

### parse_doc (sentence, callback)
```
sentence: <target sentence>

callback  : function(err, tokens)
  tokens  : token array

token     :
  i       : word index in the document
  w       : word
  c       : dictionaryId
```
### modifier (token, candidate, callback)
```
token     : See bellow

candidate : Dictionary element
  _id     : elementID
  t       : Part of speech array
  w       : word

```


## example
```js
var JPTokenizer = require("node-jptokenizer");
var tokenizer = new JPTokenizer({
  type: "file",
  file: {
    path: "conf/dictionary.json"
  }
});
tokenizer.modifier = function(token, candidate, done) {
  if ( candidate.t.indexOf("名詞") >= 0 ) {
    return done(null, token);
  }
  done(null, null);
}
tokenizer.init(function(){
 tokenizer.parse_doc("本日は晴天なり", function(err, tokens){
    for (var i in tokens) {
      var token = tokens[i];
      console.log(token.i + " : " + token.w);
    }
  });
});
```
