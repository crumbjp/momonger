## 決定木＆random forest

## クイックスタート
１. momongerセットアップ
<a href="../../core/">momonger core</a>参照

２. テストデータをMongoDBに投入

**学習データ**
```
mongoimport --drop -d momongertest -c iris --file ../sample/iris.json
```

**検証データ**
```
mongoimport --drop -d momongertest -c iris_test --file ../sample/iris_test.json
```

３. 決定木を生成
(<a href="../../core/">momonger core</a>のworkerが立ち上がってないと処理されません)
```
./id3.sh -g species -s momongertest.iris -d 3 -f loc -r -L 100
```

４. 決定木を見る
```
cd tree
npm install
NODE_PATH=src coffee ./bin/tree_test.coffee -t momongertest.id3.iris -d
```

５. 決定木をテスト
```
NODE_PATH=src coffee ./bin/tree_test.coffee -t momongertest.id3.iris -s momongertest.iris_test
```

６. RandomForestを生成
```
./random_forest.sh -g species -s momongertest.iris -d 2 -N 2 -n 10 -f loc -r -L 100
```

７. RandomForestを見る
```
NODE_PATH=src coffee ./bin/tree_test.coffee -t momongertest.rf.iris -d
```

８. RandomForestをテスト
```
NODE_PATH=src coffee ./bin/tree_test.coffee -t momongertest.rf.iris -s momongertest.iris_test
```
