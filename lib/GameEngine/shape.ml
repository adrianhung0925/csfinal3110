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

let half_extents _ = failwith "TODO: Shape.half_extents"
let hits_square _ ~dx:_ ~dy:_ ~half:_ = failwith "TODO: Shape.hits_square"
let text_size _ = failwith "TODO: Shape.text_size"
let text_cells _ = failwith "TODO: Shape.text_cells"
