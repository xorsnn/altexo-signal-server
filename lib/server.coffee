ws = require 'ws'

module.exports = (ChatRpc, config, logger, sentry) -> {
  start: ->
    {host, port, path} = config.get()

    server = ws.Server {host, port, path}, ->
      logger.info """
                    server started at ws://#{host}:#{port}#{path}
                  """

    server.on 'connection', (ws) ->
      handler = new ChatRpc()
      handler.attach(ws)
      ws.on 'close', ->
        logger.info({ id: handler.id }, 'client disconnected')
        handler.detach()

      ws.on 'ping', (arg, arg2) ->
        logger.debug '>> PING RECEIVED', arg, arg2
      ws.on 'pong', (arg, arg2) ->
        logger.debug '>> PONG RECEIVED', arg, arg2

      timeoutID = null
      _sendPing = ->
        timeoutID = null
        logger.debug '>> SEND PING', '***'
        ws.ping()
      timeoutID = setTimeout(_sendPing, 42*1000)
      ws.on 'close', ->
        clearTimeout(timeoutID) unless timeoutID == null

      logger.info({
        id: handler.id
        ip: handler.remoteAddr
        ua: handler.userAgent
      }, 'client connected')

    if sentry
      server.on 'error', (error) ->
        sentry.captureException(error)

    return server
}
