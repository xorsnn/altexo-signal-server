BaseRoom = require './base.coffee'


class P2PRoom extends BaseRoom

  RoomError = {
    ONLY_TWO_PERSONS_ALLOWED: 2001
  }

  _peer: null

  getProfile: ->
    Object.assign({ p2p: true }, super())

  create: (user) ->
    console.log '>> create p2p room'

    this.creator = user
    this.addUser(user)

  destroy: ->
    console.log '>> destroy p2p room'

    this.emit('destroy')

    Promise.resolve(true)

  addUser: (user) ->
    this._addUser(user).then =>
      this.emit('user:enter', user)

  _addUser: (user) ->
    if this.members.size > 1
      console.log '>> forbid user enter'
      return Promise.reject {
        code: RoomError.ONLY_TWO_PERSONS_ALLOWED
        message: 'only two persons allowed'
      }
    console.log '>> add p2p user', user.id
    this.members.add(user)
    unless user is this.creator
      this._peer = user
    return Promise.resolve(true)

  removeUser: (user) ->
    this._removeUser(user).then =>
      this.emit('user:leave', user)

  _removeUser: (user) ->
    unless this.members.has(user)
      throw new Error('cannot remove not existing user')
    console.log '>> remove p2p user', user.id
    this.members.delete(user)
    if user is this._peer
      this._peer = null
    return Promise.resolve(true)

  processIceCandidate: (user, candidate) ->
    if user is this.creator
      this._peer.sendCandidate(candidate)
    else
      this.creator.sendCandidate(candidate)
    return

  processOffer: (user, offerSdp) ->
    this.creator.sendOffer(offerSdp)


module.exports = P2PRoom
