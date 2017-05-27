#!/usr/bin/env bash
export NODE_PATH=src
coffee ./bin/import_dictionary.coffee -f test/fixture/dictionary.json
coffee ./bin/import_sample.coffee -f test/fixture/sampledocs.json -d momonger.sampledoc
coffee ./bin/tokenize.coffee -s momonger.sampledoc -d momonger.sampledoc.token -f body
coffee ./bin/phrase.coffee -s momonger.sampledoc.token -d momonger.sampledoc.phrase
coffee ./bin/tf.coffee -s momonger.sampledoc.token -d momonger.sampledoc.tf
coffee ./bin/df.coffee -s momonger.sampledoc.tf -d momonger.sampledoc.df
coffee ./bin/idf.coffee -s momonger.sampledoc.df -d momonger.sampledoc.idf --noun-only --use-dictionary-coefficient --filter-noise
coffee ./bin/tfidf.coffee -s momonger.sampledoc.idf -d momonger.sampledoc.tfidf --normalize
coffee ./bin/canopy.coffee -s momonger.sampledoc.tfidf -d momonger.sampledoc.canopy --t2 0.93 --t1 0.95 --threshold 5
coffee ./bin/kmeans.coffee -s momonger.sampledoc.tfidf -d momonger.sampledoc.kmeans --cluster momonger.sampledoc.canopy --iterate 10



NODE_PATH=src coffee ./bin/phrase.coffee -s analytics.target_mongo_articles.token -d analytics.target_mongo_articles.phrase
NODE_PATH=src coffee ./bin/tokenize.coffee -s analytics.target_mongo_articles -d analytics.target_mongo_articles.token -f title,body
NODE_PATH=src coffee ./bin/tf.coffee -s analytics.target_mongo_articles.token -d analytics.target_mongo_articles.tf
NODE_PATH=src coffee ./bin/df.coffee -s analytics.target_mongo_articles.tf -d analytics.target_mongo_articles.df
NODE_PATH=src coffee ./bin/idf.coffee -s analytics.target_mongo_articles.df -d analytics.target_mongo_articles.idf --noun-only --use-dictionary-coefficient --filter-noise
NODE_PATH=src coffee ./bin/tfidf.coffee -s analytics.target_mongo_articles.idf -d analytics.target_mongo_articles.tfidf --normalize
NODE_PATH=src coffee ./bin/canopy.coffee -s analytics.target_mongo_articles.tfidf -d analytics.target_mongo_articles.canopy --t2 0.93 --t1 0.95 --threshold 5
NODE_PATH=src coffee ./bin/kmeans.coffee -s analytics.target_mongo_articles.tfidf -d analytics.target_mongo_articles.kmeans --cluster analytics.target_mongo_articles.canopy --iterate 100
