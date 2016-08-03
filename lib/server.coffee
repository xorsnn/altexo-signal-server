ws = require 'ws'
nconf = require 'nconf'


nconf.argv().defaults {
  host: 'localhost'
  port: 8888
  path: '/chat'
  authUrl: 'http://unix:/tmp/altexo-accounts.sock:/users/auth/me/'
}

serverOptions = {
  host: nconf.get('host')
  port: nconf.get('port')
  path: nconf.get('path')
}

wss = ws.Server serverOptions, ->
  console.log 'server started at', \
    "#{nconf.get 'host'}:#{nconf.get 'port'}"

require('./chat.coffee')(wss)
