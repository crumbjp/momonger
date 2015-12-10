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
    -d, --dictionary  ns      : Dictionary collection ns (default: analysis.dictionary)
    -s, --source      ns      : Target collection ns
    -f, --field       name    : Target field (default: body)
    -o, --output      ns      : Output collection ns
    -q, --query       query   : (default: {})
    -A, --append      token   : Append to existed results
USAGE
  exit $1
}


DIC="D:'analysis.dictionary'"
FIELD="F:'body'"
QUERY="Q: null"
APPEND="A: null"

while getopts 'hs:o:d:f:q:A:' OPTION; do
  echo $OPTION $OPTARG
  case $OPTION in
			h|--help)       usage 0 ;;
			s|--source)     SRC="-s ${OPTARG}";;
			o|--output)     OUT="-o ${OPTARG}";;
			d|--dictionary) DIC="D:'${OPTARG}'";;
			f|--field)      FIELD="F:'${OPTARG}'";;
			q|--query)      QUERY="Q:'${OPTARG}'";;
			A|--append)     APPEND="A:'${OPTARG}'";;
  esac
done

${MOMONGER_ROOT}/bin/jobctl.sh ${SRC} ${OUT} -a "{${DIC},${FIELD},${QUERY},${APPEND}}" -f ${CURDIR}/lib/dictionary.js -f ${CURDIR}/lib/morpho.js -f ${CURDIR}/lib/jptokenizer.js -f ${CURDIR}/jobs/tokenize.js
