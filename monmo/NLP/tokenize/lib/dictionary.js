function Dictionary(ns){
	this.dictionary  = utils.getCollection(ns);
	this.pdictionary = utils.getWritableCollection(ns);
	this.seq         = utils.getWritableCollection(ns + '.seq');
  this.meta      = this.dictionary.findOne({_id:'.meta'});
}

Dictionary.prototype.nheads = function(){
  return this.meta.nheads;
}

Dictionary.prototype.findBest = function(word, done){
  var cur = this.dictionary.find({w: word}).sort({s: -1}).limit(1);
  if ( cur.hasNext()){
    return done(null, cur.next())
  }
  return done(null, null)
}
Dictionary.prototype.findCandidates = function(query, done){
  var candidates = []
  var cur = this.dictionary.find(query).sort({l:-1,s:1})
	while( cur.hasNext()){
		candidates.push(cur.next())
  }
  return done(null, candidates);
}

Dictionary.prototype.upsert = function(e, done){
	var ret = this.pdictionary.findAndModify({
		query:{w:e.w},
		update:{ $setOnInsert:e},
		upsert:true,
		new:true
	});
  done(null, ret)
}

Dictionary.prototype.save = function(elem){
	this.pdictionary.save(elem);
}
Dictionary.prototype.init = function(nheads){
	this.pdictionary.drop();
	this.pdictionary.save({_id:'.meta',nheads: nheads});

	this.seq.drop();
	this.seq.save({_id:'seq',c:0});
}
Dictionary.prototype.index = function(){
	this.pdictionary.ensureIndex({w:1});
	this.pdictionary.ensureIndex({h:1,l:-1,s:1});
	this.pdictionary.ensureIndex({t:1});
}
Dictionary.prototype.findOne = function(q,f){
	return this.dictionary.findOne(q,f);
}
Dictionary.prototype.find = function(q,f){
	return this.dictionary.find(q,f);
}
Dictionary.prototype.update = function(q,v,f){
	this.pdictionary.update(q,v,f);
}

Dictionary.prototype.remove = function(q){
	this.pdictionary.remove(q);
}
