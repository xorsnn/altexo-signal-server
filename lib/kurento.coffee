{KurentoClient} = require 'kurento-client'

module.exports = (config) ->
  {url, options} = config.get('kurento')
  KurentoClient.getSingleton(url, options)
