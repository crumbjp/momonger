#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
    cat<<USAGE
Usage :
  random_forest.sh [options]

Summary:
  Generate random forest.

Options :
    -h, --help                  : This message
    -s, --source        ns      : Target data collection
    -o, --output        ns      : Output collection ns
    -d, --depth         num     : Max tree depth (default: 2)
    -g, --goal-field    name    : Goal score field (default: score)
    -f, --field         name    : Vector field (default: loc)
    -i, --ignore-fields string  : , delimited string. Ignore field of the `Vector field`
    -n, --num-of-tree   num     : Number of the tree (default: 100)
    -N, --num-of-field  num     : Number of the fields (default: depth * 2)
    -r, --remove-tmp            : Remove temporary collection
    -m, --meta          json    : Additional meta
    -L, --limit         number  : Mimimum number of the data (default: 1000)
Src collection
    {
       _id: ...,
       loc: {
         ...
       }
       score: ...
     }

USAGE
    exit $1

}

DEPTH="D:2"
FIELD="F: 'loc'"
IGNORE="I: ''"
TOP="T: ''"
NUM_TREE="N: 100"
NUM_FIELD="NF: null"
REMOVE="R: false"
META="M: {}"
LIMIT="L: 1000"

while getopts 'hs:o:d:g:f:i:n:N:rm:L:' OPTION; do
  echo $OPTION $OPTARG
  case $OPTION in
    h) usage 0 ;;
    s) SRC="-s ${OPTARG}";;
    o) OUT="-o ${OPTARG}";;
    d) DEPTH="D: ${OPTARG}";;
    f) FIELD="F: '${OPTARG}'";;
    i) IGNORE="I: '${OPTARG}'";;
    g) GFIELD="GF:'${OPTARG}'";;
    n) NUM_TREE="N: ${OPTARG}";;
    N) NUM_FIELD="NF: ${OPTARG}";;
    r) REMOVE="R: true";;
    m) META="M: ${OPTARG}";;
    L) LIMIT="L: ${OPTARG}";;
    esac
done

${MOMONGER_ROOT}/bin/jobctl.sh ${SRC} ${OUT} -a "{${DEPTH},${FIELD},${GFIELD},${IGNORE},${NUM_TREE},${REMOVE},${NUM_FIELD},${META},${LIMIT}}" -f ${CURDIR}/jobs/id3_job.js -f ${CURDIR}/jobs/random_forest.js
