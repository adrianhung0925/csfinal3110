(** The server's game loop: everything the server does between receiving inputs
    and sending out the new state.

    The server keeps one [Gameloop.t]. Whenever an input arrives from the
    networking library (a student pressing or releasing an arrow key, a student
    disconnecting, or the Professor launching an attack), it calls [handle]. At
    a fixed tick rate (30 ticks per second with [State]'s default configuration)
    it calls [tick], then [snapshots], and hands each snapshot to the networking
    library to send to that player.

    Every function is pure: nothing is stored globally. Each function returns a
    new loop, and the server keeps the current one in its own variable, as
    described in the networking requirements. This is also what makes [replay]
    possible: the same recorded inputs always give the same result. *)

(** An arrow key. *)
type key =
  | Up
  | Down
  | Left
  | Right

(** An attack the Professor can launch. Only [Assignments] exists for now. *)
type attack = Assignments

(** One input from a player, as delivered by the networking library.
    - [Key_down (id, k)]: student [id] started holding [k].
    - [Key_up (id, k)]: student [id] released [k].
    - [Disconnect id]: student [id]'s browser disconnected. Their held keys are
      forgotten, so they stand still until they come back and press a key again
      (see [State.step]).
    - [Launch a]: the Professor launched attack [a]. *)
type event =
  | Key_down of State.student_id * key
  | Key_up of State.student_id * key
  | Disconnect of State.student_id
  | Launch of attack

type t
(** The server's loop: the current [State.t], the keys each student is holding,
    and the attack waiting to be launched on the next tick, if any. *)

(** {1 Setting up a round} *)

val create : State.config -> t
(** [create c] is a loop around [State.init c], with no keys held and no attack
    waiting. Raises [Invalid_argument] if [State.init c] does. *)

val join : State.student_id -> name:string -> t -> t
(** [join id ~name lp] adds student [id] called [name] to the round, as in
    [State.add_student]. Raises [Invalid_argument] in the same cases. *)

val start : t -> t
(** [start lp] begins the semester, as in [State.start]. *)

(** {1 Running a round} *)

val key_of_string : string -> key option
(** [key_of_string s] is the arrow key named by [s], using the browser's
    [KeyboardEvent.key] names: ["ArrowUp"], ["ArrowDown"], ["ArrowLeft"], and
    ["ArrowRight"]. Any other string gives [None]. For example,
    [key_of_string "ArrowLeft"] is [Some Left] and [key_of_string "a"] is
    [None]. *)

val handle : event -> t -> t
(** [handle e lp] records input [e]; nothing moves until the next [tick].
    Pressing a key that is already held, or releasing one that is not, changes
    nothing. Keys from ids that are not students are recorded but ignored by
    [State.step]. If the Professor launches more than once before a tick, only
    the last launch counts, so at most one attack starts per tick. Launches are
    not limited by cooldowns or energy yet; that is the scheduler's job once it
    exists. *)

val tick : t -> t
(** [tick lp] advances the round by one tick with [State.step], using the keys
    each student is currently holding as [moves], and the bullets of the waiting
    attack, if any, as [spawned]. Held keys stay held for the next tick; the
    waiting attack is used up. In phases [Lobby] and [Finished] nothing changes
    except that a waiting attack is thrown away, because [State.step] ignores
    [spawned] there.

    [Launch Assignments] spawns one bullet: the text ["A1"] in the block font
    with [cell = 12.], centered on the arena's left wall at half its height
    (with the default arena, [{ x = 0.; y = 200. }]), moving right at [4.] units
    per tick, and taking [1.0] GPA per hit.

    For example, after [handle (Key_down (1, Right))], each [tick] moves student
    1 right by [speed] until [handle (Key_up (1, Right))]. *)

(** {1 Reading the loop} *)

val state : t -> State.t
(** [state lp] is the current game state. *)

val held : State.student_id -> t -> State.dir
(** [held id lp] is the keys student [id] is holding; all [false] if none, or if
    [id] is not known. *)

val snapshots : t -> (State.student_id option * Snapshot.t) list
(** [snapshots lp] is the snapshot to send to each player: first [(None, s)] for
    the Professor, then [(Some id, s)] for every student in ascending id order,
    whatever their standing (a [Dropped] student still receives snapshots to
    spectate). Each [s] is [Snapshot.of_state ~viewer (state lp)] for that
    player. *)

(** {1 Replaying recorded inputs} *)

val replay : t -> event list list -> t
(** [replay lp frames] runs one [tick] per element of [frames], handling that
    element's events, in order, just before its tick. So [replay lp [ []; [] ]]
    is two ticks with no input, and
    [replay lp [ [ Key_down (1, Right) ]; []; [ Key_up (1, Right) ] ]] moves
    student 1 right on the first two ticks and not on the third. Used by the
    tests to check who is still standing after a recorded game. *)
