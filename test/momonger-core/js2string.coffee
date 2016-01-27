js2String = require 'momonger-core/js2string'

describe 'js2String', ->
  it 'hash', ->
    hash =
      m:
        b: 1.999
        c:
          a: [1,2]
          n: null
          b: true
          u: undefined
        d: new Date()
      f: ->
        1
    str = js2String hash
    result = null
    eval "result = #{str}"
    expect(result.m).to.deep.equal hash.m
    expect(result.f()).to.equal 1

  it 'cyclic hash', ->
    hash =
      m:
        b: 1.999
        c:
          a: [1,2]
          n: null
          b: true
          u: undefined
        d: new Date()
      f: ->
        1
    hash.hash = hash

    str = js2String hash
    result = null
    eval "result = #{str}"
    expect(result.m).to.deep.equal hash.m
    expect(result.f()).to.equal 1

  it 'class', ->
    getString = ->
      class Clazz
        constructor: ->
          @val =
            a: 1
            b: undefined
            c: null
            d: new Date(1450164623591)

        run: ->
          @val

      js2String Clazz

    eval getString()
    clazz = new Clazz
    result = clazz.run()
    expect(result).to.deep.equal
      a: 1
      b: undefined
      c: null
      d: new Date(1450164623591)

  it 'class extends', ->
    getString = ->
      class Clazz
        constructor: ->
          @val =
            a: 1
            b: undefined
            c: null
            d: new Date(1450164623591)

        run: ->
          @val

        runExtended: ->
          @val

      class ChildClazz extends Clazz
        runExtended: ->
          {a: 1}

      js2String ChildClazz

    eval getString()
    clazz = new ChildClazz
    resultRun = clazz.run()
    expect(resultRun).to.deep.equal
      a: 1
      b: undefined
      c: null
      d: new Date(1450164623591)

    resultRunExtended = clazz.runExtended()
    expect(resultRunExtended).to.deep.equal
      a: 1

  it 'function', ->
    getString = ->
      func = ->
        class Clazz
          constructor: ->
            @val =
              a: 1
          run: ->
            @val
        clazz = new Clazz
        clazz.run()
      js2String func

    func = null
    eval "func = #{getString()}"
    expect(func()).to.deep.equal {a: 1}
