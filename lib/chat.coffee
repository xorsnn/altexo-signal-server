request = require 'request'
nconf = require 'nconf'

Registry = require './registry.coffee'
JsonRpc = require './utils/json-rpc.coffee'


module.exports = (server, kurentoClient) ->

  KurentoRoom = (require './rooms/kurento.coffee')(kurentoClient)
  P2PRoom = require './rooms/p2p.coffee'


  class ChatRpc extends JsonRpc

    registry = new Registry()
    rooms = new Map()

    ChatError = {
      NOT_AUTHENTICATED:
        { code: 1001, message: 'not authenticated' }
      PEER_NOT_FOUND:
        { code: 1002, message: 'peer is not found'}
      ROOM_NOT_FOUND:
        { code: 1003, message: 'room is not found' }
      CURRENT_ROOM_PRESENT:
        { code: 1004, message: 'current room is already present' }
      NO_CURRENT_ROOM:
        { code: 1005, message: 'no current room' }
      ROOM_NAME_OCCUPIED:
        { code: 1006, message: 'room name occupied' }
      NOT_AUTHORIZED:
        { code: 1007, message: 'not authorized' }
      REQUEST_AUTH_ERROR: \
        (e) -> { code: -32000, message: "#{e.toString()}" }
      RAW_ERROR: \
        (e) -> { code: -32001, message: "#{e.message}" }
    }

    _truthy = (promisable) ->
      promisable.then -> true

    id: null
    isAuthenticated: false
    room: null

    onAttach: ->
      this.id = registry.add(this)

    onDetach: ->
      if this.room
        this._leaveRoom()

      registry.remove(this.id)
      this.id = null

    sendCandidate: (candidate) ->
      this.notify('ice-candidate', [candidate])

    sendOffer: (offerSdp) ->
      this.request('offer', [offerSdp])

    rpc: {
      'authenticate': (token) ->
        auth = new Promise (resolve, reject) ->
          authRequest = {
            url: nconf.get('auth:me')
            headers: {
              'Authorization': "Token #{token}"
              # NOTE: needed to turn off debug mode in django
              'Host': 'localhost'
            }
          }
          request authRequest, (error, response, body) ->
            if error
              return reject(ChatError.REQUEST_AUTH_ERROR(error))
            unless response.statusCode == 200
              return reject(ChatError.NOT_AUTHENTICATED)
            resolve(true)
        return auth.then => this.isAuthenticated = true

      'room/open': (name, p2p) ->
        unless this.isAuthenticated
          return Promise.reject(ChatError.NOT_AUTHENTICATED)

        if this.room
          return Promise.reject(ChatError.CURRENT_ROOM_PRESENT)

        if rooms.has(name)
          return Promise.reject(ChatError.ROOM_NAME_OCCUPIED)

        unless p2p
          room = new KurentoRoom(name)
        else
          room = new P2PRoom(name)

        rooms.set(name, room)

        _truthy(room.open(this).then =>
          this.room = rooms.set(name, room).get(name))
        .then null, ChatError.RAW_ERROR

      'room/close': ->
        unless this.room
          return Promise.reject(ChatError.NO_CURRENT_ROOM)

        unless this is this.room.creator
          return Promise.reject(ChatError.NOT_AUTHORIZED)

        room = this.room
        this.room = null

        rooms.delete(room.name)
        _truthy(room.close())
        .then null, ChatError.RAW_ERROR

      'room/enter': (name) ->
        if this.room
          return Promise.reject(ChatError.CURRENT_ROOM_PRESENT)

        unless rooms.has(name)
          return Promise.reject(ChatError.ROOM_NOT_FOUND)

        room = rooms.get(name)

        _truthy(room.addUser(this).then => this.room = room)
        .then null, ChatError.RAW_ERROR

      'room/leave': ->
        unless this.room
          return Promise.reject(ChatError.NO_CURRENT_ROOM)

        _truthy(this._leaveRoom())
        .then null, ChatError.RAW_ERROR

      'room/offer': (offerSdp) ->
        unless this.room
          return Promise.reject(ChatError.NO_CURRENT_ROOM)

        this.room.processOffer(this, offerSdp)
        .then null, ChatError.RAW_ERROR
    }

    rpcNotify: {
      'room/ice-candidate': (candidate) ->
        unless this.room
          return
        this.room.processIceCandidate(this, candidate)
    }

    notifyPeer: (id, method, params) ->
      peer = registry.getPeer(id)
      unless peer
        return
      peer.notify(method, params)

    requestPeer: (id, method, params) ->
      peer = registry.getPeer(id)
      unless peer
        return Promise.reject(ChatError.PEER_NOT_FOUND)
      peer.request(method, params)

    _leaveRoom: ->
      room = this.room
      this.room = null
      if this is room.creator
        rooms.delete(room.name)
        return room.close()
      return room.removeUser(this)


  server.on 'connection', (ws) ->

    handler = new ChatRpc()
    handler.attach(ws)

    console.log '>> client connected', handler.id

    ws.on 'close', ->
      console.log '>> client disconnected', handler.id

      handler.detach()
