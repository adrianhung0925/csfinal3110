let failures = ref 0

let check name ok =
  if ok then Printf.printf "ok   %s\n" name
  else begin
    incr failures;
    Printf.printf "FAIL %s\n" name
  end

let lp =
  Gameloop.create State.default_config
  |> Gameloop.join 1 ~name:"lucy"
  |> Gameloop.start

let snap_for viewer lp = List.assoc viewer (Gameloop.snapshots lp)

let student_pos snap =
  match Snapshot.me snap with
  | Some s -> (s.State.pos.State.x, s.State.pos.State.y) 
  | None -> (nan, nan)

let () =
  let snap = snap_for (Some 1) lp in
  check "a new student starts at the arena center (300, 200)"
    (student_pos snap = (300., 200.));
  check "the player's snapshot names its viewer" (snap.Snapshot.viewer = Some 1);
  check "the Professor's snapshot has no viewer"
    ((snap_for None lp).Snapshot.viewer = None);

  let held =
    lp
    |> Gameloop.handle (Gameloop.Key_down (1, Gameloop.Right))
    |> Gameloop.tick
  in
  check "holding right for one tick moves the student to (304, 200)"
    (student_pos (snap_for (Some 1) held) = (304., 200.));

  let launched =
    lp
    |> Gameloop.handle (Gameloop.Launch Gameloop.Assignments)
    |> Gameloop.tick
  in
  (match (snap_for (Some 1) launched).Snapshot.bullets with
   | [ b ] ->
       check "the A1 attack is a text bullet" (b.State.shape = Shape.Text { text = "A1"; cell = 12. });
       check "the A1 bullet starts on the left wall at half the height"
         (b.State.center = { State.x = 0.; y = 200. })
   | _ -> check "the A1 attack gives exactly one bullet" false);

  check "block text A1 is 11 cells wide and 7 tall"
    (Shape.text_size "A1" = (11, 7));

  if !failures > 0 then exit 1