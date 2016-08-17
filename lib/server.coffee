nconf = require 'nconf'
raven = require 'raven'
kurento = require 'kurento-client'
ws = require 'ws'


nconf.argv().defaults {
  host: 'localhost'
  port: 8888
  path: '/chat'
  auth:
    me: 'http://unix:/tmp/altexo-accounts.sock:/users/auth/me/'
  sentry:
    url: 'https://cdaedca4cea24fd19d2a9e66d0ef7b18:346c4bb4e8c24f0883e10df1f6a86aa0@sentry.altexo.com/4'
  kurento:
    url: 'ws://localhost:8080/kurento'
    options:
      # access_token: 'weanOshEtph7'
      failAfter: 1
      strict: true
}


sentryClient = null
if nconf.get('sentry:url')
  sentryClient = new raven.Client(nconf.get('sentry:url'))
  sentryClient.patchGlobal (isLogged, error) ->
    console.log 'error:', error.message
    console.log 'error: sentry report', \
      (if isLogged then 'sent' else 'not sent')
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
  console.log 'server: started at',
    "#{nconf.get 'host'}:#{nconf.get 'port'}"

.catch (error) ->
  console.log 'error:', error.message

