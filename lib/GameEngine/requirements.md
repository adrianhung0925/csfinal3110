Will provide a function that returns the game state (for the renderer and networker)

get_game_state : () -> game_state

Will provide a function that sets the game state (for the networker)

set_game_state : game_state -> unit

Will provide a function that takes a list of players for game initialization (for networker). The strings contain the user IDs. 

initialize_players : string List -> unit

Will provide a function that processes the movement of a given player by their ID. Movement is a player_inoyt_direction, string is player ID
process_movement : player_input_direction -> string -> unit


game engine needs to expose the abstract type game_state

as well as the abstract type player_input_direction

the game engine needs to expose a way to package player_input_direction

process_raw_input_to_player_direction : char list -> player_input_direction



(*if we want to later add powerups or assignment drops)
process_special_action : ()


Game State Translations:

(*Returns a list of player positions*)
get_players : game_state -> (int, int) List

(*Returns a list of projectiles with x position, y position, and symbol*)
get_projectiles : game_state -> (int, int, char) List

(*Returns a professor state int 0-5 corresponding to different faces, and an int for energy*) 
get_professor : game_state -> (int, int)