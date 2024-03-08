package main

import "core:math"
import "core:fmt"
import "core:math/rand"
import "core:strings"
import rl "vendor:raylib"

import ret "retgui"

Board :: struct {
    data: [dynamic]Tile,
    th: ^TextureHandler,
    render_texture: rl.RenderTexture,
    width: int,
    height: int,

    render_tex_rect: rl.Rectangle,
    render_tex_pos: rl.Vector2,

    generated_bombs: bool,
    
    bomb_threshold: f32,
    bombs_on_board: int,
    bombs_flagged: int,

    flag_count: int,
    click_count: int,

    widgets: map[string]ret.WidgetType,

    flag_count_buf: [8]byte,
    click_count_buf: [8]byte,

    clicked_tile_pos: rl.Vector2,
}

board_new :: proc(width, height: int, threshold: f32, th: ^TextureHandler) -> ^Board {
    assert(th != nil, "No textures to reference, unable to create this board.")

    board : ^Board = new(Board)
    board.data = make([dynamic]Tile, width * height)
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

    board.bomb_threshold = threshold
    board.bombs_on_board = 0
    board.bombs_flagged = 0

    // Like the original minesweeper
    board.flag_count = 99
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
        40.,
        rl.Color{},
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
        40.,
        rl.Color{},
    )

    board.widgets["game_over"] = ret.label_new(
        "game_over",
        {-1000, -1000},
        {200, 50},
        "Game Over!",
        20,
        rl.Color{},
    )

    board.widgets["reset_game"] = ret.button_new(
        "reset_game",
        {-1000, -1000},
        {100, 20},
        "Restart",
        20,
        reset,
        rl.BLUE,
        transmute(uintptr)board,
    )

    board.clicked_tile_pos = {-1, -1}

    return board
}


board_update :: proc(board: ^Board, dt: f32) {
    using board
    g_current_game_mode = .GAME_OVER

    if g_current_game_mode == .GAME_OVER {
        if rg, ok := widgets["reset_game"].(^ret.Button); ok && rg.bb.x < 0 && rg.bb.y < 0 {
            go := widgets["game_over"].(^ret.Label)
            go_dest := rl.Vector2{auto_cast (rl.GetScreenWidth() / 2) - (go.bb.width/ 2), 50}
            rg_dest := rl.Vector2{auto_cast (rl.GetScreenWidth() / 2) - (rg.bb.width/ 2), 85}
            go.bb.x = go_dest[0]
            go.bb.y = go_dest[1]
            rg.bb.x = rg_dest[0]
            rg.bb.y = rg_dest[1]
        } 
    }

    // Basically don't run this function unless the game is actually
    // in session.
    if g_current_game_mode != .GAME {
        return
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
    
            if m_pos == clicked_tile_pos && !tile.revealed && tile.tint == rl.WHITE {
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

            reveal_tiles(board, auto_cast m_pos[0], auto_cast m_pos[1])
        }
        
        if !is_oob(board, clicked_tile_pos) {
            tile := &data[int(clicked_tile_pos[1] * auto_cast width + clicked_tile_pos[0])]
            tile.tint = rl.WHITE
            clicked_tile_pos = {-1, -1}
        }
    }

    // For placing a flag down.
    if rl.IsMouseButtonPressed(.RIGHT) {
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
            fmt.printf("Bombs Flagged: %v / %v\n", bombs_flagged, bombs_on_board)
        }
    }

    if rl.IsKeyPressed(.ZERO) {
        for _, i in data {
            data[i].revealed = true
        }
    }

    if rl.IsKeyPressed(.E) {
        reset(transmute(uintptr)board)
    }
}

board_draw :: proc(board: ^Board) {
    using board
    mouse_pos := rl.GetMousePosition()

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

    for name, widget in widgets {
        ret.widget_update_draw(widget, mouse_pos)
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

    tile.flagged = !tile.flagged
    flag_count += -cast(int)math.pow(-1., cast(f32)(cast(int)tile.flagged+1))

    // -1^tile.flagged: adds a -1 or a 1 for counting bombs flagged.
    if tile.type == .BOMB {
        bombs_flagged += cast(int)math.pow(-1., cast(f32)(cast(int)tile.flagged+1))
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
    for type, i in data {
        if rand.float32() < bomb_threshold && coord != i {
            data[i].type = .BOMB
            bombs_on_board += 1
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

    generated_bombs = false
    bombs_on_board = 0
    bombs_flagged = 0
    click_count = 0
    flag_count = 99

    for &tile in data {
        tile.flagged = false
        tile.revealed = false
        tile.type = TileType.EMPTY
    }
}

@(private="file")
reveal_tiles :: proc(board: ^Board, tx, ty: int) {
    using board
    
    selected_tile := &data[ty * width + tx]
    selected_tile.flagged = false
    ax, ay : int
	if selected_tile.type == TileType.EMPTY {
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
						reveal_tiles(board, ax, ay)
					}
				}
			}
		}
	}
}