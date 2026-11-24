open OUnit2

let free_port () =
  let socket = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close socket)
    (fun () ->
      Unix.bind socket (Unix.ADDR_INET (Unix.inet_addr_any, 0));
      match Unix.getsockname socket with
      | Unix.ADDR_INET (_, port) -> port
      | Unix.ADDR_UNIX _ -> assert_failure "Expected an IPv4 socket")

let wait_for_server_event predicate deadline =
  let rec wait () =
    match List.find_opt predicate (Networker.Server.take_events ()) with
    | Some event -> event
    | None when Unix.gettimeofday () >= deadline ->
        assert_failure "Timed out waiting for a server event"
    | None ->
        Thread.delay 0.01;
        wait ()
  in
  wait ()

let wait_for_client_message expected deadline =
  let rec wait () =
    let messages = Networker.Client.take_incoming () in
    match List.find_opt (String.equal expected) messages with
    | Some message -> message
    | None when Unix.gettimeofday () >= deadline ->
        assert_failure "Timed out waiting for a client message"
    | None ->
        Thread.delay 0.01;
        wait ()
  in
  wait ()

let test_client_server_round_trip _ =
  let port = free_port () in
  let client_id = "localhost-integration-test" in
  Networker.Server.start_server_background port;
  Networker.Client.start_client "127.0.0.1" port client_id;
  let deadline = Unix.gettimeofday () +. 5. in
  ignore
    (wait_for_server_event
       (function
         | Networker.Server.Client_connected id -> id = client_id
         | _ -> false)
       deadline);

  let input = Input_message.to_string (Input_message.Key_down Gameloop.Left) in
  Networker.Client.send_message input;
  let received_input =
    wait_for_server_event
      (function
        | Networker.Server.Client_message (id, message) ->
            id = client_id && message = input
        | _ -> false)
      deadline
  in
  assert_equal
    (Networker.Server.Client_message (client_id, input))
    received_input;

  let snapshot =
    Snapshot.of_state ~viewer:None (State.init State.default_config)
  in
  let response = Snapshot.to_string snapshot in
  assert_bool "the client should still be connected"
    (Networker.Server.send_to_client_if_connected client_id response);
  let received_response = wait_for_client_message response deadline in
  assert_equal snapshot (Snapshot.of_string received_response)

let () =
  run_test_tt_main
    ("network"
    >::: [ "client_server_round_trip" >:: test_client_server_round_trip ])
