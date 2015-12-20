
path = require('path')
fs = require('fs')
express = require('express')

extend = (object, properties) ->
  for key, val of properties
    object[key] = val
  object

# Server part
app = express()
app.use('/', express.static(path.join(__dirname, '..')))

port = 8080
server = app.listen(port)
console.log('Server listening on port ' + port)

# Socket.IO part
io = require('socket.io')(server)

disconnected = {
  connected: false,
  keyboard: false,
  mouse: false,
  x: 0,
  y: 0,
}

status = extend {}, disconnected
config = {}
text = ''

sendStatus = (socket) ->
  console.log(status)
  socket.emit('status', status)

sendText = (socket) ->
  socket.emit('text', text)

sendConfig = (socket) ->
  socket.emit('config', config)
  ttio.emit('config', config)

try
  configStr = fs.readFileSync 'config.json', 'utf8'
  config = JSON.parse(configStr)
catch

io.on 'connection', (socket) ->
  console.log('New client connected!')

  sendStatus(socket)
  sendConfig(socket)
  sendText(socket)

  socket.on 'updateConfig', (newConfig, callback) ->
    console.log newConfig
    config = newConfig
    sendConfig(io)
    sendConfig(ttio)
    fs.writeFile 'config.json', JSON.stringify(config, null, 4)

# Typewriter connection
ttio = require('socket.io')(8081)

ttio.on 'connection', (socket) ->
  console.log('Typewriter connected!')
  status.connected = true
  sendStatus(io)
  sendConfig(ttio)

  socket.on 'disconnect', () ->
    console.log('Typewriter disconnected')
    status = extend {}, disconnected
    sendStatus(io)

  socket.on 'status', (newStatus) ->
    console.log('Typewriter updated status')
    console.log(newStatus)
    extend status, newStatus
    sendStatus(io)

  socket.on 'text', (newText) ->
    text = newText
    console.log('Typewriter sent new text: ' + text)
    sendText(io)