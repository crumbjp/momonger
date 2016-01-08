#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../mongo.env

usage (){
    cat<<USAGE
Usage :
  worker.sh [options]

Summary:
  Momo worker controller

Options :
    -h, --help                : This message
    -d, --db          dbname  :
    -J, --jobs        num     : Number of jobs
USAGE
    exit $1
}


CONFIG=${CURDIR}/../conf/settings.js
JOBS="1"

while getopts ':hc:J:' OPTION; do
    echo $OPTION $OPTARG
    case $OPTION in
        h|--help)       usage 0 ;;
        c|--config)     CONFIG="${OPTARG}";;
        J|--jobs)       JOBS="${OPTARG}";;
        --) break;;
    esac
done

QUIT=
#
PIDS=''

function kick_worker {
  if [ "${QUIT}" = "" ]; then
    ${MONGO_SHELL} --nodb --quiet ${CONFIG} ${CURDIR}/../lib/utils.js ${CURDIR}/../lib/job.js ${CURDIR}/../lib/map.js ${CURDIR}/../lib/mapreduce.js ${CURDIR}/../lib/jobctl.js ${CURDIR}/../lib/worker.js &
    PIDS="${PIDS} $!"
    echo " == RESTART WORKER ( $! ) == "
  fi
}
function sigchild {
  nChildren=`wc -w <<<${PIDS}`
  for (( i=${nChildren}; i<${JOBS}; i++ )); do
    kick_worker
  done

  NEW_PIDS=
  for PID in ${PIDS}; do
    kill -s 0 ${PID} 2> /dev/null
    if [ "$?" = "0" ];then
      NEW_PIDS="${NEW_PIDS} ${PID}"
    else
      echo " == WORKER DIED ( ${PID} ) == "
      wait ${PID}
    fi
  done
  PIDS=${NEW_PIDS}
}

function sigquit {
  echo " == TERMINATE SIGNAL == "
  QUIT=1
}

# trap "sigchild" CHLD
trap "sigquit" INT

for i in `eval echo "{1..${JOBS}}"`; do
  kick_worker
done

# To trap SIGCHLD
set -m

while true ; do
#  echo ${PIDS}
  sleep 0.3 &
  wait $!
  sigchild
  if [ "${QUIT}" != "" ]; then
    break
  fi
done
echo '== WAIT FOR WORKERS =='
echo ${PIDS}
jobs
disown
