Will provide a function that takes in keystrokes and sends them to server (called from renderer)

handle_keystrokes : player_input_direction -> unit

Will provide a function that takes in an IP address and port number (from renderer)
first int is IP, second int is port number, string is client ID
set_socket : int -> int -> string -> unit



Will provide a function that gives the clientID
returns the local client ID
get_client_ID : () -> string