{addVector, multiVector, divVector, diffVector, diffAngle, normalVector} = require 'momonger/common'

describe 'common', ->
  it 'addVector', ->
    v1 =
      f1: 10
      f2: 20
      f3: 30
    v2 =
      f1: 11
      f2: 22
      f3: 33
    expect(addVector v1, v2).to.deep.equal
      f1: 21
      f2: 42
      f3: 63

  it 'multiVector', ->
    v1 =
      f1: 1
      f2: 2
      f3: 3
    expect(multiVector v1, 10).to.deep.equal
      f1: 10
      f2: 20
      f3: 30

  it 'divVector', ->
    v1 =
      f1: 10
      f2: 20
      f3: 30
    expect(divVector v1, 10).to.deep.equal
      f1: 1
      f2: 2
      f3: 3

  it 'diffVector', ->
    v1 =
      f1: 0.5
      f2: 0.3
      f3: 0.2
    v2 =
      f2: 0.3
      f3: 0.2
      f4: 0.5
    expect(diffVector v1, v2).to.equal Math.sqrt 0.5

  it 'diffAngle', ->
    v1 =
      f1: 0.789
      f2: 0.515
      f3: 0.355
    v2 =
      f1: 0.524
      f2: 0.465
      f3: 0.405
      f4: 0.588
    expect(diffAngle v1, v2).to.equal 0.203314

  it 'normalVector', ->
    v =
      f1: 3
      f2: 4
      f3: 5
      f4: 6
    expect(normalVector v).to.deep.equal
      f1: 0.3234983196103152
      f2: 0.43133109281375365
      f3: 0.539163866017192
      f4: 0.6469966392206304
