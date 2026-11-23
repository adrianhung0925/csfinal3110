let usage () =
  Printf.eprintf "Usage:\n  %s client <server-ip> <client-id>\n  %s server\n"
    Sys.argv.(0) Sys.argv.(0);
  exit 2

let () =
  match Array.length Sys.argv with
  | 2 when Sys.argv.(1) = "server" -> Networker.Server.start_server 9000
  | 4 when Sys.argv.(1) = "client" ->
      Networker.Client.start_client Sys.argv.(2) 9000 Sys.argv.(3)
  | _ -> usage ()
