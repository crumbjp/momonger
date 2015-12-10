#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
    cat<<USAGE
Usage :
  all.sh [options]

Summary:
  This is an automation script

  Calculate the TF/IDF from tokens in the specified collection.


Options :
    -h, --help                : This message
    -s, --source      ns      : Target collection ns
    -t, --threshold   float   : IDF threashold minimum proportion (defalut : 0.0)
    -l, --limit       float   : IDF threashold maximum proportion (defalut : 0.40)
    -v, --verb-only           : Pickup verb only
    -D, --dictionary-boost    : Use dictionary coefficient.
USAGE
    exit $1
}

while getopts 'hs:t:l:v' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
				h|--help)       usage 0 ;;
				s|--source)     SRC="${OPTARG}";;
				t|--threshold)  THRESHOLD=" -t ${OPTARG} ";;
				l|--limit)      LIMIT=" -l ${OPTARG} ";;
				v|--verb-only)  VERB=" -v ";;
				D|--dictionary-boost)  DICBOOST=" -D ";;
				--) break;;
    esac
done


TF=${SRC}'.vector.tf'
DF=${SRC}'.vector.df'
IDF=${SRC}'.vector.idf'
TFIDF=${SRC}'.vector.tfidf'

$CURDIR/tf.sh    -s ${SRC} -o ${TF}
$CURDIR/df.sh    -s ${TF}  -o ${DF}
$CURDIR/idf.sh   -s ${DF}  -o ${IDF}
$CURDIR/idf.sh   -s ${DF}  -o ${IDF} ${THRESHOLD} ${LIMIT} ${VERB} ${DICBOOST}
$CURDIR/tfidf.sh -s ${IDF} -o ${TFIDF}
