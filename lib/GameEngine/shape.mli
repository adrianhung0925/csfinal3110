(** The shape of a bullet, and whether a student's square overlaps it.

    Shapes are plain data, so the server can send them to the browser and the
    renderer can draw each kind its own way. A shape has no position of its
    own: it is always placed at a bullet's center, and every function here
    works relative to that center. All shapes are axis-aligned (no rotation).

    This module is pure and depends on no other game module, so [State],
    [Pattern], and the renderer can all use it. *)

(** {1 Shapes} *)

(** A bullet's shape, centered on the bullet's position.
    - [Circle { radius }]: a filled circle.
    - [Rect { w; h }]: a filled rectangle [w] wide and [h] tall.
    - [Text { text; cell }]: [text] drawn in the built-in block font, where each
      lit pixel of the font is a square of side [cell]. Only the lit cells
      hurt: the gaps inside and between letters are safe. For example,
      [Text { text = "A1"; cell = 12. }] is 11 cells (132 units) wide and 7
      cells (84 units) tall.

    Requires: [radius], [w], [h], and [cell] are positive. *)
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

(** {1 Geometry} *)

val half_extents : t -> float * float
(** [half_extents s] is [(hw, hh)], half the width and half the height of the
    smallest rectangle around [s]. For example, [Circle { radius = 5. }] gives
    [(5., 5.)], [Rect { w = 40.; h = 10. }] gives [(20., 5.)], and
    [Text { text = "A1"; cell = 12. }] gives [(66., 42.)]. [State] uses this to
    drop bullets that have left the arena. *)

val hits_square : t -> dx:float -> dy:float -> half:float -> bool
(** [hits_square s ~dx ~dy ~half] is whether [s], centered at the origin,
    overlaps or touches the square of half-side [half] centered at
    [(dx, dy)]. In the game, [(dx, dy)] is the student's center minus the
    bullet's center, and [half] is half of [student_size]. Touching edges count
    as a hit. For example, with [half = 8.], [Circle { radius = 5. }] hits at
    [(13., 0.)] (the edges touch) but not at [(14., 0.)]. *)

(** {1 The block font}

    Each character is 5 cells wide and 7 cells tall, and letters are separated
    by one blank column. Supported characters are [A] to [Z], [0] to [9], and
    space; lowercase letters are drawn as uppercase, and any other character is
    drawn as a space. *)

val text_size : string -> int * int
(** [text_size text] is [(cols, rows)], the size of [text] in cells. For
    example, ["A1"] is [(11, 7)] (two 5-wide letters plus one gap), and [""] is
    [(0, 7)]. *)

val text_cells : string -> (int * int) list
(** [text_cells text] is the [(col, row)] of every lit cell of [text], with
    [(0, 0)] in the top-left corner, ordered by row and then by column. The
    renderer draws one square per cell, so what players see is exactly what
    hurts. *)
