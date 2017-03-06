ws = require 'ws'

module.exports = (ChatRpc, config, logger, sentry) -> {
  start: ->
    serverOptions = {
      host: config.get('host')
      port: config.get('port')
      path: config.get('path')
      ssl_key: '/etc/ssl/altexo.com/altexo.com.key',
      ssl_cert: '/etc/ssl/altexo.com/altexo.com.crt'
    }
    server = ws.Server serverOptions, ->
      url = "wss://#{config.get 'host'}:#{config.get 'port'}#{config.get 'path'}"
      logger.info("server started at #{url}")

    if sentry
      server.on 'error', (error) ->
        sentry.captureException(error)

    server.on 'connection', (ws) ->
      handler = new ChatRpc()
      handler.attach(ws)
      ws.on 'close', ->
        logger.info({ id: handler.id }, 'client disconnected')
        handler.detach()
      logger.info({
        id: handler.id
        ip: handler.remoteAddr
        ua: handler.userAgent
      }, 'client connected')

    return server
}
