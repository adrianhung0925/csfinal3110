(* Tests for the browser client's pure parts: Input (keyboard events to
   State.dir) and Client_msg (the text messages sent to the server). Every
   expected value below was worked out by hand from the .mli specifications, not
   copied from the implementation's output. *)

open OUnit2
open Csfinal3110

let no_keys : State.dir =
  { up = false; down = false; left = false; right = false }

(** [dir_to_string d] shows which keys [d] holds, for test failure messages. *)
let dir_to_string (d : State.dir) =
  Printf.sprintf "{up=%b; down=%b; left=%b; right=%b}" d.up d.down d.left
    d.right

(** [feed events] is the key set after applying [events] in order to
    [Input.empty]. *)
let feed events = List.fold_left (fun k e -> Input.apply e k) Input.empty events

(** [changes events] is the list of direction changes [Input.update] reports
    while [events] are applied in order to [Input.empty]. *)
let changes events =
  let _, out =
    List.fold_left
      (fun (k, acc) e ->
        let k', c = Input.update e k in
        ( k',
          match c with
          | Some d -> d :: acc
          | None -> acc ))
      (Input.empty, []) events
  in
  List.rev out

let dir_test name expected events =
  name >:: fun _ ->
  assert_equal ~printer:dir_to_string expected (Input.to_dir (feed events))

let input_tests =
  let open Input in
  [
    ( "key names" >:: fun _ ->
      assert_equal (Some Up) (key_of_code "ArrowUp");
      assert_equal (Some Down) (key_of_code "ArrowDown");
      assert_equal (Some Left) (key_of_code "ArrowLeft");
      assert_equal (Some Right) (key_of_code "ArrowRight");
      assert_equal None (key_of_code "a");
      assert_equal None (key_of_code "arrowup");
      assert_equal None (key_of_code "") );
    dir_test "no events holds nothing" no_keys [];
    dir_test "one key down" { no_keys with up = true } [ Key_down "ArrowUp" ];
    dir_test "diagonal"
      { no_keys with up = true; right = true }
      [ Key_down "ArrowUp"; Key_down "ArrowRight" ];
    dir_test "press then release" no_keys
      [ Key_down "ArrowLeft"; Key_up "ArrowLeft" ];
    dir_test "release one of two keys"
      { no_keys with right = true }
      [ Key_down "ArrowUp"; Key_down "ArrowRight"; Key_up "ArrowUp" ];
    (* Opposite keys are both reported; State.step is the one that cancels. *)
    dir_test "opposite keys both held"
      { no_keys with left = true; right = true }
      [ Key_down "ArrowLeft"; Key_down "ArrowRight" ];
    dir_test "non-arrow keys ignored"
      { no_keys with down = true }
      [ Key_down "ArrowDown"; Key_down " "; Key_down "w"; Key_up "Shift" ];
    dir_test "release of a key never pressed" no_keys [ Key_up "ArrowUp" ];
    dir_test "blur releases everything" no_keys
      [ Key_down "ArrowUp"; Key_down "ArrowLeft"; Blur ];
    dir_test "keys work again after blur"
      { no_keys with down = true }
      [ Key_down "ArrowUp"; Blur; Key_down "ArrowDown" ];
    ( "held agrees with to_dir" >:: fun _ ->
      let k = feed [ Key_down "ArrowDown"; Key_down "ArrowRight" ] in
      assert_bool "down" (held Down k);
      assert_bool "right" (held Right k);
      assert_bool "not up" (not (held Up k));
      assert_bool "not left" (not (held Left k)) );
    ( "auto-repeat sends only once" >:: fun _ ->
      assert_equal
        [ { no_keys with up = true } ]
        (changes [ Key_down "ArrowUp"; Key_down "ArrowUp"; Key_down "ArrowUp" ])
    );
    ( "press and release each send" >:: fun _ ->
      assert_equal
        [ { no_keys with left = true }; no_keys ]
        (changes [ Key_down "ArrowLeft"; Key_up "ArrowLeft" ]) );
    ( "ignored keys send nothing" >:: fun _ ->
      assert_equal [] (changes [ Key_down "x"; Key_up "x"; Key_up "ArrowUp" ])
    );
    ( "blur with nothing held sends nothing" >:: fun _ ->
      assert_equal [] (changes [ Blur ]) );
    ( "blur while moving sends a stop" >:: fun _ ->
      assert_equal
        [ { no_keys with right = true }; no_keys ]
        (changes [ Key_down "ArrowRight"; Blur ]) );
    ( "update returns the applied keys" >:: fun _ ->
      let k, _ = update (Key_down "ArrowUp") empty in
      assert_bool "up held" (held Up k) );
    ( "only enrolled students move" >:: fun _ ->
      assert_bool "enrolled" (can_move (Some State.Enrolled));
      assert_bool "dropped" (not (can_move (Some State.Dropped)));
      assert_bool "not joined" (not (can_move None)) );
  ]

let msg_printer = function
  | Ok m -> "Ok " ^ Client_msg.to_string m
  | Error e -> "Error " ^ e

let encode_test name msg expected =
  name >:: fun _ ->
  assert_equal ~printer:Fun.id expected (Client_msg.to_string msg)

let decode_ok name s expected =
  name >:: fun _ ->
  assert_equal ~printer:msg_printer (Ok expected) (Client_msg.of_string s)

let decode_error name s =
  name >:: fun _ ->
  match Client_msg.of_string s with
  | Ok m -> assert_failure ("expected an error, got " ^ Client_msg.to_string m)
  | Error _ -> ()

let all_dirs =
  let b = [ false; true ] in
  List.concat_map
    (fun up ->
      List.concat_map
        (fun down ->
          List.concat_map
            (fun left ->
              List.map (fun right : State.dir -> { up; down; left; right }) b)
            b)
        b)
    b

let msg_tests =
  let open Client_msg in
  [
    encode_test "join" (Join "adrian") "join adrian";
    encode_test "join with inner space" (Join "big bear") "join big bear";
    encode_test "move nothing" (Move no_keys) "move ----";
    encode_test "move up right"
      (Move { no_keys with up = true; right = true })
      "move U--R";
    encode_test "move all"
      (Move { up = true; down = true; left = true; right = true })
      "move UDLR";
    decode_ok "decode join" "join lucy" (Join "lucy");
    decode_ok "decode join trims" "join   lucy  " (Join "lucy");
    decode_ok "decode move" "move -D-R"
      (Move { no_keys with down = true; right = true });
    decode_error "empty string" "";
    decode_error "no space" "move";
    decode_error "unknown tag" "jump UDLR";
    decode_error "join with blank name" "join    ";
    decode_error "move too short" "move U-";
    decode_error "move too long" "move U--R-";
    decode_error "move letters out of order" "move DULR";
    decode_error "move lowercase" "move u---";
    decode_error "tag is case sensitive" "MOVE ----";
    ( "every direction round-trips" >:: fun _ ->
      List.iter
        (fun d ->
          assert_equal ~printer:msg_printer (Ok (Move d))
            (of_string (to_string (Move d))))
        all_dirs;
      assert_equal 16 (List.length all_dirs) );
  ]

let tests = "client" >::: [ "input" >::: input_tests; "msg" >::: msg_tests ]
