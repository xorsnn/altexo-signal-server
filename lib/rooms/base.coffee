EventEmitter = (require 'events').EventEmitter


class BaseRoom extends EventEmitter

  name: null
  creator: null
  members: null

  constructor: (name) ->
    this.name = name
    this.members = new Set()
    super()

  open: (user) ->
    throw new Error('abstract base method')

  close: ->
    throw new Error('abstract base method')

  addUser: (user) ->
    throw new Error('abstract base method')

  removeUser: (user) ->
    throw new Error('abstract base method')

  processIceCandidate: (user, candidate) ->
    throw new Error('abstract base method')

  processOffer: (user, offerSdp) ->
    throw new Error('abstract base method')


module.exports = BaseRoom
