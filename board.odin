package main

// Bug where the flag count doesn't update correctly...

import "core:math"
import "core:fmt"
import "core:math/rand"
import "core:strings"
import rl "vendor:raylib"

import ret "retgui"

Board :: struct {
    data: []Tile,
    th: ^TextureHandler,
    render_texture: rl.RenderTexture,
    width: int,
    height: int,

    render_tex_rect: rl.Rectangle,
    render_tex_pos: rl.Vector2,

    generated_bombs: bool,
    
    bomb_count: int,
    bombs_flagged: int,

    flag_count: int,
    click_count: int,

    widgets: map[string]ret.WidgetType,

    flag_count_buf: [8]byte,
    click_count_buf: [8]byte,

    clicked_tile_pos: rl.Vector2,
}

board_new :: proc(width, height: int, bomb_count: int, th: ^TextureHandler) -> ^Board {
    assert(th != nil, "No textures to reference, unable to create this board.")

    board : ^Board = new(Board)
    board.data = make([]Tile, width * height)
    board.width = width
    board.height = height
    board.th = th

    // Make the render texture as big as the board tiles * tile size
    board.render_texture = rl.LoadRenderTexture(
        auto_cast (cast(f32)board.width * th.dest_rec.width), 
        auto_cast (cast(f32)board.height * th.dest_rec.height),
    )

    // Initialize all of the tiles to their defaults in this array.
    for _, i in board.data {
        board.data[i] = Tile{TileType.EMPTY, false, false, rl.WHITE}
    }

    // Located at the center of the window minus half the board's width and height.
    board.render_tex_pos = rl.Vector2{
        auto_cast (rl.GetScreenWidth() / 2 - cast(i32)(board.render_texture.texture.width / 2)),
        auto_cast (rl.GetScreenHeight() / 2 - cast(i32)(board.render_texture.texture.height / 2)),
    }

    // Needs to be negative on the render_texture height, since OpenGL
    // draws textures upside down.
    board.render_tex_rect = rl.Rectangle{
        0, 
        0,
        auto_cast board.render_texture.texture.width,
        auto_cast -board.render_texture.texture.height,
    }
    
    board.bomb_count = bomb_count
    board.bombs_flagged = 0
    
    // You are given the same number of flags as there are bombs
    // in this array.
    board.flag_count = bomb_count
    board.click_count = 0

    // This is used to keep track of which tile is currently being held down
    // by the left mouse button (but not revealed yet.)
    board.clicked_tile_pos = {-1, -1}

    // The widgets we will use for the board.
    board.widgets = make(map[string]ret.WidgetType)
    
    b_x := board.render_tex_pos[0]
    b_y := board.render_tex_pos[1]
    b_width := cast(f32) board.render_texture.texture.width
    b_height := cast(f32) -board.render_texture.texture.height // negate this since it was set to a negative value
    
    // Write to the raw flag count buffer the flags we have.
    // This is very C like; normally a string builder would be used,
    // but since we are interfacing with cstrings from Raylib we have to use
    // []byte's which get converted to cstring's.
    fmt.bprintf(board.flag_count_buf[:], "%03d", board.flag_count)
    flag_count_text := cstring(raw_data(board.flag_count_buf[:]))

    board.widgets["flag_count"] =  ret.label_new(
        "flag_count",
        rl.Vector2 {
            b_x,
            b_y - 50,
        },
        {65, 50},
        flag_count_text,
        rl.BLACK,
        rl.Color{},
        40.,
    )

    // Do some more buffer writing here.
    fmt.bprintf(board.click_count_buf[:], "%03d", board.click_count)
    click_count_text := cstring(raw_data(board.click_count_buf[:]))

    board.widgets["click_count"] = ret.label_new(
        "click_count",
        rl.Vector2 {
            (b_x + b_width) - 65,
            b_y - 50,
        },
        {65, 50},
        click_count_text,
        rl.BLACK,
        rl.Color{},
        40.,
    )

    // The below widgets only appear whenever the game state changes to .GAME_OVER
    // or .GAME_WON; since trying to conditionally draw them is a bit too complex,
    // I simply place them outside the view of the window.
    board.widgets["game_over"] = ret.label_new(
        "game_over",
        {-1000, -1000},
        {200, 50},
        "Game Over!",
        rl.BLACK,
        rl.Color{},
        20,
    )

    board.widgets["reset_game"] = ret.button_new(
        "reset_game",
        {-1000, -1000},
        {100, 20},
        "Restart",
        rl.BLACK,
        rl.LIGHTGRAY,
        20,
        reset,
        transmute(uintptr)board,
    )

    board.widgets["back_to_menu"] = ret.button_new(
        "back_to_menu",
        {-1000, -1000},
        {150, 20},
        "Back to menu",
        rl.BLACK,
        rl.LIGHTGRAY,
        20,
        back_to_menu,
        transmute(uintptr)board,
    )

    board.widgets["game_won"] = ret.label_new(
        "game_won",
        {-1000, -1000},
        {200, 50},
        "You Won!",
        rl.BLACK,
        rl.Color{},
        20,
    )

    

    return board
}


