(*these are used for encoding client pressed to the server and decoding*)

type t =
  | Key_down of Gameloop.key
  | Key_up of Gameloop.key
  | Launch_assignments

let key_to_string = function
  | Gameloop.Up -> "ArrowUp"
  | Gameloop.Down -> "ArrowDown"
  | Gameloop.Left -> "ArrowLeft"
  | Gameloop.Right -> "ArrowRight"

let to_string = function
  | Key_down key -> "KEY_DOWN:" ^ key_to_string key
  | Key_up key -> "KEY_UP:" ^ key_to_string key
  | Launch_assignments -> "LAUNCH:ASSIGNMENTS"

let of_string message =
  match String.split_on_char ':' message with
  | [ "KEY_DOWN"; key_name ] ->
      Option.map (fun key -> Key_down key) (Gameloop.key_of_string key_name)
  | [ "KEY_UP"; key_name ] ->
      Option.map (fun key -> Key_up key) (Gameloop.key_of_string key_name)
  | [ "LAUNCH"; "ASSIGNMENTS" ] -> Some Launch_assignments
  | _ -> None
