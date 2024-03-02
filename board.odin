package main

import "core:math"
import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

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
        board.data[i] = Tile{TileType.EMPTY, false, false}
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

    return board
}


board_update :: proc(board: ^Board, dt: f32) {
    using board

    if rl.IsMouseButtonPressed(.LEFT) {

        // Adjusts the mouse position based on where the render texture is.
        m_pos := rl.GetMousePosition()
        m_pos -= render_tex_pos
        m_pos /= {th.dest_rec.width, th.dest_rec.height} 
        m_pos[0] = math.floor(m_pos[0])
        m_pos[1] = math.floor(m_pos[1])

        fmt.printf("Left Click: <%v, %v>\n", m_pos[0], m_pos[1])

        if !is_oob(board, m_pos) {
            tile_coord := cast(int)(m_pos[1] * auto_cast width + m_pos[0])
            tile := &data[tile_coord]
            
            tile.revealed = true
            if !generated_bombs {
                generated_bombs = true
                seed_board_with_bombs(board, m_pos)
                place_numbered_tiles(board)
            }

            if tile.type == .BOMB {
                reveal_all_bomb_tiles(board)
                // set a game over state
            }

            reveal_tiles(board, auto_cast m_pos[0], auto_cast m_pos[1])
        }
    }

    // For placing a flag down.
    if rl.IsMouseButtonPressed(.RIGHT) {
        // Adjusts the mouse position based on where the render texture is.
        m_pos := rl.GetMousePosition()
        m_pos -= render_tex_pos
        m_pos /= { th.dest_rec.width, th.dest_rec.height }
        m_pos[0] = math.floor(m_pos[0])
        m_pos[1] = math.floor(m_pos[1])

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
        reset(board)
    }
}


board_draw :: proc(board: ^Board) {
    using board

    rl.BeginTextureMode(render_texture)

    x, y: f32
    for tile, i in data {
        type := tile.type
        x := cast(f32)(i % board.width) * th.dest_rec.width
        y := cast(f32)(i / board.width) * th.dest_rec.height

        if !tile.revealed {
            type = TileType.UNSELECTED
        }

        texture_handler_draw(th, type, {x, y})

        if !tile.revealed && tile.flagged {
            texture_handler_draw(th, .FLAG, {x, y})
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
    delete(board.data)
    rl.UnloadRenderTexture(board.render_texture)
    free(board)
}

@(private="file")
toggle_flag_file :: proc(board: ^Board, tile: ^Tile) {
    tile.flagged = !tile.flagged

    // -1^tile.flagged: adds a -1 or a 1 for counting bombs flagged.
    if tile.type == .BOMB {
        board.bombs_flagged += cast(int)math.pow(-1., cast(f32)(cast(int)tile.flagged+1))
    }
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
reset :: proc(board: ^Board) {
    using board

    generated_bombs = false
    bombs_on_board = 0
    bombs_flagged = 0

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