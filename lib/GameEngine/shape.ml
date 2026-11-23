type t =
  | Circle of { radius : float }
  | Rect of {
      w : float;
      h : float;
    }
  | Text of {
      text : string;
      cell : float;
    }
[@@deriving yojson]

(******************************************************************************)
(* The block font. Each glyph is 7 rows of 5 characters: '#' is a lit cell and
   '.' is empty. Drawn for this project (not copied from any game or font). *)

let glyph_w = 5
let glyph_h = 7

(** [glyphs] pairs every supported character with its 7 rows. *)
let glyphs =
  [
    ('A', [ ".###."; "#...#"; "#...#"; "#####"; "#...#"; "#...#"; "#...#" ]);
    ('B', [ "####."; "#...#"; "#...#"; "####."; "#...#"; "#...#"; "####." ]);
    ('C', [ ".###."; "#...#"; "#...."; "#...."; "#...."; "#...#"; ".###." ]);
    ('D', [ "####."; "#...#"; "#...#"; "#...#"; "#...#"; "#...#"; "####." ]);
    ('E', [ "#####"; "#...."; "#...."; "####."; "#...."; "#...."; "#####" ]);
    ('F', [ "#####"; "#...."; "#...."; "####."; "#...."; "#...."; "#...." ]);
    ('G', [ ".###."; "#...#"; "#...."; "#.###"; "#...#"; "#...#"; ".###." ]);
    ('H', [ "#...#"; "#...#"; "#...#"; "#####"; "#...#"; "#...#"; "#...#" ]);
    ('I', [ ".###."; "..#.."; "..#.."; "..#.."; "..#.."; "..#.."; ".###." ]);
    ('J', [ "..###"; "...#."; "...#."; "...#."; "...#."; "#..#."; ".##.." ]);
    ('K', [ "#...#"; "#..#."; "#.#.."; "##..."; "#.#.."; "#..#."; "#...#" ]);
    ('L', [ "#...."; "#...."; "#...."; "#...."; "#...."; "#...."; "#####" ]);
    ('M', [ "#...#"; "##.##"; "#.#.#"; "#.#.#"; "#...#"; "#...#"; "#...#" ]);
    ('N', [ "#...#"; "#...#"; "##..#"; "#.#.#"; "#..##"; "#...#"; "#...#" ]);
    ('O', [ ".###."; "#...#"; "#...#"; "#...#"; "#...#"; "#...#"; ".###." ]);
    ('P', [ "####."; "#...#"; "#...#"; "####."; "#...."; "#...."; "#...." ]);
    ('Q', [ ".###."; "#...#"; "#...#"; "#...#"; "#.#.#"; "#..#."; ".##.#" ]);
    ('R', [ "####."; "#...#"; "#...#"; "####."; "#.#.."; "#..#."; "#...#" ]);
    ('S', [ ".####"; "#...."; "#...."; ".###."; "....#"; "....#"; "####." ]);
    ('T', [ "#####"; "..#.."; "..#.."; "..#.."; "..#.."; "..#.."; "..#.." ]);
    ('U', [ "#...#"; "#...#"; "#...#"; "#...#"; "#...#"; "#...#"; ".###." ]);
    ('V', [ "#...#"; "#...#"; "#...#"; "#...#"; "#...#"; ".#.#."; "..#.." ]);
    ('W', [ "#...#"; "#...#"; "#...#"; "#.#.#"; "#.#.#"; "#.#.#"; ".#.#." ]);
    ('X', [ "#...#"; "#...#"; ".#.#."; "..#.."; ".#.#."; "#...#"; "#...#" ]);
    ('Y', [ "#...#"; "#...#"; ".#.#."; "..#.."; "..#.."; "..#.."; "..#.." ]);
    ('Z', [ "#####"; "....#"; "...#."; "..#.."; ".#..."; "#...."; "#####" ]);
    ('0', [ ".###."; "#...#"; "#..##"; "#.#.#"; "##..#"; "#...#"; ".###." ]);
    ('1', [ "..#.."; ".##.."; "..#.."; "..#.."; "..#.."; "..#.."; ".###." ]);
    ('2', [ ".###."; "#...#"; "....#"; "...#."; "..#.."; ".#..."; "#####" ]);
    ('3', [ "####."; "....#"; "....#"; ".###."; "....#"; "....#"; "####." ]);
    ('4', [ "...#."; "..##."; ".#.#."; "#..#."; "#####"; "...#."; "...#." ]);
    ('5', [ "#####"; "#...."; "####."; "....#"; "....#"; "#...#"; ".###." ]);
    ('6', [ ".###."; "#...."; "#...."; "####."; "#...#"; "#...#"; ".###." ]);
    ('7', [ "#####"; "....#"; "...#."; "..#.."; ".#..."; ".#..."; ".#..." ]);
    ('8', [ ".###."; "#...#"; "#...#"; ".###."; "#...#"; "#...#"; ".###." ]);
    ('9', [ ".###."; "#...#"; "#...#"; ".####"; "....#"; "....#"; ".###." ]);
  ]

