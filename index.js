const di = require('./lib/di');

require('coffee-script/register');

// require paths are relative to di module
['config', 'logger', 'sentry', 'server']
.forEach(module => {
  di.providePath(module, './'+module+'.coffee');
});

di.providePath({
  KurentoRoom: './rooms/kurento.coffee',
  P2pRoom: './rooms/p2p.coffee',
  ChatRpc: './chat.coffee',
  kurentoClient: './kurento.coffee',
});

di.resolve('sentry');
di.resolve('server').start();
