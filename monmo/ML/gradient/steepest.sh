#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../../monmo.env

usage (){
    cat<<USAGE
Usage :
  steepest.sh.sh [options]

Summary:
  Generate vector by steepest gradient method.

Options :
    -h, --help                : This message
    -s, --source      ns      : Target data collection
    -o, --output      ns      : Output collection ns
    -f, --field       name    : Vector field (default: loc)
    -g, --goal        ns      : Goal data collection
    -F, --goal-field  name    : Goal score field (default: score)
    -d, --delta       float   : First delta (default: 0.0000001)
    -b, --beta                : Use beta vector
    -R, --resume      num     : Resume at iteration number
    -Q, --query       JS      : Query
    -M, --max-it      num     : Max iteration (default: 100)
Src collection
    {
       _id: ...,
       loc: {
         ...
       }
     }
Goal collection
    {
       _id: ...,
       score: <float>
    }

USAGE
    exit $1
#  -p, --propotion   float   : Reflect propotion of acceleration (default: 0.1)
#  -t, --threshold   float   : Difference threshold for continue (default: 1.0)

}

FIELD="F:'loc'"
GFIELD="GF:'score'"
DELTA="D:0.0000001"
PROP="P:0.00001"
THRESHOLD="T:0.0001"
BETA="B:false"
RESUME="R:0"
QUERY="Q:'{}'"
MAX_IT="M:100"
INITIAL="I:''"
while getopts 'hs:o:f:g:F:d:p:t:bi:R:Q:M:' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
				h|--help)       usage 0 ;;
				s|--source)     SRC="-s ${OPTARG}";;
				o|--output)     OUT="-o ${OPTARG}";;
        f|--field)      FIELD="F:'${OPTARG}'";;
				g|--goal)       GOAL="G:'${OPTARG}'";;
        F|--goal-field) GFIELD="GF:'${OPTARG}'";;
        d|--delta)      DELTA="D:${OPTARG}";;
        p|--prop)       PROP="P:${OPTARG}";;
        t|--threshold)  THRESHOLD="T:${OPTARG}";;
        b|--beta)       BETA="B:true";;
        i|--initial)    INITIAL="I:'${OPTARG}'";;
        R|--resume)     RESUME="R:${OPTARG}";;
        Q|--query)      QUERY="Q:'${OPTARG}'";;
        M|--max-it)     MAX_IT="M:${OPTARG}";;
    esac
done

${MONMO_ROOT}/bin/jobctl.sh ${SRC} ${OUT} -a "{${GOAL},${FIELD},${GFIELD},${DELTA},${PROP},${THRESHOLD},${BETA},${RESUME},${QUERY},${MAX_IT},${INITIAL}}" -f ${CURDIR}/jobs/steepest.js
