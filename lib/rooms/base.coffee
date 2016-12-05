EventEmitter = (require 'events').EventEmitter


class BaseRoom extends EventEmitter

  name: null
  creator: null
  members: null

  constructor: (name) ->
    this.name = name
    this.members = new Set()
    super()

  getProfile: -> {
    creator: this.creator.id
    name: this.name
    contacts: this.getContacts()
  }

  getContacts: ->
    Array.from(this.members).map (user) ->
      user.getContactInfo()

  create: (user) ->
    throw new Error('abstract base method')

  destroy: ->
    throw new Error('abstract base method')

  addUser: (user) ->
    throw new Error('abstract base method')

  removeUser: (user) ->
    throw new Error('abstract base method')

  processIceCandidate: (user, candidate) ->
    throw new Error('abstract base method')

  processOffer: (user, offerSdp) ->
    throw new Error('abstract base method')

  restartPeer: (senderId) ->
    throw new Error('abstract base method')


module.exports = BaseRoom
