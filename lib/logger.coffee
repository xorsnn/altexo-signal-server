bunyan = require 'bunyan'
nconf = require 'nconf'

try
  PrettyStream = require 'bunyan-pretty-stream'
catch e
  PrettyStream = ->
    console.log 'warning: bunyan-pretty-stream is not installed'
    process.stdout


streams = nconf.get('logger:streams').map (out) ->
  switch out.stream
    when 'pretty'
      Object.assign({}, out, { stream: new PrettyStream() })
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
