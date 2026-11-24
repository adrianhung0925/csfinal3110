(** Tests for [Gameloop]: setting up a round, recording inputs, ticking,
    attacks, per-player snapshots, and replaying recorded inputs.

    Every test builds its own loop from [State.default_config] (a 600 by 400
    arena, squares of side 16, speed 4, GPA 4.0, 30 ticks of invulnerability, a
    5400-tick semester), so students start at the center [(300, 200)]. *)

open OUnit2
open Gameloop

(******************************************************************************)
(* Helpers *)

let c = State.default_config
let pp_vec (v : State.vec) = Printf.sprintf "(%g, %g)" v.x v.y

let pp_phase = function
  | State.Lobby -> "Lobby"
  | State.Running -> "Running"
  | State.Finished -> "Finished"

let pp_dir (d : State.dir) =
  Printf.sprintf "{up=%b; down=%b; left=%b; right=%b}" d.up d.down d.left
    d.right

let pp_viewers vs =
  "["
  ^ String.concat "; "
      (List.map
         (function
           | None -> "None"
           | Some id -> "Some " ^ string_of_int id)
         vs)
  ^ "]"

let dir ?(up = false) ?(down = false) ?(left = false) ?(right = false) () :
    State.dir =
  { up; down; left; right }

let no_keys = dir ()

(** [assert_raises_invalid f] checks that [f ()] raises [Invalid_argument],
    whatever its message. *)
let assert_raises_invalid f =
  match f () with
  | _ -> assert_failure "expected Invalid_argument"
  | exception Invalid_argument _ -> ()

(** [loop ?config ids] is a started loop with students [ids], named "s1", "s2",
    and so on, all at the center of the arena. *)
let loop ?(config = c) ids =
  start
    (List.fold_left
       (fun lp id -> join id ~name:("s" ^ string_of_int id) lp)
       (create config) ids)

(** [student id lp] is student [id] in [lp]; fails the test if missing. *)
let student id lp =
  match State.find_student id (state lp) with
  | Some s -> s
  | None -> assert_failure ("no student " ^ string_of_int id)

let pos id lp = (student id lp).pos

(** [ticks n lp] is [lp] after [n] ticks with no new input. *)
let rec ticks n lp = if n = 0 then lp else ticks (n - 1) (tick lp)

let assert_pos expected id lp =
  assert_equal expected (pos id lp) ~printer:pp_vec

(** The one bullet that [Launch Assignments] spawns with [default_config]. *)
let a1 : State.bullet =
  {
    center = { x = 0.; y = 200. };
    vel = { x = 4.; y = 0. };
    shape = Shape.Text { text = "A1"; cell = 12. };
    damage = 1.0;
  }

(******************************************************************************)
(* Setting up a round *)

let setup_tests =
  [
    ( "create: empty lobby, no keys held, no attack waiting" >:: fun _ ->
      let lp = create c in
      assert_equal State.Lobby (State.phase (state lp)) ~printer:pp_phase;
      assert_equal 5400 (State.ticks_left (state lp)) ~printer:string_of_int;
      assert_equal [] (State.students (state lp));
      assert_equal no_keys (held 1 lp) ~printer:pp_dir;
      (* No attack waiting: starting and ticking spawns nothing. *)
      assert_equal [] (State.bullets (state (tick (start lp)))) );
    ( "create rejects a bad config like State.init" >:: fun _ ->
      assert_raises_invalid (fun () -> create { c with arena_w = 0. });
      assert_raises_invalid (fun () -> create { c with semester_ticks = 0 }) );
    ( "join adds a student at the center with full GPA" >:: fun _ ->
      let lp = join 7 ~name:" armen " (create c) in
      let s = student 7 lp in
      assert_equal "armen" s.name ~printer:Fun.id;
      assert_equal { State.x = 300.; y = 200. } s.pos ~printer:pp_vec;
      assert_equal 4.0 s.gpa ~printer:string_of_float );
    ( "join rejects duplicate ids and bad names" >:: fun _ ->
      let lp = join 1 ~name:"a" (create c) in
      assert_raises_invalid (fun () -> join 1 ~name:"b" lp);
      assert_raises_invalid (fun () -> join 2 ~name:"   " lp);
      assert_raises_invalid (fun () -> join 2 ~name:(String.make 17 'x') lp) );
    ( "start moves Lobby to Running and is idempotent" >:: fun _ ->
      let lp = start (create c) in
      assert_equal State.Running (State.phase (state lp)) ~printer:pp_phase;
      assert_equal State.Running
        (State.phase (state (start lp)))
        ~printer:pp_phase );
    ( "a student can join a running round and move" >:: fun _ ->
      let lp = ticks 3 (loop [ 1 ]) in
      let lp = join 2 ~name:"late" lp in
      let lp = tick (handle (Key_down (2, Down)) lp) in
      assert_pos { x = 300.; y = 204. } 2 lp );
  ]

