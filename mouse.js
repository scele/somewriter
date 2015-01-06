var fs = require('fs'),
    _ = require('lodash'),
    EventEmitter = require('events').EventEmitter,
    Keyboard = require('./input').Keyboard,
    Mouse = require('./input').Mouse;

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
      console.log("Key up, calling stableX");
      setTimeout(stableX, STABLE_AFTER_KEYUP_TIME);
      //keyLifted = true;
    }
    if (event.value == 1) {
      stableY();
      // Cannot call stableX here, because the half tick that begins
      // a keystroke might race with the keydown signal (and it does).
      // On the other hand, we need to update the x position in case we
      // have been scrolling left and right without typing.
      //stableX();
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

module.exports.Typewriter = Typewriter
