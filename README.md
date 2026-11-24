# csfinal3110
Authors:
Lyudmila Kaneva ldk66
Anthony Querbach aq63
Adrian Hung ah2427
Artyom Jhangiryan aj682
Armen Amirbekian aaa462



## Browser multiplayer

The server runs the authoritative game loop on a chosen TCP port. Browsers use
the WebSocket gateway because they cannot open TCP sockets directly. Choose a
port (for example, `9000`) and start the game server on the host computer:


# Terminal 1: start the game server and simulation
dune exec bin/server.exe -- server 9000


The gateway requires Node.js 18 or newer, which includes `npm`. Check that both
commands are available before continuing:


node --version
npm --version


If `npm` is not found, install Node.js 18+ (for example, with
`brew install node` on macOS, or from the official Node.js download page), then
open a new terminal.

In another terminal on the host, install gateway dependencies once, then start
the gateway bound to the host's network interfaces. These are two separate
commands; `WS_HOST` and `TCP_PORT` apply to `npm start`, not `npm install`.
Set `TCP_PORT` to the same port passed to the game server:


# Terminal 2
cd gateway
npm install
TCP_PORT=9000 WS_HOST=0.0.0.0 npm start


In a third terminal, return to the repository root (the directory containing
this `README.md`; do not serve from `gateway/`), build the browser bundle, then
serve the repository on the LAN:


dune build demo/demo.bc.js
python3 -m http.server 8000 --bind 0.0.0.0 --directory .


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
