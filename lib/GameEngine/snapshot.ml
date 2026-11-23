type t = {
  viewer : State.student_id option;
  config : State.config;
  phase : State.phase;
  ticks_left : int;
  students : State.student list;
  bullets : State.bullet list;
  enrolled : int;
  kills : int;
  leaderboard : State.student list;
}
[@@deriving yojson]

let of_state ~viewer st =
  {
    viewer;
    config = State.config st;
    phase = State.phase st;
    ticks_left = State.ticks_left st;
    students = State.students st;
    bullets = State.bullets st;
    enrolled = State.enrolled_count st;
    kills = State.kills st;
    leaderboard =
      (if State.phase st = State.Finished then State.leaderboard st else []);
  }

let me snap =
  match snap.viewer with
  | None -> None
  | Some id ->
      List.find_opt (fun (s : State.student) -> s.id = id) snap.students

let to_string snap = Yojson.Safe.to_string (to_yojson snap)

let of_string str =
  match of_yojson (Yojson.Safe.from_string str) with
  | Ok snap -> snap
  | Error msg -> failwith ("Snapshot.of_string: " ^ msg)
  | exception Yojson.Json_error msg -> failwith ("Snapshot.of_string: " ^ msg)
