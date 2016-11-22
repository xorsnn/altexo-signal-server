bunyan = require 'bunyan'
nconf = require 'nconf'

streams = nconf.get('logger:streams').map (out) ->
  switch out.stream
    when 'stdout'
      Object.assign({}, out, { stream: process.stdout })
    when 'stderr'
      Object.assign({}, out, { stream: process.stderr })
    else
      Object.assign({}, out)

module.exports = bunyan.createLogger {
  name: nconf.get('logger:name')
  streams: streams
}
