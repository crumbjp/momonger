#!/usr/bin/env bash
set -e
export NODE_PATH=src
WORKDIR=`dirname $0`/..
cd ${WORKDIR}

usage (){
    cat<<USAGE
Usage :
  whole.sh [options]

Summary:
  Clustering command set

Options :
    -h, --help                    : This message
    -o, --origin      collection  : ex> momonger.sampledoc
    -m, --mode        mode        : phrase, first, append

USAGE
    exit $1
}

while getopts ':ho:m:' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
        h|--help)       usage 0 ;;
        o|--origin)     ORIGIN_COLLECTION="${OPTARG}";;
        m|--mode)       MODE="${OPTARG}";;
        --) break;;
    esac
done

if [ "${ORIGIN_COLLECTION}" = "" ]; then
    echo "ERROR: origin is required !"
    exit 1
fi

function run {
    CMD=$*
    echo "RUN: ${CMD}"
    ${CMD}
}

if [ "${MODE}" = "phrase" ]; then
    run ./bin/coffee.sh ./bin/tokenize.coffee -s ${ORIGIN_COLLECTION} -d ${ORIGIN_COLLECTION}.token -f body
    run ./bin/coffee.sh ./bin/phrase.coffee -s ${ORIGIN_COLLECTION}.token -d ${ORIGIN_COLLECTION}.phrase
elif [ "${MODE}" = "first" ]; then
    run ./bin/coffee.sh ./bin/tokenize.coffee -s ${ORIGIN_COLLECTION} -d ${ORIGIN_COLLECTION}.token -f body
    run ./bin/coffee.sh ./bin/tf.coffee -s ${ORIGIN_COLLECTION}.token -d ${ORIGIN_COLLECTION}.tf
    run ./bin/coffee.sh ./bin/df.coffee -s ${ORIGIN_COLLECTION}.tf -d ${ORIGIN_COLLECTION}.df
    run ./bin/coffee.sh ./bin/idf.coffee -s ${ORIGIN_COLLECTION}.df -d ${ORIGIN_COLLECTION}.idf --noun-only --use-dictionary-coefficient --filter-noise
    run ./bin/coffee.sh ./bin/tfidf.coffee -s ${ORIGIN_COLLECTION}.idf -d ${ORIGIN_COLLECTION}.tfidf --normalize
    run ./bin/coffee.sh ./bin/canopy.coffee -s ${ORIGIN_COLLECTION}.tfidf -d ${ORIGIN_COLLECTION}.canopy --t2 0.93 --t1 0.95 --threshold 5
    run ./bin/coffee.sh ./bin/kmeans.coffee -s ${ORIGIN_COLLECTION}.tfidf -d ${ORIGIN_COLLECTION}.kmeans --cluster ${ORIGIN_COLLECTION}.canopy --iterate 20
elif [ "${MODE}" = "append" ]; then
    APPEND=`date +'%Y%m%d%H%M%S'`
    run ./bin/coffee.sh ./bin/prepare_append.coffee -s ${ORIGIN_COLLECTION} -a ${APPEND}
    run ./bin/coffee.sh ./bin/tf.coffee -s ${ORIGIN_COLLECTION}.token -d ${ORIGIN_COLLECTION}.tf -a ${APPEND}
    run ./bin/coffee.sh ./bin/tfidf.coffee -s ${ORIGIN_COLLECTION}.idf -d ${ORIGIN_COLLECTION}.tfidf --normalize -a ${APPEND}
    run ./bin/coffee.sh ./bin/kmeans.coffee -s ${ORIGIN_COLLECTION}.tfidf -d ${ORIGIN_COLLECTION}.kmeans -a first
else
    echo "ERROR: unknown mode ${MODE}!"
    exit 1
fi
exit 0
