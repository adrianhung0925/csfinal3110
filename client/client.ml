(* The browser client (Artyom). It lets a player join with a username, turns
   arrow-key events into [State.dir] with [Input], and sends each change to the
   server as a [Client_msg] over a WebSocket.

   Open index.html?server=ws://HOST:PORT to connect to a server. Without
   [server], the client runs offline: messages are only logged, and a local
   preview moves the player's square so the input path can be checked by hand.

   TEMPORARY: the preview below copies State.step's movement rule and draws a
   plain square. Both go away once the server sends snapshots: the client will
   then hand each snapshot to Lucy's renderer instead. *)

open Js_of_ocaml
open Csfinal3110

let doc = Dom_html.document

(** [element id] is the page element with id [id]. Raises [Failure] if the page
    has no such element. *)
let element id =
  Js.Opt.get
    (doc##getElementById (Js.string id))
    (fun () -> failwith ("index.html has no element #" ^ id))

let cfg = State.default_config
let keys = ref Input.empty
let standing : State.standing option ref = ref None
let socket : WebSockets.webSocket Js.t option ref = ref None
let preview = ref { State.x = cfg.arena_w /. 2.; State.y = cfg.arena_h /. 2. }

(** [set_text id s] replaces the text of element [id] with [s]. *)
let set_text id s = (element id)##.textContent := Js.some (Js.string s)

(** [log s] adds the line [s] to the top of the on-page log and the console. *)
let log s =
  let pre = element "log" in
  let old = Js.Opt.case pre##.textContent (fun () -> "") Js.to_string in
  let lines = String.split_on_char '\n' old in
  let kept = List.filteri (fun i _ -> i < 30) lines in
  pre##.textContent := Js.some (Js.string (String.concat "\n" (s :: kept)));
  Console.console##log (Js.string s)

(** [dir_label d] lists the keys held in [d], e.g. ["up right"]. *)
let dir_label (d : State.dir) =
  let names =
    List.filter_map
      (fun (held, name) -> if held then Some name else None)
      [ (d.up, "up"); (d.down, "down"); (d.left, "left"); (d.right, "right") ]
  in
  if names = [] then "(none)" else String.concat " " names

(** [show_status ()] updates the status lines from the client's state. *)
let show_status () =
  set_text "held" (dir_label (Input.to_dir !keys));
  set_text "standing"
    (match !standing with
    | None -> "not joined"
    | Some State.Enrolled -> "enrolled (controls on)"
    | Some State.Dropped -> "dropped: spectating (controls off)")

(** [send m] sends [m] to the server if connected, and logs it either way. *)
let send m =
  let s = Client_msg.to_string m in
  match !socket with
  | Some ws when ws##.readyState = WebSockets.OPEN ->
      ws##send (Js.string s);
      log ("sent: " ^ s)
  | _ -> log ("offline, not sent: " ^ s)

(** [handle e] applies keyboard event [e]: while the player may move, it updates
    the held keys and sends a [Move] if the direction changed. *)
let handle e =
  if Input.can_move !standing then begin
    let keys', change = Input.update e !keys in
    keys := keys';
    Option.iter (fun d -> send (Client_msg.Move d)) change;
    show_status ()
  end

(** [stop_controls s] sets the standing to [s] and, if that removes the player's
    controls, releases every key so the server stops moving them. *)
let stop_controls s =
  handle Input.Blur;
  standing := Some s;
  show_status ()

(** [connect url name] opens a WebSocket to [url] and sends [Join name] once it
    is open. *)
let connect url name =
  log ("connecting to " ^ url);
  let ws = new%js WebSockets.webSocket (Js.string url) in
  socket := Some ws;
  ws##.onopen :=
    Dom.handler (fun _ ->
        log "connected";
        send (Client_msg.Join name);
        Js._true);
  ws##.onmessage :=
    Dom.handler (fun ev ->
        (* The snapshot format is not agreed yet (Armen/Anthony), so for now the
           client only shows what the server sent. *)
        log ("received: " ^ Js.to_string ev##.data);
        Js._true);
  ws##.onerror :=
    Dom.handler (fun _ ->
        log "connection error";
        Js._true);
  ws##.onclose :=
    Dom.handler (fun _ ->
        log "connection closed";
        Js._true)

(** [join ()] reads the username box and joins the game. *)
let join () =
  let box = Dom_html.CoerceTo.input (element "name") in
  let name =
    Js.Opt.case box
      (fun () -> "")
      (fun i -> String.trim (Js.to_string i##.value))
  in
  if name = "" then set_text "join-error" "Please type a username."
  else if String.length name > cfg.max_name_len then
    set_text "join-error"
      (Printf.sprintf "Usernames can be at most %d characters." cfg.max_name_len)
  else begin
    set_text "join-error" "";
    (* Until the server confirms the join, assume we are enrolled so the
       controls can be tried. *)
    standing := Some State.Enrolled;
    (match List.assoc_opt "server" Url.Current.arguments with
    | Some url -> connect url name
    | None ->
        log "no ?server=ws://HOST:PORT given: offline preview";
        send (Client_msg.Join name));
    show_status ()
  end

(** [preview_tick ()] moves the preview square one tick, the way [State.step] is
    specified to: [speed] per held axis, opposite keys cancel, and the square
    stays inside the arena. *)
let preview_tick () =
  if !socket = None && !standing = Some State.Enrolled then begin
    let d = Input.to_dir !keys in
    let axis neg pos = (if pos then 1. else 0.) -. if neg then 1. else 0. in
    let half = cfg.student_size /. 2. in
    let clamp lo hi v = Float.max lo (Float.min hi v) in
    let p = !preview in
    preview :=
      {
        x =
          clamp half (cfg.arena_w -. half)
            (p.x +. (cfg.speed *. axis d.left d.right));
        y =
          clamp half (cfg.arena_h -. half)
            (p.y +. (cfg.speed *. axis d.up d.down));
      }
  end

(** [draw ctx] draws the arena outline and the preview square. *)
let draw ctx =
  let f = Js.float in
  ctx##clearRect (f 0.) (f 0.) (f cfg.arena_w) (f cfg.arena_h);
  ctx##.strokeStyle := Js.string "#ffffff";
  ctx##strokeRect (f 1.) (f 1.) (f (cfg.arena_w -. 2.)) (f (cfg.arena_h -. 2.));
  if !standing <> None && !socket = None then begin
    ctx##.fillStyle :=
      Js.string
        (if !standing = Some State.Dropped then "rgba(255,255,255,0.35)"
         else "#ffffff");
    let half = cfg.student_size /. 2. in
    ctx##fillRect
      (f (!preview.x -. half))
      (f (!preview.y -. half))
      (f cfg.student_size) (f cfg.student_size)
  end

(** [key_name ev] is the [KeyboardEvent.key] of [ev], or [""] if missing. *)
let key_name (ev : Dom_html.keyboardEvent Js.t) =
  Js.Optdef.case ev##.key (fun () -> "") Js.to_string

(** [on_key make ev] handles keyboard event [ev] as [make (key_name ev)], and
    stops the page from scrolling when an arrow key is used for movement. *)
let on_key make ev =
  let k = key_name ev in
  handle (make k);
  if Input.key_of_code k <> None && Input.can_move !standing then Js._false
  else Js._true

let () =
  Dom_html.window##.onload :=
    Dom_html.handler (fun _ ->
        let canvas =
          Js.Opt.get
            (Dom_html.CoerceTo.canvas (element "arena"))
            (fun () -> failwith "#arena is not a canvas")
        in
        canvas##.width := int_of_float cfg.arena_w;
        canvas##.height := int_of_float cfg.arena_h;
        let ctx = canvas##getContext Dom_html._2d_ in
        doc##.onkeydown := Dom_html.handler (on_key (fun k -> Input.Key_down k));
        doc##.onkeyup := Dom_html.handler (on_key (fun k -> Input.Key_up k));
        Dom_html.window##.onblur :=
          Dom_html.handler (fun _ ->
              handle Input.Blur;
              Js._true);
        (element "join")##.onclick
        := Dom_html.handler (fun _ ->
            join ();
            Js._false);
        (element "drop")##.onclick
        := Dom_html.handler (fun _ ->
            if !standing <> None then stop_controls State.Dropped;
            Js._false);
        let tick () =
          preview_tick ();
          draw ctx
        in
        ignore
          (Dom_html.window##setInterval
             (Js.wrap_callback tick)
             (Js.float (1000. /. 30.)));
        show_status ();
        Js._true)
