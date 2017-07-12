# ALTEXO SIGNAL #

В основе работы сервиса используется вариант протокола [JSON-RPC 2.0](http://www.jsonrpc.org/specification) поверх [WebSocket](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket) транспорта. В отличии от оригинального JSON-RPC:

* соединения не являются stateless;
* при обмене сообщениями поле `jsonrpc` не используется.

## Back-end ##

### Запросы ###

* `id -> string` получить uuid соединения;
* `authenticate [ token ] -> boolean` аутентификация соединения;
* `room/open [ name, p2p ] -> boolean` создание комнаты;
* `room/close -> boolean` закрытие текущей комнаты;
* `room/enter [ name ] -> boolean` вход в созданную комнату;
* `room/leave -> boolean` выход из текущей комнаты;
* `room/offer [ offerSdp ] -> answerSdp` отправление SDP предложения и получение SDP отклика в результате;
* `peer/restart -> boolean` реинициализация удаленной точки WebRTC для создания нового соединения.

### Уведомления ###

* `user/alias [ name ]` установка псевдонима пользователя;
* `user/mode [ value ]` установка режима передачи данных (аудио/видео);
* `room/text [ text ]` отправление текстового сообщения в общий чат комнаты;
* `room/ice-candidate [ candidate ]` передача обнаруженного ICE candidate.

## Front-end ##

### Запросы ###

* `offer [ offerSdp ] -> answerSdp` отправление SDP предложения и получение SDP отклика в результате;
* `restart -> boolean` реинициализация удаленной точки WebRTC для создания нового соединения.

### Уведомления ###

* `ice-candidate [ candidate ]` передача обрнаруженного ICE candidate;
* `room/contacts [ contact-list ]` обновление списка контактов в комнате;
* `room/text [ text, contact ]` сообщение из текстового чата;
* `room/destroy` комната закрыта.

### Запуск ###

$ docker-compose build

$ docker-compose up

сервер доступен по 127.0.0.1:8080
