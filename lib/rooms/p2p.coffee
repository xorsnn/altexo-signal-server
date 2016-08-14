BaseRoom = require './base.coffee'


class P2PRoom extends BaseRoom

  RoomError = {
    ONLY_TWO_PERSONS_ALLOWED: 2001
  }

  _peer: null

  open: (user) ->
    console.log '>> open p2p room'

    this.creator = user
    this.addUser(user)

  close: ->
    console.log '>> close p2p room'

    this.emit('close')
    return Promise.resolve(true)

  addUser: (user) ->
    this._addUser(user).then =>
      this.emit('user:enter', user)
      return true

  _addUser: (user) ->
    if this.members.size > 1
      console.log '>> forbid user enter'
      return Promise.reject {
        code: RoomError.ONLY_TWO_PERSONS_ALLOWED
        message: 'only two persons allowed'
      }
    console.log '>> add p2p user', user.id
    this.members.add(user)
    if user is not this.creator
      this._peer = user
    return Promise.resolve(true)

  removeUser: (user) ->
    this._removeUser(user).then =>
      this.emit('user:leave', user)
      return true

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
