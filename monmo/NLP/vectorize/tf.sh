#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
    cat<<USAGE
Usage :
  tf.sh [options]

Summary:
  Calculate the TF (Term-Frequency) from documents in the specified collection.

Options :
    -h, --help                : This message
    -s, --source      ns      : Target collection ns ( Tokenized collection )
    -o, --output      ns      : Output collection ns
    -q, --query       query   : Query          (default : {i:1} })
    -k, --key-filed   name    : Key field      (default : 'd')
    -w, --word-field  name    : Word field     (default : 'c')
    -A, --append      token   : Append to existed results with token
USAGE
    exit $1
}

QUERY="Q:{i:1}"
KEY="K:'d'";
WORD="W:'c'";
APPEND="A:null";

while getopts 'hs:o:q:k:w:A:' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
				h|--help)       usage 0 ;;
				s|--source)     SRC="-s ${OPTARG}";;
				o|--output)     OUT="-o ${OPTARG}";;
				q|--query)      QUERY="Q:${OPTARG}";;
				k|--key-field)  KEY="K:'${OPTARG}'";;
				w|--word-field) WORD="W:'${OPTARG}'";;
				A|--append)     APPEND="A:'${OPTARG}'";;
    esac
done

${MOMONGER_ROOT}/bin/jobctl.sh ${SRC} ${OUT} -a "{${QUERY},${KEY},${WORD},${APPEND}}" -f ${CURDIR}/jobs/tf.js