board_update :: proc(board: ^Board, dt: f32) {
    using board
    
    // Reposition the relevant hidden widgets to just above the board.
    // reset_game, game_won, back_to_menu
    if g_current_game_mode == .GAME_WON {
        if rg, ok := widgets["reset_game"].(^ret.Button); ok && rg.bb.x < 0 && rg.bb.y < 0 {
            gw := widgets["game_won"].(^ret.Label)
            btm := widgets["back_to_menu"].(^ret.Button)
            go_dest := rl.Vector2{auto_cast (rl.GetScreenWidth() / 2) - (gw.bb.width/ 2), 30}
            rg_dest := rl.Vector2{auto_cast (rl.GetScreenWidth() / 2) - (rg.bb.width/ 2), 70}
            btm_dest := rl.Vector2{auto_cast (rl.GetScreenWidth() / 2) - (btm.bb.width/ 2), 95}
            gw.bb.x = go_dest[0]
            gw.bb.y = go_dest[1]
            rg.bb.x = rg_dest[0]
            rg.bb.y = rg_dest[1]
            btm.bb.x = btm_dest[0]
            btm.bb.y = btm_dest[1]
        }
    }
    
    // reset_game, game_over, back_to_menu
    if g_current_game_mode == .GAME_OVER {
        if rg, ok := widgets["reset_game"].(^ret.Button); ok && rg.bb.x < 0 && rg.bb.y < 0 {
            go := widgets["game_over"].(^ret.Label)
            btm := widgets["back_to_menu"].(^ret.Button)
            go_dest := rl.Vector2{auto_cast (rl.GetScreenWidth() / 2) - (go.bb.width/ 2), 30}
            rg_dest := rl.Vector2{auto_cast (rl.GetScreenWidth() / 2) - (rg.bb.width/ 2), 70}
            btm_dest := rl.Vector2{auto_cast (rl.GetScreenWidth() / 2) - (btm.bb.width/ 2), 95}
            go.bb.x = go_dest[0]
            go.bb.y = go_dest[1]
            rg.bb.x = rg_dest[0]
            rg.bb.y = rg_dest[1]
            btm.bb.x = btm_dest[0]
            btm.bb.y = btm_dest[1]
        } 
    }

    // Don't run the rest of this if we aren't in .GAME.
    if g_current_game_mode != .GAME {
        return
    }

    // Check that all of the bomb tiles have been flagged and every other
    // tile has been revealed.
    // TODO: Have the player win even if they didn't flag the bomb tiles
    // (implicit flagging)
    if bomb_count != 0 && bombs_flagged == bomb_count {
        should_win := true
        for tile in data {
            if tile.type != .BOMB && !tile.revealed {
                should_win = false
                break
            }
        }

        if should_win {
            g_current_game_mode = .GAME_WON // yay!
        }
    }

    // Offset the mouse position by the render texture position,
    // and floor divide by the tile size.
    m_pos := rl.GetMousePosition()
    m_pos -= render_tex_pos
    m_pos /= { th.dest_rec.width, th.dest_rec.height} 
    m_pos = { math.floor(m_pos[0]), math.floor(m_pos[1]) }


    // Get the tile the player has pressed.
    if rl.IsMouseButtonPressed(.LEFT) {
        if !is_oob(board, m_pos) {
            tile_coord := cast(int)(m_pos[1] * auto_cast width + m_pos[0])
            tile := &data[tile_coord]
            clicked_tile_pos = m_pos
        }
    }

    // If they are still holding down the button and the m_pos has not changed,
    // then keep the current tile tinted a light gray.
    if rl.IsMouseButtonDown(.LEFT) {
        if !is_oob(board, m_pos) {
            tile_coord := cast(int)(m_pos[1] * auto_cast width + m_pos[0])
            tile := &data[tile_coord]

            if m_pos == clicked_tile_pos && !tile.flagged && !tile.revealed && tile.tint == rl.WHITE {
                tile.tint = {150, 150, 150, 255}
            } else if m_pos != clicked_tile_pos && !is_oob(board, clicked_tile_pos) {
                clicked_coord := cast(int)(clicked_tile_pos[1] * auto_cast width + clicked_tile_pos[0])
                data[clicked_coord].tint = rl.WHITE
            }
        }
    }

    // Once the player releases the left mouse button, execute the primary
    // game logic.
    if rl.IsMouseButtonReleased(.LEFT) {
        fmt.printf("Left Click: <%v, %v>\n", m_pos[0], m_pos[1])

        // Make sure the mouse position hasn't changed before doing
        // the magic.
        if m_pos == clicked_tile_pos && !is_oob(board, m_pos) {
            tile_coord := cast(int)(m_pos[1] * auto_cast width + m_pos[0])
            tile := &data[tile_coord]
            

            // Only allow non-flagged and non-revealed tiles to be revealed.
            // This prevents unnecessary computations from being performed
            // on already revealed tiles.
            if !tile.flagged && !tile.revealed {
                tile.revealed = true
                tile.tint = rl.WHITE
                board.click_count += 1
                
                
                fmt.bprintf(board.click_count_buf[:], "%03d", board.click_count)
                click_label := widgets["click_count"].(^ret.Label)
                click_label.text = cstring(raw_data(board.click_count_buf[:]))
                
                // If bombs have not been generated yet on this click,
                // do it now. First step in preventing players from losing on the
                // first click.
                if !generated_bombs {
                    generated_bombs = true
                    seed_board_with_bombs(board, m_pos) // this contains the second step
                    place_numbered_tiles(board)
                }
                
                if tile.type == .BOMB {
                    g_current_game_mode = .GAME_OVER
                    reveal_all_bomb_tiles(board)
                }
                
                // Start the recursive reveal_tiles function if we haven't lost yet.
                reveal_tiles(board, auto_cast m_pos[0], auto_cast m_pos[1], true)
            }
        }
        
        // When reliniquishing the clicked tile position, we want to make sure that it's
        // tint is set back to the correct color (assuming it didn't get clicked.)
        // TODO: Check if this is even necesssary, it seems like previous logic in this
        // function already handles this case.
        if !is_oob(board, clicked_tile_pos) {
            tile := &data[int(clicked_tile_pos[1] * auto_cast width + clicked_tile_pos[0])]
            tile.tint = rl.WHITE
            clicked_tile_pos = {-1, -1}
        }
    }

    // For placing a flag down.
    if rl.IsMouseButtonReleased(.RIGHT) {
        fmt.printf("Right Click: <%v, %v>\n", m_pos[0], m_pos[1])

        if !is_oob(board, m_pos) {
            tile_coord := cast(int)(m_pos[1] * auto_cast width + m_pos[0])
            tile := &data[tile_coord]

            // Have to generate the bombs here too if they haven't clicked anything yet.
            if !generated_bombs {
                generated_bombs = true
                seed_board_with_bombs(board, m_pos)
                place_numbered_tiles(board)
            }

            if !tile.revealed {
                // Toggle the flag; increment or decrement the number flagged.
                toggle_flag_file(board, tile)    
            }
            fmt.printf("Bombs Flagged: %v / %v\n", bombs_flagged, bomb_count)
        }
    }
}

