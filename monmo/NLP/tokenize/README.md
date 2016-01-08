## 形態素解析＆熟語解析


## クイックスタート
１. momongerセットアップ
<a href="../../core/">momonger core</a>参照

２. IPA辞書をダウンロード
```
pushd ./data
wget http://iij.dl.sourceforge.jp/ipadic/24435/ipadic-2.7.0.tar.gz
tar xzf ipadic-2.7.0.tar.gz
popd
```

３. 辞書をビルド（デフォルト辞書コレクション＝"analysis.dictionary"
```
./gendic.sh -i data/ipadic-2.7.0
```

４. 動作確認（形態素解析結果が出力されます
```
./test.jp.sh -i "世界の皆さんこんにちは。"
```

## テストデータを解析してみる
１. テストデータをMongoDBに投入
```
mongoimport --drop -d momongertest -c sampledoc --file ../sample/sampledocs.json
```

２. 一括解析
(<a href="../../core/">momonger core</a>のworkerが立ち上がってないと処理されません)
```
./tokenize.jp.sh -s momongertest.sampledoc -f body -o momongertest.sampledoc.token
```

３. 結果を確認
```
mongo momongertest <<<'db.sampledoc.token.find().sort({d:1,i:1})'
```

４. キーワード検索
-『ペーパー』を含むドキュメント：

```
./keyword_search.sh -s momongertest.sampledoc.token -w 'ペーパー' -V
```

-『ペーパー』から始まる単語を含むドキュメント：

```
./keyword_search.sh -s momongertest.sampledoc.token -w 'ペーパー' -F -V
```

５. 熟語解析
```
./phrase.sh -s momongertest.sampledoc.token
```

６. 熟語解析結果
cvフィールドが大きい程、熟語の確率が高い：
```
mongo momongertest <<<'db.sampledoc.token.phrase.find({cv:{$gt:0}}).sort({cv:-1})'
```

## 辞書コレクションの構成
辞書はIPADICを元に同字意義語や活用形などを考慮した状態に直して使います。

### 辞書コレクションの構造
field | definition | description
----|----|----
w | 単語 or 活用候補配列 | 単語か活用候補
h | 先頭文字配列 | 最長マッチにかける為のインデックス用の要素
l| 文字列長 | 最長マッチにかける為のインデックス用の要素
s| 品詞優先度|最長マッチにかける為のインデックス用の要素
c| コスト|未使用（品詞で別けた方が結果が良かったので使わなくなった）
f| 活用系区分| 1: 打ち切り可能<br>2: 後ろ助詞、助動詞必須<br>3: 後ろ動詞可能（通常は動詞＋動詞は無い）<br>4: 後ろ名詞優先

## 結果コレクション
形態素解析の結果であると共に、Vectorize元データになっています。

docidとcを集計するとDF,TFが得られます。

### 結果コレクションの構造
field | definition | description
----|----|----
docid| 元ドキュメントの_id |
idx | 単語の現れた順 | 何ワード目
pos | ドキュメント中の単語の位置 | 何文字目
w | 単語 |
l | 単語長 | 活用している場合は同じ単語でも長さが変わります
c | 単語ID | 辞書コレクション中の_id

## TODO
* TODO
- White space tokenizerを実装
- 意味的な正規化　辞書を弄る事で実現できそう。（活用形と同じ扱いでいけるか？）
- ＡＳＣＩＩ正規化　現在は全角に寄せているが、本来は半角に寄せて、英語解析と互換した方がいい。
