type t =
  | Join of string
  | Press of Gameloop.key
  | Release of Gameloop.key

(** [of_change c] is the message that reports [c]. *)
let of_change = function
  | Input.Pressed k -> Press k
  | Input.Released k -> Release k

(** [key_name k] is the browser's name for [k]. *)
let key_name = function
  | Gameloop.Up -> "ArrowUp"
  | Gameloop.Down -> "ArrowDown"
  | Gameloop.Left -> "ArrowLeft"
  | Gameloop.Right -> "ArrowRight"

(** [to_string m] is the text encoding of [m]. *)
let to_string = function
  | Join name -> "join " ^ name
  | Press k -> "down " ^ key_name k
  | Release k -> "up " ^ key_name k

(** [parse_key make name] is [Ok (make k)] if [name] names arrow key [k], or an
    error. *)
let parse_key make name =
  match Gameloop.key_of_string name with
  | Some k -> Ok (make k)
  | None -> Error (Printf.sprintf "%S is not an arrow key" name)

(** [of_string s] is the message encoded by [s], or an error saying why [s] is
    not a message. *)
let of_string s =
  match String.index_opt s ' ' with
  | None -> Error (Printf.sprintf "no message type in %S" s)
  | Some i -> (
      let tag = String.sub s 0 i in
      let rest = String.sub s (i + 1) (String.length s - i - 1) in
      match tag with
      | "join" ->
          let name = String.trim rest in
          if name = "" then Error "join needs a non-empty name"
          else Ok (Join name)
      | "down" -> parse_key (fun k -> Press k) rest
      | "up" -> parse_key (fun k -> Release k) rest
      | _ -> Error (Printf.sprintf "unknown message type %S" tag))

(** [to_event id m] is the [Gameloop] input for message [m] from student [id],
    if any. *)
let to_event id = function
  | Join _ -> None
  | Press k -> Some (Gameloop.Key_down (id, k))
  | Release k -> Some (Gameloop.Key_up (id, k))
