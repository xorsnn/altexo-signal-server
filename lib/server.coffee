nconf = require 'nconf'
kurento = require 'kurento-client'
ws = require 'ws'


nconf.argv().defaults {
  host: 'localhost'
  port: 8888
  path: '/chat'
  auth:
    me: 'http://unix:/tmp/altexo-accounts.sock:/users/auth/me/'
  kurento:
    url: 'ws://localhost:8080/kurento'
    options:
      # access_token: 'weanOshEtph7'
      failAfter: 1
      strict: true
}

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

.then ->
  console.log 'server: started at',
    "#{nconf.get 'host'}:#{nconf.get 'port'}"

.catch (error) ->
  console.log 'error:', error.message