(******************************************************************************)
(* key_of_string *)

let key_of_string_tests =
  let case name s expected =
    name >:: fun _ -> assert_equal expected (key_of_string s)
  in
  [
    case "ArrowUp" "ArrowUp" (Some Up);
    case "ArrowDown" "ArrowDown" (Some Down);
    case "ArrowLeft" "ArrowLeft" (Some Left);
    case "ArrowRight" "ArrowRight" (Some Right);
    case "a letter is not an arrow" "a" None;
    case "empty string" "" None;
    case "names are case-sensitive" "arrowup" None;
    case "no surrounding spaces allowed" " ArrowUp" None;
  ]

(******************************************************************************)
(* handle: recording keys *)

let handle_tests =
  [
    ( "Key_down records the key but nothing moves before tick" >:: fun _ ->
      let lp = handle (Key_down (1, Right)) (loop [ 1 ]) in
      assert_equal (dir ~right:true ()) (held 1 lp) ~printer:pp_dir;
      assert_pos { x = 300.; y = 200. } 1 lp );
    ( "several keys can be held at once" >:: fun _ ->
      let lp =
        loop [ 1 ] |> handle (Key_down (1, Up)) |> handle (Key_down (1, Left))
      in
      assert_equal (dir ~up:true ~left:true ()) (held 1 lp) ~printer:pp_dir );
    ( "Key_up releases only that key" >:: fun _ ->
      let lp =
        loop [ 1 ]
        |> handle (Key_down (1, Up))
        |> handle (Key_down (1, Left))
        |> handle (Key_up (1, Up))
      in
      assert_equal (dir ~left:true ()) (held 1 lp) ~printer:pp_dir );
    ( "pressing a held key twice is the same as once" >:: fun _ ->
      let once = handle (Key_down (1, Down)) (loop [ 1 ]) in
      let twice = handle (Key_down (1, Down)) once in
      assert_equal (held 1 once) (held 1 twice) ~printer:pp_dir;
      assert_equal (pos 1 (tick once)) (pos 1 (tick twice)) ~printer:pp_vec );
    ( "releasing a key that is not held changes nothing" >:: fun _ ->
      let lp = handle (Key_down (1, Right)) (loop [ 1 ]) in
      let lp = handle (Key_up (1, Left)) lp in
      assert_equal (dir ~right:true ()) (held 1 lp) ~printer:pp_dir;
      assert_equal no_keys
        (held 2 (handle (Key_up (2, Up)) (loop [ 2 ])))
        ~printer:pp_dir );
    ( "each student's keys are separate" >:: fun _ ->
      let lp =
        loop [ 1; 2 ]
        |> handle (Key_down (1, Up))
        |> handle (Key_down (2, Down))
      in
      assert_equal (dir ~up:true ()) (held 1 lp) ~printer:pp_dir;
      assert_equal (dir ~down:true ()) (held 2 lp) ~printer:pp_dir );
    ( "Disconnect forgets every held key" >:: fun _ ->
      let lp =
        loop [ 1; 2 ]
        |> handle (Key_down (1, Up))
        |> handle (Key_down (1, Right))
        |> handle (Key_down (2, Left))
        |> handle (Disconnect 1)
      in
      assert_equal no_keys (held 1 lp) ~printer:pp_dir;
      assert_equal (dir ~left:true ()) (held 2 lp) ~printer:pp_dir );
    ( "held is all false for an unknown id" >:: fun _ ->
      assert_equal no_keys (held 42 (loop [ 1 ])) ~printer:pp_dir );
    ( "keys from a non-student are recorded but move nobody" >:: fun _ ->
      let lp = handle (Key_down (9, Right)) (loop [ 1 ]) in
      assert_equal (dir ~right:true ()) (held 9 lp) ~printer:pp_dir;
      let lp = tick lp in
      assert_pos { x = 300.; y = 200. } 1 lp;
      assert_equal None (State.find_student 9 (state lp)) );
    ( "handle does not change the loop it was given" >:: fun _ ->
      let lp = loop [ 1 ] in
      ignore (handle (Key_down (1, Up)) lp);
      assert_equal no_keys (held 1 lp) ~printer:pp_dir );
  ]

