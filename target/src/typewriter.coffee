EventEmitter = require('events').EventEmitter
Keyboard = require('./input').Keyboard
Mouse = require('./input').Mouse
_ = require('lodash')

defaultTimeoutProvider =
  set: setTimeout
  clear: clearTimeout

class Typewriter extends EventEmitter
  constructor: (@timeout = defaultTimeoutProvider) ->
    @HALF_SPACE = 59
    @FULL_SPACE = 118
    @SMALL_ROLL = 90 # One line is 2 or 3 small rolls, depending on line spacing
    @STABLE_BEFORE_KEYDOWN_TIME = 50
    @x = 0
    @y = 0
    @chars = [[]]
    @text = ''
    @delta = {x: 0, y: 0}
    @stableYTimeout = null
    @ignoreMouse = false
    @history = []

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
    @history = []
    @delta = {x: 0, y: 0}
    @emitMoved()

  emitMoved: ->
    event =
      type: 'moved'
      x: Math.round(@x)
      y: @y
    @emit(event.type, event)

  updateX: ->
    oldX = @x
    @x += @delta.x / @HALF_SPACE * 0.5
    if (@x < 0)
      d = -Math.ceil(@x)
      @log('shifting everything to the right by ' + d)
      spaces = Array(d)
      l.unshift(spaces...) for l in @chars
      @x += d
      @updateText()
    @log 'updateX @x=' + oldX + ', @delta.x=' + @delta.x + ' -> @x=' + @x + ' @delta.x=0'
    @delta.x = 0
    @emitMoved() if oldX != @x

  stableY: ->
    oldY = @y
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

  setTimestamp: (t) ->
    @timestamp0 = t if !@timestamp0
    @timestamp = t - @timestamp0

  log: (str) ->
    console.log '[' + @timestamp.toFixed(2) + '] ' + str

  keypress: (event) ->
    return if event.code == 123 # ignore tweet button

    @setTimestamp event.time

    # if (event.value == 0)
      # Key up

    if (event.value == 1)
      @log 'keydown ' + event.char
      @stableY()

      # The platen is not stable here, because the half tick that begins
      # a keystroke might race with the keydown signal (and it does).
      # To avoid drift, we need to snap to an integer @x coordinate regularly.
      # The problem is that it's not easy to know when the platen is in a stable position.
      # Use the heuristic: small time (@STABLE_BEFORE_KEYDOWN_TIME) before keydown
      # the platen has been stable.  Find the location at that point in time, snap it
      # to an integer coordinate, and adjust the current @x accordingly.
      # On top of that, we also use the "old X coordinate" to set the location of the character.
      oldXItem = _(@history).filter((h) => h.time <= event.time - @STABLE_BEFORE_KEYDOWN_TIME)
              .sortBy('time').last()
      prev = _(@history).sortBy('time').last()

      @log 'previous history event ' + (event.time - prev.time) + ' ms ago' if prev

      if oldXItem
        oldX = oldXItem.x
        @log 'found oldX=' + oldX + ' from ' + (event.time - oldXItem.time) + ' ms ago'
        # Bias upwards to avoid misdetecting a strike as one that overwrites the previous character.
        # The cost is that we are more likely to have accidential (misdetected) spaces.
        BIAS = 0.2
        d = oldX - Math.round(oldX + BIAS)
        @log 'stabilizing @x from ' + @x + ' by ' + d + ' to ' + (@x - d) + ' (old @x=' + oldX + ')'
        @x -= d
        x = oldX - d
      else
        x = @x

      x = Math.round(x)
      y = @y
      @log 'writing ' + event.char + ' to x=' + x + ', y=' + y + ' (@x=' + @x + ', @y=' + @y + ')'

      for i in [0..y] when !(i of @chars)
        @chars[i] = []
      @chars[y][x] = event.char

      @updateText()
      if @ignoreMouse
        @x++
        @emitMoved()

  platen: (event) ->
    @setTimestamp event.time
    @delta.x -= event.yDelta # Remap: x = -y
    @delta.y += event.xDelta
    @timeout.clear(@stableYTimeout)
    @stableYTimeout = @timeout.set(@stableY.bind(this), 50)

    @updateX()
    @history.push({x: @x, time: event.time})
    @history = _(@history).sortBy('time').value()[-20..]

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
