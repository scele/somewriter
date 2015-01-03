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
      type: buffer.readUInt16LE(8),
      code: buffer.readUInt16LE(10),
      value: buffer.readInt32LE(12)
    };
    var event = dev.pendingEvent || {};
    switch (raw.type) {
      case 0x00: // EV_SYN
        dev.pendingEvent = undefined;
        return event;
      case 0x01: // EV_KEY
        event.type = 'key';
        event.code = raw.code;
        event.value = raw.value;
        event.char = codeMap[raw.code];
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
  // Parse PS/2 mouse protocol
  // According to http://www.computer-engineering.org/ps2mouse/
  function parseMouse(dev, buffer) {
    var event = {
      leftBtn:    (buffer[0] & 1  ) > 0, // Bit 0
      rightBtn:   (buffer[0] & 2  ) > 0, // Bit 1
      middleBtn:  (buffer[0] & 4  ) > 0, // Bit 2
      xSign:      (buffer[0] & 16 ) > 0, // Bit 4
      ySign:      (buffer[0] & 32 ) > 0, // Bit 5
      xOverflow:  (buffer[0] & 64 ) > 0, // Bit 6
      yOverflow:  (buffer[0] & 128) > 0, // Bit 7
      xDelta:      buffer.readInt8(1),   // Byte 2 as signed int
      yDelta:      buffer.readInt8(2)    // Byte 3 as signed int
    };
    if (event.leftBtn || event.rightBtn || event.middleBtn) {
      event.type = 'button';
    } else {
      event.type = 'moved';
    }
    return event;
  }
  InputDevice.call(this, dev, 16, 'r', parseMouse);
}
Mouse.prototype = Object.create(InputDevice.prototype, {
  constructor: {value: Mouse}
});

function Typewriter(keyboard, mouse) {

  var tt = this;
  var delta = {x: 0, y: 0};
  var xabs = {min: Number.MAX_VALUE, max: Number.MIN_VALUE, cur: 0};
  var stopTimeout, calibrateInterval;
  function keypress(event) {
    if (event.value == 1) {
      tt.chars[tt.y][tt.x] = event.char;
      tt.x++; // XXX
      var text = _(tt.chars).map(function (x) { return x.join(''); }).join('\n');
      var event = { type: 'changed', text: text };
      tt.emit(event.type, event);
    }
  }
  function stop() {
    console.log(delta);
    delta = {x: 0, y: 0};
    clearInterval(calibrateInterval);
    calibrateInterval = undefined;
  }
  function platen(event) {
    delta.x -= event.yDelta; // Remap: x = -y
    delta.y += event.xDelta;
    xabs.cur -= event.yDelta;
    xabs.min = Math.min(xabs.min, xabs.cur);
    xabs.max = Math.max(xabs.max, xabs.cur);
    xabs.span = xabs.max - xabs.min;
    xabs.percentage = Math.round((xabs.cur - xabs.min)/xabs.span * 10000) / 100;
    if (!calibrateInterval)
      calibrateInterval = setInterval(console.log, 50, xabs);
    clearTimeout(stopTimeout);
    stopTimeout = setTimeout(stop, 100);
  }
  this.keyboard = keyboard;
  this.mouse = mouse;
  this.x = 0;
  this.y = 0;
  this.chars = [[]];
  this.keyboard.on('key', keypress);
  this.mouse.on('moved', platen);
}

Typewriter.prototype = Object.create(EventEmitter.prototype, {
  constructor: {value: Typewriter}
});



/****************
 * Sample Usage *
 ****************/

// read all mouse events from /dev/input/mice
var mouse = new Mouse('/dev/input/mice');
//mouse.on('button', console.log);
//mouse.on('moved', console.log);

var keyboard = new Keyboard('/dev/input/event1');
//keyboard.on('key', console.log);

var typewriter = new Typewriter(keyboard, mouse);
typewriter.on('changed', console.log);

// Blinking leds demo
setTimeout(function () {
  keyboard.led(0, 0);
  keyboard.led(1, 0);
  keyboard.led(2, 0);
  var currentLed = 2;
  function blink() {
    keyboard.led(currentLed, 0);
    currentLed = (currentLed + 1) % 6;
    keyboard.led(currentLed, 1);
  }
  var blinking = setInterval(blink, 200);
}, 500);
