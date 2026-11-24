# csfinal3110
Authors: Lyudmila Kaneva ldk66

## Browser multiplayer

The server runs the authoritative game loop on TCP port 9000. Browsers use the
WebSocket gateway because they cannot open TCP sockets directly. On the host
computer, start the game server:

```sh
# Terminal 1: start the game server and simulation
dune exec bin/mainNetworkTest.exe -- server
```

The gateway requires Node.js 18 or newer, which includes `npm`. Check that both
commands are available before continuing:

```sh
node --version
npm --version
```

If `npm` is not found, install Node.js 18+ (for example, with
`brew install node` on macOS, or from the official Node.js download page), then
open a new terminal.

In another terminal on the host, install gateway dependencies once, then start
the gateway bound to the host's network interfaces. These are two separate
commands; `WS_HOST` applies to `npm start`, not `npm install`:

```sh
# Terminal 2
cd gateway
npm install
WS_HOST=0.0.0.0 npm start
```

In a third terminal, return to the repository root (the directory containing
this `README.md`; do not serve from `gateway/`), build the browser bundle, then
serve the repository on the LAN:

```sh
dune build demo/demo.bc.js
python3 -m http.server 8000 --bind 0.0.0.0 --directory .
```

Each device can open `http://<host-LAN-IP>:8000/demo/index.html`, enter
`ws://<host-LAN-IP>:9001` as the WebSocket URL, and choose a unique client ID.
The browser sends key-down, key-up, and launch inputs to the server; the server
advances the shared game loop and returns each player's snapshot for rendering.
Input messages are one-line values such as `KEY_DOWN:ArrowUp` and
`LAUNCH:ASSIGNMENTS`.

The gateway forwards WebSocket text messages to the server's newline-delimited
TCP protocol. `WS_HOST`, `WS_PORT`, `TCP_HOST`, and `TCP_PORT` can be used to
change its bind address or server destination. Allow ports 8000 and 9001 through
the host firewall for LAN access. Expose the gateway only on a trusted network.
