package main

import "core:fmt"
import rl "vendor:raylib"


Difficulty :: enum {
    EASY,
    NORMAL,
    HARD,
}

// TODO:
// Add the Flags. Make them static for right now. Their backgrounds need to be cleared
// since the background of the image is skyblue.
// 
// Add a menu. Here, you should be able to choose the difficulty you want, as well as a custom
// difficulty for custom sized boards and custom difficulty thresholds. This is where an idea for
// creating a retained UI or my own immediate UI will come into play (perhaps a customizable immediate UI)
// 
// Once the menu is finished and it is customizable, then I will attempt porting it to the web using the
// raylib-wasm odin template, and I'll finally be happy in life :D
main :: proc() {
    wconfig := winconfig_new(1200, 720, "Minesweeper")
    defer winconfig_free(wconfig)
    winconfig_apply(wconfig, init=true)

    difficulty := Difficulty.HARD
    
    th: ^TextureHandler
    board : ^Board
    
    switch difficulty {
    case .EASY:
        th = texture_handler_new(2)
        board = board_new(9, 9, 0.10, th)
    case .NORMAL:
        th = texture_handler_new(1.5)
        board = board_new(16, 16, 0.13, th)
    case .HARD:
        th = texture_handler_new(1)
        board = board_new(30, 16, 0.17, th)
    }
    defer texture_handler_free(th)
    defer board_free(board)

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()

        board_update(board, dt)

        rl.BeginDrawing()
        rl.ClearBackground(rl.DARKGRAY)
        rl.DrawFPS(0, 0)
        
        board_draw(board)

        rl.EndDrawing()
    }
}
