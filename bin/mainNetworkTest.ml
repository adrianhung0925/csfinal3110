let usage () =
  Printf.eprintf "Usage:\n  %s client <server-ip> <client-id>\n  %s server\n"
    Sys.argv.(0) Sys.argv.(0);
  exit 2

let parse_ipv4_address ip =
  try
    let address = Unix.inet_addr_of_string ip in
    if String.contains (Unix.string_of_inet_addr address) ':' then
      failwith "IPv6 addresses are not supported";
    address
  with Failure _ ->
    Printf.eprintf "Expected an IPv4 address, got %S\n" ip;
    usage ()

let () =
  match Array.length Sys.argv with
  | 2 when Sys.argv.(1) = "server" -> Networker.Server.start_server 9000
  | 4 when Sys.argv.(1) = "client" ->
      Networker.Client.start_client
        (parse_ipv4_address Sys.argv.(2))
        9000 Sys.argv.(3)
  | _ -> usage ()
