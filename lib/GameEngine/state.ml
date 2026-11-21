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

type t = unit (* TODO: replace with the real round state *)

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

let init _ = failwith "TODO: State.init"
let add_student _ ~name:_ _ = failwith "TODO: State.add_student"
let start _ = failwith "TODO: State.start"
let step _ ~moves:_ ~spawned:_ = failwith "TODO: State.step"
let config _ = failwith "TODO: State.config"
let phase _ = failwith "TODO: State.phase"
let students _ = failwith "TODO: State.students"
let find_student _ _ = failwith "TODO: State.find_student"
let bullets _ = failwith "TODO: State.bullets"
let ticks_left _ = failwith "TODO: State.ticks_left"
let enrolled_count _ = failwith "TODO: State.enrolled_count"
let kills _ = failwith "TODO: State.kills"
let leaderboard _ = failwith "TODO: State.leaderboard"
