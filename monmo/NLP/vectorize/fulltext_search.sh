#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
    cat<<USAGE
Usage :
  fulltext_search.sh [options]

Options :
    -h, --help                : This message
    -s, --source      ns      : Target collection ns
    -w, --word        string  : Search word
    -V, --verbose             : With document
USAGE
    exit $1
}

CONFIG=${MOMONGER_ROOT}/conf/settings.js
EVAL=''
FOWARD=''
VERBOSE="var _VERBOSE=false;"
VERBOSE_LEN="var _VERBOSE_LEN=80;"

while getopts 'hs:w:VL:' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
				h|--help)       usage 0 ;;
				s|--source)     EVAL="${EVAL}var _SRC='${OPTARG}';";;
				w|--word)       EVAL="${EVAL}var _WORD='${OPTARG}';";;
				V|--verbose)    VERBOSE="var _VERBOSE=true;";;
				L|--verbose-length)  VERBOSE_LEN="var _VERBOSE_LEN=${OPTARG};";;
				--) break;;
    esac
done

${MONGO_SHELL} --nodb --quiet --eval "${EVAL}${VERBOSE}${VERBOSE_LEN}" ${CONFIG} ${MOMONGER_ROOT}/lib/utils.js ${CURDIR}/../tokenize/lib/dictionary.js ${CURDIR}/../tokenize/lib/morpho.js ${CURDIR}/../tokenize/lib/jptokenizer.js ${CURDIR}/lib/search.js | grep -v '^loading file:'
