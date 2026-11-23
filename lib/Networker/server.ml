let send_message oc msg =
  output_string oc (msg ^ "\n");
  flush oc

let clients = ref []
let clients_mutex = Mutex.create ()

let with_clients_lock f =
  Mutex.lock clients_mutex;
  Fun.protect ~finally:(fun () -> Mutex.unlock clients_mutex) f

let send_to_client client_id message =
  with_clients_lock (fun () ->
      match List.assoc_opt client_id !clients with
      | Some oc -> send_message oc message
      | None -> failwith ("No connected client with ID " ^ client_id))

let broadcast message =
  with_clients_lock (fun () ->
      List.iter (fun (_, oc) -> send_message oc message) !clients)

let register_client client_id oc =
  with_clients_lock (fun () ->
      if List.mem_assoc client_id !clients then false
      else (
        clients := (client_id, oc) :: !clients;
        true))

let remove_client client_id =
  with_clients_lock (fun () ->
      clients := List.filter (fun (id, _) -> id <> client_id) !clients)

let start_server port =
  (*ai generated boilerplate I don't fully understand: *)
  let addr = Unix.ADDR_INET (Unix.inet_addr_any, port) in
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  (* Allow quick restart of the server on the same port *)
  Unix.setsockopt sock Unix.SO_REUSEADDR true;
  Unix.bind sock addr;
  Unix.listen sock 5;
  Printf.printf "Server listening on port %d...\n%!" port;

  let rec handle_messages client_id ic =
    match input_line ic with
    | msg ->
        Printf.printf "Received from client %s: %s\n%!" client_id msg;
        send_to_client client_id ("Echo from server: " ^ msg);
        handle_messages client_id ic
    | exception End_of_file -> ()
  in

  let handle_client client_sock oc =
    let ic = Unix.in_channel_of_descr client_sock in
    let client_id = ref None in
    let handle_connection () =
      match input_line ic with
      | exception End_of_file -> ()
      | "" -> send_message oc "ID_REJECTED: client ID cannot be empty"
      | id ->
          if register_client id oc then (
            client_id := Some id;
            send_message oc "ID_ACCEPTED";
            Printf.printf "Client %s connected\n%!" id;
            handle_messages id ic)
          else send_message oc "ID_REJECTED: client ID is already in use"
    in
    (try
       Fun.protect
         ~finally:(fun () ->
           (match !client_id with
           | Some id -> remove_client id
           | None -> ());
           close_in_noerr ic;
           close_out_noerr oc)
         handle_connection
     with Sys_error message ->
       Printf.eprintf "Client connection error: %s\n%!" message);
    match !client_id with
    | Some id -> Printf.printf "Client %s disconnected\n%!" id
    | None -> Printf.printf "Unidentified client disconnected\n%!"
  in

  let rec accept_clients () =
    let client_sock, client_addr = Unix.accept sock in
    let oc = Unix.out_channel_of_descr client_sock in
    (match client_addr with
    | Unix.ADDR_INET (ip, cport) ->
        Printf.printf "Connection from %s:%d\n%!"
          (Unix.string_of_inet_addr ip)
          cport
    | Unix.ADDR_UNIX _ -> Printf.printf "Unix domain connection\n%!");

    ignore (Thread.create (fun () -> handle_client client_sock oc) ());
    accept_clients ()
  in
  accept_clients ()
