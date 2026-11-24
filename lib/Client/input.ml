type event =
  | Key_down of string
  | Key_up of string
  | Blur

type change =
  | Pressed of Gameloop.key
  | Released of Gameloop.key

(* The keys held are exactly the information in a State.dir. *)
type t = State.dir

(** [empty] holds no keys. *)
let empty : t = { up = false; down = false; left = false; right = false }

(** [held k keys] is whether [k] is held in [keys]. *)
let held k (keys : t) =
  match k with
  | Gameloop.Up -> keys.up
  | Gameloop.Down -> keys.down
  | Gameloop.Left -> keys.left
  | Gameloop.Right -> keys.right

(** [to_dir keys] is the [State.dir] for [keys]. *)
let to_dir (keys : t) : State.dir = keys

(** [set k v keys] is [keys] with [k] held if [v], or released if not. *)
let set k v (keys : t) : t =
  match k with
  | Gameloop.Up -> { keys with up = v }
  | Gameloop.Down -> { keys with down = v }
  | Gameloop.Left -> { keys with left = v }
  | Gameloop.Right -> { keys with right = v }

(** [all_keys] is every arrow key, in the order [Blur] releases them. *)
let all_keys = [ Gameloop.Up; Gameloop.Down; Gameloop.Left; Gameloop.Right ]

(** [update e keys] is the keys held after [e], with the changes [e] made. *)
let update e keys =
  match e with
  | Blur ->
      ( empty,
        List.filter_map
          (fun k -> if held k keys then Some (Released k) else None)
          all_keys )
  | Key_down name -> (
      match Gameloop.key_of_string name with
      | Some k when not (held k keys) -> (set k true keys, [ Pressed k ])
      | _ -> (keys, []))
  | Key_up name -> (
      match Gameloop.key_of_string name with
      | Some k when held k keys -> (set k false keys, [ Released k ])
      | _ -> (keys, []))

(** [to_message c] is the message that tells the server about [c]. *)
let to_message = function
  | Pressed k -> Input_message.Key_down k
  | Released k -> Input_message.Key_up k

(** [can_move standing] is whether a player with [standing] controls a square.
*)
let can_move = function
  | Some State.Enrolled -> true
  | Some State.Dropped | None -> false
