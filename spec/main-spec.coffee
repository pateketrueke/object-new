#require('debug').enable('*');

$new = require('..')

describe 'Object.new()', ->
  it 'is a function', ->
    expect(typeof $new).toEqual 'function'

  it 'returns a factory function', ->
    expect(typeof $new()).toEqual 'function'

  it 'should fail if no name is given', ->
    expect(-> $new('')).toThrow()

  it 'returns an function when is called', ->
    expect(typeof $new('example')).toEqual 'function'

  it 'will nest multiple objects using keypaths', ->
    m = $new('m')
    n = $new('m.n')
    o = $new('m.n.o')

    expect(m.name).toEqual 'm'
    expect(m.n.name).toEqual 'n'
    expect(m.n.o.name).toEqual 'o'

  it 'can create objects with identity', ->
    expect($new('myObject').name).toEqual 'myObject'

  it 'can define static properties', ->
    expect($new('staticProps', { a: 'b' }).a).toEqual 'b'

  it 'can define static methods', ->
    expect($new('staticMethods', { a: -> 'b' }).a()).toEqual 'b'

  it 'should validate its methods', ->
    expect(-> $new({
      methods:
        foo: 'bar'
    })).toThrow()

    expect(-> $new({
      init: ->
        methods:
          foo: 'bar'
    })).toThrow()

  it 'can define properties', ->
    # properties are always called as getters regardless of its arguments
    expect($new('props', { props: { x: 'y' } }).new().x).toEqual 'y'
    expect($new('dynamicProps', { props: { x: -> 'y' } }).new().x).toEqual 'y'
    expect($new('dynamicProps_', { props: { x: (_) -> 'y' } }).new().x).toEqual 'y'

  it 'can define read-only properties', ->
    O = $new('dynamic', {
      props:
        value: 'WILL CHANGE'
        readonly: -> @value
    })

    o = O.new()
    o.value = 'CHANGED'

    # all values are kept safe
    expect(o.value).toEqual 'CHANGED'
    expect(O.new().value).toEqual 'WILL CHANGE'

    # cannot override readonly-props
    expect(o.readonly).toEqual 'CHANGED'
    expect(-> o.readonly = 'NO').toThrow()
    expect(o.readonly).toEqual 'CHANGED'

  it 'can define properties with getters/setters', ->
    o = $new(eval('''({
        props: {
          get someValue() { return this._value; },
          set someValue(value) { this._value = value; }
        }
      })'''))

    expect(o.someValue).toBeUndefined()

    o.someValue = 'OK'

    # you shall not pass!
    delete o.someValue

    expect(o.someValue).toEqual 'OK'

  it 'can define methods', ->
    # fails is given methods is not a function
    expect(-> $new('errMethods', { methods: { x: 'y' } }).new()).toThrow()

    # all methods has the context as first argument
    expect($new('short', { methods: { x: -> 'y' } }).new().x()).toEqual 'y'
    expect($new('args', { methods: { x: (y) -> y } }).new().x('z')).toEqual 'z'

  it 'can define init', ->
    o = $new('mutatedObject', {
      init: (value) ->
        @_value = value or 'OK'
        null

      methods:
        value: (suffix = '!') ->
          @_value + suffix
    })

    expect(o.new().value('!!!')).toEqual 'OK!!!'
    expect(o.new('OSOM').value()).toEqual 'OSOM!'

  it 'can be instantiated with new', ->
    O = $new('ClassExample', { props: { x: 'y' } })

    expect(typeof O).toEqual 'function'
    expect((new O).x).toEqual 'y'

    # calling the object as function will nest definitions
    o = O('NestedObject', { props: { foo: 'bar' } })
    expect(O.NestedObject.new().foo).toEqual 'bar'

  it 'inject this as expected', ->
    o = $new('ClassA', { props: { x: 'y' }, methods: { z: -> @x } })
    expect(o.new().z()).toEqual 'y'

  it 'handles enumerability by default', ->
    o = $new('Test', {
      # hidden
      init: ->
      props:
        _hiddenProperty: true
        enumerableProperty: true
      methods:
        _hiddenMethod: ->
        enumerableMethod: ->
    })

    expect(Object.keys(o)).toEqual []
    expect(Object.keys(o.new())).toEqual ['enumerableProperty', 'enumerableMethod']
    expect(JSON.stringify(o.new())).toEqual '{"enumerableProperty":true}'

  it 'will merge multiple definitions', ->
    results = []

    $new('Base', {
      init: ->
        results.push 'DEFAULT'
        null

      props:
        value: 'OK'

      methods:
        test: -> 'OVERRIDE ME'
    })

    $new('Base', {
      init: ->
        @super.init()
        results.push 'MIXIN'
        null

      props:
        foo: -> 'bar'

      methods:
        test: -> 'OK'
    })

    o = $new('Base').new()

    expect(o.foo).toEqual 'bar'
    expect(o.test()).toEqual 'OK'
    expect(results).toEqual ['DEFAULT', 'MIXIN']
    expect(Object.keys(o)).toEqual ['value', 'foo', 'test']

  it 'can compose multiple inheritance', ->
    # static props
    A = $new('A', { v: 1 } )
    B = A({ v: 2 })

    expect(A.v).toEqual 1
    expect(B.v).toEqual 2

    # mixed props/methods
    A2 = A({ methods: get: -> @x })
    A3 = A2({ props: { x: 'y' } })

    expect(A3.new().get()).toEqual 'y'

    # constructors run in order
    C = $new('C', { init: -> @r.push(1); null })
    C1 = C({ props: { r: [] } })

    # don't pollute
    C1.new()
    C2 = C1({ init: -> @super.init(); @r.push(2); null })

    expect(C2.new().r).toEqual [1, 2]

  it 'has support for namespaces', ->
    Global = $new('TEST', { init: -> @_global = 1; null })
    Local = $new()
    Other = $new()

    TEST = Local('TEST', { init: -> @_local = 1; null })

    a = Other('TEST').new()
    b = $new('TEST').new()
    c = Local('TEST').new()

    expect(JSON.stringify(a)).toEqual '{}'
    expect(JSON.stringify(b)).toEqual '{"_global":1}'
    expect(JSON.stringify(c)).toEqual '{"_local":1}'

  it 'can provide values', ->
    expect($new('getInjector', () -> 'OSOM').new()).toEqual 'OSOM'

  it 'can avoid extensions', ->
    test = null

    $new('foo', { bar: 'baz' })
    $new('foo', { candy: 'does nothing' }, null, false)
    $new('foo', `{ get test() { test = 42 } }`, null, false)

    expect(test).toBe null
    expect($new('foo').extensions.length).toEqual 1

  it 'can receive args on factories', ->
    bar = $new('bar', (_, x) -> {props:{x}})

    expect(bar.new(null, 42).x).toEqual 42

  it 'can copy complex values, e.g. RegExp/Date', ->
    time = new Date()

    Top = $new 'Top',
      opts:
        str: 'OK'
        regex: /x/
        timestamp: time

    Sub = Top
      opts:
        str: 'OSOM'

    Top.opts.timestamp.setTime(0)
    expect(Top.opts.timestamp.getTime()).toEqual 0

    expect(Sub.opts.str).toEqual 'OSOM'
    expect(Sub.opts.regex).toEqual /x/
    expect(Sub.opts.timestamp.getTime()).toEqual time.getTime()

  it "can invoke parents' methods or props", ->
    test = []

    Parent = $new 'Parent',
      methods:
        foo: ->
          test.push 'OK'

    Child = Parent
      methods:
        bar: ->
          @super.foo()

    Toy = Child
      methods:
        baz: ->
          @super.bar()

    y = new Toy()

    expect(-> y.baz()).not.toThrow()
    expect(y.baz()).toEqual 2

    expect(test).toEqual ['OK', 'OK']

    expect(-> y.super).not.toThrow()
    expect(-> y.super.super).not.toThrow()
    expect(-> y.super.super.super).toThrow()

    expect(Object.keys(y)).toEqual ['foo', 'bar', 'baz']
    expect(Object.keys(y.super)).toEqual ['foo', 'bar']
    expect(Object.keys(y.super.super)).toEqual ['foo']

  it 'can pass arguments to init() calls', ->
    Polygon = $new 'Polygon',
      name: 'FunkPolygon'
      init: (w, h) ->
        @width = w
        @height = h
        null

    Square = Polygon
      name: 'SquareX'
      init: (x) ->
        @super.init(x, x)
        null

    p = new Polygon(3, 4)

    expect(p.width).toEqual 3
    expect(p.height).toEqual 4

    s = new Square(2)

    expect(s.width).toEqual 2
    expect(s.height).toEqual 2

    expect(Square.name).toEqual 'SquareX'
    expect(Polygon.name).toEqual 'FunkPolygon'