(** [glyph ch] is the rows for [ch]. Lowercase letters use the uppercase glyph;
    a space, or any character without a glyph, is all empty. *)
let glyph ch =
  match List.assoc_opt (Char.uppercase_ascii ch) glyphs with
  | Some rows -> rows
  | None -> List.init glyph_h (fun _ -> String.make glyph_w '.')

let text_size text =
  let n = String.length text in
  if n = 0 then (0, glyph_h) else ((n * glyph_w) + (n - 1), glyph_h)

let text_cells text =
  let n = String.length text in
  let cells = ref [] in
  (* Walk backwards so that consing builds the list in row, then column, order.
     Character [i] starts at column [i * 6] (5 wide plus 1 gap). *)
  for row = glyph_h - 1 downto 0 do
    for i = n - 1 downto 0 do
      let line = List.nth (glyph text.[i]) row in
      for c = glyph_w - 1 downto 0 do
        if line.[c] = '#' then cells := ((i * (glyph_w + 1)) + c, row) :: !cells
      done
    done
  done;
  !cells

(******************************************************************************)
(* Geometry *)

let half_extents s =
  match s with
  | Circle { radius } -> (radius, radius)
  | Rect { w; h } -> (w /. 2., h /. 2.)
  | Text { text; cell } ->
      let cols, rows = text_size text in
      (float_of_int cols *. cell /. 2., float_of_int rows *. cell /. 2.)

(** [clamp lo hi v] is [v] limited to the range [lo] to [hi]. *)
let clamp lo hi v = if v < lo then lo else if v > hi then hi else v

(** [boxes_touch ~dx ~dy ~hw ~hh ~half] is whether a box of half-size [(hw, hh)]
    centered at the origin overlaps or touches a square of half-side [half]
    centered at [(dx, dy)]. *)
let boxes_touch ~dx ~dy ~hw ~hh ~half =
  Float.abs dx <= hw +. half && Float.abs dy <= hh +. half

let hits_square s ~dx ~dy ~half =
  match s with
  | Circle { radius } ->
      (* The point of the square closest to the circle's center (the origin) is
         the origin clamped into the square. The circle touches the square
         exactly when that point is within [radius]. *)
      let px = clamp (dx -. half) (dx +. half) 0. in
      let py = clamp (dy -. half) (dy +. half) 0. in
      (px *. px) +. (py *. py) <= radius *. radius
  | Rect { w; h } -> boxes_touch ~dx ~dy ~hw:(w /. 2.) ~hh:(h /. 2.) ~half
  | Text { text; cell } ->
      (* Each lit cell is a small square of side [cell]. The cell in column
         [col] has its center [(col + 0.5) * cell] from the text's left edge,
         which is [hw] left of the text's center. *)
      let hw, hh = half_extents s in
      let half_cell = cell /. 2. in
      List.exists
        (fun (col, row) ->
          let cx = ((float_of_int col +. 0.5) *. cell) -. hw in
          let cy = ((float_of_int row +. 0.5) *. cell) -. hh in
          boxes_touch ~dx:(dx -. cx) ~dy:(dy -. cy) ~hw:half_cell ~hh:half_cell
            ~half)
        (text_cells text)
