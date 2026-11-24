(** Browser-side WebSocket client. The WebSocket endpoint must bridge to the
    server's existing line-based TCP protocol. *)

type status =
  | Connecting
  | Connected
  | Rejected of string
  | Disconnected
  | Error of string

type t

val connect :
  url:string ->
  client_id:string ->
  on_status:(status -> unit) ->
  on_message:(string -> unit) ->
  t
(** [connect] opens a WebSocket to [url]. When it opens, [client_id] is sent as
    the first text message; the client becomes [Connected] after receiving
    ["ID_ACCEPTED"]. The browser can only connect to a WebSocket endpoint, not
    directly to the existing TCP server. *)

val status : t -> status
(** The latest connection status. *)

val send : t -> string -> unit
(** Sends a text message. Raises [Invalid_argument] unless the handshake has
    succeeded and the WebSocket is open. *)

val close : t -> unit
