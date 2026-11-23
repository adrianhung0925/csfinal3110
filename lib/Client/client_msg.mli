(** The messages a browser client sends to the server, their text encoding, and
    how the server turns them into [Gameloop] input.

    As the team agreed, each key press or release travels on its own, so the
    server can hand it straight to [Gameloop.handle]. The client never sends its
    own id: the server knows which connection a message came from and supplies
    the id in [to_event].

    The text encoding, one message per line or WebSocket frame, is:
    - [Join name]: ["join "] followed by the name, e.g. ["join lucy"].
    - [Press k]: ["down "] followed by the browser's name for [k], e.g.
      ["down ArrowUp"].
    - [Release k]: ["up "] followed by the browser's name for [k], e.g.
      ["up ArrowLeft"].

    Key names are those of [Gameloop.key_of_string]. Plain text needs no extra
    library on either side and is easy to read in a server log. *)

(** One message from a client.
    - [Join name]: the player asks to join the round as a student called [name].
    - [Press k]: the player started holding arrow key [k].
    - [Release k]: the player stopped holding [k]. *)
type t =
  | Join of string
  | Press of Gameloop.key
  | Release of Gameloop.key

val of_change : Input.change -> t
(** [of_change c] is the message that reports [c]: [Press k] for
    [Input.Pressed k] and [Release k] for [Input.Released k]. *)

val key_name : Gameloop.key -> string
(** [key_name k] is the browser's name for [k], the inverse of
    [Gameloop.key_of_string]: ["ArrowUp"], ["ArrowDown"], ["ArrowLeft"], or
    ["ArrowRight"]. *)

val to_string : t -> string
(** [to_string m] is the encoding of [m] described above. *)

val of_string : string -> (t, string) result
(** [of_string s] is [Ok m] if [s] is the encoding of some message [m], or
    [Error reason] otherwise, where [reason] says what is wrong, for the
    server's log. It never raises, so one client's bad message cannot stop the
    server. The name in a ["join"] message is everything after ["join "] with
    leading and trailing spaces removed; it is an error if that is empty.
    Checking the name's length is left to [Gameloop.join]. For every message [m]
    whose name is non-empty with no leading or trailing spaces,
    [of_string (to_string m)] is [Ok m]. *)

val to_event : State.student_id -> t -> Gameloop.event option
(** [to_event id m] is the [Gameloop] input for message [m] from student [id]:
    [Some (Key_down (id, k))] for [Press k], [Some (Key_up (id, k))] for
    [Release k], and [None] for [Join _], which the server handles with
    [Gameloop.join] instead. *)
