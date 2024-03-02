package main

import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

import rg "retgui"


Difficulty :: enum {
    EASY,
    NORMAL,
    HARD,
}

game_loop :: proc() {
    wconfig := winconfig_new(1200, 720, "Minesweeper")
    defer winconfig_free(wconfig)
    winconfig_apply(wconfig, init=true)

    difficulty := Difficulty.NORMAL
    
    th: ^TextureHandler
    board : ^Board
    
    switch difficulty {
    case .EASY:
        th = texture_handler_new(1.5)
        board = board_new(9, 9, 0.10, th)
    case .NORMAL:
        th = texture_handler_new(1)
        board = board_new(16, 16, 0.12, th)
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

    track: mem.Tracking_Allocator

    when ODIN_DEBUG {
        fmt.println("DEBUG: Using the tracking allocator to find memory leaks.")
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)
    }

    game_loop()

    when ODIN_DEBUG {
        mem_leaked := len(track.allocation_map) != 0
        bad_frees := len(track.bad_free_array) != 0

        fmt.println("DEBUG: Checking for any leaked memory...")

        for _, leak in track.allocation_map {
            fmt.printf("%v leaked %m\n", leak.location, leak.size)
        }

        for bad_free in track.bad_free_array {
            fmt.printf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory)
        }

        if !mem_leaked {
            fmt.println("No memory leaked!")
        }

        if !bad_frees {
            fmt.println("No bad frees!")
        }

        mem.tracking_allocator_destroy(&track)
    }
}
