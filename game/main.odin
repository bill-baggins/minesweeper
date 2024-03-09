package main

import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

import rg "retgui"

import "core:thread"


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

@(export)
start :: proc () {

    track: mem.Tracking_Allocator
    arena: mem.Arena

    when ODIN_DEBUG {
        fmt.println("DEBUG: Using the tracking allocator to find memory leaks.")
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)
    } else {
        @static heap : [4096 * 4096]u8
        fmt.printf("Size of the arena heap: %v\n", len(heap))
        fmt.println("Using the arena allocator.")
        mem.arena_init(&arena, heap[:])
        context.allocator = mem.arena_allocator(&arena)
    }

    main_loop()

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

DataPacket :: struct {
    th: ^TextureHandler,
    board: ^Board,
    menu: ^Menu,
}

main_loop :: proc() {
    wconfig := winconfig_new(1200, 720, "Minesweeper")
    defer winconfig_free(wconfig)
    winconfig_apply(wconfig, init=true)

    rl.SetExitKey(.KEY_NULL)

    d := DataPacket{}
    d.menu = menu_new(&d)
    d.th = nil
    d.board = nil

    defer texture_handler_free(d.th)
    defer board_free(d.board)
    defer menu_free(d.menu)

    should_leave := false

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()

        if rl.IsKeyPressed(.ESCAPE) {
            toggle_menu()
        }

        switch g_current_game_mode {
        case .GAME:
            fallthrough
        case .GAME_OVER:
            fallthrough
        case .GAME_WON:
            board_update(d.board, dt)

            rl.BeginDrawing()
            rl.ClearBackground(rl.DARKGRAY)
            rl.DrawFPS(0, 0)

            board_draw(d.board)

            rl.EndDrawing()

        case .MENU:
            rl.BeginDrawing()
            rl.ClearBackground(rl.DARKGRAY)
            rl.DrawFPS(0, 0)
            menu_update_draw(d.menu)

            rl.EndDrawing()
        case .QUIT:
            should_leave = true
            break
        }

        if should_leave {
            break
        }
    }
}