(******************************************************************************)
(* tick: movement and phases *)

let tick_tests =
  [
    ( "a held key moves the student by speed each tick" >:: fun _ ->
      let lp = tick (handle (Key_down (1, Right)) (loop [ 1 ])) in
      assert_pos { x = 304.; y = 200. } 1 lp;
      (* The key stays held, so the next tick moves again. *)
      assert_pos { x = 308.; y = 200. } 1 (tick lp) );
    ( "each direction moves the right way" >:: fun _ ->
      let moved k = pos 1 (tick (handle (Key_down (1, k)) (loop [ 1 ]))) in
      assert_equal { State.x = 300.; y = 196. } (moved Up) ~printer:pp_vec;
      assert_equal { State.x = 300.; y = 204. } (moved Down) ~printer:pp_vec;
      assert_equal { State.x = 296.; y = 200. } (moved Left) ~printer:pp_vec;
      assert_equal { State.x = 304.; y = 200. } (moved Right) ~printer:pp_vec );
    ( "a diagonal moves speed along both axes" >:: fun _ ->
      let lp =
        loop [ 1 ] |> handle (Key_down (1, Up)) |> handle (Key_down (1, Right))
      in
      assert_pos { x = 304.; y = 196. } 1 (tick lp) );
    ( "opposite keys cancel" >:: fun _ ->
      let lp =
        loop [ 1 ]
        |> handle (Key_down (1, Left))
        |> handle (Key_down (1, Right))
      in
      assert_pos { x = 300.; y = 200. } 1 (tick lp) );
    ( "releasing the key stops the student" >:: fun _ ->
      let lp = tick (handle (Key_down (1, Right)) (loop [ 1 ])) in
      let lp = tick (handle (Key_up (1, Right)) lp) in
      assert_pos { x = 304.; y = 200. } 1 lp );
    ( "a disconnected student stands still" >:: fun _ ->
      let lp = tick (handle (Key_down (1, Up)) (loop [ 1 ])) in
      let lp = ticks 5 (handle (Disconnect 1) lp) in
      assert_pos { x = 300.; y = 196. } 1 lp;
      assert_equal State.Enrolled (student 1 lp).standing );
    ( "the arena wall stops the student" >:: fun _ ->
      (* 300 + 4 * 100 would be 700, but half the square (8) must stay in. *)
      let lp = ticks 100 (handle (Key_down (1, Right)) (loop [ 1 ])) in
      assert_pos { x = 592.; y = 200. } 1 lp );
    ( "tick counts down the semester" >:: fun _ ->
      assert_equal 5397
        (State.ticks_left (state (ticks 3 (loop [ 1 ]))))
        ~printer:string_of_int );
    ( "in the Lobby, tick changes nothing" >:: fun _ ->
      let lp = join 1 ~name:"a" (create c) in
      let lp = ticks 2 (handle (Key_down (1, Right)) lp) in
      assert_equal State.Lobby (State.phase (state lp)) ~printer:pp_phase;
      assert_equal 5400 (State.ticks_left (state lp)) ~printer:string_of_int;
      assert_pos { x = 300.; y = 200. } 1 lp );
    ( "the round finishes when the timer runs out" >:: fun _ ->
      let lp = loop ~config:{ c with semester_ticks = 2 } [ 1 ] in
      let lp = ticks 2 (handle (Key_down (1, Right)) lp) in
      assert_equal State.Finished (State.phase (state lp)) ~printer:pp_phase;
      assert_pos { x = 308.; y = 200. } 1 lp;
      (* Finished: further ticks do nothing. *)
      assert_pos { x = 308.; y = 200. } 1 (ticks 3 lp) );
  ]

