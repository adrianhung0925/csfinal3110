Functionality provided by the game engine (Adrian): the modules State, Shape, Pattern, and Scheduler.

Every function is pure: nothing is stored globally. Each function returns a new value, and the server loop keeps
the current State.t and Scheduler.t in its own variables and passes them back in on the next tick.

