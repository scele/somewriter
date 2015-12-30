{Typewriter} = require('./typewriter')
{Mouse, Keyboard} = require('./input')
udev = require('udev')
io = require('socket.io-client')
fs = require('fs')
gpio = require("pi-gpio")
exec = require('child_process').exec

os = require('os')
ifaces = os.networkInterfaces()
console.log(ifaces)
ipv4 = (iface) -> 'IPv4' == iface.family && !iface.internal
ips = (({iface: ifname, address: i.address} for i in ii when ipv4(i)) for ifname, ii of ifaces)
ips = [].concat.apply([], ips)
console.log(ips)

# histogram = new MouseHistogram(mouse)
# setInterval(console.log, 5000, histogram)

# calibrator = new MouseCalibrator(mouse)

# keyboard.on('key', console.log)

# Pins 5 (wake-up) and 7 (GPIO4) are connected to 6 (GND) when power is on.
# Pin 5 cannot be read by pi-gpio, it's only used for wake-up as per http://elinux.org/RPI_safe_mode
# Here we poll pin 7 to detect user's poweroff signal (use internal pullup resistor).
# Pin layout: http://pinout.xyz/
pin = 7
halted = false

pollReset = ->
  gpio.read pin, (error, value) ->
    if error
      console.log error
      return
    if value == 1 && !halted
      socket.emit 'halt'
      console.log 'Detected poweroff signal...'
      exec(__dirname + '/../halt.sh')
      halted = true

gpio.close pin, ->
  gpio.open pin, "input pullup", (error) ->
    if error
      console.log(error)
      return
    setInterval pollReset, 300

keyboard = 0
mouse = 0

logIndex = 1
logEvents = []
logEvent = (event) ->
  logEvents.push(event)

flushLog = ->
  log = { output: status.text, events: logEvents }
  filename = __dirname + '/../log/trace' + logIndex + '.json'
  fs.writeFileSync filename, JSON.stringify(log, null, 4)
  console.log('Wrote log to ' + filename)
  logEvents = []
  logIndex++

initTypewriter = (k, m) ->
  keyboard.close() if keyboard
  keyboard = new Keyboard k
  typewriter.setKeyboard keyboard
  keyboard.on 'key', logEvent
  keyboard.led(0, 1)
  keyboard.led(1, 1)
  keyboard.led(2, 1)

  mouse.close() if mouse
  mouse = new Mouse m
  typewriter.setMouse mouse
  mouse.on 'moved', logEvent

## Blinking leds
#setTimeout(->
#  keyboard.led(0, 0)
#  keyboard.led(1, 0)
#  keyboard.led(2, 0)
#  currentLed = 2
#  blink = ->
#    keyboard.led(currentLed, 0)
#    currentLed = (currentLed + 1) % 6
#    keyboard.led(currentLed, 1)
#  setInterval(blink, 200)
#, 500)

isMouse = (m) -> m.ID_INPUT_MOUSE and m.DEVNAME?.match /event\d+$/
isKeyboard = (k) -> k.ID_INPUT_KEYBOARD and k.DEVNAME?.match /event\d+$/

err = console.log
clearErr = -> console.log "Ok!"

status = {
  mouse: false,
  keyboard: false,
  ip: ips,
  x: 0,
  y: 0,
  text: '',
}

socket = io('http://192.168.0.20:8081')

socket.on 'connect', ->
  sendStatus()

socket.on 'config', (config) ->
  typewriter.ignoreMouse = config.ignoreMouse

socket.on 'resetText', ->
  flushLog()
  typewriter.resetPosition()
  typewriter.resetText()

socket.on 'resetPosition', ->
  flushLog()
  typewriter.resetPosition()
  typewriter.resetText()

sendStatus = ->
  console.log('Sending status:')
  console.log(status)
  socket.emit('status', status)

probe = ->
  console.log "Probing..."
  [m, ...] = (dev for dev in udev.list() when isMouse dev)
  [k, ...] = (dev for dev in udev.list() when isKeyboard dev)
  status.mouse = !!m
  status.keyboard = !!k
  if m and k
    clearErr()
    initTypewriter k.DEVNAME, m.DEVNAME
  else if !m
    err "USB mouse not found"
  else
    err "USB keyboard not found"
  sendStatus()

monitor = udev.monitor()
monitor.on 'add', (dev) ->
  probe() if (isMouse dev) or (isKeyboard dev)

typewriter = new Typewriter
typewriter.on 'changed', (event) ->
  status.text = event.text
  console.log(event.text)
  sendStatus()
typewriter.on 'moved', (event) ->
  status.x = event.x
  status.y = event.y
  sendStatus()
typewriter.on('error', (event) -> probe())
probe()
