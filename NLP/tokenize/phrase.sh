#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
    cat<<USAGE
Usage :
  phrase.sh [options]

Summary:
  Analyze phrases from tokenized collection by using C-VALUE.

Options :
    -h, --help                : This message
    -s, --source      ns      : Target collection ns > ( TOKEN collection )
    -o, --output      ns      : Output collection ns
    -t, --threshold   float   : IDF threashold minimum proportion (defalut : 0.0)
    -n, --ngram       int     : N of N-gram (default: 4)
USAGE
    exit $1
}

THRESHOLD="T:0.0";
NGRAM="N:4";

while getopts 'hs:o:t:n:' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
				h|--help)       usage 0 ;;
				s|--source)     SRC="-s ${OPTARG}";;
				o|--output)     OUT="-o ${OPTARG}";;
				t|--threshold)  THRESHOLD="T:${OPTARG}";;
				n|--ngram)      NGRAM="N:${OPTARG}";;
    esac
done

${MOMONGER_ROOT}/bin/jobctl.sh ${SRC} ${OUT} -a "{${THRESHOLD},${NGRAM}}" -f ${CURDIR}/lib/dictionary.js -f ${CURDIR}/jobs/phrase.js
