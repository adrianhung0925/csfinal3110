val handle_keystrokes : 't -> unit
(**Takes in an abstract type containing the player's inputs Client Renderer ->
   client networker.handle_keystrokes -> server networker -> server game engine*)

val set_socket : int -> int -> string -> unit
(**Takes in an IP, port, and userID to make a connection with*)

val get_client_ID : unit -> string
(**Returns the local client ID*)
