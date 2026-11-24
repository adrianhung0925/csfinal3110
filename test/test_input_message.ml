open OUnit2

let test_round_trip _ =
  let inputs =
    [
      Input_message.Key_down Gameloop.Up;
      Input_message.Key_down Gameloop.Down;
      Input_message.Key_down Gameloop.Left;
      Input_message.Key_down Gameloop.Right;
      Input_message.Key_up Gameloop.Up;
      Input_message.Key_up Gameloop.Down;
      Input_message.Key_up Gameloop.Left;
      Input_message.Key_up Gameloop.Right;
      Input_message.Launch_assignments;
    ]
  in
  List.iter
    (fun input ->
      assert_equal (Some input)
        (Input_message.of_string (Input_message.to_string input)))
    inputs

let test_reject_invalid_messages _ =
  List.iter
    (fun message -> assert_equal None (Input_message.of_string message))
    [ ""; "KEY_DOWN:ArrowForward"; "LAUNCH:UNKNOWN"; "KEY_UP:ArrowLeft:extra" ]

let tests =
  "input_message"
  >::: [
         "round_trip" >:: test_round_trip;
         "reject_invalid_messages" >:: test_reject_invalid_messages;
       ]
