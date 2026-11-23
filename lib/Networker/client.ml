let output_channel = ref None
let send_mutex = Mutex.create ()
let incoming_messages = Queue.create ()
let incoming_mutex = Mutex.create ()

let with_send_lock f =
  Mutex.lock send_mutex;
  Fun.protect ~finally:(fun () -> Mutex.unlock send_mutex) f

let with_incoming_lock f =
  Mutex.lock incoming_mutex;
  Fun.protect ~finally:(fun () -> Mutex.unlock incoming_mutex) f

let enqueue_incoming message =
  with_incoming_lock (fun () -> Queue.add message incoming_messages)

let take_incoming () =
  with_incoming_lock (fun () ->
      let rec drain messages =
        if Queue.is_empty incoming_messages then List.rev messages
        else drain (Queue.take incoming_messages :: messages)
      in
      drain [])

let send_message msg =
  with_send_lock (fun () ->
      match !output_channel with
      | None -> invalid_arg "Client.send_message: client is not connected"
      | Some oc ->
          output_string oc (msg ^ "\n");
          flush oc)

let parse_ipv4_address ip =
  let address =
    try Unix.inet_addr_of_string ip
    with Failure _ ->
      invalid_arg
        (Printf.sprintf "Client.start_client: expected an IPv4 address, got %S"
           ip)
  in
  if String.contains (Unix.string_of_inet_addr address) ':' then
    invalid_arg
      (Printf.sprintf "Client.start_client: IPv6 is not supported, got %S" ip);
  address

let start_client server_ip port client_id =
  let addr = Unix.ADDR_INET (parse_ipv4_address server_ip, port) in
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.connect sock addr;

  let ic = Unix.in_channel_of_descr sock in
  let oc = Unix.out_channel_of_descr sock in

  let close_connection () =
    with_send_lock (fun () ->
        output_channel := None;
        close_in_noerr ic;
        close_out_noerr oc)
  in

  let rec receive_messages () =
    match input_line ic with
    | message ->
        enqueue_incoming message;
        receive_messages ()
    | exception End_of_file -> Printf.printf "Server disconnected\n%!"
    | exception Sys_error message ->
        Printf.eprintf "Connection error: %s\n%!" message
  in

  output_string oc (client_id ^ "\n");
  flush oc;
  match input_line ic with
  | "ID_ACCEPTED" ->
      Printf.printf "Connected to server on port %d as %s\n%!" port client_id;
      with_send_lock (fun () -> output_channel := Some oc);
      ignore
        (Thread.create
           (fun () -> Fun.protect ~finally:close_connection receive_messages)
           ())
  | rejection ->
      Printf.eprintf "Connection rejected: %s\n%!" rejection;
      close_in_noerr ic;
      close_out_noerr oc
