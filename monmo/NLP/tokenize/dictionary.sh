#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
    cat<<USAGE
Usage :
  keyword_search.sh [options]

Options :
    -h, --help                : This message
    -D, --dictionary          : Dictionary collection ns
    -w, --word        string  : Search word
    -F, --forward-match       : Left-hand match
    -V, --verbose             :
USAGE
    exit $1
}

CONFIG=${MOMONGER_ROOT}/conf/settings.js
EVAL=''
WORD=''
FOWARD=''
DIC="var _DIC='analysis.dictionary';"
VERBOSE="var _VERBOSE=false;"

while getopts 'hD:w:FV' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
				h|--help)       usage 0 ;;
				D|--dictionary)    DIC="var _DIC='${OPTARG}';";;
				w|--word)          WORD="${OPTARG}";;
				F|--forward-match) FORWARD=1;;
				V|--verbose)       VERBOSE="var _VERBOSE=true;";;
				--) break;;
				*) echo "Internal error! " >&2; exit 1 ;;
    esac
done

QUERY="var _QUERY={w:'$WORD'};"
if [ "$FORWARD" = "1" ];then
		QUERY="var _QUERY={w:/^$WORD/};"
fi

${MONGO_SHELL} --nodb --quiet --eval "${EVAL}${DIC}${QUERY}${VERBOSE}" ${CONFIG} ${MOMONGER_ROOT}/lib/utils.js ${CURDIR}/lib/dictionary.js ${CURDIR}/lib/moddic.js | grep -v '^loading file:'