(******************************************************************************)
(* Attacks *)

let attack_tests =
  [
    ( "Launch Assignments spawns one A1 bullet on the left wall" >:: fun _ ->
      let lp = tick (handle (Launch Assignments) (loop [ 1 ])) in
      assert_equal [ a1 ] (State.bullets (state lp)) );
    ( "nothing spawns before the tick" >:: fun _ ->
      let lp = handle (Launch Assignments) (loop [ 1 ]) in
      assert_equal [] (State.bullets (state lp)) );
    ( "the attack is used up after one tick and the bullet moves" >:: fun _ ->
      let lp = ticks 2 (handle (Launch Assignments) (loop [ 1 ])) in
      match State.bullets (state lp) with
      | [ b ] ->
          assert_equal { State.x = 4.; y = 200. } b.center ~printer:pp_vec
      | bs ->
          assert_failure
            (Printf.sprintf "expected 1 bullet, got %d" (List.length bs)) );
    ( "launching twice before a tick starts only one attack" >:: fun _ ->
      let lp =
        loop [ 1 ]
        |> handle (Launch Assignments)
        |> handle (Launch Assignments)
        |> tick
      in
      assert_equal 1
        (List.length (State.bullets (state lp)))
        ~printer:string_of_int );
    ( "the bullet is at half the arena's height" >:: fun _ ->
      let config = { c with arena_h = 300. } in
      let lp = tick (handle (Launch Assignments) (loop ~config [ 1 ])) in
      match State.bullets (state lp) with
      | [ b ] ->
          assert_equal { State.x = 0.; y = 150. } b.center ~printer:pp_vec
      | _ -> assert_failure "expected exactly 1 bullet" );
    ( "a launch in the Lobby is thrown away" >:: fun _ ->
      let lp = join 1 ~name:"a" (create c) in
      let lp = tick (handle (Launch Assignments) lp) in
      let lp = tick (start lp) in
      assert_equal [] (State.bullets (state lp)) );
    ( "the assignment hits a student who walks into it" >:: fun _ ->
      (* Student 1 walks left into the bullet; it costs 1.0 GPA, once. *)
      let lp =
        loop [ 1 ]
        |> handle (Launch Assignments)
        |> handle (Key_down (1, Left))
        |> ticks 60
      in
      assert_equal 3.0 (student 1 lp).gpa ~printer:string_of_float );
  ]

(******************************************************************************)
(* snapshots *)

let viewers lp = List.map fst (snapshots lp)

