var dictionary   = new Dictionary(_DIC);

var _c_dictionary = dictionary.find(_QUERY);
while ( _c_dictionary.hasNext() ) {
	var elem = _c_dictionary.next();
	print(utils.encode(elem));
}
