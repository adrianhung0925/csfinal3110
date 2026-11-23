# csfinal3110
Authors: Lyudmila Kaneva ldk66

## Local browser networking demo

The game server listens for TCP clients on port 9000. Browsers cannot open TCP
sockets, so run the WebSocket gateway in `gateway/` alongside the server:

```sh
# Terminal 1: start the game server
dune exec bin/mainNetworkTest.exe -- server

# Terminal 2: install gateway dependencies once, then start the gateway
cd gateway
npm install
npm start
```

The gateway listens on `ws://127.0.0.1:9001` and forwards connections to
`127.0.0.1:9000`. Configure the browser client with that WebSocket URL and a
unique client ID. The gateway translates each WebSocket text message into one
newline-terminated TCP line and relays each TCP line as a WebSocket text
message.

Build the JS client bundle with:

```sh
dune build bin/browser_client_main.bc.js
```

Include `_build/default/bin/browser_client_main.bc.js` in the browser page. It
exports `window.Csfinal3110Client` with `connect(url, clientId, onStatus,
onMessage)`, `send(handle, message)`, `status(handle)`, and `close(handle)`.
Status callbacks receive `"connecting"`, `"connected"`, `"disconnected"`,
`"rejected:..."`, or `"error:..."`; message callbacks receive each server
message as a string.

Override `WS_HOST`, `WS_PORT`, `TCP_HOST`, or `TCP_PORT` to change the bind
address or server destination. The gateway binds to loopback by default; only
expose it on another interface in a trusted environment.
