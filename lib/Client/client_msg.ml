type t =
  | Join of string
  | Move of State.dir

(** [flag held c] is [c] if [held], or ['-'] otherwise. *)
let flag held c = if held then c else '-'

(** [to_string m] is the text encoding of [m]. *)
let to_string = function
  | Join name -> "join " ^ name
  | Move { up; down; left; right } ->
      let s =
        String.init 4 (function
          | 0 -> flag up 'U'
          | 1 -> flag down 'D'
          | 2 -> flag left 'L'
          | _ -> flag right 'R')
      in
      "move " ^ s

(** [parse_flag s i c] is whether position [i] of [s] marks key [c] as held, or
    an error if it is neither [c] nor ['-']. *)
let parse_flag s i c =
  match s.[i] with
  | '-' -> Ok false
  | x when x = c -> Ok true
  | x ->
      Error
        (Printf.sprintf "expected '%c' or '-' at position %d, got '%c'" c i x)

(** [parse_move s] is the direction encoded by the four characters [s]. *)
let parse_move s =
  if String.length s <> 4 then
    Error (Printf.sprintf "move needs 4 characters, got %S" s)
  else
    match
      ( parse_flag s 0 'U',
        parse_flag s 1 'D',
        parse_flag s 2 'L',
        parse_flag s 3 'R' )
    with
    | Ok up, Ok down, Ok left, Ok right -> Ok (Move { up; down; left; right })
    | Error e, _, _, _ | _, Error e, _, _ | _, _, Error e, _ | _, _, _, Error e
      -> Error e

(** [of_string s] is the message encoded by [s], or an error explaining why [s]
    is not a message. *)
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
      | "move" -> parse_move rest
      | _ -> Error (Printf.sprintf "unknown message type %S" tag))
