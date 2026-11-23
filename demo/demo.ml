open Js_of_ocaml

let me = 1

let loop =
  ref
    (Gameloop.create State.default_config
     |> Gameloop.join me ~name:"me"
     |> Gameloop.start)

let send e = loop := Gameloop.handle e !loop 

let tick () =
  loop := Gameloop.tick !loop;
  match List.assoc_opt (Some me) (Gameloop.snapshots !loop) with
  | Some snap -> Rendering.Render.render snap
  | None -> ()

let key_of ev = Js.Optdef.case ev##.key (fun () -> "") Js.to_string

let () =
  Dom_html.document##.onkeydown :=
    Dom_html.handler (fun ev ->
        let k = key_of ev in
        (match Gameloop.key_of_string k with
         | Some key ->
             send (Gameloop.Key_down (me, key));
             Dom.preventDefault ev
         | None ->
             if k = " " then begin
               send (Gameloop.Launch Gameloop.Assignments);
               Dom.preventDefault ev
             end);
        Js._true);
  Dom_html.document##.onkeyup :=
    Dom_html.handler (fun ev ->
        (match Gameloop.key_of_string (key_of ev) with
         | Some key -> send (Gameloop.Key_up (me, key))
         | None -> ());
        Js._true);
  tick ();
  ignore
    (Js.Unsafe.fun_call
       (Js.Unsafe.js_expr "setInterval")
       [| Js.Unsafe.inject (Js.wrap_callback tick); Js.Unsafe.inject 33 |])