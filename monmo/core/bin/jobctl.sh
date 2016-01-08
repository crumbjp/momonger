#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../mongo.env

usage (){
cat<<USAGE
Usage :
  phrase.sh [options]

Summary:
  Analyze phrases from tokenized collection by using C-VALUE.

Options :
    -h, --help                      : This message
    -d, --db          dbname        :
    -j, --job         jobname       :
    -f, --files       JS files      :
    -s, --src         src collection:
    -o, --out         dst collection:
    -f, --files       JS files      :
USAGE
  exit $1
}


EVAL=''
CONFIG=${CURDIR}/../conf/settings.js
JOBNAME="var _JOBNAME=null;"
FILES=
DST="var _DST=null;"
CJOB="var _CJOB=false;"
ARGS="var _ARGS={};"

while getopts 'hn:f:s:o:a:j:c:' OPTION; do
  echo $OPTION $OPTARG
  case $OPTION in
			h|--help)       usage 0 ;;
			c|--config)     CONFIG="${OPTARG}";;
			j|--job)        JOBNAME="var _JOBNAME='${OPTARG}';";;
			f|--files)      FILES="${FILES} '${OPTARG}'";;
			s|--src)        EVAL="${EVAL}var _SRC='${OPTARG}';";;
			o|--out)        DST="var _DST='${OPTARG}';";;
			a|--args)       ARGS="var _ARGS=${OPTARG};";;
			--) break;;
  esac
done

JOBFILES='var _FILES=[';
for f in ${FILES}; do
		JOBFILES=${JOBFILES}$f','
done
JOBFILES=${JOBFILES}'null];'

${MONGO_SHELL} --nodb --quiet --eval "${EVAL}${DST}${ARGS}${JOBNAME}${JOBFILES}" ${CONFIG} ${CURDIR}/../lib/utils.js ${CURDIR}/../lib/job.js ${CURDIR}/../lib/map.js ${CURDIR}/../lib/mapreduce.js ${CURDIR}/../lib/jobctl.js ${CURDIR}/../lib/jobput.js
exit 0
