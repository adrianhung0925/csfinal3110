Functionality provided by the game engine (Adrian): the modules State, Shape, Pattern, and Scheduler.

Every function is pure: nothing is stored globally. Each function returns a new value, and the server loop keeps
the current State.t and Scheduler.t in its own variables and passes them back in on the next tick.


Types the game engine exposes:

The game state of one round (abstract)

State.t

A student's id, assigned by the server when they join

State.student_id = int

A position or a movement, in game units (not pixels; x grows right, y grows down)

State.vec = { x : float; y : float }

The arrow keys one student is holding right now (a plain record, so the client can build it directly)

State.dir = { up : bool; down : bool; left : bool; right : bool }

Whether a student is still playing or has been knocked out

State.standing = Enrolled | Dropped

Everything about one student (pos is the center of their square)

State.student = { id : student_id; name : string; pos : vec; gpa : float; invuln : int; survived : int; standing : standing }

One bullet (center is the middle of its shape)

State.bullet = { center : vec; vel : vec; shape : Shape.t; damage : float }

The stage of the round

State.phase = Lobby | Running | Finished

The shape of a bullet, for drawing it

Shape.t = Circle of { radius : float } | Rect of { w : float; h : float } | Text of { text : string; cell : float }

One of the Professor's attacks

Pattern.id = Assignments | Concurrency | Recursion | Pattern_matching | Prelim

The Professor's energy bar and cooldowns (abstract)

Scheduler.t

Why the Professor's attack was refused

Scheduler.reject = Not_running | On_cooldown of int | Not_enough_energy


Setting up a round (for the server loop and networker):

Will provide the default game settings (arena size, speed, GPA, round length, ...)

State.default_config : State.config

Will provide a function that creates an empty round in the lobby

State.init : State.config -> State.t

Will provide a function that adds one player in the lobby, with their id and username. Call it once per player.

State.add_student : State.student_id -> name:string -> State.t -> State.t

Will provide a function that starts the round (the timer starts running)

State.start : State.t -> State.t

Will provide a function that creates a full energy bar for the Professor

Scheduler.init : Scheduler.config -> Scheduler.t


Every tick (for the server loop):

Will provide a function that turns the Professor's number key (1-5) into an attack

Pattern.of_key : int -> Pattern.id option

Will provide a function that tries to launch the Professor's attack. bool is whether the round is running.

Scheduler.request : running:bool -> Pattern.id -> Scheduler.t -> (Scheduler.t, Scheduler.reject) result

Will provide a function that advances the attacks by one tick and returns the new bullets for this tick

Scheduler.tick : State.config -> Random.State.t -> Scheduler.t -> Scheduler.t * State.bullet list

Will provide a function that advances the game by one tick: moves every player, moves the bullets, checks hits,
and counts down the timer. moves has each player's id and the keys they are holding; players left out stand still.

State.step : State.t -> moves:(State.student_id * State.dir) list -> spawned:State.bullet list -> State.t


Game State Translations (for the renderer and networker):

(*Returns every player, sorted by id*)
State.students : State.t -> State.student list

(*Returns one player, if they exist*)
State.find_student : State.student_id -> State.t -> State.student option

(*Returns every bullet in the arena*)
State.bullets : State.t -> State.bullet list

(*Returns whether the round is in the lobby, running, or finished*)
State.phase : State.t -> State.phase

(*Returns the ticks left in the round (30 ticks = 1 second)*)
State.ticks_left : State.t -> int

(*Returns how many players are still playing*)
State.enrolled_count : State.t -> int

(*Returns how many players the Professor has knocked out*)
State.kills : State.t -> int

(*Returns every player ranked by GPA, then by how long they survived, for the end screen*)
State.leaderboard : State.t -> State.student list

(*Returns the game settings, e.g. arena size and student square size*)
State.config : State.t -> State.config


Professor's attack bar (for the renderer):

(*Returns every attack, in attack-bar order*)
Pattern.all : Pattern.id list

(*Returns the number key for an attack*)
Pattern.key : Pattern.id -> int

(*Returns the label for an attack, e.g. "Pattern matching"*)
Pattern.name : Pattern.id -> string

(*Returns how much energy an attack costs*)
Pattern.cost : Pattern.id -> float

(*Returns the Professor's current energy*)
Scheduler.energy : Scheduler.t -> float

(*Returns the size of the energy bar, as max_energy*)
Scheduler.config : Scheduler.t -> Scheduler.config

(*Returns how many ticks until an attack can be used again (0 = ready)*)
Scheduler.cooldown_left : Pattern.id -> Scheduler.t -> int

(*Returns the attacks currently running*)
Scheduler.running : Scheduler.t -> Pattern.id list


Drawing bullets (for the renderer):

(*Returns the half width and half height of a shape, (hw, hh)*)
Shape.half_extents : Shape.t -> float * float

(*Returns the (column, row) of every lit cell of a giant text bullet; draw one square of size cell per cell*)
Shape.text_cells : string -> (int * int) list

(*Returns the size of a giant text bullet, in cells: (columns, rows)*)
Shape.text_size : string -> int * int


Differences from the earlier list:

get_game_state / set_game_state: not provided. The engine keeps no global state; the server loop holds the
current State.t in a variable, passes it to State.step, and keeps the result.

initialize_players : string List -> unit: replaced by State.add_student, once per player. Ids are ints
(State.student_id), and each player also gives a username.

process_movement : player_input_direction -> string -> unit: replaced by the moves list in State.step, which
moves every player at once each tick.

player_input_direction: the type is called State.dir. It is a plain record of four bools, not abstract, so no
packaging function is needed.

process_raw_input_to_player_direction : char list -> player_input_direction: not planned, since the client can
build a State.dir directly from the keys it is holding. Can be added if wanted (say which characters mean which
direction).

get_players : game_state -> (int, int) List: replaced by State.students. Positions are floats in game units, and
each student also has a name, GPA, and standing.

get_projectiles : game_state -> (int, int, char) List: replaced by State.bullets. Each bullet has a float center
and a Shape.t (circle, rectangle, or giant text) instead of a char symbol.

get_professor : game_state -> (int, int): energy comes from Scheduler.energy (a float). Professor faces (0-5) are
not planned yet; the renderer could pick a face from the energy or the running attacks, or it can be added.

process_special_action (powerups, assignment drops): not planned yet.
