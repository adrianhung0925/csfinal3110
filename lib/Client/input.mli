(** The arrow keys one player is holding, built from the browser's key events.

    The browser reports the keyboard one event at a time: a key goes down
    (repeatedly, while it is held), a key comes up, or the page loses focus.
    This module keeps track of which arrow keys are held and reports each real
    change as a [change], which the client sends to the server as a
    [Client_msg]. Auto-repeated presses of a key that is already held are not
    changes, so they are never sent.

    Arrow keys are [Gameloop.key] and are named as in [Gameloop.key_of_string],
    so the client and the server agree on them by construction.

    This module is pure and does not touch the browser, so it can be tested
    without opening a page. *)

(** Something the browser reported about the keyboard.
    - [Key_down name]: the key named [name] (a [KeyboardEvent.key] value such as
      ["ArrowUp"]) was pressed, or is auto-repeating while held.
    - [Key_up name]: the key named [name] was released.
    - [Blur]: the page lost focus, for example because the player switched tabs.
      The browser will not report the releases, so every held key counts as
      released. *)
type event =
  | Key_down of string
  | Key_up of string
  | Blur

(** A change in which arrow keys are held: [Pressed k] when [k] starts being
    held, [Released k] when it stops. *)
type change =
  | Pressed of Gameloop.key
  | Released of Gameloop.key

type t
(** The set of arrow keys currently held. *)

val empty : t
(** [empty] holds no keys. *)

val held : Gameloop.key -> t -> bool
(** [held k keys] is whether [k] is held in [keys]. *)

val to_dir : t -> State.dir
(** [to_dir keys] is the [State.dir] whose fields say which keys [keys] holds.
    Opposite keys are both reported; [State.step] cancels them. *)

val update : event -> t -> t * change list
(** [update e keys] is [(keys', changes)], where [keys'] is the set held after
    [e] and [changes] lists what [e] changed:
    - [Key_down name] for an arrow key not yet held: it is added, with
      [[Pressed k]]. If it is already held (auto-repeat), nothing changes and
      [changes] is [[]].
    - [Key_up name] for a held arrow key: it is removed, with [[Released k]]. If
      it is not held, [changes] is [[]].
    - [Blur]: every key is released, with one [Released] per key that was held,
      in the order [Up], [Down], [Left], [Right].
    - [Key_down] or [Key_up] of a key that is not an arrow key changes nothing.

    For example, [update (Key_down "ArrowUp") empty] holds only [Up] and gives
    [[Pressed Up]], and pressing ["ArrowUp"] again gives [[]]. *)

val can_move : State.standing option -> bool
(** [can_move standing] is whether a player with [standing] controls a square:
    [true] only for [Some Enrolled]. [None] means the player is not a student in
    the round yet. A [Dropped] student is a spectator, so the client ignores
    their arrow keys. *)
