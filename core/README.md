## About Momonger
MongoDB上で動作するお手軽な分散処理環境です。

現在は以下の機能が実装されています。
- Job
- Map
- MapReduce


## 特徴
MongoDB本体にもMapReduce機能が実装されていますが
並列化が不十分であったり、性能面での不満が多く使い難い状態です。

何よりデータストレージ上でロジックを走らせ、負荷を掛けるモデルは危険です。

Momonger はmongo shell (mongoコマンド)上、つまりクライアントサイドで動作します。
MongoDBに対する負担が少なく、MongoDBの性能が許す限りの並列化が望めます。

mongodと同じホスト上で動作させると並列性は落ちますが
通信オーバーヘッドが無い分高速に動作します

Momongerのセットアップは非常に簡単です。

### 必要なもの
- MongoDB
- MongoShell (mongo コマンド)
- Momongerプロジェクト

### クイックスタート
１．MongoDBインスタンスを構築

２．Momongerプロジェクトをクローン
```
cd /tmp
git clone git@github.com:crumbjp/momonger.git
cd /tmp/momonger
```

３．mongo.envを設定
```
cp _mongo.env mongo.env
```
mongo.envを編集しMongoShellのパスをあわせる

４．sconf/etting.jsを設定
```
cp conf/_setting.js conf/setting.js
```
setting.jsを編集しMongoDBの接続・認証情報を設定

５. testを走らせてみる
```
./bin/test.sh
```
全てOKになれば、設定出来ています。

### サンプルを叩いてみる
１．Momonger workerを起動
別ターミナルでworkerを４つ起動
```
./bin/worker.sh -J 4
```

２．サンプル・ジョブ起動
```
./sample/sample.sh
```
