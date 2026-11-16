A function called 'Render' that is called by game engine to render each frame (pass in game state as arg)

render : game_state -> unit



**THIS PLAYS FOR EVERYONE WHEN SOMEONE IS DEFEATED
trigger_defeat_animation : (int, int) -> unit



provide a function called trigger_death_screen to signify that the local client player has been defeated
**THIS PLAYS ON SOMEONE'S SCREEN, ONLY FOR THE PERSON WHO IS DEFEATED WHEN THEY ARE DEFEATED
trigger_defeat_screen : unit -> unit