board_draw :: proc(board: ^Board) {
    using board
    mouse_pos := rl.GetMousePosition()


    for name, widget in widgets {
        ret.widget_update_draw(widget, mouse_pos)
    }

    rl.BeginTextureMode(render_texture)

    x, y: f32
    for tile, i in data {
        type := tile.type
        x := cast(f32)(i % board.width) * th.dest_rec.width
        y := cast(f32)(i / board.width) * th.dest_rec.height

        if !tile.revealed {
            type = .UNSELECTED
        }

        texture_handler_draw(th, type, {x, y}, tile.tint)

        if !tile.revealed && tile.flagged {
            texture_handler_draw(th, .FLAG, {x, y}, tile.tint)
        }
    }


    rl.EndTextureMode()


    rl.DrawTextureRec(
        render_texture.texture,
        render_tex_rect, 
        render_tex_pos, 
        rl.WHITE,
    )
}


board_free :: proc(board: ^Board) {
    fmt.println("Freeing board memory...")

    if board == nil {
        return
    }

    rl.UnloadRenderTexture(board.render_texture)
    rl.ClearBackground(rl.WHITE)
    
    for key, widget in board.widgets {
        ret.widget_free(widget)
    }
    delete(board.data)
    delete(board.widgets)
    free(board)
}


