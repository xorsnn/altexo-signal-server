module.exports = ListenerMixin = {
  listenTo: (obj, name, cb) ->
    obj.addListener(name, cb)
    unless this._listeners
      this._listeners = []
    this._listeners.push({ obj, name, cb })
    return

  stopListening: (obj) ->
    if this._listeners
      remainListeners = []
      for listener in this._listeners
        if listener.obj is obj
          obj.removeListener(listener.name, listener.cb)
        else
          remainListeners.push(listener)
      this._listeners = remainListeners
    return
}
