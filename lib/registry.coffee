uuid = require 'node-uuid'


class Registry

  clients: null

  constructor: ->
    this.clients = new Map()

  add: (handler) ->
    id = uuid.v4()
    this.clients.set(id, handler)
    return id

  remove: (id) ->
    this.clients.delete(id)

  getPeer: (id) ->
    this.clients.get(id)


module.exports = Registry
