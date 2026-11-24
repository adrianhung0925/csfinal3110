open OUnit2

(******************************************************************************)
(* Helpers *)

let c = State.default_config
let pp_vec (v : State.vec) = Printf.sprintf "(%g, %g)" v.x v.y
let pp_ids ids = "[" ^ String.concat "; " (List.map string_of_int ids) ^ "]"

let pp_phase p =
  match p with
  | State.Lobby -> "Lobby"
  | State.Running -> "Running"
  | State.Finished -> "Finished"

let keys ?(up = false) ?(down = false) ?(left = false) ?(right = false) () :
    State.dir =
  { up; down; left; right }

(** [assert_raises_invalid f] checks that [f ()] raises [Invalid_argument],
    whatever its message. *)
let assert_raises_invalid f =
  match f () with
  | _ -> assert_failure "expected Invalid_argument"
  | exception Invalid_argument _ -> ()

(** [student id st] is student [id] in [st]; fails the test if missing. *)
let student id st =
  match State.find_student id st with
  | Some s -> s
  | None -> assert_failure ("no student " ^ string_of_int id)

(** [round ?config ids] is a running round with students [ids] (named "s1",
    "s2", ...) at the center of the arena. *)
let round ?(config = c) ids =
  State.start
    (List.fold_left
       (fun st id -> State.add_student id ~name:("s" ^ string_of_int id) st)
       (State.init config) ids)

(** [steps n ?moves ?spawned st] is [st] after [n] ticks with the same [moves],
    and [spawned] only on the first of them. *)
let steps n ?(moves = []) ?(spawned = []) st =
  let rec go i st =
    if i = 0 then st
    else
      let spawned = if i = n then spawned else [] in
      go (i - 1) (State.step st ~moves ~spawned)
  in
  go n st

(** [dot x y damage] is a still circle bullet of radius 1 at [(x, y)]. *)
let dot x y damage : State.bullet =
  {
    center = { x; y };
    vel = { x = 0.; y = 0. };
    shape = Shape.Circle { radius = 1. };
    damage;
  }

let pos_test name moves expected =
  name >:: fun _ ->
  let st = State.step (round [ 1 ]) ~moves:[ (1, moves) ] ~spawned:[] in
  assert_equal expected (student 1 st).pos ~printer:pp_vec

(******************************************************************************)
(* Setting up a round *)

let setup_tests =
  [
    ( "init starts an empty lobby" >:: fun _ ->
      let st = State.init c in
      assert_equal State.Lobby (State.phase st) ~printer:pp_phase;
      assert_equal 5400 (State.ticks_left st) ~printer:string_of_int;
      assert_equal [] (State.students st);
      assert_equal [] (State.bullets st) );
    ( "init rejects a bad config" >:: fun _ ->
      let bad c = assert_raises_invalid (fun () -> State.init c) in
      bad { c with arena_w = 0. };
      bad { c with student_size = 700. };
      bad { c with invuln_ticks = -1 };
      bad { c with semester_ticks = 0 } );
    ( "add_student: trimmed name, center, full GPA" >:: fun _ ->
      let st = State.add_student 3 ~name:"  adrian " (State.init c) in
      let s = student 3 st in
      assert_equal "adrian" s.name ~printer:Fun.id;
      assert_equal { State.x = 300.; y = 200. } s.pos ~printer:pp_vec;
      assert_equal 4.0 s.gpa ~printer:string_of_float;
      assert_equal 0 s.survived ~printer:string_of_int;
      assert_equal State.Enrolled s.standing );
    ( "add_student: bad names and duplicate ids are rejected" >:: fun _ ->
      let st = State.add_student 1 ~name:"a" (State.init c) in
      assert_raises_invalid (fun () -> State.add_student 1 ~name:"b" st);
      assert_raises_invalid (fun () -> State.add_student 2 ~name:"   " st);
      assert_raises_invalid (fun () ->
          State.add_student 2 ~name:(String.make 17 'x') st);
      ignore (State.add_student 2 ~name:(String.make 16 'x') st) );
    ( "a student can join a running round" >:: fun _ ->
      (* Student 1 plays 2 ticks alone, then student 2 joins at the center and
         holds right for 1 tick: 300 + 4 = 304. Student 1 has finished 3 ticks,
         student 2 only the 1 after joining. *)
      let st = steps 2 (round [ 1 ]) in
      let st = State.add_student 2 ~name:"late" st in
      assert_equal State.Running (State.phase st) ~printer:pp_phase;
      assert_equal { State.x = 300.; y = 200. } (student 2 st).pos
        ~printer:pp_vec;
      assert_equal 4.0 (student 2 st).gpa ~printer:string_of_float;
      let st = State.step st ~moves:[ (2, keys ~right:true ()) ] ~spawned:[] in
      assert_equal { State.x = 304.; y = 200. } (student 2 st).pos
        ~printer:pp_vec;
      assert_equal 3 (student 1 st).survived ~printer:string_of_int;
      assert_equal 1 (student 2 st).survived ~printer:string_of_int );
    ( "add_student after the round finished is rejected" >:: fun _ ->
      let config = { c with semester_ticks = 1 } in
      let st = State.step (round ~config [ 1 ]) ~moves:[] ~spawned:[] in
      assert_equal State.Finished (State.phase st) ~printer:pp_phase;
      assert_raises_invalid (fun () -> State.add_student 9 ~name:"late" st) );
    ( "students are sorted by id" >:: fun _ ->
      let ids st = List.map (fun (s : State.student) -> s.id) st in
      assert_equal [ 1; 2; 3 ]
        (ids (State.students (round [ 3; 1; 2 ])))
        ~printer:pp_ids );
    ( "start only changes the lobby" >:: fun _ ->
      let st = round [ 1 ] in
      assert_equal State.Running (State.phase st) ~printer:pp_phase;
      assert_equal st (State.start st) );
    ( "find_student of a missing id" >:: fun _ ->
      assert_equal None (State.find_student 7 (round [ 1 ])) );
  ]

