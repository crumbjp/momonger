#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
    cat<<USAGE
Usage :
  keyword_search.sh [options]

Options :
    -h, --help                : This message
    -s, --source      ns      : Target collection ns
    -w, --word        string  : Search word
    -F, --forward-match       : Left-hand match
    -V, --verbose             : With document
    -L, --verbose-length      : View document size
USAGE
    exit $1
}

CONFIG=${MOMONGER_ROOT}/conf/settings.js
EVAL=''
WORD=''
FOWARD=''
VERBOSE="var _VERBOSE=false;"
VERBOSE_LEN="var _VERBOSE_LEN=80;"

while getopts 'hs:w:FVL:' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
				h|--help)       usage 0 ;;
				s|--source)     EVAL="${EVAL}var _SRC='${OPTARG}';";;
				w|--word)       WORD="${OPTARG}";;
				F|--forward-match)   FORWARD=1;;
				V|--verbose)         VERBOSE="var _VERBOSE=true;";;
				L|--verbose-length)  VERBOSE_LEN="var _VERBOSE_LEN=${OPTARG};";;
				--) break;;
    esac
done

QUERY="var _QUERY={w:'$WORD'};"
if [ "$FORWARD" = "1" ];then
		QUERY="var _QUERY={w:/^$WORD/};"
fi

${MONGO_SHELL} --nodb --quiet --eval "${EVAL}${QUERY}${VERBOSE}${VERBOSE_LEN}" ${CONFIG} ${MOMONGER_ROOT}/lib/utils.js ${CURDIR}/lib/search.js | grep -v '^loading file:'
