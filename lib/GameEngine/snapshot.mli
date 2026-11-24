(** What one player receives after each tick: the parts of the game state the
    client needs to draw a frame, from that player's point of view.

    The server builds one snapshot per player and hands it to the networking
    library, which sends it. The client gives it to the renderer. A snapshot is
    plain data with no functions inside, so the networking library can send it
    as is.

    This module is pure: [of_state] only reads the state. *)

type t = {
  viewer : State.student_id option;
      (** Who this snapshot is for: [Some id] for student [id], whose square is
          drawn solid with an arrow above it, or [None] for the Professor, who
          sees every student the same way. *)
  config : State.config;
      (** The round's configuration, so the client knows the arena size and the
          square size without a separate message. *)
  phase : State.phase;  (** The current stage of the round. *)
  ticks_left : int;  (** Ticks left in the semester, for the timer. *)
  students : State.student list;
      (** Every student, whatever their standing, sorted by ascending id, as in
          [State.students]. *)
  bullets : State.bullet list;
      (** Every bullet in the arena, oldest first, as in [State.bullets]. *)
  enrolled : int;  (** Students still [Enrolled], for "students remaining". *)
  kills : int;  (** Students the Professor has knocked out so far. *)
  leaderboard : State.student list;
      (** The final ranking from [State.leaderboard] once the phase is
          [Finished], for the end-of-round screen; [[]] in every other phase, so
          it is not sent on every tick. *)
}
[@@deriving yojson]
(** One player's view of the round after a tick. The Professor's cooldowns and
    energy are not here yet; they will be added once the scheduler that owns
    them exists. *)

val of_state : viewer:State.student_id option -> State.t -> t
(** [of_state ~viewer st] is the snapshot of [st] for [viewer]. [viewer] is
    copied as given, even if it is not a student in [st], so a client that has
    not joined yet can still be sent the lobby. For example, after one tick of a
    round with student 1 at [{ x = 304.; y = 200. }],
    [of_state ~viewer:(Some 1) st] has [viewer = Some 1], [phase = Running], and
    that student in [students]. *)

val me : t -> State.student option
(** [me snap] is [Some s] if [snap.viewer] is [Some id] and student [id] is in
    [snap.students], or [None] (always [None] for the Professor). The client
    uses it to find its own GPA and to switch to the spectator view once
    [s.standing] is [Dropped]. *)

(** {1 Sending a snapshot over the network} *)

val to_string : t -> string
(** [to_string snap] is [snap] written as one line of JSON, ready for the
    networker to send. It never contains a newline, so it works with
    [output_string oc (msg ^ "\n")] on one side and [input_line ic] on the
    other. For example, a lobby snapshot starts like
    [{"viewer":1,"config":{"arena_w":600.0,...},"phase":["Lobby"],...}]. *)

val of_string : string -> t
(** [of_string str] is the snapshot that [to_string] turned into [str], so
    [of_string (to_string snap) = snap] for every [snap]. Raises [Failure] if
    [str] is not valid JSON or does not describe a snapshot. *)
