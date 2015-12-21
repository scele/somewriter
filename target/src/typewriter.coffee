EventEmitter = require('events').EventEmitter
Keyboard = require('./input').Keyboard
Mouse = require('./input').Mouse

defaultTimeoutProvider =
  set: setTimeout
  clear: clearTimeout

class Typewriter extends EventEmitter
  constructor: (@timeout = defaultTimeoutProvider) ->
    @HALF_SPACE = 59
    @FULL_SPACE = 118
    @SMALL_ROLL = 90 # One line is 2 or 3 small rolls, depending on line spacing
    @STABLE_AFTER_KEYUP_TIME = 150
    @x = 0
    @y = 0
    @chars = [[]]
    @text = ''
    @delta = {x: 0, y: 0}
    @stableYTimeout = null
    @unstableXTimeout = null
    @ignoreMouse = false

  setMouse: (m) ->
    @mouse?.close()
    @mouse = m
    @mouse?.on('moved', @platen.bind(this))
    @mouse?.on('error', (e) => @emit('error', e))

  setKeyboard: (k) ->
    @keyboard?.close()
    @keyboard = k
    @keyboard?.on('key', @keypress.bind(this))
    @keyboard?.on('error', (e) => @emit('error', e))

  resetText: ->
    @chars = [[]]
    @updateText()

  resetPosition: ->
    @x = 0
    @y = 0
    @delta = {x: 0, y: 0}
    @emitMoved()

  emitMoved: ->
    event =
      type: 'moved'
      x: @x
      y: @y
    @emit(event.type, event)

  stableX: ->
    oldX = @x
    @x += Math.round(@delta.x / @HALF_SPACE) * 0.5
    if (@x < 0)
      d = -Math.ceil(@x)
      console.log('Shifting everything to the right by ' + d)
      spaces = Array(d)
      l.unshift(spaces...) for l in @chars
      @x += d
      @updateText()
    @delta.x = 0
    console.log('Moved cursor horizontally to ' + @x + ',' + @y)
    @emitMoved() if oldX != @x

  unstableX: ->
    oldX = @x
    deltaUnits = @delta.x / @HALF_SPACE * 0.5;
    idelta = Math.round(deltaUnits)
    console.log("unstableX @x=" + @x + " idelta=" + idelta + " @delta.x=" + @delta.x);
    @delta.x -= idelta / 0.5 * @HALF_SPACE;
    @x += idelta
    if (@x < 0)
      d = -Math.ceil(@x)
      console.log('Shifting everything to the right by ' + d)
      spaces = Array(d)
      l.unshift(spaces...) for l in @chars
      @x += d
      @updateText()
    @emitMoved() if oldX != @x

  stableY: ->
    oldY = @y
    console.log('delta.y: ' + @delta.y)
    d = Math.round(@delta.y / @SMALL_ROLL)
    @y += d
    if @y < 0
      dd = -@y
      console.log('Shifting everything down by ' + dd)
      while (dd--)
        @chars.unshift([])
      @y = 0
      @updateText()
    @delta.y = 0
    if d then console.log('Moved cursor vertically ' + d + ' lines to ' + @x + ',' + @y)
    @emitMoved() if oldY != @y

  updateText: ->
      # Join chars to form a list of line strings.
      lines = ((char or ' ' for char in line).join('') for line in @chars)
      # For each empty line, remove two consecutive empty lines.
      #i = 0
      #while i < lines.length
      #  lines.splice(i, 1) for j in [0..2] when !lines[i]
      #  i++

      @text = lines.join('\n')
      event =
        type: 'changed'
        text: @text
      @emit(event.type, event)

  keypress: (event) ->
    if (event.value == 0)
      # Key up: platen should be stable
      @timeout.set(@stableX.bind(this), @STABLE_AFTER_KEYUP_TIME)

    if (event.value == 1)
      @stableY()
      # Cannot call stableX here, because the half tick that begins
      # a keystroke might race with the keydown signal (and it does).
      # On the other hand, we need to update the x position in case we
      # have been scrolling left and right without typing.
      #@unstableX()
      if (@x != Math.ceil(@x))
        console.log('Adjusting half step from ' + @x + ' to ' + Math.ceil(@x))
        @x = Math.ceil(@x)

      for i in [0..@y] when !(i of @chars)
        @chars[i] = []
      @chars[@y][@x] = event.char

      @updateText()
      if @ignoreMouse
        @x++
        @emitMoved()

  platen: (event) ->
    @delta.x -= event.yDelta # Remap: x = -y
    @delta.y += event.xDelta
    @timeout.clear(@stableYTimeout)
    @stableYTimeout = @timeout.set(@stableY.bind(this), 50)
    @timeout.clear(@unstableXTimeout)
    @unstableXTimeout = @timeout.set(@unstableX.bind(this), 50)

class MouseHistogram
  constructor: (mouse, @timeout = defaultTimeoutProvider) ->
    delta = {x: 0, y: 0}
    stopTimeout = null
    stop = =>
      this[delta.y] = (this[delta.y] || 0) + 1
    mouse.on 'moved', (event) ->
      delta.x -= event.yDelta # Remap: x = -y
      delta.y += event.xDelta
      @timeout.clear(stopTimeout)
      stopTimeout = @timeout.set(stop, 100)

class MouseCalibrator
  constructor: (mouse) ->
    xabs = {min: Number.MAX_VALUE, max: Number.MIN_VALUE, cur: 0}
    mouse.on 'moved', (event) ->
      xabs.cur -= event.yDelta
      xabs.min = Math.min(xabs.min, xabs.cur)
      xabs.max = Math.max(xabs.max, xabs.cur)
      xabs.span = xabs.max - xabs.min
      xabs.percentage = Math.round((xabs.cur - xabs.min)/xabs.span * 10000) / 100
      console.log(xabs)

module.exports.Typewriter = Typewriter
