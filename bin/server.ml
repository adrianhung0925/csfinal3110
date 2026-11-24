let usage () =
  Printf.eprintf
    "Usage:\n  %s server <port>\n  %s client <server-ip> <port> <client-id>\n"
    Sys.argv.(0) Sys.argv.(0);
  exit 2

let parse_port value =
  match int_of_string_opt value with
  | Some port when port >= 1 && port <= 65535 -> port
  | _ ->
      Printf.eprintf "Invalid port %S: expected an integer from 1 to 65535\n"
        value;
      exit 2

let run_game_server port =
  let game_state = ref (Gameloop.create State.default_config) in

  (*all players who ever connected*)
  let player_ids = Hashtbl.create 8 in
  (*only the active connections*)
  let connected_clients = Hashtbl.create 8 in
  let next_player_id = ref 0 in
  Networker.Server.start_server_background port;
  let assign_player client_id =
    match Hashtbl.find_opt player_ids client_id with
    (*Handle a reconnecting player.*)
    | Some id -> Some id
    (*No new connections when the game is finished*)
    | None when State.phase (Gameloop.state !game_state) = State.Finished ->
        None
    (*Normal new player joining*)
    | None ->
        incr next_player_id;
        let name = Printf.sprintf "P%d" !next_player_id in
        game_state :=
          Gameloop.join !next_player_id ~name !game_state
          |>
          (*Game starts after a single player joins. Lobby should fix this
            later. Also fix starting for every new player*)
          Gameloop.start;
        Hashtbl.add player_ids client_id !next_player_id;
        Some !next_player_id
  in
  let handle_event event =
    match event with
    | Networker.Server.Client_connected client_id ->
        (*replace is just add if it doesn't already exist*)
        Hashtbl.replace connected_clients client_id ();
        ignore (assign_player client_id)
    (*handle a disconnecting player*)
    | Networker.Server.Client_disconnected client_id -> (
        Hashtbl.remove connected_clients client_id;
        match Hashtbl.find_opt player_ids client_id with
        | Some id ->
            game_state := Gameloop.handle (Gameloop.Disconnect id) !game_state
        | None -> ())
    (*Handle client messages like inputs*)
    | Networker.Server.Client_message (client_id, message) -> (
        (*this code currently does the peeling apart of messsages. This code
          should be moved to Game_loop to handle strings?*)
        match
          ( Hashtbl.find_opt player_ids client_id,
            Input_message.of_string message )
        with
        | Some id, Some (Input_message.Key_down key) ->
            game_state :=
              Gameloop.handle (Gameloop.Key_down (id, key)) !game_state
        | Some id, Some (Input_message.Key_up key) ->
            game_state :=
              Gameloop.handle (Gameloop.Key_up (id, key)) !game_state
        | Some _, Some Input_message.Launch_assignments ->
            game_state :=
              Gameloop.handle (Gameloop.Launch Gameloop.Assignments) !game_state
        | _, None ->
            Printf.eprintf "Ignoring invalid input from client %s\n%!" client_id
        | None, Some _ ->
            Printf.eprintf "Ignoring input from unregistered client %s\n%!"
              client_id)
  in

  (*Main game and connection loop. TODO: these should be separated so messaging
    clients can't block the main game update. *)
  while true do
    List.iter handle_event (Networker.Server.take_events ());
    (*in the future game_state updates should be moved to gameloop so that
      game_loop calls tick. This is because the server thread should be
      asynchronous with game logic. *)
    game_state := Gameloop.tick !game_state;

    (*why does each player get their own snapshot?*)
    let snapshots = Gameloop.snapshots !game_state in
    Hashtbl.iter
      (fun client_id () ->
        let snapshot =
          match Hashtbl.find_opt player_ids client_id with
          | Some id -> List.assoc_opt (Some id) snapshots
          | None -> None
        in
        let snapshot =
          match snapshot with
          | Some snapshot -> snapshot
          | None -> Snapshot.of_state ~viewer:None (Gameloop.state !game_state)
        in
        ignore
          (*this should be changed to only follow custom_networker.ml*)
          (Networker.Server.send_to_client_if_connected client_id
             (Snapshot.to_string snapshot)))
      connected_clients;
    Unix.sleepf (1. /. 30.)
  done

let () =
  match Array.length Sys.argv with
  | 3 when Sys.argv.(1) = "server" -> run_game_server (parse_port Sys.argv.(2))
  (*this is for running a client via the CLI which is deprecated as of MS2*)
  | 5 when Sys.argv.(1) = "client" ->
      Networker.Client.start_client Sys.argv.(2)
        (parse_port Sys.argv.(3))
        Sys.argv.(4)
  | _ -> usage ()
