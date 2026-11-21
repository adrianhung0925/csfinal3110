(** Messages a browser client sends to the server, and their text encoding.

    PROPOSED: this format still needs to be agreed with Anthony (networking) and
    Armen (server loop). It is plain text so that it needs no extra library on
    either side and is easy to read in a log.

    The encodings are:
    - [Join name] is ["join "] followed by the name, e.g. ["join adrian"].
    - [Move dir] is ["move "] followed by four characters for up, down, left,
      and right, each either the key's letter ([U], [D], [L], [R]) when held or
      [-] when not. For example, holding up and right is ["move U--R"], and
      holding nothing is ["move ----"]. *)

(** A message from one client to the server.
    - [Join name]: the player asks to join the lobby with username [name].
    - [Move dir]: the player is now holding the keys in [dir]. Sent only when
      that changes; the server keeps using the last [dir] it received. *)
type t =
  | Join of string
  | Move of State.dir

val to_string : t -> string
(** [to_string m] is the encoding of [m] described above. *)

val of_string : string -> (t, string) result
(** [of_string s] is [Ok m] if [s] is the encoding of some message [m], or
    [Error reason] if it is not, with [reason] explaining what is wrong for a
    log. The name in a [join] message is everything after ["join "], with
    leading and trailing spaces removed; a name that is empty after that is an
    error. Checking the name's length is left to [State.add_student]. For every
    message [m] whose name is non-empty and has no leading or trailing spaces,
    [of_string (to_string m)] is [Ok m]. *)
