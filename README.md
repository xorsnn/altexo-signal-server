# ALTEXO SIGNAL #

В основе работы сервиса используется вариант протокола [JSON-RPC 2.0](http://www.jsonrpc.org/specification) поверх [WebSocket](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket) транспорта. В отличии от оригинального JSON-RPC:

* соединения не являются stateless;
* при обмене сообщениями поле `jsonrpc` не используется.

### Запросы ###

* `authenticate [ token ] -> boolean` аутентификация соединения;
* `room/open [ name, p2p ] -> boolean` создание комнаты;
* `room/close -> boolean` закрытие текущей комнаты;
* `room/enter [ name ] -> boolean` вход в созданную комнату;
* `room/leave -> boolean` выход из текущей комнаты;
* `room/offer [ offerSdp ] -> answerSdp` отправление SDP предложения и получение SDP отклика в результате.

### Уведомления ###

* `room/ice-candidate [ candidate ]` отправление обнаруженного ICE candidate.