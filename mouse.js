/**
 * Read Linux mouse(s) in node.js
 * Author: Marc Loehe (marcloehe@gmail.com)
 * From: https://gist.github.com/boundaryfunctions/2020943
 *
 * Adapted from Tim Caswell's nice solution to read a linux joystick
 * http://nodebits.org/linux-joystick
 * https://github.com/nodebits/linux-joystick
 */

var fs = require('fs'),
    _ = require('lodash'),
    EventEmitter = require('events').EventEmitter;


function InputDevice(dev, bufferSize, mode, parse) {
  this.wrap('onOpen');
  this.wrap('onRead');
  this.dev = dev;
  this.buf = new Buffer(bufferSize);
  this.parse = parse;
  fs.open(this.dev, mode, this.onOpen);
}

InputDevice.prototype = Object.create(EventEmitter.prototype, {
  constructor: {value: InputDevice}
});

InputDevice.prototype.wrap = function(name) {
  var self = this;
  var fn = this[name];
  this[name] = function (err) {
    if (err) return self.emit('error', err);
    return fn.apply(self, Array.prototype.slice.call(arguments, 1));
  };
};

InputDevice.prototype.onOpen = function(fd) {
  this.fd = fd;
  this.startRead();
};

InputDevice.prototype.startRead = function() {
  fs.read(this.fd, this.buf, 0, this.buf.length, null, this.onRead);
};

InputDevice.prototype.onRead = function(bytesRead) {
  var event = this.parse(this, this.buf);
  if (event) {
    event.dev = this.dev;
    this.emit(event.type, event);
  }
  if (this.fd) this.startRead();
};

InputDevice.prototype.close = function(callback) {
  fs.close(this.fd, (function(){console.log(this);}));
  this.fd = undefined;
};


// Keyboard

function Keyboard(dev) {
  var codeMap = {
    16: 'q',
    17: 'w',
    18: 'e',
    19: 'r',
    20: 't',
    21: 'y',
    22: 'u',
    23: 'i',
    24: 'o',
    25: 'p',
    25: '-',
    30: 'a',
    31: 's',
    32: 'd',
    33: 'f',
    34: 'g',
    35: 'h',
    36: 'j',
    37: 'k',
    38: 'l',
    39: '.',
    40: ',',
    44: 'z',
    45: 'x',
    46: 'c',
    47: 'v',
    48: 'b',
    49: 'n',
    50: 'm',
    51: 'å',
    52: 'ä',
    53: 'ö',
  };
  var codeMapShift = {
    16: 'Q',
    17: 'W',
    18: 'E',
    19: 'R',
    20: 'T',
    21: 'Y',
    22: 'U',
    23: 'I',
    24: 'O',
    25: 'P',
    26: '=',
    30: 'A',
    31: 'S',
    32: 'D',
    33: 'F',
    34: 'G',
    35: 'H',
    36: 'J',
    37: 'K',
    38: 'L',
    39: ':',
    40: '+',
    44: 'Z',
    45: 'X',
    46: 'C',
    47: 'V',
    48: 'B',
    49: 'N',
    50: 'M',
    51: 'Å',
    52: 'Ä',
    53: 'Ö',
  };

  function parseKeyboard(dev, buffer) {
    // /usr/include/linux/input.h:
    // struct input_event {
    //     struct timeval time;
    //     __u16 type;
    //     __u16 code;
    //     __s32 value;
    // };
    var raw = {
      time: { tv_sec: buffer.readInt32LE(0), tv_usec: buffer.readInt32LE(4) },
      type: buffer.readUInt16LE(8),
      code: buffer.readUInt16LE(10),
      value: buffer.readInt32LE(12)
    };
    var event = dev.pendingEvent || {};
    switch (raw.type) {
      case 0x00: // EV_SYN
        event.time = raw.time.tv_sec * 1000 + raw.time.tv_usec / 1000; // ms
        dev.pendingEvent = undefined;
        return event;
      case 0x01: // EV_KEY
        event.type = 'key';
        event.code = raw.code;
        event.value = raw.value;
        event.char = codeMap[raw.code];
        event.shiftChar = codeMapShift[raw.code];
        break;
      case 0x04: // EV_MSC
        if (raw.code == 0x04)
          event.scancode = raw.value;
        break;
      case 0x11: // EV_LED
        break;
      default:
        console.log(raw);
    }
    dev.pendingEvent = event;
    return undefined;
  }
  InputDevice.call(this, dev, 16, 'r+', parseKeyboard);
}

Keyboard.prototype = Object.create(InputDevice.prototype, {
  constructor: {value: Keyboard}
});

Keyboard.prototype.led = function (led, value) {
  var buf = new Buffer(16);
  buf.writeUInt16LE(0x11, 8); // EV_LED
  buf.writeUInt16LE(led, 10);
  buf.writeUInt32LE(value, 12);
  fs.write(this.fd, buf, 0, buf.length, null);
};

