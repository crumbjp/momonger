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
    -b, --base        base_name   : ex> momonger.sampledoc_dst
    -m, --mode        mode        : phrase, first, append, rebalance
    -c, --cluster     collection  :  for rebalance-mode
    -a, --append      append_id   :  for append-mode: Append {a: <append_id>} records
    -n, --new-append  append_id   :  for append-mode: Append {a: null} records
    -p, --chunk-size  chunk_size  :  for tokenize
    -f, --fields      fields      :  , delimited fields
    -d, --dryrun                  : dry-run mode

USAGE
    exit $1
}

while getopts ':ho:b:m:c:a:n:p:f:d' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
        h|--help)       usage 0 ;;
        o|--origin)     ORIGIN_COLLECTION="${OPTARG}";;
        b|--base)       BASE_NAME="${OPTARG}";;
        m|--mode)       MODE="${OPTARG}";;
        c|--cluster)    CLUSTER="${OPTARG}";;
        a|--append)     APPEND="${OPTARG}";;
        n|--new-append) NEW_APPEND="${OPTARG}";;
        p|--chunk-size) CHUNK_SIZE="${OPTARG}";;
        f|--fields)     FIELDS="${OPTARG}";;
        d|--dryrun)     DRY="1";;
        --) break;;
    esac
done

if [ "${ORIGIN_COLLECTION}" = "" ]; then
    echo "ERROR: origin is required !"
    exit 1
fi

if [ "${FIELDS}" = "" ]; then
    echo "fields is required !"
    exit 1
fi

if [ "${BASE_NAME}" = "" ]; then
    BASE_NAME="${ORIGIN_COLLECTION}"
fi

if [ "$CHUNK_SIZE" = "" ]; then
    CHUNK_SIZE=300
fi

function run {
    CMD=$*
    echo "RUN: ${CMD}"
    if [ "${DRY}" != "1" ]; then
        ${CMD}
    fi
}

if [ "${MODE}" = "phrase" ]; then
    run ./bin/coffee.sh ./bin/tokenize.coffee -s ${ORIGIN_COLLECTION} -d ${BASE_NAME}.token -p ${CHUNK_SIZE} -f ${FIELDS}
    run ./bin/coffee.sh ./bin/phrase.coffee -s ${BASE_NAME}.token -d ${BASE_NAME}.phrase
elif [ "${MODE}" = "first" ]; then
    run ./bin/coffee.sh ./bin/tokenize.coffee -s ${ORIGIN_COLLECTION} -d ${BASE_NAME}.token -p ${CHUNK_SIZE} -f ${FIELDS}
    run ./bin/coffee.sh ./bin/tf.coffee -s ${BASE_NAME}.token -d ${BASE_NAME}.tf
    run ./bin/coffee.sh ./bin/df.coffee -s ${BASE_NAME}.tf -d ${BASE_NAME}.df
    run ./bin/coffee.sh ./bin/idf.coffee -s ${BASE_NAME}.df -d ${BASE_NAME}.idf --noun-only --use-dictionary-coefficient --filter-noise
    run ./bin/coffee.sh ./bin/tfidf.coffee -s ${BASE_NAME}.idf -d ${BASE_NAME}.tfidf --normalize
    run ./bin/coffee.sh ./bin/canopy.coffee -s ${BASE_NAME}.tfidf -d ${BASE_NAME}.canopy --t2 0.93 --t1 0.95 --threshold 5
    run ./bin/coffee.sh ./bin/kmeans.coffee -s ${BASE_NAME}.tfidf -d ${BASE_NAME}.kmeans --cluster ${BASE_NAME}.canopy --iterate 20
elif [ "${MODE}" = "rebalance" ]; then
    if [ "$CLUSTER" = "" ]; then
        run ./bin/coffee.sh ./bin/copy_collection.coffee -s ${BASE_NAME}.kmeans.cluster -d ${BASE_NAME}.tmp_cluster
        CLUSTER="${BASE_NAME}.tmp_cluster"
    fi
    run ./bin/coffee.sh ./bin/tokenize.coffee -s ${ORIGIN_COLLECTION} -d ${BASE_NAME}.token -p ${CHUNK_SIZE} -f ${FIELDS}
    run ./bin/coffee.sh ./bin/tf.coffee -s ${BASE_NAME}.token -d ${BASE_NAME}.tf
    run ./bin/coffee.sh ./bin/df.coffee -s ${BASE_NAME}.tf -d ${BASE_NAME}.df
    run ./bin/coffee.sh ./bin/idf.coffee -s ${BASE_NAME}.df -d ${BASE_NAME}.idf --noun-only --use-dictionary-coefficient --filter-noise
    run ./bin/coffee.sh ./bin/tfidf.coffee -s ${BASE_NAME}.idf -d ${BASE_NAME}.tfidf --normalize
    run ./bin/coffee.sh ./bin/kmeans.coffee -s ${BASE_NAME}.tfidf -d ${BASE_NAME}.kmeans --cluster ${CLUSTER} --iterate 20
elif [ "${MODE}" = "append" ]; then
    if [ "$NEW_APPEND" != "" ]; then
        APPEND="${NEW_APPEND}"
        run ./bin/coffee.sh ./bin/prepare_append.coffee -s ${ORIGIN_COLLECTION} -a ${APPEND}
    fi
    if [ "$APPEND" = "" ]; then
        echo 'append_id not specified !'
        exit 1
    fi
    run ./bin/coffee.sh ./bin/tokenize.coffee -s ${ORIGIN_COLLECTION} -d ${BASE_NAME}.token -p ${CHUNK_SIZE} -f ${FIELDS} -a ${APPEND}
    run ./bin/coffee.sh ./bin/tf.coffee -s ${BASE_NAME}.token -d ${BASE_NAME}.tf -a ${APPEND}
    run ./bin/coffee.sh ./bin/tfidf.coffee -s ${BASE_NAME}.idf -d ${BASE_NAME}.tfidf --normalize -a ${APPEND}
    run ./bin/coffee.sh ./bin/kmeans.coffee -s ${BASE_NAME}.tfidf -d ${BASE_NAME}.kmeans -a ${APPEND}
else
    echo "ERROR: unknown mode ${MODE}!"
    exit 1
fi
exit 0
