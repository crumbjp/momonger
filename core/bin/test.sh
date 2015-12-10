#!/usr/bin/env bash
CURDIR=`dirname $0`
source $CURDIR/../mongo.env
${MONGO_SHELL} --nodb --quiet ${CURDIR}/../conf/settings.js ${CURDIR}/../lib/utils.js ${CURDIR}/../lib/job.js ${CURDIR}/../lib/map.js ${CURDIR}/../lib/mapreduce.js ${CURDIR}/../lib/jobctl.js ${CURDIR}/../lib/test.js ${CURDIR}/../test/*
