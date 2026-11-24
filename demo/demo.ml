open Js_of_ocaml

let connection : Networker_browser.Browser_client.t option ref = ref None

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

let connect () =
  let url_input = input_element "server-url" in
  let client_id_input = input_element "client-id" in
  let url = Js.to_string url_input##.value in
  let client_id = Js.to_string client_id_input##.value in
  if url = "" || client_id = "" then
    set_status "Enter a WebSocket URL and a unique client ID."
  else (
    Option.iter Networker_browser.Browser_client.close !connection;
    try
      connection :=
        Some
          (Networker_browser.Browser_client.connect ~url ~client_id
             ~on_status:(fun status -> set_status (status_to_string status))
             ~on_message:(fun message ->
               try Rendering.Render.render (Snapshot.of_string message)
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
      (match Gameloop.key_of_string k with
      | Some key ->
          send_input (Input_message.Key_down key);
          Dom.preventDefault ev
      | None ->
          if k = " " then begin
            send_input Input_message.Launch_assignments;
            Dom.preventDefault ev
          end);
      Js._true);
  Dom_html.document##.onkeyup
  := Dom_html.handler (fun ev ->
      (match Gameloop.key_of_string (key_of ev) with
      | Some key -> send_input (Input_message.Key_up key)
      | None -> ());
      Js._true)
