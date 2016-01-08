## Web viewer (alpha)

## クイックスタート
１．<a href="../clusterize/">clusterize</a>クイックスタートを実行

２. 起動
```
NODE_PATH=. coffee ./bin/www
```

３. ブラウザで`http://localhost:3000/`にアクセス

`momongertest.sampledoc` を入力して検索

## トップメニュー
#### クラスター
クラスタの中心座標と所属ドキュメント

#### ドキュメント
スペース区切りでのワード検索

#### IDF
IDF無効化ボタン

#### 熟語抽出
熟語解析結果の辞書登録ボタン

## TODO
- 辞書Editor
- ドキュメント検索で、スペース区切りではなくnode-jptokenizerを使う
