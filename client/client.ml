(* The browser client (Artyom).

   A player types a username and joins. From then on, every arrow-key event goes
   through Input, and each real change (a key starting or stopping being held)
   is sent as one Client_msg.

   Two modes: - Local (default): no server exists yet, so this page runs Armen's
   Gameloop itself as a stand-in server for one student (id 1). Each message is
   still turned into text and decoded again before Client_msg.to_event hands it
   to Gameloop.handle, exactly as the server will. Every tick, the student's
   snapshot is drawn with Lucy's Render.render, and the student's standing from
   Snapshot.me decides whether the controls are on. Key "1" makes the Professor
   launch the Assignments attack, so getting hit and dropped can be tried. -
   Server: open index.html?server=ws://HOST:PORT and the client sends the same
   text messages over a WebSocket. Snapshots from the server are only logged
   until the snapshot text format is agreed. *)

open Js_of_ocaml

let doc = Dom_html.document

(** [element id] is the page element with id [id]. Raises [Failure] if the page
    has no such element. *)
let element id =
  Js.Opt.get
    (doc##getElementById (Js.string id))
    (fun () -> failwith ("index.html has no element #" ^ id))

let cfg = State.default_config

(* In local mode this browser is student 1, the id the server would assign to
   the first player who joins. *)
let me : State.student_id = 1
let keys = ref Input.empty
let standing : State.standing option ref = ref None
let socket : WebSockets.webSocket Js.t option ref = ref None
let local : Gameloop.t option ref = ref None

(** [set_text id s] replaces the text of element [id] with [s]. *)
let set_text id s = (element id)##.textContent := Js.some (Js.string s)

(** [log s] adds the line [s] to the top of the on-page log (keeping the latest
    30 lines) and to the browser console. *)
let log s =
  let pre = element "log" in
  let old = Js.Opt.case pre##.textContent (fun () -> "") Js.to_string in
  let kept = List.filteri (fun i _ -> i < 29) (String.split_on_char '\n' old) in
  pre##.textContent := Js.some (Js.string (String.concat "\n" (s :: kept)));
  Console.console##log (Js.string s)

(** [held_label keys] lists the arrow keys held in [keys], e.g. ["up right"]. *)
let held_label keys =
  let d = Input.to_dir keys in
  let names =
    List.filter_map
      (fun (h, name) -> if h then Some name else None)
      [ (d.up, "up"); (d.down, "down"); (d.left, "left"); (d.right, "right") ]
  in
  if names = [] then "(none)" else String.concat " " names

(** [show_status ()] updates the status line from the client's state. *)
let show_status () =
  set_text "held" (held_label !keys);
  set_text "standing"
    (match !standing with
    | None -> "not joined"
    | Some State.Enrolled -> "enrolled (arrow keys on)"
    | Some State.Dropped -> "dropped: spectating (arrow keys off)")

(** [deliver_locally wire] does what the server will do when text [wire] arrives
    from this student: decode it, attach the student's id, and hand the event to
    [Gameloop.handle]. *)
let deliver_locally wire =
  match !local with
  | None -> ()
  | Some lp -> (
      match Client_msg.of_string wire with
      | Error e -> log ("stand-in server rejected " ^ wire ^ ": " ^ e)
      | Ok m -> (
          match Client_msg.to_event me m with
          | Some ev -> local := Some (Gameloop.handle ev lp)
          | None -> ()))

(** [send m] sends message [m] as text: over the WebSocket in server mode, or to
    the stand-in server in local mode. It logs the text either way. *)
let send m =
  let wire = Client_msg.to_string m in
  match !socket with
  | Some ws ->
      if ws##.readyState = WebSockets.OPEN then begin
        ws##send (Js.string wire);
        log ("sent: " ^ wire)
      end
      else log ("not connected, not sent: " ^ wire)
  | None ->
      deliver_locally wire;
      log ("sent: " ^ wire)

(** [handle e] applies keyboard event [e] while the player controls a square,
    and sends one message per change. *)
let handle e =
  if Input.can_move !standing then begin
    let keys', changes = Input.update e !keys in
    keys := keys';
    List.iter (fun c -> send (Client_msg.of_change c)) changes;
    show_status ()
  end

(** [set_standing s] records the standing the server reports. When the player
    loses their controls, every held key is released first, so the server stops
    moving them. *)
let set_standing s =
  if s <> !standing then begin
    if not (Input.can_move s) then handle Input.Blur;
    standing := s;
    (match s with
    | Some State.Dropped -> log "you were dropped: now spectating"
    | Some State.Enrolled -> log "enrolled: arrow keys move your square"
    | None -> ());
    show_status ()
  end

(** [show_snapshot snap] draws [snap] and updates the player's standing, GPA,
    and the time left from it. *)
let show_snapshot snap =
  Rendering.Render.render snap;
  let mine = Snapshot.me snap in
  set_standing (Option.map (fun (s : State.student) -> s.standing) mine);
  set_text "gpa"
    (match mine with
    | Some s -> Printf.sprintf "%.2f" s.gpa
    | None -> "-");
  set_text "time" (Printf.sprintf "%ds" (snap.Snapshot.ticks_left / 30))

(** [tick ()] advances the stand-in server by one tick and shows this student's
    snapshot. It does nothing in server mode or before joining. *)
let tick () =
  match !local with
  | None -> ()
  | Some lp -> (
      let lp = Gameloop.tick lp in
      local := Some lp;
      match List.assoc_opt (Some me) (Gameloop.snapshots lp) with
      | Some snap -> show_snapshot snap
      | None -> ())

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
        (* The server will report the standing in its snapshots; until that
           format is agreed, assume the join succeeded. *)
        set_standing (Some State.Enrolled);
        Js._true);
  ws##.onmessage :=
    Dom.handler (fun ev ->
        log ("received: " ^ Js.to_string ev##.data);
        Js._true);
  ws##.onerror :=
    Dom.handler (fun _ ->
        log "connection error";
        Js._true);
  ws##.onclose :=
    Dom.handler (fun _ ->
        log "connection closed";
        set_standing None;
        Js._true)

(** [join ()] reads the username box and joins the round, or explains why the
    name is not allowed. *)
let join () =
  let name =
    Js.Opt.case
      (Dom_html.CoerceTo.input (element "name"))
      (fun () -> "")
      (fun i -> String.trim (Js.to_string i##.value))
  in
  if !standing <> None then set_text "join-error" "You have already joined."
  else if name = "" then set_text "join-error" "Please type a username."
  else if String.length name > cfg.max_name_len then
    set_text "join-error"
      (Printf.sprintf "Usernames can be at most %d characters." cfg.max_name_len)
  else begin
    set_text "join-error" "";
    match List.assoc_opt "server" Url.Current.arguments with
    | Some url -> connect url name
    | None ->
        log ("local mode: joined as student 1, " ^ name);
        local :=
          Some (Gameloop.create cfg |> Gameloop.join me ~name |> Gameloop.start)
  end

(** [key_name ev] is the [KeyboardEvent.key] of [ev], or [""] if missing. *)
let key_name (ev : Dom_html.keyboardEvent Js.t) =
  Js.Optdef.case ev##.key (fun () -> "") Js.to_string

(** [is_arrow name] is whether [name] is an arrow key's browser name. *)
let is_arrow name = Gameloop.key_of_string name <> None

(** [typing ()] is whether the username box has the keyboard, so keys are left
    to it. *)
let typing () =
  Js.Opt.case doc##.activeElement
    (fun () -> false)
    (fun el -> Js.to_string el##.id = "name")

let () =
  doc##.onkeydown :=
    Dom_html.handler (fun ev ->
        let k = key_name ev in
        if typing () then Js._true
        else if k = "1" && !local <> None then begin
          local :=
            Option.map
              (Gameloop.handle (Gameloop.Launch Gameloop.Assignments))
              !local;
          log "Professor (local stand-in) launched Assignments";
          Js._true
        end
        else begin
          handle (Input.Key_down k);
          (* Stop the arrow keys from scrolling the page while they move the
             square. *)
          if is_arrow k && Input.can_move !standing then Js._false else Js._true
        end);
  doc##.onkeyup :=
    Dom_html.handler (fun ev ->
        if not (typing ()) then handle (Input.Key_up (key_name ev));
        Js._true);
  Dom_html.window##.onblur :=
    Dom_html.handler (fun _ ->
        handle Input.Blur;
        Js._true);
  (element "join")##.onclick
  := Dom_html.handler (fun _ ->
      join ();
      (* Give the keyboard back to the game after joining. *)
      (element "name")##blur;
      Js._false);
  ignore
    (Dom_html.window##setInterval
       (Js.wrap_callback tick)
       (Js.float (1000. /. 30.)));
  show_status ()
