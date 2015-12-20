{Typewriter} = require('./typewriter')
{Mouse, Keyboard} = require('./input')
udev = require('udev')
io = require('socket.io-client')

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

initTypewriter = (k, m) ->
  typewriter.setKeyboard new Keyboard k
  typewriter.setMouse new Mouse m

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
}
text = ''

socket = io('http://192.168.0.20:8081')

socket.on 'connect', ->
  sendStatus()
  sendText()

socket.on 'config', (config) ->
  typewriter.ignoreMouse = config.ignoreMouse

sendStatus = ->
  console.log('Sending status:')
  console.log(status)
  socket.emit('status', status)

sendText = ->
  socket.emit 'text', text

probe = ->
  console.log "Probing..."
  [mouse, ...] = (dev for dev in udev.list() when isMouse dev)
  [keyboard, ...] = (dev for dev in udev.list() when isKeyboard dev)
  status.mouse = !!mouse
  status.keyboard = !!keyboard
  if mouse and keyboard
    clearErr()
    initTypewriter keyboard.DEVNAME, mouse.DEVNAME
  else if !mouse
    err "USB mouse not found"
  else
    err "USB keyboard not found"
  sendStatus()

monitor = udev.monitor()
monitor.on 'add', (dev) ->
  probe() if (isMouse dev) or (isKeyboard dev)

typewriter = new Typewriter
typewriter.on 'changed', (event) ->
  text = event.text
  console.log(event.text)
  sendText()
typewriter.on 'moved', (event) ->
  status.x = event.x
  status.y = event.y
  sendStatus()
typewriter.on('error', (event) -> probe())
probe()