@(private="file")
toggle_flag_file :: proc(board: ^Board, tile: ^Tile) {
    using board

    if !tile.flagged && flag_count == 0 {
        return
    }

    tile.flagged = !tile.flagged

    flag_count += cast(int)math.pow(-1., cast(f32)(cast(int)tile.flagged))
    // -1^tile.flagged: adds a -1 or a 1 for counting bombs flagged.
    if tile.type == .BOMB {
        bombs_flagged += -cast(int)math.pow(-1., cast(f32)(cast(int)tile.flagged))
    }


    fmt.bprintf(flag_count_buf[:], "%03d", flag_count)
    flag_label := widgets["flag_count"].(^ret.Label)
    flag_label.text = cstring(raw_data(flag_count_buf[:]))
}

@(private="file")
is_oob :: proc(board: ^Board, pos: rl.Vector2) -> bool {
    using board

    return pos[0] < 0 || pos[0] > auto_cast board.width - 1 || pos[1] < 0 || pos[1] > auto_cast board.height - 1
}

@(private="file")
seed_board_with_bombs :: proc(board: ^Board, clicked_pos: rl.Vector2) {
    using board

    // So I don't need to compute it again.
    coord := cast(int)(clicked_pos[1] * auto_cast width + clicked_pos[0])
    
    // Place bomb_count bombs into the array sequentially.
    bomb_counter := 0
    for _, i in data {
        if i != coord {
            data[i].type = .BOMB
            bomb_counter += 1
        }

        if bomb_counter == bomb_count {
            break
        }
    }

    // Shuffle the array (very similar to core:rand.shuffle) to scatter
    // the bombs across the map.
    for i := int(0); i < len(data); {
		j := rand.int63_max(i64(len(data)))
		data[i].type, data[j].type = data[j].type, data[i].type
        i += 1
    }

    // Naive way of ensuring that the tile we clicked is NOT a bomb ever.
    if data[coord].type == .BOMB {
        for _, i in data {
            if data[i].type == TileType.EMPTY {
                data[coord].type, data[i].type = data[i].type, data[coord].type
                break
            }
        }
    }

}

@(private="file")
place_numbered_tiles :: proc(board: ^Board) {
    using board

    x, y: int
    ax, ay: int
    for tile, i in data {

        // Nice way of computing the x and y for a 1D array.
        x = i % width
        y = i / width

        // Number this tile according to the tiles around it.
        if tile.type == TileType.EMPTY {
            
            neighbors := 0
            for dy in -1..<2 {
                for dx in -1..<2 {
                    ax = x + dx
                    ay = y + dy
                    if !is_oob(board, {auto_cast ax, auto_cast ay}) && data[ay * width + ax].type == TileType.BOMB {
                        neighbors += 1
                    }
                }
            }

            data[y * width + x].type = cast(TileType)neighbors
        }   
    }
}

