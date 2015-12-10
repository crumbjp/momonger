#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
    cat<<USAGE
Usage :
  canopy.sh [options]

Options :
    -h, --help                : This message
    -s, --source       ns     : Target collection ns (TFIDF collection)
    -o, --output      ns      : Output collection ns
    -f, --filed        name   : Vector field                      (defalut : 'value')
    -t, --threshold    float  : Cluster member minimum threashold (defalut : 0.1)
                              :  Ignoring clusters having member less than "#all-member / #cluster * threshold"
    -2, --t2   float          : T2 cluster redius                 (defalut : 0.93)
    -1, --t1   float          : T1 have to be bigger than T2      (defalut : 0.94)
    -N, --normalize           : Normalize vector
    -C, --closed              : Reduce closed cluster
USAGE
    exit $1
}

FIELD="F:'value'"
THRESHOLD="T:0.1";
T2="T2:0.93";
T1="T1:0.94";
NORMALIZE="N:false";
CLOSED="C:false";

while getopts 'hs:o:f:t:2:1:NC' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
				h|--help)         usage 0 ;;
				s|--source)       SRC="-s ${OPTARG}";;
				o|--output)       OUT="-o ${OPTARG}";;
				f|--field)        FIELD="F:'${OPTARG}'";;
				t|--threshold)    THRESHOLD="T:${OPTARG}";;
				2|--t2)           T2="T2:${OPTARG}";;
				1|--t1)           T1="T1:${OPTARG}";;
				N|--normalize)    NORMALIZE="N:true";;
				C|--closed)       CLOSED="C:true";;
				--) break;;
    esac
done

${MOMONGER_ROOT}/bin/jobctl.sh ${SRC} ${OUT} -a "{${FIELD},${THRESHOLD},${T1},${T2},${NORMALIZE},${CLOSED}}" -f ${CURDIR}/jobs/canopy5.js
