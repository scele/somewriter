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

  stableX: ->
    @x += Math.round(@delta.x / @HALF_SPACE) * 0.5
    if (@x < 0)
      d = -Math.ceil(@x)
      console.log('Shifting everything to the right by ' + d)
      spaces = Array(d)
      l.unshift(spaces...) for l in @chars
      @x += d
    @delta.x = 0
    console.log('Moved cursor horizontally to ' + @x + ',' + @y)

  stableY: ->
    console.log('delta.y: ' + @delta.y)
    d = Math.round(@delta.y / @SMALL_ROLL)
    @y += d
    if @y < 0
      dd = -@y
      console.log('Shifting everything to the right by ' + dd)
      while (dd--)
        @chars.unshift([])
      @y = 0
    @delta.y = 0
    if d then console.log('Moved cursor vertically ' + d + ' lines to ' + @x + ',' + @y)

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
      #@stableX()
      if (@x != Math.ceil(@x))
        console.log('Adjusting half step from ' + @x + ' to ' + Math.ceil(@x))
        @x = Math.ceil(@x)

      if (!(@y of @chars))
        @chars[@y] = []
      @chars[@y][@x] = event.char

      # Join chars to form a list of line strings.
      lines = ((char or ' ' for char in line).join('') for line in @chars)
      # For each empty line, remove two consecutive empty lines.
      i = 0
      while i < lines.length
        lines.splice(i, 1) for j in [0..2] when !lines[i]
        i++

      @text = lines.join('\n')
      event =
        type: 'changed'
        text: @text
      @emit(event.type, event)

  platen: (event) ->
    @delta.x -= event.yDelta # Remap: x = -y
    @delta.y += event.xDelta
    @timeout.clear(@stableYTimeout)
    @stableYTimeout = @timeout.set(@stableY.bind(this), 50)

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
