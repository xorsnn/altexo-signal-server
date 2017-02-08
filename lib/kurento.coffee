kurento = require 'kurento-client'

module.exports = (config, logger) -> {
  connect: ->
    logger.trace('kurento: get instance')
    kurento(config.get('kurento:url'), config.get('kurento:options'))
    .then (kurentoClient) ->
      logger.trace('kurento: instance connection established')
      return kurentoClient
}
