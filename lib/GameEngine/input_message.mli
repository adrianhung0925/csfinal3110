(** Text protocol for inputs sent from a browser client to the game server. *)

type t =
  | Key_down of Gameloop.key
  | Key_up of Gameloop.key
  | Launch_assignments

val to_string : t -> string
(** [to_string input] encodes an input as one line for the network connection. *)

val of_string : string -> t option
(** [of_string message] decodes an input line, or returns [None] if malformed. *)
