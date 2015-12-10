#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
    cat<<USAGE
Usage :
  idf.sh [options]

Summary:
  Calculate the TF (Term-Frequency) from documents in the specified collection.

Options :
    -h, --help                : This message
    -s, --source      ns      : Target collection ns ( DF collection )
    -o, --output      ns      : Output collection ns
    -t, --threshold   float   : IDF threashold minimum proportion (defalut : 0.0)
    -l, --limit       float   : IDF threashold maximum proportion (defalut : 0.40)
    -v, --verb-only           : Pickup verb only
    -D, --dictionary-boost    : Use dictionary coefficient.
USAGE
    exit $1
}

THRESHOLD="T:0.0";
LIMIT="L:0.40";
VERB="V:false";
DICBOOST="D:false";

while getopts 'hs:o:q:t:l:vD' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
				h|--help)       usage 0 ;;
				s|--source)     SRC="-s ${OPTARG}";;
				o|--output)     OUT="-o ${OPTARG}";;
				t|--threshold)  THRESHOLD="T:${OPTARG}";;
				l|--limit)      LIMIT="L:${OPTARG}";;
				v|--verb-only)  VERB="V:true";;
				D|--dictionary-boost)  DICBOOST="D:true";;
				--) break;;
    esac
done

${MOMONGER_ROOT}/bin/jobctl.sh ${SRC} ${OUT} -a "{${THRESHOLD},${LIMIT},${VERB},${DICBOOST}}" -f ${CURDIR}/jobs/idf.js
