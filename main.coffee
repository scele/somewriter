{Mouse, Keyboard, Typewriter} = require('./mouse.js')

mouse = new Mouse('/dev/input/event0')

# histogram = new MouseHistogram(mouse)
# setInterval(console.log, 5000, histogram)

# calibrator = new MouseCalibrator(mouse)

keyboard = new Keyboard('/dev/input/event1')
# keyboard.on('key', console.log)

typewriter = new Typewriter(keyboard, mouse)
typewriter.on('changed', (event) -> console.log(event.text))

# Blinking leds
setTimeout(->
  keyboard.led(0, 0)
  keyboard.led(1, 0)
  keyboard.led(2, 0)
  currentLed = 2
  blink = ->
    keyboard.led(currentLed, 0)
    currentLed = (currentLed + 1) % 6
    keyboard.led(currentLed, 1)
  setInterval(blink, 200)
, 500)


