(** Runs every OUnit suite. Each module's tests live in their own file and are
    added to the list below. *)

open OUnit2

let () =
  run_test_tt_main
    ("csfinal3110"
    >::: [ Test_shape.tests; Test_state.tests; Test_input_message.tests ])
