#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
    cat<<USAGE
Usage :
  kmeans.sh [options]

Options :
    -h, --help                : This message
    -s, --source         ns   : Target collection ns (TFIDF collection)
    -o, --output      ns      : Output collection ns
    -f, --filed        name   : Vector field                      (defalut : 'value')
    -i, --inital-cluster ns   : Cluster collection ns (Initial centers)
    -c, --cluster-filed  name : Vector field                      (defalut : 'loc')
    -r, --resume  it-num      : Resume at iteration number
    -A, --append      token   : Append to existed results with token
USAGE
    exit $1
}


FIELD="F:'value'"
CFIELD="C:'loc'"
LOOP="L:99"
INITIAL="I:null"
RESUME="R:null"
APPEND="A:null";

while getopts 'hs:o:f:i:c:r:A:' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
				h|--help)       usage 0 ;;
				s|--source)          SRC="-s ${OPTARG}";;
				o|--output)          OUT="-o ${OPTARG}";;
				f|--field)           FIELD="F:'${OPTARG}'";;
				i|--initial-cluster) INITIAL="I:'${OPTARG}'";;
				c|--cluster-field)   CFIELD="C:'${OPTARG}'";;
				r|--resume)          RESUME="R:'${OPTARG}'";;
				A|--append)          APPEND="A:'${OPTARG}'";;
    esac
done

${MOMONGER_ROOT}/bin/jobctl.sh ${SRC} ${OUT} -a "{${FIELD},${INITIAL},${CFIELD},${RESUME},${LOOP},${APPEND}}" -f ${CURDIR}/jobs/kmeans.js
