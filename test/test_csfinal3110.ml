(* Runs every test suite in the project. Add each module's suite to this
   list. *)

let () = OUnit2.run_test_tt_main (OUnit2.test_list [ Test_client.tests ])
