const di = require('./lib/di');

require('coffee-script/register');

// require paths are relative to di module
['config', 'logger', 'sentry', 'server']
.forEach(module => {
  di.providePath(module, './'+module+'.coffee');
});

di.providePath({
  ChatRpc: './chat.coffee',
  KurentoService: './kurento.coffee',
  KurentoRoom: './rooms/kurento.coffee',
  P2pRoom: './rooms/p2p.coffee',
});

di.resolve('sentry');
di.resolve('server').start();
