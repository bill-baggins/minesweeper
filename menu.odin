package main


import "core:fmt"
import "core:log"
import "core:os"
import rl "vendor:raylib"
import ret "retgui"


Menu :: struct {
	// Is stack allocated in the main_loop scope.
	data: ^DataPacket,
	widgets: [dynamic]ret.WidgetType,
	mode: MenuMode,
}


menu_new :: proc(data: ^DataPacket) -> ^Menu {
	menu : ^Menu = new(Menu)
	menu.widgets = make([dynamic]ret.WidgetType)
	menu.data = data

	append(&menu.widgets, ret.label_new(
		"minesweeper_title",
		{auto_cast (rl.GetScreenWidth() / 2) - 200, auto_cast(rl.GetScreenHeight() / 2) - 200},
		{400, 50},
		"Minesweeper",
        rl.BLACK,
        rl.Color{},
		40,
	))

	start_game_button := ret.button_new(
		"start_button",
		{auto_cast (rl.GetScreenWidth() / 2) - 150, auto_cast(rl.GetScreenHeight() / 2) - 100},
		{300, 50},
		"Start",
        rl.BLACK,
        rl.BLUE,
		40,
		start_game,
		transmute(uintptr)menu.data,
	)

	append(&menu.widgets, start_game_button)
	difficulty_button := ret.button_new(
		"Difficulty",
		{auto_cast (rl.GetScreenWidth() / 2) - 150, auto_cast(rl.GetScreenHeight() / 2)},
		{300, 50},
		"Normal (16x16)",
        rl.BLACK,
        rl.BLUE,
		40,
		switch_difficulty,
	)

	difficulty_button.data = transmute(uintptr)difficulty_button

	append(&menu.widgets, difficulty_button)
	append(&menu.widgets, ret.button_new(
		"quit",
		{auto_cast (rl.GetScreenWidth() / 2) - 150, auto_cast(rl.GetScreenHeight() / 2) + 100},
		{300, 50},
		"Quit",
        rl.BLACK,
        rl.BLUE,
		40,
		quit,
	))

	menu.mode = .MAIN

	return menu
}

menu_update_draw :: proc(menu: ^Menu) {
	using menu

	mouse_pos := rl.GetMousePosition()

	for widget in widgets {
		ret.widget_update_draw(widget, mouse_pos)
	}
}

menu_free :: proc(menu: ^Menu) {
	using menu

    if menu == nil {
        return
    }

	for widget in widgets {
		ret.widget_free(widget)
	}

	delete(widgets)

	free(menu)
}

@(private="file")
index := cast(int)Difficulty.NORMAL

@(private="file")
switch_difficulty :: proc(data: uintptr) {
	button := transmute(^ret.Button)data

	// Since we will be inside of the menu, this will
	// start the game.
	index = (index + 1) % (cast(int)Difficulty.HARD + 1)

	g_difficulty = cast(Difficulty)index


	switch g_difficulty {
	case .EASY:
		button.text = "Easy (9x9)"
	case .NORMAL:
		button.text = "Normal (16x16)"
	case .HARD:
		button.text = "Hard (30x16)"
	}
}

@(private="file")
start_game :: proc(data: uintptr) {
	d := transmute(^DataPacket)data
	texture_handler_free(d.th)
    board_free(d.board)
	switch g_difficulty {
    case .EASY:
        d.th = texture_handler_new(1.5)
        d.board = board_new(9, 9, 0.10, d.th)
    case .NORMAL:
        d.th = texture_handler_new(1)
        d.board = board_new(16, 16, 0.12, d.th)
    case .HARD:
        d.th = texture_handler_new(1)
        d.board = board_new(30, 16, 0.17, d.th)
    }

	// Since we will be inside of the menu, this will
	// start the game.
	toggle_menu()
}

@(private="file")
quit :: proc(data: uintptr) {
	// Since we will be inside of the menu, this will
	// start the game.
	g_current_game_mode = .QUIT
}

