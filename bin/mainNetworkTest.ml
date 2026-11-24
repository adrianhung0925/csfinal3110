let usage () =
  Printf.eprintf "Usage:\n  %s client <server-ip> <client-id>\n  %s server\n"
    Sys.argv.(0) Sys.argv.(0);
  exit 2

let run_game_server () =
  let module Server = Networker.Server in
  let game = ref (Gameloop.create State.default_config) in
  let player_ids = Hashtbl.create 8 in
  let connected_clients = Hashtbl.create 8 in
  let next_player_id = ref 0 in
  Server.start_server_background 9000;
  let assign_player client_id =
    match Hashtbl.find_opt player_ids client_id with
    | Some id -> Some id
    | None when State.phase (Gameloop.state !game) = State.Finished -> None
    | None ->
        incr next_player_id;
        let id = !next_player_id in
        let name = Printf.sprintf "P%d" id in
        game := Gameloop.join id ~name !game |> Gameloop.start;
        Hashtbl.add player_ids client_id id;
        Some id
  in
  let handle_event = function
    | Server.Client_connected client_id ->
        Hashtbl.replace connected_clients client_id ();
        ignore (assign_player client_id)
    | Server.Client_disconnected client_id ->
        Hashtbl.remove connected_clients client_id;
        (match Hashtbl.find_opt player_ids client_id with
        | Some id -> game := Gameloop.handle (Gameloop.Disconnect id) !game
        | None -> ())
    | Server.Client_message (client_id, message) ->
        (match
           (Hashtbl.find_opt player_ids client_id, Input_message.of_string message)
         with
        | Some id, Some (Input_message.Key_down key) ->
            game := Gameloop.handle (Gameloop.Key_down (id, key)) !game
        | Some id, Some (Input_message.Key_up key) ->
            game := Gameloop.handle (Gameloop.Key_up (id, key)) !game
        | Some _, Some Input_message.Launch_assignments ->
            game := Gameloop.handle (Gameloop.Launch Gameloop.Assignments) !game
        | _, None ->
            Printf.eprintf "Ignoring invalid input from client %s\n%!" client_id
        | None, Some _ ->
            Printf.eprintf "Ignoring input from unregistered client %s\n%!"
              client_id)
  in
  while true do
    List.iter handle_event (Server.take_events ());
    game := Gameloop.tick !game;
    let snapshots = Gameloop.snapshots !game in
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
          | None ->
              Snapshot.of_state ~viewer:None (Gameloop.state !game)
        in
        ignore
          (Server.send_to_client_if_connected client_id
             (Snapshot.to_string snapshot)))
      connected_clients;
    Unix.sleepf (1. /. 30.)
  done

let () =
  match Array.length Sys.argv with
  | 2 when Sys.argv.(1) = "server" -> run_game_server ()
  | 4 when Sys.argv.(1) = "client" ->
      Networker.Client.start_client Sys.argv.(2) 9000 Sys.argv.(3)
  | _ -> usage ()
