
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

desc = {
  connected: ['Device offline', 'Device online'],
  keyboard: ['Keyboard not connected', 'Keyboard connected'],
  mouse: ['Mouse not connected', 'Mouse connected'],
}

disconnected = {
  connected: false,
  keyboard: false,
  mouse: false,
}

status = extend {}, disconnected


sendStatus = ->
  console.log(status)
  int = (a) -> if a then 1 else 0
  s = ({text: desc[key][int(value)], ok: value} for key, value of status)
  console.log(s)
  io.emit('status', s)

sendText = (text) ->
  io.emit('text', text)


sendComments = (socket) ->
  fs.readFile '_comments.json', 'utf8', (err, comments) ->
    if !err
      comments = JSON.parse(comments)
      socket.emit('comments', comments)

io.on 'connection', (socket) ->
  console.log('New client connected!')

  sendStatus(socket)

  socket.on 'newComment', (comment, callback) ->
    fs.readFile '_comments.json', 'utf8', (err, comments) ->
      comments = JSON.parse(comments)
      comments.push(comment)
      fs.writeFile '_comments.json', JSON.stringify(comments, null, 4), (err) ->
        io.emit('comments', comments)
        callback(err)

# Typewriter connection
ttio = require('socket.io')(8081)

ttio.on 'connection', (socket) ->
  console.log('Typewriter connected!')
  status.connected = true
  sendStatus()

  socket.on 'disconnect', () ->
    console.log('Typewriter disconnected')
    status = extend {}, disconnected
    sendStatus()

  socket.on 'status', (newStatus) ->
    console.log('Typewriter updated status')
    console.log(newStatus)
    extend status, newStatus
    sendStatus()
  socket.on 'text', (text) ->
    console.log('Typewriter sent new text: ' + text)
    sendText text
