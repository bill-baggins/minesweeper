package main

GameMode :: enum {
	MENU,
	GAME,
	GAME_OVER,
	QUIT,
}

MenuMode :: enum {
	MAIN,
	OPTIONS,
	EDIT,
}

Difficulty :: enum {
    EASY,
    NORMAL,
    HARD,
}

g_current_game_mode : GameMode = .MENU
g_difficulty : Difficulty = .NORMAL

toggle_menu :: proc() {
	if g_current_game_mode == .GAME {
        g_current_game_mode = .MENU
    } else {
        g_current_game_mode = .GAME
    }
}