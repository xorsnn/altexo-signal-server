request = require 'request'
nconf = require 'nconf'
kurento = require 'kurento-client'

Registry = require './registry.coffee'
RoomList = require './room-list.coffee'

JsonRpc = require './utils/json-rpc.coffee'


module.exports = (server, kurentoClient) ->

  class ChatRpc extends JsonRpc

    registry = new Registry()
    roomList = new RoomList()

    ChatError = {
      AUTH_SERVICE_BROKEN: -32000
      KURENTO_ERROR: -32001
      NOT_AUTHENTICATED: 1001
      PEER_NOT_FOUND: 1002
      ONLY_ONE_ROOM_ALLOWED: 1003
      ROOM_NAME_OCCUPIED: 1004
      ROOM_NOT_FOUND: 1005
      NEED_NO_OFFER_NOW: 1006
    }

    id: null
    isAuthenticated: false
    room: null

    pipeline: null
    candidatesQueue: null

    onAttach: ->
      this.id = registry.add(this)
      this.candidatesQueue = []

    onDetach: ->
      if this.webRtcEndpoint
        this.webRtcEndpoint.release()
        this.webRtcEndpoint = null

      if this.room
        roomList.leave(this.room.name, this)
        this.room = null

      registry.remove(this.id)
      this.id = null

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

      'create-room': (name) ->
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

        if roomList.exists(name)
          return Promise.reject {
            code: ChatError.ROOM_NAME_OCCUPIED
            message: 'room already exists'
          }

        this.room = roomList.create(name, this)
        this.room.on 'close', =>
          if this.pipeline
            this.pipeline.release()
            this.pipeline = null
          this.room = null

        kurentoClient.create('MediaPipeline')
        .then (pipeline) =>
          this.pipeline = pipeline
          this.pipeline.create('WebRtcEndpoint')
        .then (webRtcEndpoint) =>
          this.webRtcEndpoint = webRtcEndpoint

          while this.candidatesQueue.length
            candidate = this.candidatesQueue.shift()
            this.webRtcEndpoint.addIceCandidate(candidate)

          this.webRtcEndpoint.on 'OnIceCandidate', (ev) =>
            candidate = (kurento.getComplexType 'IceCandidate')(ev.candidate)
            this.notify('ice-candidate', [candidate])

          return true

        .then null, (error) ->
          Promise.reject {
            code: ChatError.KURENTO_ERROR
            message: error.message
          }

      'offer': (offerSdp) ->
        unless this.webRtcEndpoint
          return Promise.reject {
            code: ChatError.NEED_NO_OFFER_NOW
            message: 'offer discarded'
          }

        this.webRtcEndpoint.processOffer(offerSdp)
        .then (answerSdp) =>
          this.webRtcEndpoint.connect(this.webRtcEndpoint)
          .then => this.webRtcEndpoint.gatherCandidates()

          return answerSdp

        .then null, (error) ->
          Promise.reject {
            code: ChatError.KURENTO_ERROR
            message: error.message
          }

      'watch-room': (name) ->
        unless roomList.exists(name)
          return Promise.reject {
            code: ChatError.ROOM_NOT_FOUND
            message: 'room is not found'
          }

        if this.room
          return Promise.reject {
            code: ChatError.ONLY_ONE_ROOM_ALLOWED
            message: 'user is in other room now'
          }

        this.room = roomList.enter(name, this)
        this.room.on 'close', =>
          this.room = null

        return Promise.resolve(true)
    }

    rpcNotify: {
      'ice-candidate': (candidate) ->
        candidate = (kurento.getComplexType 'IceCandidate')(candidate)

        unless this.webRtcEndpoint
          this.candidatesQueue.push(candidate)
        else
          this.webRtcEndpoint.addIceCandidate(candidate)

        return
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
          code: ChatError.PEER_NOT_FOUND
          message: 'peer is not found'
        }
      peer.request(method, params)

  server.on 'connection', (ws) ->

    console.log '>> client connected'

    handler = new ChatRpc()
    handler.attach(ws)

    ws.on 'close', ->
      console.log '>> client disconnected'

      handler.detach()
