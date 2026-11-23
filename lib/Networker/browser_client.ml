open Js_of_ocaml

type status =
  | Connecting
  | Connected
  | Rejected of string
  | Disconnected
  | Error of string

type t = {
  socket : WebSockets.webSocket Js.t;
  on_status : status -> unit;
  on_message : string -> unit;
  mutable current_status : status;
}

let set_status client status =
  client.current_status <- status;
  client.on_status status

let connect ~url ~client_id ~on_status ~on_message =
  if not (WebSockets.is_supported ()) then
    invalid_arg "Browser_client.connect: WebSockets are not supported";
  let socket = new%js WebSockets.webSocket (Js.string url) in
  let client =
    { socket; on_status; on_message; current_status = Connecting }
  in
  on_status Connecting;
  socket##.onopen
  := Dom.handler (fun _ ->
         socket##send (Js.string client_id);
         Js._false);
  socket##.onmessage
  := Dom.handler (fun event ->
         let message = Js.to_string event##.data in
         if message = "ID_ACCEPTED" then set_status client Connected
         else if String.starts_with ~prefix:"ID_REJECTED:" message then
           set_status client (Rejected message)
         else on_message message;
         Js._false);
  socket##.onerror
  := Dom.handler (fun _ ->
         set_status client (Error "WebSocket connection error");
         Js._false);
  socket##.onclose
  := Dom.handler (fun _ ->
         (match client.current_status with
         | Rejected _ | Error _ -> ()
         | _ -> set_status client Disconnected);
         Js._false);
  client

let status client = client.current_status

let send client message =
  if
    client.current_status <> Connected
    || client.socket##.readyState <> WebSockets.OPEN
  then invalid_arg "Browser_client.send: client is not connected";
  client.socket##send (Js.string message)

let close client = client.socket##close
