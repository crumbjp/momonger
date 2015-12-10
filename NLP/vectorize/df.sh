#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
    cat<<USAGE
Usage :
  df.sh [options]

Summary:
  Calculate the DF (Document-Frequency) from TF.

Options :
    -h, --help                : This message
    -s, --source      ns      : Target collection ns > ( TF collection )
    -o, --output      ns      : Output collection ns
USAGE
    exit $1
}


while getopts 'hs:o:' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
				h|--help)       usage 0 ;;
				s|--source)     SRC="-s ${OPTARG}";;
				o|--output)     OUT="-o ${OPTARG}";;
				--) break;;
    esac
done

${MOMONGER_ROOT}/bin/jobctl.sh ${SRC} ${OUT} -f ${CURDIR}/jobs/df.js
