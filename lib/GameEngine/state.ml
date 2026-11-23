type vec = {
  x : float;
  y : float;
}

type student_id = int

type config = {
  arena_w : float;
  arena_h : float;
  student_size : float;
  speed : float;
  start_gpa : float;
  invuln_ticks : int;
  semester_ticks : int;
  max_name_len : int;
}

type standing =
  | Enrolled
  | Dropped

type student = {
  id : student_id;
  name : string;
  pos : vec;
  gpa : float;
  invuln : int;
  survived : int;
  standing : standing;
}

type bullet = {
  center : vec;
  vel : vec;
  shape : Shape.t;
  damage : float;
}

type dir = {
  up : bool;
  down : bool;
  left : bool;
  right : bool;
}

type phase =
  | Lobby
  | Running
  | Finished

type t = {
  config : config;
  phase : phase;
  students : student list;  (** Sorted by ascending id. *)
  bullets : bullet list;  (** Oldest first. *)
  ticks_left : int;
}
(* Representation invariant: [students] is sorted by strictly ascending id;
   every student's square is inside the arena; every GPA is between 0.0 and
   [config.start_gpa]; a student is [Dropped] exactly when their GPA is 0.0; [0
   <= ticks_left <= config.semester_ticks]. *)

let default_config =
  {
    arena_w = 600.;
    arena_h = 400.;
    student_size = 16.;
    speed = 4.;
    start_gpa = 4.0;
    invuln_ticks = 30;
    semester_ticks = 5400;
    max_name_len = 16;
  }

(* Creating a round *)

let init c =
  if c.arena_w <= 0. || c.arena_h <= 0. || c.student_size <= 0. then
    invalid_arg "State.init: sizes must be positive"
  else if c.speed <= 0. || c.start_gpa <= 0. then
    invalid_arg "State.init: speed and start_gpa must be positive"
  else if c.student_size > c.arena_w || c.student_size > c.arena_h then
    invalid_arg "State.init: student_size is larger than the arena"
  else if c.invuln_ticks < 0 then
    invalid_arg "State.init: invuln_ticks must not be negative"
  else if c.semester_ticks <= 0 || c.max_name_len <= 0 then
    invalid_arg "State.init: semester_ticks and max_name_len must be positive"
  else
    {
      config = c;
      phase = Lobby;
      students = [];
      bullets = [];
      ticks_left = c.semester_ticks;
    }

(** [insert_by_id s students] is [students] with [s] added so that the list
    stays sorted by ascending id. *)
let rec insert_by_id s students =
  match students with
  | [] -> [ s ]
  | first :: rest ->
      if s.id < first.id then s :: students else first :: insert_by_id s rest

let add_student id ~name st =
  let name = String.trim name in
  if st.phase = Finished then
    invalid_arg "State.add_student: the round has finished"
  else if List.exists (fun s -> s.id = id) st.students then
    invalid_arg ("State.add_student: id " ^ string_of_int id ^ " is taken")
  else if name = "" || String.length name > st.config.max_name_len then
    invalid_arg "State.add_student: name is empty or too long"
  else
    let c = st.config in
    let s =
      {
        id;
        name;
        pos = { x = c.arena_w /. 2.; y = c.arena_h /. 2. };
        gpa = c.start_gpa;
        invuln = 0;
        survived = 0;
        standing = Enrolled;
      }
    in
    { st with students = insert_by_id s st.students }

let start st = if st.phase = Lobby then { st with phase = Running } else st

(******************************************************************************)
(* One tick, in the order documented in state.mli *)

(** [clamp lo hi v] is [v] limited to the range [lo] to [hi]. *)
let clamp lo hi v = if v < lo then lo else if v > hi then hi else v

(** [axis neg pos speed] is the movement along one axis: [-speed] if only the
    negative key is held, [speed] if only the positive one is, and [0.] if
    neither or both are. *)
let axis neg pos speed =
  (if pos then speed else 0.) -. if neg then speed else 0.

(** [move_student c moves s] is [s] after moving by its entry in [moves] (the
    first one, if there are several) and clamping it inside the arena. Dropped
    students and students missing from [moves] do not move. *)
