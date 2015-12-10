#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
cat<<USAGE
Usage :
  viewvector.sh [options]

Options :
    -h, --help                : This message
    -s, --source      ns      : Target collection ns
    -V, --verbose             :
    -L, --verbose-length      : View document size
USAGE
  exit $1
}

CONFIG=${MOMONGER_ROOT}/conf/settings.js
EVAL=''
VERBOSE="var _VERBOSE=false;"
VERBOSE_LEN="var _VERBOSE_LEN=10;"

while getopts 'hs:VL:' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
				h|--help)       usage 0 ;;
				s|--source)     EVAL="${EVAL}var _SRC='${OPTARG}';";;
				V|--verbose)    VERBOSE="var _VERBOSE=true;";;
				L|--verbose-length)  VERBOSE_LEN="var _VERBOSE_LEN=${OPTARG};";;
				--) break;;
    esac
done

${MONGO_SHELL} --nodb --quiet --eval "${EVAL}${DIC}${VERBOSE}${VERBOSE_LEN}" ${CONFIG} ${MOMONGER_ROOT}/lib/utils.js ${CURDIR}/lib/viewvector.js | grep -v '^loading file:'
