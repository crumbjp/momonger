#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
    cat<<USAGE
Usage :
  tfidf.sh [options]

Summary:
  Calculate the DF (Document-Frequency) from TF.

Options :
    -h, --help                : This message
    -s, --source      ns      : Target collection ns > ( IDF collection )
    -o, --output      ns      : Output collection ns
    -A, --append      token   : Append to existed results with token
USAGE
    exit $1
}


APPEND="A:null";

while getopts 'hs:o:A:' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
				h|--help)       usage 0 ;;
				s|--source)     SRC="-s ${OPTARG}";;
				o|--output)     OUT="-o ${OPTARG}";;
				A|--append)     APPEND="A:'${OPTARG}'";;
    esac
done

${MOMONGER_ROOT}/bin/jobctl.sh ${SRC} ${OUT} -a "{${APPEND}}" -f ${CURDIR}/jobs/tfidf.js
