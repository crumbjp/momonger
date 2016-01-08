
UnitTest({
  setUp : function(){
    this.target = {
      foo: 'Foo',
      bar: 'Bar',
      baz: [3,2,1,5,4,9,7,8,6],
    }
  },
  katakana : function(){
    var exp = 'アイウアイワヲンーワヲンヰュ漢字';
    var ret = utils.katakana('あいうアイわをんーワヲンゐゅ漢字');
    assertEq(exp,ret);
  },
  unique : function(){
    var exp = [3,2,1];
    assertEq(
             tojson(exp) ,
             tojson(utils.unique([3,3,3,2,1,2,1,2,1,3,1])));
  },
  extend : function(){
    var ret = utils.extend({},this.target,{bar : 'BAR' , foobar : 1 });
    this.target.foobar = 1;
    this.target.bar = 'BAR';
    assertEq(
           tojson(this.target),
           tojson(ret));
  },
  sort : function(){
    var ret = utils.sort(this.target.baz,function(a,b){ return b < a; } );
    assertEq(
             '[ 9, 8, 7, 6, 5, 4, 3, 2, 1 ]',
             tojson(ret));
  },
  array_in : function(){
    assertEq( true , utils.array_in(this.target.baz,1));
    assertEq( true , utils.array_in(this.target.baz,5));
    assertEq( true , utils.array_in(this.target.baz,9));
    assertEq( false, utils.array_in(this.target.baz,11));
  },
  array_all : function(){
    assertEq( true , utils.array_all(this.target.baz,[1]));
    assertEq( true , utils.array_all(this.target.baz,[1,2]));
    assertEq( true , utils.array_all(this.target.baz,[3,4,5,6,7]));
    assertEq( false, utils.array_all(this.target.baz,[10]));
    assertEq( false, utils.array_all(this.target.baz,[1,2,10]));
  },
  heads : function(){
    var exp = [
      [3,2,1],[3,2],[3]];
    assertEq(
             tojson(exp) ,
             tojson(utils.heads(this.target.baz,3)));
  },
  getField : function(){
    assertEq(
             999 ,
             utils.getField({
               a : 10,
               b : {
                 c : {
                   d : 999
                 }
               }
             },'b.c.d'));
  },
  addVector : function(){
    var exp = {
      a : 10,
      b : 10,
      c : 10 };

    assertEq(
             tojson(exp) ,
             tojson(utils.addVector({
               a : 5,
               b : 10
             },{
               a : 5,
               c : 10
             })));
  },
	diffVector: function (loc1,loc2){
    // 3,4 = 5
    // 5,12= 13
    assertEq(
             13 ,
             utils.diffVector({
               a : 3,
               b : 0
             },{
               a : 0,
               b : 4,
               c : 12
             }));
	},
	diffAngle: function (loc1,loc2){
    // 0.5 * 0.5 + 0.5 * 0.5 = 0.5
    assertEq(
             0.5 ,
             utils.diffAngle({
               a : 0.5,
               b : 0.5,
               c : 0.5,
               d : 0.5,
             },{
               c : 0.5,
               d : 0.5,
               e : 0.5,
               f : 0.5,
             }));
	},
  normalize : function(){
    // (0.5 * 0.5) * 4 = 1;
    var exp = {
      a : 0.5,
      b : 0.5,
      c : 0.5,
      d : 0.5};

    assertEq(
             tojson(exp) ,
             tojson(utils.normalize({
               a : 1,
               b : 1,
               c : 1,
               d : 1,
             })));
  },
  trimSpace : function(){
    assertEq(
             'aa bb cc\ndd' ,
             utils.trimSpace('aa  bb\t\tcc\ndd'));
  },
  parseCollection : function(){
    var exp = {
      db : 'test',
      col : 'foo.bar'};
    assertEq(
             tojson(exp) ,
             tojson(utils.parseCollection('test.foo.bar')));
  },
  encodeDecode : function(){
    var src = {
      _string: 'foo',
      _int: 1,
      _float: 1.1,
      _nan: NaN,
      _Infinity: Infinity,
      _null: null,
      _date: new Date(),
      _array: [
        'foo',
        1,
        1.1,
        {
          _int: 1,
          _float: 1.1,
        },{
          _int: 1,
          _float: 1.1,
        }],
      _hash: {
        _date: new Date(),
        _sub: {
          _date: new Date(),
        }
      }
    }
    var encoded = utils.encode(src);
    var decoded = utils.decode(encoded);
    assertEq(
      tojson(src),
      tojson(decoded)
    )
  },
});
