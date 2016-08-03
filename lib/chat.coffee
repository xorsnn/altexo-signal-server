request = require 'request'
nconf = require 'nconf'

Registry = require './registry.coffee'
RoomList = require './room-list.coffee'

JsonRpc = require './utils/json-rpc.coffee'
Q = require './utils/q'


class ChatRpc extends JsonRpc

  registry = new Registry()
  roomList = new RoomList()

  Error = {
    AUTH_SERVICE_BROKEN: -32000
    NOT_AUTHENTICATED: 1001
    PEER_NOT_FOUND: 1002
    ONLY_ONE_ROOM_ALLOWED: 1003
    ROOM_NAME_OCCUPIED: 1004
    ROOM_NOT_FOUND: 1005
  }

  id: null
  isAuthenticated: false
  room: null

  onAttach: ->
    this.id = registry.add(this)

  onDetach: ->
    if this.room
      roomList.leave(this.room.name, this)
      this.room = null

    registry.remove(this.id)
    this.id = null

  rpc: {
    'authenticate': (token) ->
      auth = Q (resolve, reject) ->
        authRequest = {
          url: nconf.get('authUrl')
          headers: { 'Authorization': "Token #{token}" }
        }
        request authRequest, (error, response, body) ->
          if error
            return reject {
              code: Error.AUTH_SERVICE_BROKEN
              message: error.toString()
            }
          unless response.statusCode == 200
            return reject {
              code: Error.NOT_AUTHENTICATED
              message: 'invalid token'
            }
          resolve(true)
      return auth.then => this.isAuthenticated = true

    'create-room': (name) ->
      unless this.isAuthenticated
        return Q.reject {
          code: Error.NOT_AUTHENTICATED
          message: 'not authenticated'
        }

      if this.room
        return Q.reject {
          code: Error.ONLY_ONE_ROOM_ALLOWED
          message: 'user is in other room now'
        }

      if roomList.exists(name)
        return Q.reject {
          code: Error.ROOM_NAME_OCCUPIED
          message: 'room already exists'
        }

      this.room = roomList.create(name, this)
      this.room.on 'close', =>
        this.room = null

      # ok. we have a room
      # - wait for a sdp offer
      # - create kurento pipeline
      # - add webrtc endpoint to the pipeline
      # - exchange ice candidates
      # - ...

      return Q.resolve(true)

    'watch-room': (name) ->
      unless roomList.exists(name)
        return Q.reject {
          code: Error.ROOM_NOT_FOUND
          message: 'room is not found'
        }

      if this.room
        return Q.reject {
          code: Error.ONLY_ONE_ROOM_ALLOWED
          message: 'user is in other room now'
        }

      this.room = roomList.enter(name, this)
      this.room.on 'close', =>
        this.room = null

      # ok. we are in a room
      # - add webrtc endpoint to the pipeline
      # - wait for sdp offer
      # - exchange ice candidates
      # - ...

      return Q.resolve(true)
  }

  notifyPeer: (id, method, params) ->
    peer = registry.getPeer(id)
    unless peer
      return
    peer.notify(method, params)

  requestPeer: (id, method, params) ->
    peer = registry.getPeer(id)
    unless peer
      return Q.reject {
        code: Error.PEER_NOT_FOUND
        message: 'peer is not found'
      }
    peer.request(method, params)


module.exports = (server) ->
  server.on 'connection', (ws) ->

    console.log '>> client connected'

    handler = new ChatRpc()
    handler.attach(ws)

    ws.on 'close', ->
      console.log '>> client disconnected'

      handler.detach()
