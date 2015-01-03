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
        break;
      case 0x04: // EV_MSC
        if (raw.code == 0x04)
          event.scancode = raw.value;
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



/****************
 * Sample Usage *
 ****************/

// read all mouse events from /dev/input/mice
var mouse = new Mouse('/dev/input/mice');
mouse.on('button', console.log);
mouse.on('moved', console.log);

var keyboard = new Keyboard('/dev/input/event1');
keyboard.on('key', console.log);

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
