ws = require 'ws'
nconf = require 'nconf'
kurento = require 'kurento-client'


nconf.argv().defaults {
  host: 'localhost'
  port: 8888
  path: '/chat'
  auth:
    me: 'http://unix:/tmp/altexo-accounts.sock:/users/auth/me/'
  kurento:
    url: 'ws://localhost:8080/kurento'
    options:
      failAfter: 5
}

serverOptions = {
  host: nconf.get('host')
  port: nconf.get('port')
  path: nconf.get('path')
}

kurento(nconf.get('kurento:url'), nconf.get('kurento:options'))
.then (kurentoClient) ->
  wss = ws.Server serverOptions, ->
    console.log 'server: started at', \
      "#{nconf.get 'host'}:#{nconf.get 'port'}"

  require('./chat.coffee')(wss, kurentoClient)
.catch (error) ->
  console.log 'kurento:', error.message
