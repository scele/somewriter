getTweetText = (text, y) ->
  # Take previous lines until we hit three consecutive empty lines.
  tweet = ''
  tweetLines = []
  lines = text.split '\n'
  emptyLines = Math.max(0, y - lines.length + 1)
  i = y - emptyLines
  while i >= 0 && emptyLines < 3
    line = lines[i].trim()
    if line.length
      tweetLines.unshift line
      emptyLines = 0
    else
      ++emptyLines
    i--
  return tweetLines.join '\n'

module.exports.getTweetText = getTweetText