function Mouse(dev) {
  function parseMouse(dev, buffer) {
    // /usr/include/linux/input.h:
    // struct input_event {
    //     struct timeval time;
    //     __u16 type;
    //     __u16 code;
    //     __s32 value;
    // };
    var raw = {
      time: { tv_sec: buffer.readInt32LE(0), tv_usec: buffer.readInt32LE(4) },
      type: buffer.readUInt16LE(8),
      code: buffer.readUInt16LE(10),
      value: buffer.readInt32LE(12)
    };
    var event = dev.pendingEvent || {xDelta: 0, yDelta: 0};
    switch (raw.type) {
      case 0x00: // EV_SYN
        event.time = raw.time.tv_sec * 1000 + raw.time.tv_usec / 1000; // ms
        dev.pendingEvent = undefined;
        return event;
      case 0x02: // EV_REL
        event.type = 'moved';
        if (raw.code == 0x00) // REL_X
          event.xDelta = raw.value;
        else if (raw.code == 0x01) // REL_Y
          event.yDelta = raw.value;
        else
          console.log(raw);
        break;
      default:
        console.log(raw);
    }
    dev.pendingEvent = event;
    return undefined;
  }

  InputDevice.call(this, dev, 16, 'r', parseMouse);
}
Mouse.prototype = Object.create(InputDevice.prototype, {
  constructor: {value: Mouse}
});

function Typewriter(keyboard, mouse) {

  var HALF_SPACE = 59;
  var FULL_SPACE = 118;
  var SMALL_ROLL = 90; // One line is 2 or 3 small rolls, depending on line spacing
  var STABLE_AFTER_KEYUP_TIME = 150;
  var tt = this;
  var delta = {x: 0, y: 0};
  var stableYTimeout;
  function stableX() {
    tt.x += Math.round(delta.x / HALF_SPACE) * 0.5;
    if (tt.x < 0) {
      var d = -Math.ceil(tt.x);
      console.log('Shifting everything to the right by ' + d);
      var spaces = Array(d);
      _(tt.chars).each(function (l) { if (l) { Array.prototype.unshift.apply(l, spaces); } });
      tt.x += d;
    }
    delta.x = 0;
    console.log('Moved cursor horizontally to ' + tt.x + ',' + tt.y);
  }
  function stableY() {
    console.log('delta.y: ' + delta.y);
    var d = Math.round(delta.y / SMALL_ROLL);
    tt.y += d;
    if (tt.y < 0) {
      var d = -tt.y;
      console.log('Shifting everything to the right by ' + d);
      while (d--)
        tt.chars.unshift([]);
      tt.y = 0;
    }
    delta.y = 0;
    if (d)
      console.log('Moved cursor vertically ' + d + ' lines to ' + tt.x + ',' + tt.y);
  }

  function keypress(event) {
    if (event.value == 0) {
      // Key up: platen should be stable
      setTimeout(stableX, STABLE_AFTER_KEYUP_TIME);
    }
    if (event.value == 1) {
      stableY();
      stableX(); // XXX Is this true? The half tick might race to keydown..
      if (tt.x != Math.ceil(tt.x)) {
        console.log('Adjusting half step from ' + tt.x + ' to ' + Math.ceil(tt.x));
        tt.x = Math.ceil(tt.x);
      }
      if (!(tt.y in tt.chars))
        tt.chars[tt.y] = [];
      tt.chars[tt.y][tt.x] = event.char;
      //tt.x++; // XXX
      //for (i = 0; i < tt.y; i++)
      //  if (typeof tt.chars[i] === 'undefined')
      //    tt.chars[i] = [];
      //for (i = 0; i < tt.x; i++)
      //  if (typeof tt.chars[tt.y][i] === 'undefined')
      //    tt.chars[tt.y][i] = ' ';

      var lines = _(tt.chars).map(function (x) { return _(x || []).map(function (c) { return c || ' '; }).join(''); }).value();
      // For each empty line, remove two consecutive empty lines.
      var i, j;
      for (i = 0; i < lines.length; i++)
        for (j = 0; j < 3; j++)
          if (!lines[i])
            lines.splice(i, 1);
      tt.text = _(lines).join('\n');
      var event = { type: 'changed', text: tt.text };
      tt.emit(event.type, event);
    }
  }
  function stop() {
    console.log(delta);
    delta = {x: 0, y: 0};
  }
  function platen(event) {
    delta.x -= event.yDelta; // Remap: x = -y
    delta.y += event.xDelta;
    clearTimeout(stableYTimeout);
    stableYTimeout = setTimeout(stableY, 50);
  }
  this.keyboard = keyboard;
  this.mouse = mouse;
  this.x = 0;
  this.y = 0;
  this.chars = [[]];
  this.text = '';
  this.keyboard.on('key', keypress);
  this.mouse.on('moved', platen);
}

Typewriter.prototype = Object.create(EventEmitter.prototype, {
  constructor: {value: Typewriter}
});


function MouseHistogram(mouse) {
  var delta = {x: 0, y: 0};
  var stopTimeout;
  function stop() {
      this[delta.y] = (this[delta.y] || 0) + 1;
  }
  mouse.on('moved', function (event) {
    delta.x -= event.yDelta; // Remap: x = -y
    delta.y += event.xDelta;
    clearTimeout(stopTimeout);
    stopTimeout = setTimeout(stop, 100);
  });
}

function MouseCalibrator(mouse) {
  var xabs = {min: Number.MAX_VALUE, max: Number.MIN_VALUE, cur: 0};
  mouse.on('moved', function (event) {
    xabs.cur -= event.yDelta;
    xabs.min = Math.min(xabs.min, xabs.cur);
    xabs.max = Math.max(xabs.max, xabs.cur);
    xabs.span = xabs.max - xabs.min;
    xabs.percentage = Math.round((xabs.cur - xabs.min)/xabs.span * 10000) / 100;
    console.log(xabs);
  });
}

module.exports.Mouse = Mouse
module.exports.Keyboard = Keyboard
module.exports.Typewriter = Typewriter
