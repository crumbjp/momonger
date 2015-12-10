## クラスタリング
ベクトル群を距離を元にクラスタリングします。

現在は以下の機能が実装されています。

**Canopy**
ベクトル群を大まかに解析し、クラスタ数と仮重心を算出する。
アルゴリズムの特性上、並列化が難しく速度に難あり。

**Kmeans**
初期クラスタを元にベクトル群をクラスタリングします。

## クイックスタート
１．<a href="../vectorize/">vectorize</a>クイックスタートを実行
TF/IDFを算出します

２. Canopy
仮重心を算出
```
./canopy.sh -s momongertest.sampledoc.token.vector.tfidf -N -2 0.98 -1 0.99
```

３．仮重心を確認
```
./viewcluster.sh -s momongertest.sampledoc.token.vector.tfidf.canopy.cluster
```

４．Kmeans
```
./kmeans.sh -s momongertest.sampledoc.token.vector.tfidf -i momongertest.sampledoc.token.vector.tfidf.canopy.cluster
```

５．クラスター確認
```
./viewcluster.sh -s momongertest.sampledoc.token.vector.tfidf.kmeans.fin.cluster -V -L 100
```
