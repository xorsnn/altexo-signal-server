request = require 'request'
nconf = require 'nconf'

Registry = require './registry.coffee'
JsonRpc = require './utils/json-rpc.coffee'
ListenerMixin = require './utils/listener.coffee'
logger = require './logger'


module.exports = (server, kurentoClient) ->

  KurentoRoom = (require './rooms/kurento.coffee')(kurentoClient)
  P2PRoom = require './rooms/p2p.coffee'


  class ChatRpc extends JsonRpc

    Object.assign( @::, ListenerMixin )

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
        (e) -> { code: - 32000, message: "#{e.toString()}" }
    }

    _rawError = (e) ->
      unless e.code and e.message
        Promise.reject { code: -32001, message: "#{e.message}" }
      else
        Promise.reject(e)

    id: null
    isAuthenticated: false
    room: null
    alias: null
    mode: null

    getContactInfo: -> {
      id: this.id
      name: this.alias || 'John Doe'
      mode: this.mode || { video: '2d', audio: true }
    }

    rpc: {
      'id': -> this.id

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
        # unless this.isAuthenticated
        #   return Promise.reject(ChatError.NOT_AUTHENTICATED)

        if this.room
          return Promise.reject(ChatError.CURRENT_ROOM_PRESENT)

        if rooms.has(name)
          return Promise.reject(ChatError.ROOM_NAME_OCCUPIED)

        # TODO: make this decision based on payment
        unless p2p
          room = new KurentoRoom(name)
        else
          room = new P2PRoom(name)

        room.create(this)
        .then => this.connectRoom(rooms.set(name, room).get(name))
        .then => logger.info({ p2p, room: name, user: this.id }, 'room created')
        .then => this.room.getProfile()
        .then null, _rawError

      'room/enter': (name) ->
        if this.room
          return Promise.reject(ChatError.CURRENT_ROOM_PRESENT)

        unless rooms.has(name)
          return Promise.reject(ChatError.ROOM_NOT_FOUND)

        rooms.get(name).addUser(this)
        .then => this.connectRoom(rooms.get(name))
        .then => logger.info({ room: name, user: this.id }, 'room entered')
        .then => this.room.getProfile()
        .then null, _rawError

      'room/close': ->
        unless this.room
          return Promise.reject(ChatError.NO_CURRENT_ROOM)

        unless this is this.room.creator
          return Promise.reject(ChatError.NOT_AUTHORIZED)

        this.disconnectRoom()
        .then -> true
        .then null, _rawError

      'room/leave': ->
        unless this.room
          return Promise.reject(ChatError.NO_CURRENT_ROOM)

        this.disconnectRoom()
        .then -> true
        .then null, _rawError

      'room/offer': (offerSdp) ->
        unless this.room
          return Promise.reject(ChatError.NO_CURRENT_ROOM)

        this.room.processOffer(this, offerSdp)
        .then null, _rawError

      'peer/restart': ->
        unless this.room
          return Promise.reject(ChatRpc.NO_CURRENT_ROOM)
        this.room.restartPeer(this)
    }

    rpcNotify: {
      'user/alias': (name) ->
        this.alias = "#{name}"
        if this.room
          this.room.members.forEach (user) ->
            user.sendContactList()
        return

      'user/mode': (value) ->
        this.mode = value
        if this.room
          this.room.members.forEach (user) =>
            user.sendContactList()
        return

      'room/text': (text) ->
        if this.room
          contact = this.getContactInfo()
          this.room.members.forEach (user) ->
            user.notify('room/text', [text, contact])
        return

      'room/ice-candidate': (candidate) ->
        if this.room
          this.room.processIceCandidate(this, candidate)
        return
    }

    onAttach: ->
      this.id = registry.add(this)
      this.remoteAddr = this._ws.upgradeReq.headers['x-real-ip'] || '=/='
      this.userAgent = this._ws.upgradeReq.headers['user-agent'] || '=/='

    onDetach: ->
      if this.room
        this.disconnectRoom()
      registry.remove(this.id)
      this.id = null

    sendCandidate: (candidate) ->
      this.notify('ice-candidate', [candidate])

    sendOffer: (offerSdp) ->
      this.request('offer', [offerSdp])

    sendContactList: ->
      this.notify('room/contacts', [this.room.getContacts()])

    sendRestart: ->
      this.request('restart').then -> true

    connectRoom: (room) ->
      this.listenTo(room, 'user:enter', => this.sendContactList())
      this.listenTo(room, 'user:leave', => this.sendContactList())
      unless this is room.creator
        this.listenTo(room, 'destroy', => this.notify('room/destroy'))
      this.room = room

    disconnectRoom: ->
      room = this.room
      this.room = null
      this.stopListening(room)
      if this is room.creator
        logger.info({ room: room.name }, 'room closed')
        rooms.delete(room.name)
        return room.destroy()
      else
        logger.info({ room: room.name, user: this.id }, 'user quit room')
      return room.removeUser(this)

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


  server.on 'connection', (ws) ->

    handler = new ChatRpc()
    handler.attach(ws)

    logger.info({
      id: handler.id
      ip: handler.remoteAddr
      ua: handler.userAgent
    }, 'client connected')

    ws.on 'close', ->
      logger.info({ id: handler.id }, 'client disconnected')

      handler.detach()
