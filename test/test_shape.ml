open OUnit2

let pp_pair (a, b) = Printf.sprintf "(%g, %g)" a b
let pp_ipair (a, b) = Printf.sprintf "(%d, %d)" a b
let pp_cells cells = "[" ^ String.concat "; " (List.map pp_ipair cells) ^ "]"

(** [first n xs] is the first [n] elements of [xs]. *)
let rec first n xs =
  match xs with
  | [] -> []
  | x :: rest -> if n = 0 then [] else x :: first (n - 1) rest

let hit_test name shape ~dx ~dy expected =
  name >:: fun _ ->
  assert_equal expected
    (Shape.hits_square shape ~dx ~dy ~half:8.)
    ~printer:string_of_bool

(* The Professor's attack: "A1" with cells of side 12. It is 11 cells (132
   units) wide and 7 cells (84 units) tall, so its top-left corner is at
   (-66, -42) from its center. A student's square has half-side 8. *)
let a1 = Shape.Text { text = "A1"; cell = 12. }

let tests =
  "Shape"
  >::: [
         ( "A1 is 11 cells wide and 7 tall" >:: fun _ ->
           (* Two letters of 5 columns plus one blank column between them. *)
           assert_equal (11, 7) (Shape.text_size "A1") ~printer:pp_ipair );
         ( "A1 reaches 66 by 42 from its center" >:: fun _ ->
           assert_equal (66., 42.) (Shape.half_extents a1) ~printer:pp_pair );
         ( "the top row of A1, with the 1 starting 6 columns right" >:: fun _ ->
           (* The top of "A" is .###. (columns 1-3); the top of "1" is ..#..,
              which is column 2 of the second letter: 6 + 2 = 8. *)
           assert_equal
             [ (1, 0); (2, 0); (3, 0); (8, 0) ]
             (first 4 (Shape.text_cells "A1"))
             ~printer:pp_cells );
         (* Cell (8, 0) has its center at (8.5 * 12 - 66, 0.5 * 12 - 42) =
            (36, -36). *)
         hit_test "a student on a lit cell is hit" a1 ~dx:36. ~dy:(-36.) true;
         (* The hole of the "A" is columns 1-3, rows 1-2: x from -54 to -18 and
            y from -30 to -6. A student centered at (-36, -18) spans -44 to -28
            and -26 to -10, so it touches no lit cell. *)
         hit_test "a student inside the hole of the A is not hit" a1 ~dx:(-36.)
           ~dy:(-18.) false;
         (* 100 is more than 66 + 8 to the right of the word. *)
         hit_test "a student far to the right is not hit" a1 ~dx:100. ~dy:0.
           false;
       ]
