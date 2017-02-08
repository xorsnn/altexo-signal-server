raven = require 'raven'

module.exports = (config, logger) ->
  sentryClient = null

  if config.get('sentry:url')
    sentryClient = new raven.Client(config.get('sentry:url'))
    sentryClient.patchGlobal (reported, error) ->
      logger.error({ reported }, error.message)
      process.exit(1)

  return sentryClient
