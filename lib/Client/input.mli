(** The arrow keys a student is holding, built from the browser's key events.

    The browser reports keys one event at a time: a key goes down, a key comes
    up, or the page loses focus. This module turns that stream into the
    [State.dir] the server needs, and says when that direction has changed, so
    the client sends a message only when there is something new to say.

    This module is pure and does not touch the browser, so it can be tested
    without opening a page. *)

(** One of the four arrow keys. *)
type key =
  | Up
  | Down
  | Left
  | Right

val key_of_code : string -> key option
(** [key_of_code code] is the arrow key named by the browser key name [code], or
    [None] if [code] is not an arrow key. The names are the values of
    [KeyboardEvent.key]: ["ArrowUp"], ["ArrowDown"], ["ArrowLeft"], and
    ["ArrowRight"]. For example, [key_of_code "ArrowLeft"] is [Some Left] and
    [key_of_code "a"] is [None]. *)

(** Something the browser reported about the keyboard.
    - [Key_down code]: the key named [code] was pressed, or is auto-repeating
      while held.
    - [Key_up code]: the key named [code] was released.
    - [Blur]: the page lost focus (for example, the player switched tabs), so
      the browser will not report releases any more and every key counts as
      released. *)
type event =
  | Key_down of string
  | Key_up of string
  | Blur

type t
(** The set of arrow keys currently held. *)

val empty : t
(** [empty] holds no keys. *)

val held : key -> t -> bool
(** [held k keys] is whether [k] is held in [keys]. *)

val to_dir : t -> State.dir
(** [to_dir keys] is the direction for [keys]: each field of the result is
    whether the corresponding key is held. Opposite keys are both reported;
    [State.step] cancels them. *)

val apply : event -> t -> t
(** [apply e keys] is [keys] after event [e]: [Key_down] adds an arrow key,
    [Key_up] removes it, and [Blur] removes every key. Events for keys that are
    not arrow keys leave [keys] unchanged. *)

val update : event -> t -> t * State.dir option
(** [update e keys] is [(keys', change)], where [keys'] is [apply e keys] and
    [change] is [Some (to_dir keys')] if the direction differs from
    [to_dir keys], or [None] if it is the same. For example, auto-repeated
    [Key_down "ArrowUp"] events while up is already held give [None], so the
    client does not resend the same direction. *)

val can_move : State.standing option -> bool
(** [can_move standing] is whether a student with [standing] may control their
    square: [true] only for [Some Enrolled]. [None] means the student has not
    joined yet. A [Dropped] student is a spectator and has no controls. *)
