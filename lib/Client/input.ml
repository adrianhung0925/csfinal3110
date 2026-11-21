type key =
  | Up
  | Down
  | Left
  | Right

type event =
  | Key_down of string
  | Key_up of string
  | Blur

(* A record of four bools is the same information as [State.dir]; keeping it
   abstract lets us change the representation without touching callers. *)
type t = State.dir

(** [key_of_code code] is the arrow key named by [code], if any. *)
let key_of_code = function
  | "ArrowUp" -> Some Up
  | "ArrowDown" -> Some Down
  | "ArrowLeft" -> Some Left
  | "ArrowRight" -> Some Right
  | _ -> None

(** [empty] holds no keys. *)
let empty : t = { up = false; down = false; left = false; right = false }

(** [held k keys] is whether [k] is held in [keys]. *)
let held k (keys : t) =
  match k with
  | Up -> keys.up
  | Down -> keys.down
  | Left -> keys.left
  | Right -> keys.right

(** [to_dir keys] is the direction for [keys]. *)
let to_dir (keys : t) : State.dir = keys

(** [set k v keys] is [keys] with key [k] held if [v] is true, or released. *)
let set k v (keys : t) : t =
  match k with
  | Up -> { keys with up = v }
  | Down -> { keys with down = v }
  | Left -> { keys with left = v }
  | Right -> { keys with right = v }

(** [apply e keys] is [keys] after event [e]. *)
let apply e keys =
  match e with
  | Blur -> empty
  | Key_down code -> (
      match key_of_code code with
      | Some k -> set k true keys
      | None -> keys)
  | Key_up code -> (
      match key_of_code code with
      | Some k -> set k false keys
      | None -> keys)

(** [update e keys] is [apply e keys] paired with the new direction if it
    changed. *)
let update e keys =
  let keys' = apply e keys in
  let dir = to_dir keys' in
  if dir = to_dir keys then (keys', None) else (keys', Some dir)

(** [can_move standing] is whether a student with [standing] has controls. *)
let can_move = function
  | Some State.Enrolled -> true
  | Some State.Dropped | None -> false
