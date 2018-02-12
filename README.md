# ALTEXO SIGNAL #

Service is based on [JSON-RPC 2.0](http://www.jsonrpc.org/specification) protocol over [WebSocket](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket) transport unlike original JSON-RPC.

*   connections are not stateless;
*   field `jsonrpc` is not used while message exchanging.

## Back-end ##

### Requests ###

*   `id -> string` get connection uuid;
*   `authenticate [ token ] -> boolean` connection authentication;
*   `room/open [ name, p2p ] -> boolean` create room;
*   `room/close -> boolean` close room;
*   `room/enter [ name ] -> boolean` enter room;
*   `room/leave -> boolean` leave room;
*   `room/offer [ offerSdp ] -> answerSdp` send SDP offer and get SDP response as a result;
*   `peer/restart -> boolean` reinitialize remote WebRTC point to create new connection.

### Notifications ###

*   `user/alias [ name ]` setting user nickname;
*   `user/mode [ value ]` setting mode of data streaming (audio/video);
*   `room/text [ text ]` sending messages to the room chat;
*   `room/ice-candidate [ candidate ]` sending ICE candidate.

## Front-end ##

### Requests ###

*   `offer [ offerSdp ] -> answerSdp` sending SDP offer end getting SDP response as a result;
*   `restart -> boolean` reinitialize remote WebRTC point to create new connection.

### Notifications ###

*   `ice-candidate [ candidate ]` sending ICE candidate;
*   `room/contacts [ contact-list ]` refresh contacts list in the room;
*   `room/text [ text, contact ]` message from the text chat;
*   `room/destroy` room closed.

### Run server ###
```
$ docker-compose build
$ docker-compose up
```
server is avaliable 127.0.0.1:8080
