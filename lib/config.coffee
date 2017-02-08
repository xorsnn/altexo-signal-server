nconf = require 'nconf'

nconf.argv()
nconf.file(config) if (config = nconf.get('config'))

module.exports = ->
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
