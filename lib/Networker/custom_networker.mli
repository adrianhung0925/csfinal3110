val handle_keystrokes : 't -> unit
(**Takes in an abstract type containing the player's inputs Client Renderer ->
   client networker.handle_keystrokes -> server networker -> server game engine*)

val set_socket : int -> int -> string -> unit
(**Takes in an IP, port, and userID to make a connection with*)

val get_client_ID : unit -> string
(**Returns the local client ID*)

val client_start : string -> int -> string -> unit
(**Connects to an IPv4 server address, port, and client ID. Raises
   [Invalid_argument] for a malformed or IPv6 address.*)

val client_send_message : string -> unit
(**Sends a message to the server.*)

val client_take_incoming : unit -> string list
(**Removes and returns all received messages, oldest first. Returns [] when no
   messages are waiting.*)

val server_start : int -> unit
(**Starts listening on the given port and returns once the server is ready.*)
