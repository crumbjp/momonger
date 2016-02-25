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
