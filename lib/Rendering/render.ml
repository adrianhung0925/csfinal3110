open Js_of_ocaml
open State
open Shape
let background_color = "#151923"
let border_color = "#A8B9B0"
let other_player_color = "#FFF0AC"
let curr_player_color = "#E0A03F"
let projectile_color = "#9e2a2b"
let dangerous_attack_color = "#540b0e"

let get_canvas (id : string) : Dom_html.canvasElement Js.t =
  Option.get (Dom_html.getElementById_coerce id Dom_html.CoerceTo.canvas)

let canvas = get_canvas "game-canvas"

let ctx = canvas##getContext Dom_html._2d_

(* Logical (CSS) size of the game area. All drawing code uses these coords. *)
let logical_width = 800.
let logical_height = 600.

(* Match the canvas backing store to the screen's pixel density so drawing
   stays crisp on high-DPI (e.g. Retina) displays, then scale the context so
   we can keep drawing in 800x600 logical coordinates. Called again whenever
   the window is resized or zoomed, since that changes devicePixelRatio. *)
let setup_canvas () =
  let dpr =
    Js.Optdef.case
      (Js.Unsafe.get Dom_html.window "devicePixelRatio")
      (fun () -> 1.)
      (fun r -> Js.float_of_number r) 
  in
  let dpr = if dpr > 0. then dpr else 1. in
  canvas##.width := int_of_float (Float.round (logical_width *. dpr));
  canvas##.height := int_of_float (Float.round (logical_height *. dpr));
  canvas##.style##.width := Js.string (Printf.sprintf "%.0fpx" logical_width);
  canvas##.style##.height := Js.string (Printf.sprintf "%.0fpx" logical_height);
  ctx##setTransform (Js.number_of_float dpr) (Js.number_of_float 0.)
    (Js.number_of_float 0.) (Js.number_of_float dpr)
    (Js.number_of_float 0.) (Js.number_of_float 0.)

let num = Js.number_of_float

let draw_arena (config : State.config) =
  (* Draw background *)
  ctx##.fillStyle := Js.string background_color;
  ctx##fillRect (num 0.) (num 0.) (num 800.) (num 600.);

  (* Draw arena border *)
  ctx##.strokeStyle := Js.string border_color;
  ctx##.lineWidth := num 2.;
  ctx##strokeRect
    (num 100.)
    (num 100.)
    (num config.arena_w)
    (num config.arena_h)
let draw_player size (s : State.student)  =
  let x = 100. +. s.pos.x -. size /. 2. in
  let y = 100. +. s.pos.y -. size /. 2. in

  (* TODO: determine whether this is the local player *)
  let fill_color = curr_player_color in
  ctx##.fillStyle := Js.string fill_color;

  ctx##fillRect
    (num x)
    (num y)
    (num size)
    (num size)

let draw_circle radius pos =
  let x = fst pos in
  let y = snd pos in 
  ctx##.fillStyle := Js.string projectile_color;
  ctx##beginPath;
  ctx##arc
    (num x)
    (num y)
    (num radius)
    (num 0.)
    (num (2. *. Float.pi))
    Js._false;
  ctx##fill

let draw_rectangle w h pos = 
  let x = fst pos -. w /. 2. in
  let y = snd pos -. h /. 2. in

  ctx##.fillStyle := Js.string projectile_color;
  ctx##fillRect
    (num x)
    (num y)
    (num w)
    (num h)

let draw_text text cell pos =
  let x, y = pos in
  let cols, rows = Shape.text_size text in

  (* Top-left corner of the entire text *)
  let start_x = x -. (float_of_int cols *. cell) /. 2. in
  let start_y = y -. (float_of_int rows *. cell) /. 2. in

  ctx##.fillStyle := Js.string projectile_color;

  List.iter
    (fun (col, row) ->
      let px = start_x +. float_of_int col *. cell in
      let py = start_y +. float_of_int row *. cell in

      ctx##fillRect
        (num px)
        (num py)
        (num cell)
        (num cell))
    (Shape.text_cells text)

let draw_bullet (bullet : State.bullet) =
  let x = 100. +. bullet.center.x in
  let y = 100. +. bullet.center.y in

  match bullet.shape with
  | Shape.Circle { radius } -> draw_circle radius (x,y)
      (* Your code here *)
  | Shape.Rect {w;h} -> draw_rectangle w h (x, y)
  | Shape.Text {text;cell} -> draw_text text cell (x,y)

let render (state:State.t) = 
  let config = State.config state in
  draw_arena config;
  let size_student = config.student_size in
  let students = State.students state in

  List.iter (draw_player size_student) students;
  List.iter draw_bullet (State.bullets state)