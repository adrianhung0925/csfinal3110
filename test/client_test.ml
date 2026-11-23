(* Tests for the browser client (Artyom): Input (browser key events to key
   changes), Client_msg (the text messages sent to the server), and the whole
   path from a browser key event to a student moving in Gameloop.

   Every expected value was worked out by hand from the .mli specifications, not
   copied from the implementation's output. Positions follow state.mli: a
   student starts at the arena center (300, 200), moves [speed] = 4 units per
   tick along each held axis, and stops when half the 16-unit square (8 units)
   touches a wall, e.g. x = 600 - 8 = 592. *)

open OUnit2

let change_to_string = function
  | Input.Pressed k -> "Pressed " ^ Client_msg.key_name k
  | Input.Released k -> "Released " ^ Client_msg.key_name k

let changes_to_string cs = String.concat "; " (List.map change_to_string cs)

(** [run events] is [(keys, changes)]: the keys held after applying [events] in
    order to [Input.empty], and every change [Input.update] reported. *)
let run events =
  List.fold_left
    (fun (keys, acc) e ->
      let keys', cs = Input.update e keys in
      (keys', acc @ cs))
    (Input.empty, []) events

let changes_test name expected events =
  name >:: fun _ ->
  assert_equal ~printer:changes_to_string expected (snd (run events))

let dir_to_string (d : State.dir) =
  Printf.sprintf "{up=%b; down=%b; left=%b; right=%b}" d.up d.down d.left
    d.right

let no_keys : State.dir =
  { up = false; down = false; left = false; right = false }

let input_tests =
  let open Input in
  let open Gameloop in
  [
    changes_test "nothing happens with no events" [] [];
    changes_test "pressing an arrow key" [ Pressed Up ] [ Key_down "ArrowUp" ];
    changes_test "press then release"
      [ Pressed Left; Released Left ]
      [ Key_down "ArrowLeft"; Key_up "ArrowLeft" ];
    changes_test "auto-repeat is reported once" [ Pressed Right ]
      [ Key_down "ArrowRight"; Key_down "ArrowRight"; Key_down "ArrowRight" ];
    changes_test "releasing a key that is not held" [] [ Key_up "ArrowDown" ];
    changes_test "non-arrow keys are ignored" []
      [ Key_down "a"; Key_down " "; Key_up "Shift"; Key_down "arrowup" ];
    changes_test "two keys held together"
      [ Pressed Up; Pressed Right; Released Up ]
      [ Key_down "ArrowUp"; Key_down "ArrowRight"; Key_up "ArrowUp" ];
    changes_test "blur releases every held key in order"
      [
        Pressed Right;
        Pressed Up;
        Pressed Left;
        Released Up;
        Released Left;
        Released Right;
      ]
      [ Key_down "ArrowRight"; Key_down "ArrowUp"; Key_down "ArrowLeft"; Blur ];
    changes_test "blur with nothing held reports nothing" [] [ Blur ];
    changes_test "keys work again after blur"
      [ Pressed Up; Released Up; Pressed Down ]
      [ Key_down "ArrowUp"; Blur; Key_down "ArrowDown" ];
    changes_test "a key released after blur is not released twice"
      [ Pressed Up; Released Up ]
      [ Key_down "ArrowUp"; Blur; Key_up "ArrowUp" ];
    ( "held and to_dir agree" >:: fun _ ->
      let keys, _ = run [ Key_down "ArrowDown"; Key_down "ArrowRight" ] in
      assert_bool "down" (Input.held Down keys);
      assert_bool "right" (Input.held Right keys);
      assert_bool "not up" (not (Input.held Up keys));
      assert_bool "not left" (not (Input.held Left keys));
      assert_equal ~printer:dir_to_string
        { no_keys with down = true; right = true }
        (to_dir keys) );
    ( "opposite keys are both held" >:: fun _ ->
      let keys, _ = run [ Key_down "ArrowLeft"; Key_down "ArrowRight" ] in
      assert_equal ~printer:dir_to_string
        { no_keys with left = true; right = true }
        (to_dir keys) );
    ( "empty holds nothing" >:: fun _ ->
      assert_equal ~printer:dir_to_string no_keys (to_dir empty) );
    ( "only enrolled students can move" >:: fun _ ->
      assert_bool "enrolled" (can_move (Some State.Enrolled));
      assert_bool "dropped" (not (can_move (Some State.Dropped)));
      assert_bool "not a student yet" (not (can_move None)) );
  ]

let msg_printer = function
  | Ok m -> "Ok " ^ Client_msg.to_string m
  | Error e -> "Error " ^ e

let encode_test name m expected =
  name >:: fun _ ->
  assert_equal ~printer:Fun.id expected (Client_msg.to_string m)

let decode_ok name s expected =
  name >:: fun _ ->
  assert_equal ~printer:msg_printer (Ok expected) (Client_msg.of_string s)

let decode_error name s =
  name >:: fun _ ->
  match Client_msg.of_string s with
  | Ok m -> assert_failure ("expected an error, got " ^ Client_msg.to_string m)
  | Error _ -> ()

let all_keys = Gameloop.[ Up; Down; Left; Right ]

let msg_tests =
  let open Client_msg in
  let open Gameloop in
  [
    encode_test "join" (Join "lucy") "join lucy";
    encode_test "join keeps inner spaces" (Join "big bear") "join big bear";
    encode_test "press up" (Press Up) "down ArrowUp";
    encode_test "release left" (Release Left) "up ArrowLeft";
    encode_test "press right" (Press Right) "down ArrowRight";
    encode_test "release down" (Release Down) "up ArrowDown";
    decode_ok "decode join" "join armen" (Join "armen");
    decode_ok "decode join trims spaces" "join   armen  " (Join "armen");
    decode_ok "decode press" "down ArrowDown" (Press Down);
    decode_ok "decode release" "up ArrowRight" (Release Right);
    decode_error "empty string" "";
    decode_error "no space" "down";
    decode_error "unknown type" "jump ArrowUp";
    decode_error "type is case sensitive" "DOWN ArrowUp";
    decode_error "join with a blank name" "join    ";
    decode_error "not an arrow key" "down a";
    decode_error "key name is case sensitive" "down arrowup";
    decode_error "extra space before key" "down  ArrowUp";
    ( "key_name is the inverse of Gameloop.key_of_string" >:: fun _ ->
      List.iter
        (fun k -> assert_equal (Some k) (Gameloop.key_of_string (key_name k)))
        all_keys );
    ( "every key message round-trips" >:: fun _ ->
      List.iter
        (fun m ->
          assert_equal ~printer:msg_printer (Ok m) (of_string (to_string m)))
        (List.concat_map (fun k -> [ Press k; Release k ]) all_keys) );
    ( "of_change" >:: fun _ ->
      assert_equal (Press Up) (of_change (Input.Pressed Up));
      assert_equal (Release Left) (of_change (Input.Released Left)) );
    ( "to_event adds the sender's id" >:: fun _ ->
      assert_equal (Some (Key_down (7, Up))) (to_event 7 (Press Up));
      assert_equal (Some (Key_up (2, Right))) (to_event 2 (Release Right));
      assert_equal None (to_event 1 (Join "lucy")) );
  ]

(* End to end: what the browser reports for student [id] goes through Input, is
   encoded and decoded as the server would receive it, becomes a Gameloop event,
   and moves the student in the game state. *)

(** [send id changes lp] is [lp] after the server receives, from student [id],
    the message for each change in [changes]. Fails the test if the server
    cannot decode a message the client sends. *)
let send id changes lp =
  List.fold_left
    (fun lp c ->
      let wire = Client_msg.to_string (Client_msg.of_change c) in
      match Client_msg.of_string wire with
      | Error e -> assert_failure ("server could not decode " ^ wire ^ ": " ^ e)
      | Ok m -> (
          match Client_msg.to_event id m with
          | Some ev -> Gameloop.handle ev lp
          | None -> lp))
    lp changes

(** [deliver id events lp] is [lp] after the server receives everything the
    client sends for browser events [events], starting with no keys held. *)
let deliver id events lp = send id (snd (run events)) lp

(** [ticks n lp] is [lp] after [n] ticks. *)
let rec ticks n lp = if n <= 0 then lp else ticks (n - 1) (Gameloop.tick lp)

(** [pos id lp] is student [id]'s position in their own snapshot. *)
let pos id lp =
  match List.assoc_opt (Some id) (Gameloop.snapshots lp) with
  | None -> assert_failure (Printf.sprintf "no snapshot for student %d" id)
  | Some snap -> (
      match Snapshot.me snap with
      | Some s -> (s.State.pos.State.x, s.State.pos.State.y)
      | None -> assert_failure (Printf.sprintf "student %d not in snapshot" id))

let pos_printer (x, y) = Printf.sprintf "(%g, %g)" x y

(** [round ()] is a running round with students 1 ("lucy") and 2 ("armen"), both
    at the arena center. *)
let round () =
  Gameloop.create State.default_config
  |> Gameloop.join 1 ~name:"lucy"
  |> Gameloop.join 2 ~name:"armen"
  |> Gameloop.start

let move_test name events n expected =
  name >:: fun _ ->
  let lp = round () |> deliver 1 events |> ticks n in
  assert_equal ~printer:pos_printer expected (pos 1 lp)

let end_to_end_tests =
  let open Input in
  [
    move_test "no input, no movement" [] 5 (300., 200.);
    move_test "hold right for one tick" [ Key_down "ArrowRight" ] 1 (304., 200.);
    move_test "hold right for three ticks" [ Key_down "ArrowRight" ] 3
      (312., 200.);
    move_test "auto-repeat does not speed up the student"
      [ Key_down "ArrowRight"; Key_down "ArrowRight"; Key_down "ArrowRight" ]
      1 (304., 200.);
    move_test "diagonal up and left"
      [ Key_down "ArrowUp"; Key_down "ArrowLeft" ]
      1 (296., 196.);
    move_test "opposite keys cancel"
      [ Key_down "ArrowLeft"; Key_down "ArrowRight" ]
      3 (300., 200.);
    move_test "press and release before a tick does not move"
      [ Key_down "ArrowDown"; Key_up "ArrowDown" ]
      2 (300., 200.);
    move_test "stops at the right wall" [ Key_down "ArrowRight" ] 100
      (592., 200.);
    move_test "stops at the top wall" [ Key_down "ArrowUp" ] 100 (300., 8.);
    ( "a release the client never saw pressed sends nothing" >:: fun _ ->
      let lp =
        round ()
        |> deliver 1 [ Key_down "ArrowRight" ]
        |> ticks 2
        |> deliver 1 [ Key_up "ArrowRight" ]
        |> ticks 3
      in
      (* The second [deliver] starts from no keys held, so its Key_up is not a
         change and sends nothing: the student keeps moving. This is why the
         client keeps one Input.t for the whole session (next test). *)
      assert_equal ~printer:pos_printer (320., 200.) (pos 1 lp) );
    ( "releasing with the client's real key state stops the student" >:: fun _ ->
      let keys, pressed = run [ Key_down "ArrowRight" ] in
      let _, released = Input.update (Key_up "ArrowRight") keys in
      let lp =
        round () |> send 1 pressed |> ticks 2 |> send 1 released |> ticks 3
      in
      assert_equal ~printer:pos_printer (308., 200.) (pos 1 lp) );
    ( "blur stops the student" >:: fun _ ->
      let keys, pressed = run [ Key_down "ArrowDown"; Key_down "ArrowLeft" ] in
      let _, released = Input.update Blur keys in
      let lp =
        round () |> send 1 pressed |> ticks 1 |> send 1 released |> ticks 3
      in
      assert_equal ~printer:pos_printer (296., 204.) (pos 1 lp) );
    ( "each student moves only their own square" >:: fun _ ->
      let lp =
        round ()
        |> deliver 1 [ Key_down "ArrowRight" ]
        |> deliver 2 [ Key_down "ArrowDown" ]
        |> ticks 2
      in
      assert_equal ~printer:pos_printer (308., 200.) (pos 1 lp);
      assert_equal ~printer:pos_printer (300., 208.) (pos 2 lp) );
  ]

let () =
  run_test_tt_main
    ("client"
    >::: [
           "input" >::: input_tests;
           "msg" >::: msg_tests;
           "end_to_end" >::: end_to_end_tests;
         ])