let move_student c moves s =
  match List.assoc_opt s.id moves with
  | None -> s
  | Some d ->
      if s.standing = Dropped then s
      else
        let half = c.student_size /. 2. in
        let x = s.pos.x +. axis d.left d.right c.speed in
        let y = s.pos.y +. axis d.up d.down c.speed in
        {
          s with
          pos =
            {
              x = clamp half (c.arena_w -. half) x;
              y = clamp half (c.arena_h -. half) y;
            };
        }

(** [move_bullet b] is [b] after one tick of moving by its velocity. *)
let move_bullet b =
  { b with center = { x = b.center.x +. b.vel.x; y = b.center.y +. b.vel.y } }

(** [in_arena c b] is whether any part of [b]'s bounding rectangle is inside the
    arena or touching its edge. *)
let in_arena c b =
  let hw, hh = Shape.half_extents b.shape in
  b.center.x +. hw >= 0.
  && b.center.x -. hw <= c.arena_w
  && b.center.y +. hh >= 0.
  && b.center.y -. hh <= c.arena_h

(** [round2 g] is [g] rounded to two decimal places. GPAs are rounded after
    every hit so that repeated float subtraction cannot leave a student at a
    tiny positive GPA such as [6e-16] instead of exactly [0.0]. *)
let round2 g = Float.round (g *. 100.) /. 100.

(** [worst_hit c bullets s] is the largest damage among the bullets in [bullets]
    that touch [s]'s square, or [0.] if none do. *)
let worst_hit c bullets s =
  let half = c.student_size /. 2. in
  List.fold_left
    (fun worst b ->
      let dx = s.pos.x -. b.center.x in
      let dy = s.pos.y -. b.center.y in
      if Shape.hits_square b.shape ~dx ~dy ~half then Float.max worst b.damage
      else worst)
    0. bullets

(** [hit_student c bullets s] is [s] after this tick's invulnerability and hit
    check. *)
let hit_student c bullets s =
  if s.standing = Dropped then s
  else if s.invuln > 0 then { s with invuln = s.invuln - 1 }
  else
    let damage = worst_hit c bullets s in
    if damage <= 0. then s
    else
      let gpa = round2 (s.gpa -. damage) in
      if gpa <= 0. then
        { s with gpa = 0.; invuln = c.invuln_ticks; standing = Dropped }
      else { s with gpa; invuln = c.invuln_ticks }

(** [count_enrolled students] is how many of [students] are [Enrolled]. *)
let count_enrolled students =
  List.length (List.filter (fun s -> s.standing = Enrolled) students)

let step st ~moves ~spawned =
  if st.phase <> Running then st
  else
    let c = st.config in
    (* 1. Students move. *)
    let students = List.map (move_student c moves) st.students in
    (* 2. Old bullets move, new ones are added where they are, and bullets that
       have left the arena are dropped. *)
    let bullets =
      List.filter (in_arena c) (List.map move_bullet st.bullets @ spawned)
    in
    (* 3. Invulnerability and hits. *)
    let students = List.map (hit_student c bullets) students in
    (* 4. Survival time for everyone still enrolled. *)
    let students =
      List.map
        (fun s ->
          if s.standing = Enrolled then { s with survived = s.survived + 1 }
          else s)
        students
    in
    (* 5. The timer, and the end of the round. An empty round keeps running so
       that students can still join. *)
    let ticks_left = st.ticks_left - 1 in
    let everyone_dropped = students <> [] && count_enrolled students = 0 in
    let phase =
      if ticks_left = 0 || everyone_dropped then Finished else Running
    in
    { st with students; bullets; ticks_left; phase }

(******************************************************************************)
(* Reading the state *)

let config st = st.config
let phase st = st.phase
let students st = st.students
let find_student id st = List.find_opt (fun s -> s.id = id) st.students
let bullets st = st.bullets
let ticks_left st = st.ticks_left
let enrolled_count st = count_enrolled st.students

let kills st =
  List.length (List.filter (fun s -> s.standing = Dropped) st.students)

(** [rank a b] orders students for the leaderboard: higher GPA first, then
    longer survival, then ascending id. *)
let rank a b =
  if a.gpa <> b.gpa then compare b.gpa a.gpa
  else if a.survived <> b.survived then compare b.survived a.survived
  else compare a.id b.id

let leaderboard st = List.sort rank st.students
