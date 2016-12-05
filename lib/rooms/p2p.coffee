BaseRoom = require './base.coffee'


class P2PRoom extends BaseRoom

  RoomError = {
    ONLY_TWO_PERSONS_ALLOWED: 2001
  }

  _peer: null

  getProfile: ->
    Object.assign({ p2p: true }, super())

  create: (user) ->
    this.creator = user
    this.addUser(user)

  destroy: ->
    this.emit('destroy')

    Promise.resolve(true)

  addUser: (user) ->
    this._addUser(user).then =>
      this.emit('user:enter', user)

  _addUser: (user) ->
    if this.members.size > 1
      return Promise.reject {
        code: RoomError.ONLY_TWO_PERSONS_ALLOWED
        message: 'only two persons allowed'
      }
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

  restartPeer: (sender) ->
    if sender is this.creator
      return this._peer.sendRestart()
    return this.creator.sendRestart()


module.exports = P2PRoom
