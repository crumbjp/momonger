var jobctl = new Jobctl(config.mongo.basedb);
var options = jobctl.load(_JOBNAME,_SRC,_DST,_FILES,_ARGS);
