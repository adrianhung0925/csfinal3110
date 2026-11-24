(** Tests for [Snapshot]: building a player's view from a [State.t], finding the
    viewer's own student, and the JSON round trip used by the networker.

    States are built directly with [State], from [State.default_config] (a 600
    by 400 arena, squares of side 16, speed 4, GPA 4.0, a 5400-tick semester),
    so students start at the center [(300, 200)]. *)

open OUnit2

(******************************************************************************)
(* Helpers *)

let c = State.default_config

let pp_phase = function
  | State.Lobby -> "Lobby"
  | State.Running -> "Running"
  | State.Finished -> "Finished"

let pp_ids ids = "[" ^ String.concat "; " (List.map string_of_int ids) ^ "]"

let ids (ss : State.student list) =
  List.map (fun (s : State.student) -> s.id) ss

let pp_viewer = function
  | None -> "None"
  | Some id -> "Some " ^ string_of_int id

let right : State.dir = { up = false; down = false; left = false; right = true }

(** [lobby ?config ids] is a round in the Lobby with students [ids]. *)
let lobby ?(config = c) ids =
  List.fold_left
    (fun st id -> State.add_student id ~name:("s" ^ string_of_int id) st)
    (State.init config) ids

let running ?config ids = State.start (lobby ?config ids)
let step ?(moves = []) ?(spawned = []) st = State.step st ~moves ~spawned

(** [dot x y damage] is a still circle bullet of radius 1 at [(x, y)]. *)
let dot x y damage : State.bullet =
  {
    center = { x; y };
    vel = { x = 0.; y = 0. };
    shape = Shape.Circle { radius = 1. };
    damage;
  }

(** A running round of three students after four ticks: student 1 walked right
    to [(312, 200)], then a 4.0 dot at the center dropped students 2 and 3. *)
let after_drop () =
  let st = running [ 1; 2; 3 ] in
  let st = step ~moves:[ (1, right) ] st in
  let st = step ~moves:[ (1, right) ] st in
  let st = step ~moves:[ (1, right) ] st in
  step ~spawned:[ dot 300. 200. 4.0 ] st

(** A finished round: student 2 lost 1.0 GPA, student 1 did not, and the 3-tick
    semester ran out. *)
let finished () =
  let st = running ~config:{ c with semester_ticks = 3 } [ 2; 1 ] in
  let st = step ~moves:[ (1, right) ] st in
  let st = step ~moves:[ (1, right) ] st in
  step ~moves:[ (1, right) ] ~spawned:[ dot 300. 200. 1.0 ] st

let roundtrip name snap =
  name >:: fun _ ->
  assert_equal snap (Snapshot.of_string (Snapshot.to_string snap))

let contains s sub =
  let n = String.length s and m = String.length sub in
  let rec go i = i + m <= n && (String.sub s i m = sub || go (i + 1)) in
  go 0

let assert_failure_raised f =
  match f () with
  | _ -> assert_failure "expected Failure"
  | exception Failure _ -> ()

(******************************************************************************)
(* of_state *)

let of_state_tests =
  [
    ( "a lobby snapshot copies every field" >:: fun _ ->
      let st = lobby [ 2; 1 ] in
      let snap = Snapshot.of_state ~viewer:(Some 1) st in
      assert_equal (Some 1) snap.viewer ~printer:pp_viewer;
      assert_equal c snap.config;
      assert_equal State.Lobby snap.phase ~printer:pp_phase;
      assert_equal 5400 snap.ticks_left ~printer:string_of_int;
      assert_equal [ 1; 2 ] (ids snap.students) ~printer:pp_ids;
      assert_equal (State.students st) snap.students;
      assert_equal [] snap.bullets;
      assert_equal 2 snap.enrolled ~printer:string_of_int;
      assert_equal 0 snap.kills ~printer:string_of_int;
      assert_equal [] snap.leaderboard );
    ( "the documented example: one tick, student 1 at (304, 200)" >:: fun _ ->
      let st = step ~moves:[ (1, right) ] (running [ 1 ]) in
      let snap = Snapshot.of_state ~viewer:(Some 1) st in
      assert_equal (Some 1) snap.viewer ~printer:pp_viewer;
      assert_equal State.Running snap.phase ~printer:pp_phase;
      assert_equal 5399 snap.ticks_left ~printer:string_of_int;
      match snap.students with
      | [ s ] -> assert_equal { State.x = 304.; y = 200. } s.pos
      | _ -> assert_failure "expected exactly one student" );
    ( "the Professor's snapshot has viewer None" >:: fun _ ->
      let snap = Snapshot.of_state ~viewer:None (running [ 1 ]) in
      assert_equal None snap.viewer ~printer:pp_viewer );
    ( "viewer is copied even if it is not a student" >:: fun _ ->
      let snap = Snapshot.of_state ~viewer:(Some 99) (lobby [ 1 ]) in
      assert_equal (Some 99) snap.viewer ~printer:pp_viewer );
    ( "the viewer does not change what is shown" >:: fun _ ->
      let st = after_drop () in
      let a = Snapshot.of_state ~viewer:None st
      and b = Snapshot.of_state ~viewer:(Some 2) st in
      assert_equal { a with viewer = Some 2 } b );
    ( "bullets are copied, oldest first" >:: fun _ ->
      let st = step ~spawned:[ dot 50. 50. 1.; dot 60. 60. 2. ] (running []) in
      let snap = Snapshot.of_state ~viewer:None st in
      assert_equal (State.bullets st) snap.bullets;
      assert_equal 2 (List.length snap.bullets) ~printer:string_of_int );
    ( "dropped students are still listed and counted as kills" >:: fun _ ->
      let snap = Snapshot.of_state ~viewer:None (after_drop ()) in
      assert_equal [ 1; 2; 3 ] (ids snap.students) ~printer:pp_ids;
      assert_equal 1 snap.enrolled ~printer:string_of_int;
      assert_equal 2 snap.kills ~printer:string_of_int;
      assert_equal State.Running snap.phase ~printer:pp_phase );
    ( "no leaderboard while Running" >:: fun _ ->
      let snap = Snapshot.of_state ~viewer:None (after_drop ()) in
      assert_equal [] snap.leaderboard );
    ( "the final leaderboard once Finished" >:: fun _ ->
      let st = finished () in
      let snap = Snapshot.of_state ~viewer:(Some 2) st in
      assert_equal State.Finished snap.phase ~printer:pp_phase;
      assert_equal 0 snap.ticks_left ~printer:string_of_int;
      assert_equal (State.leaderboard st) snap.leaderboard;
      (* Student 1 kept 4.0, student 2 fell to 3.0. *)
      assert_equal [ 1; 2 ] (ids snap.leaderboard) ~printer:pp_ids );
  ]

