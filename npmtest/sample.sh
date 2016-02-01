#!/usr/bin/env bash
pushd `dirname $0`
mkdir -p config
cp ../config/dictionary.conf ./config/
cp ../config/momonger.conf ./config/
node ./node_modules/momonger/bin/import_dictionary.js -f ../test/fixture/dictionary.json
node ./node_modules/momonger/bin/import_sample.js -f ../test/fixture/sampledocs.json -d momonger.sampledoc
node ./node_modules/momonger/bin/tokenize.js -s momonger.sampledoc -d momonger.sampledoc.token
node ./node_modules/momonger/bin/phrase.js -s momonger.sampledoc.token -d momonger.sampledoc.phrase
node ./node_modules/momonger/bin/tf.js -s momonger.sampledoc.token -d momonger.sampledoc.tf
node ./node_modules/momonger/bin/df.js -s momonger.sampledoc.tf -d momonger.sampledoc.df
node ./node_modules/momonger/bin/idf.js -s momonger.sampledoc.df -d momonger.sampledoc.idf --noun-only --use-dictionary-coefficient --filter-noise
node ./node_modules/momonger/bin/tfidf.js -s momonger.sampledoc.idf -d momonger.sampledoc.tfidf --normalize
node ./node_modules/momonger/bin/canopy.js -s momonger.sampledoc.tfidf -d momonger.sampledoc.canopy --t2 0.93 --t1 0.95 --threshold 5
node ./node_modules/momonger/bin/kmeans.js -s momonger.sampledoc.tfidf -d momonger.sampledoc.kmeans --cluster momonger.sampledoc.canopy --iterate 10
popd