let snapshot_tests =
  [
    ( "Professor first, then students in ascending id order" >:: fun _ ->
      let lp = loop [ 3; 1; 2 ] in
      assert_equal
        [ None; Some 1; Some 2; Some 3 ]
        (viewers lp) ~printer:pp_viewers );
    ( "only the Professor when nobody has joined" >:: fun _ ->
      assert_equal [ None ] (viewers (create c)) ~printer:pp_viewers );
    ( "each snapshot is Snapshot.of_state for its viewer" >:: fun _ ->
      let lp =
        loop [ 1; 2 ]
        |> handle (Key_down (1, Right))
        |> handle (Launch Assignments)
        |> tick
      in
      List.iter
        (fun (viewer, snap) ->
          assert_equal (Snapshot.of_state ~viewer (state lp)) snap;
          assert_equal viewer snap.Snapshot.viewer)
        (snapshots lp) );
    ( "a dropped student still receives snapshots" >:: fun _ ->
      (* Student 1 starts with 1.0 GPA and walks into the assignment; student 2
         heads to the far wall, out of reach, so the round keeps running. *)
      let config = { c with start_gpa = 1.0 } in
      let lp =
        loop ~config [ 1; 2 ]
        |> handle (Launch Assignments)
        |> handle (Key_down (1, Left))
        |> handle (Key_down (2, Right))
        |> ticks 60
      in
      assert_equal State.Dropped (student 1 lp).standing;
      assert_equal State.Running (State.phase (state lp)) ~printer:pp_phase;
      assert_equal [ None; Some 1; Some 2 ] (viewers lp) ~printer:pp_viewers );
  ]

(******************************************************************************)
(* replay *)

(** [same a b] checks that loops [a] and [b] have the same state. *)
let same a b =
  assert_equal
    (Snapshot.of_state ~viewer:None (state a))
    (Snapshot.of_state ~viewer:None (state b))

let replay_tests =
  [
    ( "replay with no frames changes nothing" >:: fun _ ->
      let lp = loop [ 1 ] in
      same lp (replay lp []) );
    ( "each empty frame is one tick" >:: fun _ ->
      let lp = replay (loop [ 1 ]) [ []; []; [] ] in
      assert_equal 5397 (State.ticks_left (state lp)) ~printer:string_of_int );
    ( "the documented example moves the student on two ticks" >:: fun _ ->
      let lp =
        replay (loop [ 1 ])
          [ [ Key_down (1, Right) ]; []; [ Key_up (1, Right) ] ]
      in
      assert_pos { x = 308.; y = 200. } 1 lp;
      assert_equal no_keys (held 1 lp) ~printer:pp_dir );
    ( "events in a frame are handled in order" >:: fun _ ->
      let down_up = replay (loop [ 1 ]) [ [ Key_down (1, Up); Key_up (1, Up) ] ]
      and up_down =
        replay (loop [ 1 ]) [ [ Key_up (1, Up); Key_down (1, Up) ] ]
      in
      assert_pos { x = 300.; y = 200. } 1 down_up;
      assert_pos { x = 300.; y = 196. } 1 up_down );
    ( "replay matches handling and ticking by hand" >:: fun _ ->
      let frames =
        [
          [ Key_down (1, Down); Launch Assignments ];
          [ Key_down (2, Left) ];
          [];
          [ Disconnect 1; Key_up (2, Left) ];
          [];
        ]
      in
      let by_hand =
        List.fold_left
          (fun lp events ->
            tick (List.fold_left (fun lp e -> handle e lp) lp events))
          (loop [ 1; 2 ])
          frames
      in
      same by_hand (replay (loop [ 1; 2 ]) frames) );
    ( "replaying the same inputs twice gives the same result" >:: fun _ ->
      let frames =
        [ Launch Assignments; Key_down (1, Left) ] :: List.init 59 (fun _ -> [])
      in
      same (replay (loop [ 1; 2 ]) frames) (replay (loop [ 1; 2 ]) frames) );
  ]

let tests =
  "Gameloop"
  >::: [
         "setup" >::: setup_tests;
         "key_of_string" >::: key_of_string_tests;
         "handle" >::: handle_tests;
         "tick" >::: tick_tests;
         "attacks" >::: attack_tests;
         "snapshots" >::: snapshot_tests;
         "replay" >::: replay_tests;
       ]
