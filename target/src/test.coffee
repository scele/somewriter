should = require('should')
_ = require('lodash')
fs = require('fs')
{EventEmitter} = require('events')
testModule = require('./typewriter')
Typewriter = testModule.Typewriter

#log = console.log
log = ->

logAndRet = (args..., next) ->
  log args...
  next

replay = (desc) ->
  mockKeyboard = new EventEmitter
  mockMouse = new EventEmitter
  timeouts = []
  lastEvent = null

  timeoutProvider =
    set: (callback, ms, args...) ->
      log 'setTimeout called with ' + ms
      timeouts.push timeout =
        key: {}
        callback: callback
        args: args
        time: (lastEvent?.time or 0) + ms
      timeouts.sort (a,b) -> a.time < b.time
      return timeout.key
    clear: (key) ->
      log 'clearTimeout called with ' + key
      timeouts = (t for t in timeouts when t.key isnt key)

  runTimeouts = (timeouts) ->
    logAndRet t, t.callback(t.args...) for t in timeouts
  split = (list, fn) -> [_.head(list, fn), _.tail(list, fn)]

  typewriter = new Typewriter(timeoutProvider)
  typewriter.setKeyboard mockKeyboard
  typewriter.setMouse mockMouse

  processEvent = (event) ->
    # Run expired timeouts
    [expired, timeouts] = split timeouts, (t) -> t.time < event.time
    runTimeouts expired
    # Emit the event to Typewriter
    eventMap =
      key: mockKeyboard
      moved: mockMouse
    eventMap[event.type].emit(event.type, event)
    lastEvent = event

  processEvent e for e in desc.events
  runTimeouts timeouts

  typewriter.text

if (process.argv.length >= 3 && process.argv[1] == __filename)
  run = (f) ->
    test = JSON.parse fs.readFileSync f
    console.log "Actual:"
    console.log replay test
    console.log "Expected:"
    console.log test.output
  run f for f in process.argv[2..]
else
  dir = __dirname + '/../tests/'
  run = (f) ->
    describe f, ->
      this.timeout 10000
      it 'output should match', ->
        test = require dir + f
        replay(test).should.equal(test.output)
  run f for f in fs.readdirSync(dir) when f[0] isnt '.'