(******************************************************************************)
(* Movement *)

let movement_tests =
  [
    pos_test "right" (keys ~right:true ()) { x = 304.; y = 200. };
    pos_test "up" (keys ~up:true ()) { x = 300.; y = 196. };
    pos_test "diagonal is not normalized"
      (keys ~up:true ~right:true ())
      { x = 304.; y = 196. };
    pos_test "opposite keys cancel"
      (keys ~left:true ~right:true ())
      { x = 300.; y = 200. };
    ( "clamped at the right wall" >:: fun _ ->
      (* 300 + 4 * 73 = 592 = 600 - 8, so after 80 ticks it is stuck there. *)
      let st = steps 80 ~moves:[ (1, keys ~right:true ()) ] (round [ 1 ]) in
      assert_equal
        { State.x = 592.; y = 200. }
        (student 1 st).pos ~printer:pp_vec );
    ( "clamped in the top-left corner" >:: fun _ ->
      let st =
        steps 80 ~moves:[ (1, keys ~up:true ~left:true ()) ] (round [ 1 ])
      in
      assert_equal { State.x = 8.; y = 8. } (student 1 st).pos ~printer:pp_vec
    );
    ( "missing from moves stands still; unknown ids are ignored" >:: fun _ ->
      let st =
        State.step (round [ 1 ]) ~moves:[ (5, keys ~right:true ()) ] ~spawned:[]
      in
      assert_equal
        { State.x = 300.; y = 200. }
        (student 1 st).pos ~printer:pp_vec );
    ( "only the first entry for an id counts" >:: fun _ ->
      let st =
        State.step (round [ 1 ])
          ~moves:[ (1, keys ~right:true ()); (1, keys ~left:true ()) ]
          ~spawned:[]
      in
      assert_equal
        { State.x = 304.; y = 200. }
        (student 1 st).pos ~printer:pp_vec );
    ( "nothing moves in the lobby" >:: fun _ ->
      let lobby = State.add_student 1 ~name:"a" (State.init c) in
      let st =
        State.step lobby ~moves:[ (1, keys ~right:true ()) ] ~spawned:[]
      in
      assert_equal lobby st );
  ]

(******************************************************************************)
(* Timer, results, and the end of the round *)

let round_tests =
  [
    ( "the timer counts down" >:: fun _ ->
      assert_equal 5399
        (State.ticks_left (State.step (round [ 1 ]) ~moves:[] ~spawned:[]))
        ~printer:string_of_int );
    ( "the round finishes when the timer runs out" >:: fun _ ->
      let config = { c with semester_ticks = 3 } in
      let st = steps 2 (round ~config [ 1 ]) in
      assert_equal State.Running (State.phase st) ~printer:pp_phase;
      let st = State.step st ~moves:[] ~spawned:[] in
      assert_equal State.Finished (State.phase st) ~printer:pp_phase;
      assert_equal 0 (State.ticks_left st) ~printer:string_of_int;
      assert_equal st (State.step st ~moves:[] ~spawned:[ dot 300. 200. 1. ]) );
    ( "a round with no students keeps running until someone joins" >:: fun _ ->
      (* 3 empty ticks (5400 - 3 = 5397), then student 1 joins and plays one
         tick (5396). *)
      let st = steps 3 (round []) in
      assert_equal State.Running (State.phase st) ~printer:pp_phase;
      assert_equal 5397 (State.ticks_left st) ~printer:string_of_int;
      let st = State.add_student 1 ~name:"first" st in
      let st = State.step st ~moves:[] ~spawned:[] in
      assert_equal State.Running (State.phase st) ~printer:pp_phase;
      assert_equal 5396 (State.ticks_left st) ~printer:string_of_int;
      assert_equal 1 (student 1 st).survived ~printer:string_of_int );
  ]

let tests =
  "State" >::: setup_tests @ movement_tests @ round_tests
