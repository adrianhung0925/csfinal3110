let start_server port =
  (*ai generated boilerplate I don't fully understand: *)
  let addr = Unix.ADDR_INET (Unix.inet_addr_any, port) in
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  (* Allow quick restart of the server on the same port *)
  Unix.setsockopt sock Unix.SO_REUSEADDR true;
  Unix.bind sock addr;
  Unix.listen sock 5;
  Printf.printf "Server listening on port %d...\n%!" port;

  let rec handle_messages ic oc =
    match input_line ic with
    | msg ->
        Printf.printf "Received from client: %s\n%!" msg;
        output_string oc ("Echo from server: " ^ msg ^ "\n");
        flush oc;
        handle_messages ic oc
    | exception End_of_file -> ()
  in

  let handle_client client_sock =
    let ic = Unix.in_channel_of_descr client_sock in
    let oc = Unix.out_channel_of_descr client_sock in
    (try
       Fun.protect
         ~finally:(fun () ->
           close_in_noerr ic;
           close_out_noerr oc)
         (fun () -> handle_messages ic oc)
     with Sys_error message ->
       Printf.eprintf "Client connection error: %s\n%!" message);
    Printf.printf "Client disconnected\n%!"
  in

  let rec accept_clients () =
    let client_sock, client_addr = Unix.accept sock in
    (match client_addr with
    | Unix.ADDR_INET (ip, cport) ->
        Printf.printf "Client connected from %s:%d\n%!"
          (Unix.string_of_inet_addr ip)
          cport
    | Unix.ADDR_UNIX _ -> Printf.printf "Unix domain client connected\n%!");

    ignore (Thread.create (fun () -> handle_client client_sock) ());
    accept_clients ()
  in
  accept_clients ()
