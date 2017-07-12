bunyan = require 'bunyan'
try
  PrettyStream = require 'bunyan-pretty-stream'
catch e
  PrettyStream = ->
    console.log 'warning: bunyan-pretty-stream is not installed'
    return process.stdout

module.exports = (config) ->
  streams = config.get('logger:streams').map (out) ->
    switch out.stream
      when 'pretty'
        Object.assign({}, out, { stream: new PrettyStream() })
      when 'stdout'
        Object.assign({}, out, { stream: process.stdout })
      when 'stderr'
        Object.assign({}, out, { stream: process.stderr })
      else
        Object.assign({}, out)

  bunyan.createLogger {
    streams, name: config.get('logger:name')
  }
