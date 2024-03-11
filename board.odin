package main

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

    board.render_texture = rl.LoadRenderTexture(
        auto_cast (cast(f32)board.width * th.dest_rec.width), 
        auto_cast (cast(f32)board.height * th.dest_rec.height),
    )

    for _, i in board.data {
        board.data[i] = Tile{TileType.EMPTY, false, false, rl.WHITE}
    }

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

    // Like the original minesweeper
    board.flag_count = bomb_count
    board.click_count = 0

    board.widgets = make(map[string]ret.WidgetType)
    
    b_x := board.render_tex_pos[0]
    b_y := board.render_tex_pos[1]
    b_width := cast(f32) board.render_texture.texture.width
    b_height := cast(f32) -board.render_texture.texture.height // Since it was set to a negative value
    

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

    board.clicked_tile_pos = {-1, -1}

    return board
}


board_update :: proc(board: ^Board, dt: f32) {
    using board

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

    // Basically don't run this function unless the game is actually
    // in session.
    if g_current_game_mode != .GAME {
        return
    }

    if bomb_count != 0 && bombs_flagged == bomb_count {
        should_win := true
        for tile in data {
            if tile.type != .BOMB && !tile.revealed {
                should_win = false
                break
            }
        }

        if should_win {
            g_current_game_mode = .GAME_WON
        }
    }

    // Adjusts the mouse position based on where the render texture is.
    m_pos := rl.GetMousePosition()
    m_pos -= render_tex_pos
    m_pos /= {th.dest_rec.width, th.dest_rec.height} 
    m_pos[0] = math.floor(m_pos[0])
    m_pos[1] = math.floor(m_pos[1])


    if rl.IsMouseButtonPressed(.LEFT) {
        if !is_oob(board, m_pos) {
            tile_coord := cast(int)(m_pos[1] * auto_cast width + m_pos[0])
            tile := &data[tile_coord]
            clicked_tile_pos = m_pos
        }
    }

    if rl.IsMouseButtonDown(.LEFT) {
        if !is_oob(board, m_pos) {
            tile_coord := cast(int)(m_pos[1] * auto_cast width + m_pos[0])
            tile := &data[tile_coord]

            if m_pos == clicked_tile_pos && !tile.flagged && !tile.revealed && tile.tint == rl.WHITE {
                tile.tint = {150, 150, 150, 255}
            } else if m_pos != clicked_tile_pos {
                clicked_coord := cast(int)(clicked_tile_pos[1] * auto_cast width + clicked_tile_pos[0])
                data[clicked_coord].tint = rl.WHITE
            }
        }
    }

    if rl.IsMouseButtonReleased(.LEFT) {
        fmt.printf("Left Click: <%v, %v>\n", m_pos[0], m_pos[1])

        if m_pos == clicked_tile_pos && !is_oob(board, m_pos) {
            tile_coord := cast(int)(m_pos[1] * auto_cast width + m_pos[0])
            tile := &data[tile_coord]
            

            // Prevent the flagged tiles from getting revealed
            // by accident from the flag
            if !tile.flagged {
                tile.revealed = true
                tile.tint = rl.WHITE
                board.click_count += 1
                
                
                fmt.bprintf(board.click_count_buf[:], "%03d", board.click_count)
                click_label := widgets["click_count"].(^ret.Label)
                click_label.text = cstring(raw_data(board.click_count_buf[:]))
                
                if !generated_bombs {
                    generated_bombs = true
                    seed_board_with_bombs(board, m_pos)
                    place_numbered_tiles(board)
                }

                if tile.type == .BOMB {
                    g_current_game_mode = .GAME_OVER
                    reveal_all_bomb_tiles(board)
                }

                reveal_tiles(board, auto_cast m_pos[0], auto_cast m_pos[1], true)
            }
        }
        
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

            // Have to generate the bombs here too just in case.
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

    coord := cast(int)(clicked_pos[1] * auto_cast width + clicked_pos[0])
    
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

    // Repurposed array shuffle (very similar to rand.shuffle) for scattering
    // the bombs across the map.
    for i := int(0); i < len(data); {
		j := rand.int63_max(i64(len(data)))
		data[i].type, data[j].type = data[j].type, data[i].type
        i += 1
    }

    // Native way of ensuring that the tile we clicked is NOT a bomb ever.
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
        x = i % width
        y = i / width

        
        if tile.type != TileType.BOMB && tile.type == TileType.EMPTY {
            
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

    for &tile in data {
        tile.flagged = false
        tile.revealed = false
        tile.type = .EMPTY
    }
}

@(private="file")
back_to_menu :: proc(board: uintptr) {
    board := transmute(^Board)board

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
					tile.revealed = true
                    tile.flagged = false
					if tile.type == TileType.EMPTY {

                        // false is passed in to ensure numbered tiles
                        // do not get chorded to reveal what is around
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