#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
    cat<<USAGE
Usage :
  tokenize.jp.sh [options]

Summary:
  Parse Japanese sentense by morphological analysis.
  It use "analysis.dictionary" collelction as dictionary by default.

    Use "gendic.sh" to create dictionary collection.

Options :
    -h, --help                : This message
    -d, --dictionary  ns      : Dictionary collection ns
    -i, --input       string  : Input sentense directly
    -V, --verbose             : With document
USAGE
    exit $1
}

CONFIG=${MOMONGER_ROOT}/conf/settings.js
DIC="var _DIC='analysis.dictionary';"
VERBOSE="var _VERBOSE=false;"

while getopts 'hd:i:V' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
				h|--help)       usage 0 ;;
				d|--dictionary) DIC="var _DIC='${OPTARG}';";;
				i|--input)      SENTENSE="var _SENTENSE='`echo \"${OPTARG}\"|tr "\n" " "`';";;
				V|--verbose)         VERBOSE="var _VERBOSE=true;";;
    esac
done

${MONGO_SHELL} --nodb --quiet --eval "${DIC}${SENTENSE}${VERBOSE}" ${CONFIG} ${MOMONGER_ROOT}/lib/utils.js  ${CURDIR}/lib/dictionary.js  ${CURDIR}/lib/morpho.js  ${CURDIR}/lib/jptokenizer.js  ${CURDIR}/lib/test.jp.js | grep -v '^loading file:'
