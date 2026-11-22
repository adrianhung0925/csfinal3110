let start_client server_ip port =
  let addr = Unix.ADDR_INET (server_ip, port) in
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.connect sock addr;
  Printf.printf "Connected to server on port %d\n%!" port;

  let ic = Unix.in_channel_of_descr sock in
  let oc = Unix.out_channel_of_descr sock in

  let send_message msg =
    output_string oc (msg ^ "\n");
    flush oc;
    let reply = input_line ic in
    Printf.printf "Server replied: %s\n%!" reply
  in

  let rec send_more_messages () =
    Printf.printf "Message (Ctrl-D to disconnect): %!";
    match input_line stdin with
    | msg ->
        send_message msg;
        send_more_messages ()
    | exception End_of_file -> ()
  in

  send_message "Hello from OCaml client";
  send_more_messages ();

  close_in_noerr ic;
  close_out_noerr oc