@(private="file")
reveal_all_bomb_tiles :: proc(board: ^Board) {
    using board

    for &tile in data {

        // Change the tile's type at the game over screen
        // if it was incorrectly marked as a bomb.
        if tile.flagged && tile.type != .BOMB {
            tile.revealed = true
            tile.type = .BOMB_WRONG
        }

        if tile.type == TileType.BOMB {
            tile.revealed = true
        }
    }
}

@(private="file")
reset :: proc(board: uintptr) {
    board := transmute(^Board)board
    using board

    // Move all of the game over/won widgets out of view again.
    g_current_game_mode = .GAME
    go := widgets["game_over"].(^ret.Label)
    go.bb.x = -1000
    go.bb.y = -1000

    rg := widgets["reset_game"].(^ret.Button)
    rg.bb.x = -1000
    rg.bb.y = -1000

    btm := widgets["back_to_menu"].(^ret.Button)
    btm.bb.x = -1000
    btm.bb.y = -1000

    gw := widgets["game_won"].(^ret.Label)
    gw.bb.x = -1000
    gw.bb.y = -1000

    // Reset the rest of the values
    generated_bombs = false
    bombs_flagged = 0
    click_count = 0
    flag_count = bomb_count

    fmt.bprintf(board.click_count_buf[:], "%03d", board.click_count)
    click_label := widgets["click_count"].(^ret.Label)
    click_label.text = cstring(raw_data(board.click_count_buf[:]))


    fmt.bprintf(flag_count_buf[:], "%03d", flag_count)
    flag_label := widgets["flag_count"].(^ret.Label)
    flag_label.text = cstring(raw_data(flag_count_buf[:]))

    // Reset the tiles in the board.
    for &tile in data {
        tile.flagged = false
        tile.revealed = false
        tile.type = .EMPTY
    }
}

@(private="file")
back_to_menu :: proc(board: uintptr) {
    board := transmute(^Board)board
    
    // The switching of the screens is handled by the main method in main.odin.
    g_current_game_mode = .MENU
}

@(private="file")
reveal_tiles :: proc(board: ^Board, tx, ty: int, first_clicked: bool) {
    using board
    
    selected_tile := &data[ty * width + tx]
    selected_tile.flagged = false
    ax, ay : int


    if selected_tile.type == TileType.EMPTY { // Recursive case 
		for y in -1..<2 {
			for x in -1..<2 {
				ax = x + tx
				ay = y + ty

				if (x == 0 && y == 0) || x == y || is_oob(board, {auto_cast ax, auto_cast ay}) {
					continue
				}

				// Source of bugs here, forgot to take the address before which made tile a copy, not a reference.
				tile := &data[ay * width + ax]

				if !tile.revealed && tile.type != TileType.BOMB {
                    if tile.flagged {
                        tile.flagged = false
                        flag_count += 1
                    }

                    tile.revealed = true

					if tile.type == TileType.EMPTY {

                        // false is passed in to ensure numbered tiles
                        // do not get chorded to reveal what is around
                        // TODO: chording isn't actually implemented yet.
						reveal_tiles(board, ax, ay, false)
					}
				}
			}
		}
	}
    
}


/*
currently scrapped chording logic, I ran into an array oob bug and this code does work as intended,
so this will stay here for now.


 if first_clicked && selected_tile.revealed && selected_tile.type != .EMPTY && selected_tile.type != .BOMB { // chord case
        tiles_to_reveal := make([dynamic]^Tile)
        defer delete(tiles_to_reveal)
        bomb_correctly_flagged := false

        for y in -1..<2 {
			for x in -1..<2 {
                ax = x + tx
				ay = y + ty

				if (x == 0 && y == 0) || x == y || is_oob(board, {auto_cast ax, auto_cast ay}) {
					continue
				}

				tile := &data[ay * width + ax]
                if !tile.revealed && tile.flagged && tile.type == .BOMB {
                    bomb_correctly_flagged = true
                }
                
                if !tile.revealed && tile.type != .BOMB {
                    append(&tiles_to_reveal, tile)
                }
            }

            if bomb_correctly_flagged {
                break
            }
        }
        
        if bomb_correctly_flagged {
            for tile in tiles_to_reveal {
                tile.revealed = true
            }
        }
    }
    else

*/