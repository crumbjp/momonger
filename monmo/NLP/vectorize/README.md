## TF/IDF
<a href="../tokenize">tokenize</a>の結果からドキュメントのTF/IDFベクトルを算出します。
また、その途中経過のコレクションを使って、フルテキストサーチ（ANDやORなど）が出来ます。

## 高速化
まともに全ての単語を評価するとベクトルの次元数が膨大になる為、間引きする必要があります。
　　
IDFの段階で、閾値（threshold）と制限値（limit）でフィルタリングおり
フィルタリングされた単語は、IDFコレクション中（"value"=0）とされ、TF-IDFでも0と判定され、除外されます。

また、DF=1 （１つのドキュメントにだけ含まれている単語）はドキュメントの特徴を捉えているものの、
他ドキュメントと比較する術が無いのでやはり除外しています。

## 差分処理
既に算出済みのTF/IDFに少量のドキュメントを追加したい場合があります。
本来は追加するドキュメントによってDF, IDFが変化するので、全てのベクトルを更新しなければ正しい値にはなりませんが
DF, IDFの変化は誤差として、追加するTF -> TF/IDFだけを処理する機能があります。

## ドキュメント検索
TFコレクションを使ってドキュメント検索ができます。

## クイックスタート
１．<a href="../tokenize">tokenize</a>クイックスタートを実行

２．ベクトル算出
```
./tf.sh -s momongertest.sampledoc.token -o momongertest.sampledoc.token.vector.tf
./df.sh -s momongertest.sampledoc.token.vector.tf -o momongertest.sampledoc.token.vector.df
./idf.sh -s momongertest.sampledoc.token.vector.df -o momongertest.sampledoc.token.vector.idf
./idf.sh -s momongertest.sampledoc.token.vector.df -o momongertest.sampledoc.token.vector.idf
./tfidf.sh -s momongertest.sampledoc.token.vector.idf -o momongertest.sampledoc.token.vector.tfidf
```

３. tfidfを確認
```
./viewvector.sh -s momongertest.sampledoc.token.vector.tfidf
```

４. 文書検索
```
./fulltext_search.sh -s momongertest.sampledoc.token.vector.tf -w 'はさみや糊など' -V -L 1000
```

## IDFチューニング
IDFはTF/IDFの精度を左右します。

１．IDFを確認する。
```
./view_df.sh -s momongertest.sampledoc.token.vector.idf
```

２. DFを確認しながら切る範囲を検討
```
./view_df.sh -s momongertest.sampledoc.token.vector.df
```

３．上を確認しながら、limit,threshold,verb-onlyの値を調整する。

name | description
-----|-------
l| （DF / 総ドキュメント数）の最大値
threshold | （DF / 総ドキュメント数）の最小値
verb-only | 名詞だけ抽出

切り捨て過ぎの場合はlimit値を下げる
```
./idf.sh -l 0.3 -s momongertest.sampledoc.token.vector.df -o momongertest.sampledoc.token.vector.idf
```

もっと切り捨てたい場合はlimit値を上げる
```
./idf.sh -l 0.5  -s momongertest.sampledoc.token.vector.df -o momongertest.sampledoc.token.vector.idf
```

強く出過ぎるIDFを削る
```
./idf.sh -t 0.1  -s momongertest.sampledoc.token.vector.df -o momongertest.sampledoc.token.vector.idf
```

名詞だけを評価する
```
./idf.sh -v -s momongertest.sampledoc.token.vector.df  -o momongertest.sampledoc.token.vector.idf
```

idfを確認（１.）しながら繰り返し

５. TF-IDFを再産出
```
./tfidf.sh -s momongertest.sampledoc.token.vector.idf -o momongertest.sampledoc.token.vector.tfidf
```
