#!/usr/bin/env bash
CURDIR=`dirname $0`

${CURDIR}/../bin/jobctl.sh -s momongertest.TEST1 -o momongertest.RESULT1  -f ${CURDIR}/jobs/samplejob.js
${CURDIR}/../bin/jobctl.sh -s momongertest.TEST2 -o momongertest.RESULT2  -f ${CURDIR}/jobs/samplemap.js
${CURDIR}/../bin/jobctl.sh -s momongertest.TEST3 -o momongertest.RESULT3  -f ${CURDIR}/jobs/samplemapreduce.js
${CURDIR}/../bin/jobctl.sh -s momongertest.TEST4 -o momongertest.RESULT4  -f ${CURDIR}/jobs/sample_kick_another_job.js
