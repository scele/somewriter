
path = require('path')
fs = require('fs')
express = require('express')
Twitter = require('twitter')

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
  text: '',
}

status = extend {}, disconnected
config = {}

sendStatus = (socket) ->
  console.log(status)
  socket.emit('status', status)

sendConfig = (socket) ->
  socket.emit('config', config)
  ttio.emit('config', config)

twitterConfig = JSON.parse(fs.readFileSync path.join(__dirname, 'twitter.json'), 'utf8')
twitter = new Twitter(twitterConfig)
twitter.get 'account/verify_credentials', (err, response, req) ->
  if (!err)
    status.twitter = {}
    status.twitter.widget = twitterConfig.widget

try
  configStr = fs.readFileSync 'config.json', 'utf8'
  config = JSON.parse(configStr)
catch

io.on 'connection', (socket) ->
  console.log('New client connected!')

  sendStatus(socket)
  sendConfig(socket)

  socket.on 'updateConfig', (newConfig, callback) ->
    console.log newConfig
    config = newConfig
    sendConfig(io)
    sendConfig(ttio)
    fs.writeFile 'config.json', JSON.stringify(config, null, 4)

  socket.on 'tweet', (tweet) ->
    twitter.post 'statuses/update', {status: tweet}, (error, tweet, response) ->
      console.log(tweet)
      ttio.emit('resetText')

  socket.on 'resetText', ->
    ttio.emit('resetText')

  socket.on 'resetPosition', ->
    ttio.emit('resetPosition')

# Typewriter connection
ttio = require('socket.io')(8081, {
  pingTimeout: 2000,
  pingInterval: 800,
})

ttio.on 'connection', (socket) ->
  console.log('Typewriter connected!')

  status.connected = true
  sendConfig(ttio)

  socket.on 'disconnect', () ->
    console.log('Typewriter disconnected')
    status.connected = false
    sendStatus(io)

  socket.on 'status', (newStatus) ->
    console.log('Typewriter updated status')
    console.log(newStatus)
    extend status, newStatus
    sendStatus(io)
