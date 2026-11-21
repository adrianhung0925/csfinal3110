type key =
  | Up
  | Down
  | Left
  | Right

type attack = Assignments

type event =
  | Key_down of State.student_id * key
  | Key_up of State.student_id * key
  | Disconnect of State.student_id
  | Launch of attack

type t = {
  state : State.t;
  keys : (State.student_id * State.dir) list;
  launch : attack option;
}

let no_keys : State.dir =
  { up = false; down = false; left = false; right = false }

let create c = { state = State.init c; keys = []; launch = None }
let join id ~name lp = { lp with state = State.add_student id ~name lp.state }
let start lp = { lp with state = State.start lp.state }

let key_of_string = function
  | "ArrowUp" -> Some Up
  | "ArrowDown" -> Some Down
  | "ArrowLeft" -> Some Left
  | "ArrowRight" -> Some Right
  | _ -> None

let held id lp =
  match List.assoc_opt id lp.keys with
  | Some d -> d
  | None -> no_keys

let set_key k b (d : State.dir) : State.dir =
  match k with
  | Up -> { d with up = b }
  | Down -> { d with down = b }
  | Left -> { d with left = b }
  | Right -> { d with right = b }

let update_key id k b lp =
  let d = set_key k b (held id lp) in
  { lp with keys = (id, d) :: List.remove_assoc id lp.keys }

let handle e lp =
  match e with
  | Key_down (id, k) -> update_key id k true lp
  | Key_up (id, k) -> update_key id k false lp
  | Disconnect id -> { lp with keys = List.remove_assoc id lp.keys }
  | Launch a -> { lp with launch = Some a }

let spawn (c : State.config) = function
  | Assignments ->
      [
        {
          State.center = { x = 0.; y = c.arena_h /. 2. };
          vel = { x = 4.; y = 0. };
          shape = Shape.Text { text = "A1"; cell = 12. };
          damage = 1.0;
        };
      ]

let tick lp =
  let spawned =
    match lp.launch with
    | None -> []
    | Some a -> spawn (State.config lp.state) a
  in
  { lp with state = State.step lp.state ~moves:lp.keys ~spawned; launch = None }

let state lp = lp.state

let snapshots lp =
  let snap viewer = (viewer, Snapshot.of_state ~viewer lp.state) in
  snap None
  :: List.map
       (fun (s : State.student) -> snap (Some s.id))
       (State.students lp.state)

let replay lp frames =
  List.fold_left
    (fun lp events -> tick (List.fold_left (fun lp e -> handle e lp) lp events))
    lp frames
