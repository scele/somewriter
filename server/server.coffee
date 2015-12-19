
path = require('path')
fs = require('fs')
express = require('express')

# Server part
app = express()
app.use('/', express.static(path.join(__dirname, '..')))

port = 8080
server = app.listen(port)
console.log('Server listening on port ' + port)

# Socket.IO part
io = require('socket.io')(server)

status = [
  { text: 'Connected', ok: true },
  { text: 'Keyboard not connected', ok: false },
  { text: 'Mouse not connected', ok: false },
]

sendStatus = (socket) ->
  socket.emit('status', status)


sendComments = (socket) ->
  fs.readFile '_comments.json', 'utf8', (err, comments) ->
    if !err
      comments = JSON.parse(comments)
      socket.emit('comments', comments)

io.on 'connection', (socket) ->
  console.log('New client connected!')

  socket.on 'fetchStatus', () ->
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
  status[0].ok = true
  sendStatus

