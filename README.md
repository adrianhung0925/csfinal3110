# Survive the Hump Days

A multiplayer browser game written in OCaml for CS 3110. Each player is a student, a small square that moves with
the arrow keys inside an arena. The Professor launches attacks, such as the block-letter "A1" assignment, and a
hit lowers the student's GPA (everyone starts at 4.0). At 0.0 the student is dropped and spectates. The server
runs the game; browsers only send key presses and draw what the server sends back.

Authors: Lyudmila Kaneva (ldk66), Anthony Querbach (aq63), Adrian Hung (ah2427), Artyom Jhangiryan (aj682),
Armen Amirbekian (aaa462). See `AUTHORS.md`.

## Requirements

- OCaml (tested with 5.3.0) and dune 3.24 or newer, through opam
- These opam packages:

  ```sh
  opam install ounit2 js_of_ocaml js_of_ocaml-ppx yojson ppx_deriving_yojson
  ```

- For playing in the browser: Node.js 18 or newer (includes `npm`) and Python 3 (only used to serve the page).
  Check with `node --version`, `npm --version` and `python3 --version`. If `npm` is missing, install Node.js 18+
  (for example `brew install node` on macOS) and open a new terminal.

## Build and test

From the repository root (the folder containing this `README.md`):

```sh
dune build
dune test
```

`dune test` runs the OUnit suite in `test/test_csfinal3110.ml` (State, Shape, Input_message, Gameloop and
Snapshot tests) and the separate programs `test/render_test.ml`, `test/client_test.ml` and `test/network_test.ml`.
Both commands should finish without errors.

## Playing in the browser (multiplayer on one network)

The game server speaks TCP, and browsers can only use WebSockets, so a small gateway in `gateway/` (Node.js)
passes messages between them. The host computer runs **three programs at the same time**, each in its own
terminal, all started from the repository root.

**Terminal 1: the game server** (choose a port, for example `9000`):

```sh
dune exec bin/server.exe -- server 9000
```

It prints `Server listening on port 9000...` and keeps running.

**Terminal 2: the WebSocket gateway.** Install its dependency once, then start it. `TCP_PORT` must match the
game server's port. These are two separate commands: `WS_HOST` and `TCP_PORT` belong to `npm start`, not to
`npm install`.

```sh
cd gateway
npm install
TCP_PORT=9000 WS_HOST=0.0.0.0 npm start
```

It prints `WebSocket gateway listening on ws://0.0.0.0:9001 -> 127.0.0.1:9000`.

**Terminal 3: the web page.** From the repository root (not from `gateway/` or your home folder), build the
browser code and serve the repository:

```sh
dune build demo/demo.bc.js
python3 -m http.server 8000 --bind 0.0.0.0 --directory .
```

Find the host's IP address on the local network (on macOS: `ipconfig getifaddr en0`). Then on each device:

1. Open `http://<host-IP>:8000/demo/index.html`.
2. Enter `ws://<host-IP>:9001` as the WebSocket URL (not the default `127.0.0.1`, unless you are on the host).
3. Enter a client ID that no one else is using, and click **Connect** once.
4. Use the arrow keys to move. Space launches the A1 assignment.

Reconnecting with the same client ID gives you back your old square.

## Troubleshooting

| Problem | Fix |
|---|---|
| The page shows `404 File not found` | Terminal 3 was started outside the repository root. Stop it and start it again from the root. |
| Chrome shows `ERR_ADDRESS_UNREACHABLE` | On macOS, allow the browser in System Settings → Privacy & Security → Local Network, then restart it. Safari works without this. |
| "Connection error" on the page | The gateway (terminal 2) is not running or is blocked. On the host, allow `node` through the firewall (System Settings → Network → Firewall), and allow ports 8000 and 9001. |
| "Connection refused" in the gateway's terminal | The game server (terminal 1) is not running, or it uses a different port than `TCP_PORT`. |
| "Rejected: client ID is already in use" | Choose a different client ID. |
| Everything stops moving after about 3 minutes | The semester timer has ended the round; there is no end screen yet. Restart the game server (terminal 1) for a new round. |

The gateway's settings can be changed with `WS_HOST`, `WS_PORT`, `TCP_HOST` and `TCP_PORT`. Expose it only on a
trusted network.

## Project layout

| Folder | Contents |
|---|---|
| `lib/GameEngine/` | Game rules (`State`, `Shape`), the game loop (`Gameloop`), per-player views (`Snapshot`, sent as JSON), input messages (`Input_message`) |
| `lib/Rendering/` | Draws a snapshot on the page's canvas (`Render`) |
| `lib/Client/` | Tracks the arrow keys a player holds (`Input`) |
| `lib/Networker/` | TCP server and clients, and the browser WebSocket client (`Browser_client`) |
| `bin/server.ml` | The game server program |
| `demo/` | The browser page (`index.html`, `demo.ml`) |
| `gateway/` | The Node.js WebSocket-to-TCP gateway (interface glue only) |
| `test/` | Automated tests, run with `dune test` |
