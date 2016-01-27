## 自然言語処理環境
MongoDB上で動作する`並列＆高速`自然言語処理環境です。

MongoDBのコレクションをソースとして、tokenize -> tfidf -> clustering を行います。

### オンライン処理
オンライン処理で解析結果を利用する際には、形態素解析ライブラリの実装の差が問題になります。

例えば解析時に
`|本日|は|晴天|`

と処理されていた文章がオンライン処理で
`|本|日|は|晴天|`

と処理されてしまうと巧くヒットさせる事が出来ません

momonger-NLPでは形態素解析エンジンは<a href="https://www.npmjs.com/package/node-jptokenizer">node-jptokenizer</a>と共有しており
`解析時の形態素解析結果はオンライン側でも完全に再現`できます。

### 構成
- <a href="../core/">momonger core</a>(並列処理環境)
- <a href="./tokenize/">tokenize</a>(形態素解析・熟語解析)
- <a href="./vectorize/">vectorize</a>(TF/IDF)
- <a href="./clusterize/">clusterize</a>(Canopy・Kmeans)
- <a href="./viewer/">Web viewer</a>
