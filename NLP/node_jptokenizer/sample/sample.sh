#!/usr/bin/env bash
cd `dirname $0`

pushd ..
npm run build
popd

rm -rf ./node_modules
npm install

SENTENCE='MongoDBは、オープンソースのドキュメント指向データベースである。C++言語で記述されており、開発とサポートはMongoDB Inc.によって行なわれている。'

export NODE_PATH=.
echo '== mongo based dictionary =='
coffee tokenize_test.coffee -c conf/mongo-directory.conf  -s "$SENTENCE"
echo '== file based dictionary =='
coffee tokenize_test.coffee -c conf/file-directory.conf  -s "$SENTENCE"
