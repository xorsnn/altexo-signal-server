EventEmitter = require('events').EventEmitter


class Room extends EventEmitter

  name: null
  creator: null
  members: null

  constructor: (name, user) ->
    this.name = name
    this.creator = user
    this.members = new Set()
    this.members.add(user)
    super()

  enter: (user) ->
    this.members.add(user)
    this.emit('user:enter', user)

  leave: (user) ->
    this.members.delete(user)
    this.emit('user:leave', user)

  close: ->
    this.members.forEach (user) =>
      this.leave(user)
    this.emit('close')


class RoomList

  rooms: null

  constructor: ->
    this.rooms = new Map()

  create: (name, user) ->
    if this.exists(name)
      throw new Error('room already exists')
    room = new Room(name, user)
    this.rooms.set(name, room)
    return room

  close: (name) ->
    unless this.exists(name)
      throw new Error('room does not exist')
    room = this.rooms.get(name)
    room.close()
    this.rooms.delete(name)

  enter: (name, user) ->
    unless this.exists(name)
      throw new Error('room does not exist')
    room = this.rooms.get(name)
    room.enter(user)
    return room

  leave: (name, user) ->
    unless this.exists(name)
      throw new Error('room does not exist')
    room = this.rooms.get(name)
    unless room.creator.id == user.id
      room.leave(user)
    else
      this.close(name)
    return

  exists: (name) ->
    this.rooms.has(name)


module.exports = RoomList
