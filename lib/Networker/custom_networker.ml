(*client only*)
let handle_keystrokes player_input_dir = ()
let set_socket ip port user_id = ()

(**Returns the local client ID*)
let get_client_ID () = "placeholder"

let client_start server_ip port client_id =
  Client.start_client server_ip port client_id

let client_send_message message = Client.send_message message

(*all messages since the last time client_take_incoming was called*)
let client_take_incoming () = Client.take_incoming ()

(*server only*)
let server_start port = Server.start_server_background port

let server_send_message_to_client clientID message =
  Server.send_to_client clientID message

let server_broadcast message = Server.broadcast message
