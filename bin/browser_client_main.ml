open Js_of_ocaml

let clients : (int, Networker_browser.Browser_client.t) Hashtbl.t =
  Hashtbl.create 8

let next_handle = ref 0

let status_to_string = function
  | Networker_browser.Browser_client.Connecting -> "connecting"
  | Connected -> "connected"
  | Rejected message -> "rejected:" ^ message
  | Disconnected -> "disconnected"
  | Error message -> "error:" ^ message

let call_js callback message =
  ignore
    (Js.Unsafe.fun_call callback [| Js.Unsafe.inject (Js.string message) |])

let require_callback name callback =
  if Js.to_string (Js.typeof callback) <> "function" then
    invalid_arg ("Csfinal3110Client." ^ name ^ ": callback must be a function")

let get_client handle =
  match Hashtbl.find_opt clients handle with
  | Some client -> client
  | None -> invalid_arg "Csfinal3110Client: unknown client handle"

let () =
  Js.export "Csfinal3110Client"
    object%js
      method connect (url : Js.js_string Js.t) (client_id : Js.js_string Js.t)
          (on_status : Js.Unsafe.any) (on_message : Js.Unsafe.any) : int =
        require_callback "connect" on_status;
        require_callback "connect" on_message;
        incr next_handle;
        let handle = !next_handle in
        let client =
          Networker_browser.Browser_client.connect ~url:(Js.to_string url)
            ~client_id:(Js.to_string client_id)
            ~on_status:(fun status ->
              call_js on_status (status_to_string status))
            ~on_message:(call_js on_message)
        in
        Hashtbl.add clients handle client;
        handle

      method send (handle : int) (message : Js.js_string Js.t) : unit =
        Networker_browser.Browser_client.send (get_client handle)
          (Js.to_string message)

      method close (handle : int) : unit =
        let client = get_client handle in
        Hashtbl.remove clients handle;
        Networker_browser.Browser_client.close client

      method status (handle : int) : Js.js_string Js.t =
        Networker_browser.Browser_client.status (get_client handle)
        |> status_to_string |> Js.string
    end
