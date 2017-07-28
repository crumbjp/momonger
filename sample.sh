#!/usr/bin/env bash
set -e
WORKDIR=`dirname $0`
cd ${WORKDIR}

export NODE_PATH=src
./bin/coffee.sh ./bin/import_dictionary.coffee -f test/fixture/dictionary.json
./bin/coffee.sh ./bin/import_sample.coffee -f test/fixture/sampledocs.json -d momonger.sampledoc

bash ./bin/whole.sh -o momonger.sampledoc -m first

exit 0
