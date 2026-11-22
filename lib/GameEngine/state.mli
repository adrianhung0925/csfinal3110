(** The game state of one round and the rules that advance it one tick at a
    time.

    A round has no winner. It ends when the semester timer runs out or when no
    student is still playing, and its results are the number of students the
    Professor knocked out ([kills]) and a [leaderboard] of usernames ranked by
    final GPA and then by how long each student stayed in the course.

    Units: positions and sizes are in game units (floats), not pixels; times
    are in ticks (ints); speeds are in units per tick. The origin is the
    arena's top-left corner, with x growing rightward and y growing downward,
    as on a canvas. *)

type vec = {
  x : float;
  y : float;
}
(** A point or displacement in game units. For example, [{ x = 300.; y = 200. }]
    is the center of the default arena. *)

type student_id = int
(** Assigned by the server when a client joins. Unique within a round. *)

type config = {
  arena_w : float;  (** Arena width, e.g. [600.]. *)
  arena_h : float;  (** Arena height, e.g. [400.]. *)
  student_size : float;  (** Side length of a student's square, e.g. [16.]. *)
  speed : float;
      (** Distance a student moves per tick along each held axis, e.g. [4.].
          Diagonal movement is not normalized: holding up and right moves
          [speed] along both axes. *)
  start_gpa : float;  (** GPA every student starts with, e.g. [4.0]. *)
  invuln_ticks : int;
      (** Number of ticks after a hit during which a student cannot be hit
          again, e.g. [30]. *)
  semester_ticks : int;  (** Length of the round in ticks, e.g. [5400]. *)
  max_name_len : int;
      (** Longest username allowed, in characters, e.g. [16], so names fit on
          the leaderboard. *)
}
(** Every number that affects the game. *)

(** Where a student stands in the course.
    - [Enrolled]: still in the course. Moves, and can be hit.
    - [Dropped]: knocked out by the Professor (GPA reached [0.0]). Counts as a
      kill, and spectates for the rest of the round.

    [State] does not track connections. A student whose browser disconnects
    stays [Enrolled] and simply stands still, because no input arrives for
    them (see [step]), until they come back or are dropped. *)
type standing =
  | Enrolled
  | Dropped

type student = {
  id : student_id;
  name : string;
      (** Username chosen when joining, e.g. ["adrian"]. Never empty, no
          leading or trailing spaces, at most [max_name_len] characters. Two
          students may have the same name; [id] tells them apart. *)
  pos : vec;
      (** Center of the student's square. The whole square is always inside
          the arena. *)
  gpa : float;  (** Between [0.0] and [start_gpa], inclusive. *)
  invuln : int;
      (** Number of upcoming ticks on which this student cannot be hit; [0]
          means the student can be hit on the next tick. Never negative. *)
  survived : int;
      (** Number of ticks of the semester this student finished while
          [Enrolled]: [0] before the round starts, and it stops growing once
          the student is [Dropped]. The renderer can show it in seconds
          (divide by the tick rate). *)
  standing : standing;
}
(** One student, as seen by [Snapshot] and tests. *)

type bullet = {
  center : vec;  (** Center of the bullet's shape. *)
  vel : vec;  (** Movement per tick. *)
  shape : Shape.t;
      (** What the bullet looks like and where it hurts, e.g.
          [Shape.Circle { radius = 5. }] or
          [Shape.Text { text = "A1"; cell = 12. }]. *)
  damage : float;  (** GPA lost when this bullet hits a student. Positive. *)
}
(** One bullet: anything that moves and hurts, from a small circle to a whole
    word. Bullets do not disappear when they hit a student; the hit student's
    invulnerability stops repeat damage. *)

type dir = {
  up : bool;
  down : bool;
  left : bool;
  right : bool;
}
(** The arrow keys one student is currently holding. Holding two opposite keys
    (up and down, or left and right) cancels movement along that axis. *)

(** The stage of the round. [Lobby]: students are registering with their
    usernames; nothing moves, there are no bullets, and the timer does not
    run. [Running]: the
    semester is in progress. [Finished]: the timer ran out or no student is
    [Enrolled] any more; nothing changes after this, and [kills] and
    [leaderboard] are the final results. *)
type phase =
  | Lobby
  | Running
  | Finished

type t
(** The state of one round. *)

(** {1 Creating a round} *)

val default_config : config
(** [default_config] is the proposed default configuration: a 600 by 400
    arena, squares of side 16, speed 4, GPA 4.0, 30 ticks of invulnerability, a
    5400-tick semester (3 minutes at 30 ticks per second), and usernames of up
    to 16 characters. *)

val init : config -> t
(** [init c] is a round in phase [Lobby] with configuration [c], no students, no
    bullets, and [c.semester_ticks] ticks left. Raises [Invalid_argument] if any
    size, speed, or GPA in [c] is not positive, [student_size] is larger than
    the arena in either direction, [invuln_ticks] is negative, or
    [semester_ticks] or [max_name_len] is not positive. *)

val add_student : student_id -> name:string -> t -> t
(** [add_student id ~name st] is [st] with a new [Enrolled] student [id]
    called [name], with leading and trailing spaces removed, at the center
    of the arena with [start_gpa], invulnerability [0], and [survived = 0]. For
    example, [add_student 3 ~name:"  adrian " st] adds student 3 named
    ["adrian"]. Raises [Invalid_argument] if [st] is not in phase [Lobby] (no
    new students once the semester has started; a student who reconnects
    keeps their old [id] and is not added again), if [id] is already in [st],
    or if
    [name] is empty or longer than [max_name_len] after removing the
    spaces. *)

val start : t -> t
(** [start st] begins the semester: if [st] is in phase [Lobby], it is [st] in
    phase [Running]. Otherwise it is [st] unchanged. A round started with no
    students becomes [Finished] on its first tick, because no one is
    [Enrolled]. *)

(** {1 Advancing one tick} *)

val step : t -> moves:(student_id * dir) list -> spawned:bullet list -> t
(** [step st ~moves ~spawned] advances [st] by exactly one tick.

    [moves] pairs students with the keys they are holding. Students missing
    from [moves] stand still; this is how a disconnected student stays in
    place, so the server must leave them out (and forget the keys they were
    holding) until they come back. Unknown ids and [Dropped] students are
    ignored. If an id appears more than once, only its first entry counts.
    [spawned] are the new bullets from the scheduler for this tick.

    In phase [Running], the tick happens in this order:
    + Move each [Enrolled] student in [moves] by [speed] along each held
      axis, then clamp the center so the whole square stays inside the
      arena.
    + Move every existing bullet by its velocity. Then add [spawned] at their
      given positions (they do not move on the tick they appear). Then drop
      every bullet whose bounding rectangle (from [Shape.half_extents]) lies
      entirely outside the arena.
    + For each [Enrolled] student, moving or not: if [invuln > 0], decrease
      it by 1 and skip the student (no hit is possible this tick). Otherwise,
      if the student's square overlaps or touches any bullet (by
      [Shape.hits_square]), subtract the largest damage among those bullets
      (at most one hit per tick), clamp the GPA at [0.0], and set [invuln] to
      [invuln_ticks]. A student whose GPA reaches [0.0] becomes [Dropped].
    + Add 1 to [survived] for every student still [Enrolled]. A student
      dropped on this tick does not get this tick.
    + Decrease the ticks left by 1. If none are left, or no student is
      [Enrolled], the phase becomes [Finished].

    So after a hit on tick [T], the student is safe on ticks [T+1] through
    [T + invuln_ticks] and can be hit again on tick [T + invuln_ticks + 1].

    In phases [Lobby] and [Finished], [step] returns [st] unchanged: nobody
    moves, [spawned] is ignored, and the timer does not run.

    For example, with [default_config], an [Enrolled] student at
    [{ x = 300.; y = 200. }] holding only [right] moves to
    [{ x = 304.; y = 200. }]; a student at [{ x = 590.; y = 200. }] holding
    [right] stops at [{ x = 592.; y = 200. }], because half the square (8
    units) must stay inside the 600-unit arena. *)

(** {1 Reading the state} *)

val config : t -> config
(** [config st] is the configuration [st] was created with. *)

val phase : t -> phase
(** [phase st] is the current stage of the round. *)

val students : t -> student list
(** [students st] is every student in [st], whatever their standing, sorted by
    ascending id. *)

val find_student : student_id -> t -> student option
(** [find_student id st] is [Some s] if student [id] is in [st], or [None]. *)

val bullets : t -> bullet list
(** [bullets st] is every bullet currently in the arena, oldest first; bullets
    added on the same tick keep the order they had in [spawned]. *)

val ticks_left : t -> int
(** [ticks_left st] is the number of ticks left in the semester. It is
    [semester_ticks] until the round starts and never negative. It can be
    above [0] when the phase is [Finished], if every student was dropped
    early. *)

val enrolled_count : t -> int
(** [enrolled_count st] is the number of students still [Enrolled], for the
    "students remaining" display. *)

val kills : t -> int
(** [kills st] is the number of students the Professor has knocked out so far:
    those who are [Dropped]. *)

val leaderboard : t -> student list
(** [leaderboard st] is every student, ranked by:
    + higher GPA first;
    + on equal GPA, longer [survived] first;
    + on equal GPA and [survived], ascending id.

    It can be read at any time and is the final ranking once the phase is
    [Finished]. When every student was dropped, all GPAs are [0.0], so the
    ranking is purely by how long each student lasted.

    For example, if [adrian] (id 1) ends [Enrolled] with GPA [2.8] and
    [survived = 5400], [lucy] (id 2) was dropped with [survived = 3000], and
    [armen] (id 3) was dropped with [survived = 4500], the order is [adrian],
    [armen], [lucy]. *)
