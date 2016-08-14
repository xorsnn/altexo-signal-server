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
      AUTH_SERVICE_BROKEN: -32000
      KURENTO_ERROR: -32001
      NOT_AUTHENTICATED: 1001
      PEER_NOT_FOUND: 1002
      ONLY_ONE_ROOM_ALLOWED: 1003
      ROOM_NAME_OCCUPIED: 1004
      ROOM_NOT_FOUND: 1005
      OFFER_DISCARDED: 1006
      NOT_IN_ROOM: 1007
    }

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

    _leaveRoom: ->
      room = this.room
      this.room = null
      if this is room.creator
        rooms.delete(room.name)
        return room.close()
      return room.removeUser(this)

    rpc: {
      'authenticate': (token) ->
        auth = new Promise (resolve, reject) ->
          authRequest = {
            url: nconf.get('auth:me')
            headers: { 'Authorization': "Token #{token}" }
          }
          request authRequest, (error, response, body) ->
            if error
              return reject {
                code: ChatError.AUTH_SERVICE_BROKEN
                message: error.toString()
              }
            unless response.statusCode == 200
              return reject {
                code: ChatError.NOT_AUTHENTICATED
                message: 'invalid token'
              }
            resolve(true)
        return auth.then => this.isAuthenticated = true

      'create-room': (name, p2p) ->
        unless this.isAuthenticated
          return Promise.reject {
            code: ChatError.NOT_AUTHENTICATED
            message: 'not authenticated'
          }

        if this.room
          return Promise.reject {
            code: ChatError.ONLY_ONE_ROOM_ALLOWED
            message: 'user is in other room now'
          }

        if rooms.has(name)
          return Promise.reject {
            code: ChatError.ROOM_NAME_OCCUPIED
            message: 'room already exists'
          }

        unless p2p
          this.room = new KurentoRoom(name)
        else
          this.room = new P2PRoom(name)

        rooms.set(name, this.room)

        this.room.open(this)
        .then -> true
        .then null, (error) =>
          rooms.delete(name)
          this.room = null

          Promise.reject {
            code: ChatError.KURENTO_ERROR
            message: error.message
          }

      'watch-room': (name) ->
        if this.room
          return Promise.reject {
            code: ChatError.ONLY_ONE_ROOM_ALLOWED
            message: 'user is in other room now'
          }

        unless rooms.has(name)
          return Promise.reject {
            code: ChatError.ROOM_NOT_FOUND
            message: 'room is not found'
          }

        this.room = rooms.get(name)
        this.room.on 'close', =>
          this.room = null

        this.room.addUser(this)
        .then -> true
        .then null, (error) =>
          this.room = null

          Promise.reject {
            code: ChatError.KURENTO_ERROR
            message: error.message
          }

      'leave-room': ->
        unless this.room
          return Promise.reject {
            code: ChatError.NOT_IN_ROOM
            message: 'not in a room'
          }

        this._leaveRoom()
        .then -> true
        .then null, (error) ->
          Promise.reject {
            code: ChatError.KURENTO_ERROR
            message: error.message
          }

      'offer': (offerSdp) ->
        unless this.room
          return Promise.reject {
            code: ChatError.OFFER_DISCARDED
            message: 'offer discarded'
          }

        this.room.processOffer(this, offerSdp)
        .then null, (error) ->
          Promise.reject {
            code: ChatError.KURENTO_ERROR
            message: error.message
          }
    }

    rpcNotify: {
      'ice-candidate': (candidate) ->
        unless this.room
          return
        this.room.processIceCandidate(this, candidate)
    }

    sendCandidate: (candidate) ->
      this.notify('ice-candidate', [candidate])

    sendOffer: (offerSdp) ->
      this.request('offer', [offerSdp])

    notifyPeer: (id, method, params) ->
      peer = registry.getPeer(id)
      unless peer
        return
      peer.notify(method, params)

    requestPeer: (id, method, params) ->
      peer = registry.getPeer(id)
      unless peer
        return Promise.reject {
          code: ChatError.PEER_NOT_FOUND
          message: 'peer is not found'
        }
      peer.request(method, params)


  server.on 'connection', (ws) ->

    handler = new ChatRpc()
    handler.attach(ws)

    console.log '>> client connected', handler.id

    ws.on 'close', ->
      console.log '>> client disconnected', handler.id

      handler.detach()
