nconf = require 'nconf'
raven = require 'raven'
kurento = require 'kurento-client'
ws = require 'ws'

nconf.argv()
nconf.file(config) if (config = nconf.get('config'))
nconf.defaults {
  host: 'localhost'
  port: 8080
  path: '/al_chat'
  auth:
    me: 'http://unix:/tmp/altexo-accounts.sock:/users/auth/me/'
  sentry:
    url: false
  logger:
    name: 'altexo-signal'
    streams: [{ level: 'trace', stream: 'pretty' }]
  kurento:
    url: 'ws://127.0.0.1:8888/kurento'
    options:
      # access_token: 'weanOshEtph7'
      failAfter: 1
      strict: true
  setup: {}
}


# NOTE: logger must not be required until nconf is set up
logger = require './logger'


sentryClient = null
if nconf.get('sentry:url')
  sentryClient = new raven.Client(nconf.get('sentry:url'))
  sentryClient.patchGlobal (reported, error) ->
    logger.error({ reported }, error.message)
    process.exit(1)


kurento(nconf.get('kurento:url'), nconf.get('kurento:options'))
.then (kurentoClient) ->

  return new Promise (resolve) ->
    serverOptions = {
      host: nconf.get('host')
      port: nconf.get('port')
      path: nconf.get('path')
    }

    wss = ws.Server(serverOptions, resolve)

    require('./chat.coffee')(wss, kurentoClient)

    if sentryClient
      wss.on 'error', (error) ->
        sentryClient.captureException(error)

.then ->
  logger.info({ port: nconf.get('port'), host: nconf.get('host') }, 'server started')

.catch (error) ->
  logger.error(error.message) 
