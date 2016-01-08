#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
  cat<<USAGE
Usage :
  id3.sh [options]

Summary:
  Generate decision tree by ID3.

Options :
    -h, --help                  : This message
    -s, --source        ns      : Target data collection
    -o, --output        ns      : Output collection ns
    -d, --depth         number  : Max tree depth (default: 3)
    -g, --goal-field    name    : Goal score field (default: score)
    -f, --field         name    : Vector field (default: loc)
    -i, --ignore-fields string  : , delimited string. Ignore field of the `Vector field`
    -t, --top-fields    string  : , delimited string. Force top of the tree
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

DEPTH="D:3"
FIELD="F: 'loc'"
IGNORE="I: ''"
TOP="T: ''"
REMOVE="R: false"
META="M: {}"
LIMIT="L: 1000"

while getopts 'hs:o:d:g:f:i:t:rR:m:L:' OPTION; do
  echo $OPTION $OPTARG
  case $OPTION in
    h) usage 0 ;;
    s) SRC="-s ${OPTARG}";;
    o) OUT="-o ${OPTARG}";;
    d) DEPTH="D: ${OPTARG}";;
    f) FIELD="F: '${OPTARG}'";;
    i) IGNORE="I: '${OPTARG}'";;
    g) GFIELD="GF:'${OPTARG}'";;
    t) TOP="T: '${OPTARG}'";;
    r) REMOVE="R: true";;
    m) META="M: ${OPTARG}";;
    L) LIMIT="L: ${OPTARG}";;
  esac
done

${MOMONGER_ROOT}/bin/jobctl.sh ${SRC} ${OUT} -a "{${DEPTH},${FIELD},${GFIELD},${IGNORE},${TOP},${REMOVE},${META},${LIMIT}}" -f ${CURDIR}/jobs/id3_job.js -f ${CURDIR}/jobs/id3.js
