#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../momonger.env

usage (){
    cat<<USAGE
Usage :
  gendic.sh [options]

Summary:
  Compile the dictionary collection.
    1. Import from IPADIC when specified -i option
    2. Compile from 1. to specified collection.
    3. Some amendment.

Options :
    -h, --help       : This message.
    -D, --dictionary : Dictionary collection ns
    -i, --ipadic-dir : IPADIC directory path will get it by extacting ipadic-???.tar.gz.
                        (ex> ../data/ipadic-2.7.0/
                     : Use old collection instead of clean-created collection if this option is not specfied.
    -n, --nheads     : #Charactors of word in index.

How to get IPA Dictionary

   pushd ./data
   wget http://iij.dl.sourceforge.jp/ipadic/24435/ipadic-2.7.0.tar.gz
   tar xzf ipadic-2.7.0.tar.gz
   popd

USAGE
    exit $1
}

IPADIC=''
CONFIG=${MOMONGER_ROOT}/conf/settings.js
DICSTR='analysis.dictionary'
NHEADS='var _NHEADS = 2;'
#NHEADS='var _NHEADS = 3;'


while getopts 'hc:D:i:n:' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
        h|--help)       usage 0 ;;
        c|--config)     CONFIG="${OPTARG}";;
			  D|--dictionary) DICSTR="${OPTARG}";;
			  i|--ipadic-dir) IPADIC="--ipadic=${OPTARG}";;
			  n|--nheads)     NHEADS="var _NHEADS=${OPTARG};";;
			  --) break;;
    esac
done

DIC="var _DIC='${DICSTR}';"

DICJS="${CURDIR}/data/dic.json"
if [ "$IPADIC" != "" ]; then
		echo '=== PARSE IPADIC ==='
		perl ${CURDIR}/bin/parsedic.pl $IPADIC > ${DICJS}
		echo '=== IMPORT IPADIC ==='
    ${MONGO_SHELL}  --nodb --quiet --eval "${DIC}" ${CONFIG} ${MOMONGER_ROOT}/lib/utils.js ${DICJS} ${CURDIR}/lib/import.js
fi
echo '=== BUILDING DICTIONARY ==='
${MONGO_SHELL}  --nodb --quiet --eval "${DIC}${NHEADS}" ${CONFIG} ${MOMONGER_ROOT}/lib/utils.js ${CURDIR}/lib/dictionary.js ${CURDIR}/lib/morpho.js ${CURDIR}/lib/gendic.js
echo '=== AMEND DICTIONARY ==='
${MONGO_SHELL}  --nodb --quiet --eval "${DIC}${NHEADS}" ${CONFIG} ${MOMONGER_ROOT}/lib/utils.js ${CURDIR}/lib/dictionary.js ${CURDIR}/lib/morpho.js ${CURDIR}/lib/amenddic.js
echo '=== COMPLETE ==='
