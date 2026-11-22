let usage () =
  Printf.eprintf "Usage: %s <client|server>\n" Sys.argv.(0);
  exit 2

let () =
  match Array.length Sys.argv with
  | 2 -> (
      match Sys.argv.(1) with
      | "client" -> Networker.Client.start_client 9000
      | "server" -> Networker.Server.start_server 9000
      | _ -> usage ())
  | _ -> usage ()
