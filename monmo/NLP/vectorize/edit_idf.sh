#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
    cat<<USAGE
Usage :
  edit_idf.sh [options]

Options :
    -h, --help                : This message
    -s, --source      ns      : IDF collection ns
    -i, --id     dictionary-id: target dictionary id
    -v, --value  new-value    : new i-value
USAGE
    exit $1
}

CONFIG=${MOMONGER_ROOT}/conf/settings.js
EVAL=''

while getopts 'hs:i:v:' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
				h|--help)       usage 0 ;;
				s|--source)     SRC="var _SRC='${OPTARG}';";;
				i|--id)           ID="var _ID='${OPTARG}';";;
				v|--value)     VALUE="var _VALUE=${OPTARG};";;
    esac
done

${MONGO_SHELL} --nodb --quiet --eval "${EVAL}${SRC}${ID}${VALUE}" ${CONFIG} ${MOMONGER_ROOT}/lib/utils.js ${CURDIR}/../tokenize/lib/dictionary.js ${CURDIR}/lib/edit_idf.js | grep -v '^loading file:'
