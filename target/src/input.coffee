#
# Adapted from: https:#gist.github.com/boundaryfunctions/2020943
# Author: Marc Loehe (marcloehe@gmail.com)
# Adapted from Tim Caswell's nice solution to read a linux joystick
# http:#nodebits.org/linux-joystick
# https:#github.com/nodebits/linux-joystick
#

fs = require('fs')
EventEmitter = require('events').EventEmitter

class InputDevice extends EventEmitter
  constructor: (@dev, bufferSize, mode) ->
    @wrap('onRead')
    @buf = new Buffer(bufferSize)
    @fd = fs.openSync(@dev, mode)
    @startRead()
  wrap: (name) ->
    fn = this[name]
    self = this
    this[name] = (err, args...) =>
      if err then @emit('error', err) else fn.apply(self, args)
  startRead: () ->
    fs.read(@fd, @buf, 0, @buf.length, null, @onRead)
  onRead: (bytesRead) ->
    event = @parse(@buf)
    if (event)
      event.dev = @dev
      @emit(event.type, event)
    @startRead() if @fd
  close: ->
    try
      fs.close(@fd, ->)
    @fd = undefined

class Keyboard extends InputDevice
  constructor: (dev) ->
    super(dev, 16, 'r+')
  parse: (buffer) ->
    codeMap =
      16: ['q', 'Q']
      17: ['w', 'W']
      18: ['e', 'E']
      19: ['r', 'R']
      20: ['t', 'T']
      21: ['y', 'Y']
      22: ['u', 'U']
      23: ['i', 'I']
      24: ['o', 'O']
      25: ['p', 'P']
      26: ['-', '=']
      30: ['a', 'A']
      31: ['s', 'S']
      32: ['d', 'D']
      33: ['f', 'F']
      34: ['g', 'G']
      35: ['h', 'H']
      36: ['j', 'J']
      37: ['k', 'K']
      38: ['l', 'L']
      39: ['.', ':']
      40: [',', '+']
      44: ['z', 'Z']
      45: ['x', 'X']
      46: ['c', 'C']
      47: ['v', 'V']
      48: ['b', 'B']
      49: ['n', 'N']
      50: ['m', 'M']
      51: ['å', 'Å']
      52: ['ä', 'Ä']
      53: ['ö', 'Ö']

    # /usr/include/linux/input.h:
    # struct input_event {
    #     struct timeval time
    #     __u16 type
    #     __u16 code
    #     __s32 value
    # }
    raw =
      time:
        tv_sec: buffer.readInt32LE(0)
        tv_usec: buffer.readInt32LE(4)
      type: buffer.readUInt16LE(8)
      code: buffer.readUInt16LE(10)
      value: buffer.readInt32LE(12)
    event = @pendingEvent || {}
    switch (raw.type)
      when 0x00 # EV_SYN
        event.time = raw.time.tv_sec * 1000 + raw.time.tv_usec / 1000 # ms
        @pendingEvent = undefined
        return event
      when 0x01 # EV_KEY
        event.type = 'key'
        event.code = raw.code
        event.value = raw.value
        if (raw.code of codeMap)
          event.char = codeMap[raw.code][0]
          event.shiftChar = codeMap[raw.code][1]
        else
          console.log('Unknown keycode:')
          console.log(raw)
          event.char = '?'
          event.shiftChar = '?'
      when 0x04 # EV_MSC
        if (raw.code == 0x04)
          event.scancode = raw.value
      when 0x11 # EV_LED
        # Ignored
      else
        console.log(raw)
    @pendingEvent = event
    return undefined

  led: (led, value) ->
    buf = new Buffer(16)
    buf.writeUInt16LE(0x11, 8) # EV_LED
    buf.writeUInt16LE(led, 10)
    buf.writeUInt32LE(value, 12)
    fs.writeSync(@fd, buf, 0, buf.length)

class Mouse extends InputDevice
  constructor: (dev) ->
    super(dev, 16, 'r')
  parse: (buffer) ->
    # /usr/include/linux/input.h:
    # struct input_event {
    #     struct timeval time
    #     __u16 type
    #     __u16 code
    #     __s32 value
    # }
    raw =
      time:
        tv_sec: buffer.readInt32LE(0)
        tv_usec: buffer.readInt32LE(4)
      type: buffer.readUInt16LE(8)
      code: buffer.readUInt16LE(10)
      value: buffer.readInt32LE(12)
    event = @pendingEvent || {xDelta: 0, yDelta: 0}
    switch raw.type
      when 0x00 # EV_SYN
        event.time = raw.time.tv_sec * 1000 + raw.time.tv_usec / 1000 # ms
        @pendingEvent = undefined
        return event
      when 0x02 # EV_REL
        event.type = 'moved'
        if (raw.code == 0x00) # REL_X
          event.xDelta = raw.value
        else if (raw.code == 0x01) # REL_Y
          event.yDelta = raw.value
        else
          console.log(raw)
      else
        console.log(raw)
    @pendingEvent = event
    return undefined

module.exports.Mouse = Mouse
module.exports.Keyboard = Keyboard
