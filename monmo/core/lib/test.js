
function assertEq ( e , a ) {
  if ( e == a ) {
    return true;
  }
  throw 'Exp: ' + e + '  , Act: ' + a ;
}
function UnitTest(test){
  for ( var i in test ) {
    if ( typeof(test[i]) === 'function' && i !== 'setUp' && i !== 'tearDown' ) {
      try { 
        if ( test.setUp ) {
          test.setUp();
        }
        test[i]();
        print( i + ' : OK ');
        if ( test.tearDown ) {
          test.tearDown();
        }
      }catch(e){
        print( i + ' : ERROR : ' + e );
      }
    }
  }
}