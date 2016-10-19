kurento = require 'kurento-client'
BaseRoom = require './base.coffee'


module.exports = (kurentoClient) ->

  class KurentoRoom extends BaseRoom

    _pipeline: null
    _endpoints: null
    _candidateQueues: null

    getProfile: ->
      Object.assign({ p2p: false }, super())

    create: (user) ->
      this._endpoints = new Map()
      this._candidateQueues = new Map()

      this.creator = user

      kurentoClient.create('MediaPipeline')
      .then (pipeline) => this._pipeline = pipeline
      .then => this._addUser(user)

    destroy: ->
      Promise.all(Array.from(this.members, (user) => this._removeUser(user)))
      .then => this._pipeline.release()
      .then => this.emit('destroy')

    addUser: (user) ->
      this._addUser(user).then =>
        this.emit('user:enter', user)

    _addUser: (user) ->
      this.members.add(user)
      this._createEndpoint(user)

    removeUser: (user) ->
      unless this.members.has(user)
        throw new Error('cannot remove not existing user')
      this._removeUser(user).then =>
        this.emit('user:leave', user)

    _removeUser: (user) ->
      this.members.delete(user)
      this._releaseEndpoint(user)

    processIceCandidate: (user, candidate) ->
      candidate = (kurento.getComplexType 'IceCandidate')(candidate)
      webRtcEndpoint = this._endpoints.get(user.id)
      unless webRtcEndpoint
        unless this._candidateQueues.has(user.id)
          this._candidateQueues.set(user.id, [])
        candidateQueue = this._candidateQueues.get(user.id)
        candidateQueue.push(candidate)
      else
        webRtcEndpoint.addIceCandidate(candidate)
      return

    processOffer: (user, offerSdp) ->
      webRtcEndpoint = this._endpoints.get(user.id)
      unless webRtcEndpoint
        throw new Error('no endpoint found')
      webRtcEndpoint.processOffer(offerSdp)
      .then (answerSdp) =>

        this._getPresenterEndpoint().connect(webRtcEndpoint)
        .then -> webRtcEndpoint.gatherCandidates()

        return answerSdp

    _getPresenterEndpoint: ->
      this._endpoints.get(this.creator.id)

    _createEndpoint: (user) ->
      this._pipeline.create('WebRtcEndpoint')
      .then (webRtcEndpoint) =>
        this._endpoints.set(user.id, webRtcEndpoint)

        candidateQueue = this._candidateQueues.get(user.id)
        if candidateQueue
          while candidateQueue.length
            webRtcEndpoint.addIceCandidate(candidateQueue.shift())
          this._candidateQueues.delete(user.id)

        webRtcEndpoint.on 'OnIceCandidate', (ev) ->
          candidate = (kurento.getComplexType 'IceCandidate')(ev.candidate)
          user.sendCandidate(candidate)

        return

    _releaseEndpoint: (user) ->
      webRtcEndpoint = this._endpoints.get(user.id)
      this._endpoints.delete(user.id)
      this._candidateQueues.delete(user.id)
      webRtcEndpoint.release()