(******************************************************************************)
(* me *)

let me_tests =
  let me_id snap =
    Option.map (fun (s : State.student) -> s.id) (Snapshot.me snap)
  in
  [
    ( "me finds the viewer's own student" >:: fun _ ->
      let snap = Snapshot.of_state ~viewer:(Some 2) (running [ 1; 2; 3 ]) in
      assert_equal (Some 2) (me_id snap) ~printer:pp_viewer );
    ( "me is None for the Professor" >:: fun _ ->
      let snap = Snapshot.of_state ~viewer:None (running [ 1 ]) in
      assert_equal None (me_id snap) ~printer:pp_viewer );
    ( "me is None for a viewer who has not joined" >:: fun _ ->
      let snap = Snapshot.of_state ~viewer:(Some 5) (lobby [ 1 ]) in
      assert_equal None (me_id snap) ~printer:pp_viewer );
    ( "me shows a dropped student so the client can spectate" >:: fun _ ->
      let snap = Snapshot.of_state ~viewer:(Some 3) (after_drop ()) in
      match Snapshot.me snap with
      | Some s ->
          assert_equal State.Dropped s.standing;
          assert_equal 0.0 s.gpa ~printer:string_of_float
      | None -> assert_failure "expected Some student" );
  ]

(******************************************************************************)
(* to_string / of_string *)

let text_bullet : State.bullet =
  {
    center = { x = 12.5; y = 200. };
    vel = { x = 4.; y = -0.25 };
    shape = Shape.Text { text = "A1"; cell = 12. };
    damage = 1.0;
  }

let rect_bullet : State.bullet =
  {
    center = { x = 100.; y = 100. };
    vel = { x = 0.; y = 3. };
    shape = Shape.Rect { w = 40.; h = 10. };
    damage = 0.3;
  }

let json_tests =
  [
    roundtrip "round trip: lobby"
      (Snapshot.of_state ~viewer:(Some 1) (lobby [ 1 ]));
    roundtrip "round trip: empty round, Professor"
      (Snapshot.of_state ~viewer:None (State.init c));
    roundtrip "round trip: dropped students"
      (Snapshot.of_state ~viewer:(Some 2) (after_drop ()));
    roundtrip "round trip: finished with a leaderboard"
      (Snapshot.of_state ~viewer:(Some 1) (finished ()));
    roundtrip "round trip: every bullet shape"
      (Snapshot.of_state ~viewer:None
         (step
            ~spawned:[ text_bullet; rect_bullet; dot 300. 50. 0.5 ]
            (running [ 1 ])));
    ( "to_string is a single line" >:: fun _ ->
      let s =
        Snapshot.to_string (Snapshot.of_state ~viewer:(Some 2) (finished ()))
      in
      assert_bool "contains a newline" (not (String.contains s '\n')) );
    ( "to_string writes the documented lobby format" >:: fun _ ->
      let s =
        Snapshot.to_string (Snapshot.of_state ~viewer:(Some 1) (lobby [ 1 ]))
      in
      assert_bool s (String.starts_with ~prefix:"{\"viewer\":1," s);
      assert_bool s (contains s "\"arena_w\":600.0");
      assert_bool s (contains s "\"phase\":[\"Lobby\"]") );
    ( "of_string rejects text that is not JSON" >:: fun _ ->
      assert_failure_raised (fun () -> Snapshot.of_string "not json");
      assert_failure_raised (fun () -> Snapshot.of_string "") );
    ( "of_string rejects JSON that is not a snapshot" >:: fun _ ->
      assert_failure_raised (fun () -> Snapshot.of_string "{}");
      assert_failure_raised (fun () -> Snapshot.of_string "[1, 2, 3]") );
    ( "of_string rejects a snapshot with a field removed" >:: fun _ ->
      let s = Snapshot.to_string (Snapshot.of_state ~viewer:None (lobby [])) in
      (* Drop the last field, "leaderboard", and close the object again. *)
      let i = String.rindex s ',' in
      assert_failure_raised (fun () ->
          Snapshot.of_string (String.sub s 0 i ^ "}")) );
  ]

let tests =
  "Snapshot"
  >::: [
         "of_state" >::: of_state_tests;
         "me" >::: me_tests;
         "to_string/of_string" >::: json_tests;
       ]
