open Js_of_ocaml

let connection : Networker_browser.Browser_client.t option ref = ref None

(* Keyboard state (Artyom): the arrow keys this player holds, and their standing
   from the latest snapshot. Only real changes are sent; see
   lib/Client/input.mli. *)
let keys = ref Input.empty
let standing : State.standing option ref = ref None

let input_element id =
  Option.get (Dom_html.getElementById_coerce id Dom_html.CoerceTo.input)

let status_element = Dom_html.getElementById "connection-status"

let set_status message =
  status_element##.textContent := Js.Opt.return (Js.string message)

let status_to_string = function
  | Networker_browser.Browser_client.Connecting -> "Connecting..."
  | Connected -> "Connected"
  | Rejected message -> "Rejected: " ^ message
  | Disconnected -> "Disconnected"
  | Error message -> "Connection error: " ^ message

let send_input input =
  match !connection with
  | Some client
    when Networker_browser.Browser_client.status client
         = Networker_browser.Browser_client.Connected -> (
      try
        Networker_browser.Browser_client.send client
          (Input_message.to_string input)
      with Invalid_argument error -> set_status error)
  | Some _ | None -> ()

(** [handle_key e] applies keyboard event [e] while this player controls a
    square, and sends one message for each arrow key that starts or stops being
    held. Auto-repeated key-downs send nothing, and [Input.Blur] releases every
    held key. *)
let handle_key e =
  if Input.can_move !standing then begin
    let keys', changes = Input.update e !keys in
    keys := keys';
    List.iter (fun c -> send_input (Input.to_message c)) changes
  end

(** [set_standing s] records this player's standing from a snapshot. When the
    player loses their controls (they were dropped), every held key is released
    first, so the server stops moving them. *)
let set_standing s =
  if s <> !standing then begin
    if not (Input.can_move s) then handle_key Input.Blur;
    standing := s
  end

(** [show_snapshot snap] draws [snap] and updates this player's standing. *)
let show_snapshot snap =
  Rendering.Render.render snap;
  set_standing
    (Option.map (fun (s : State.student) -> s.standing) (Snapshot.me snap))

(** [typing ()] is whether a text box has the keyboard, so keys are left to it
    instead of moving the square. *)
let typing () =
  Js.Opt.case
    Dom_html.document##.activeElement
    (fun () -> false)
    (fun el -> Js.to_string el##.tagName = "INPUT")

let connect () =
  let url_input = input_element "server-url" in
  let client_id_input = input_element "client-id" in
  let url = Js.to_string url_input##.value in
  let client_id = Js.to_string client_id_input##.value in
  if url = "" || client_id = "" then
    set_status "Enter a WebSocket URL and a unique client ID."
  else (
    Option.iter Networker_browser.Browser_client.close !connection;
    keys := Input.empty;
    standing := None;
    try
      connection :=
        Some
          (Networker_browser.Browser_client.connect ~url ~client_id
             ~on_status:(fun status -> set_status (status_to_string status))
             ~on_message:(fun message ->
               try show_snapshot (Snapshot.of_string message)
               with Failure error ->
                 set_status ("Invalid game snapshot: " ^ error)));
      set_status "Connecting..."
    with Invalid_argument error -> set_status error)

let key_of ev = Js.Optdef.case ev##.key (fun () -> "") Js.to_string

let () =
  let connect_button =
    Option.get
      (Dom_html.getElementById_coerce "connect-button" Dom_html.CoerceTo.button)
  in
  connect_button##.onclick :=
    Dom_html.handler (fun _ ->
        connect ();
        Js._false);
  Dom_html.document##.onkeydown
  := Dom_html.handler (fun ev ->
      let k = key_of ev in
      (if not (typing ()) then
         match Gameloop.key_of_string k with
         | Some _ ->
             handle_key (Input.Key_down k);
             Dom.preventDefault ev
         | None ->
             if k = " " then begin
               send_input Input_message.Launch_assignments;
               Dom.preventDefault ev
             end);
      Js._true);
  Dom_html.document##.onkeyup
  := Dom_html.handler (fun ev ->
      if not (typing ()) then handle_key (Input.Key_up (key_of ev));
      Js._true);
  (* Switching tabs or windows hides the key releases from the page, so release
     every held key now. *)
  Dom_html.window##.onblur :=
    Dom_html.handler (fun _ ->
        handle_key Input.Blur;
        Js._true)
