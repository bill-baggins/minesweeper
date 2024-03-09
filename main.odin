package main

import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:thread"
import "core:strings"
import "core:time"
import "core:sync"

MAIN :: "start"
DLL :: "game.dll"

RAYLIB_DLL_PATH :: "C:/Odin-dev-2024-02/vendor/raylib/windows/raylib.dll"

Symbols :: struct {
    start: proc(),
    minesweeper_handle: dynlib.Library,
}

previous_build : time.Time
sym : Symbols
should_rebuild : sync.Cond
lock : sync.Mutex

main :: proc () {
    sb : strings.Builder


    strings.builder_init(&sb)
    defer strings.builder_destroy(&sb)

    count, ok := dynlib.initialize_symbols(&sym, "./out/game.dll", "", "minesweeper_handle")
	defer dynlib.unload_library(sym.minesweeper_handle)
	fmt.printf("(Initial DLL Load) ok: %v. %v symbols loaded from %v (%p).\n", ok, count, DLL, sym.minesweeper_handle)

    game_thread := thread.create(run)
    check_dll_thread := thread.create(check_dll_creation_date)

    thread.start(check_dll_thread)
    thread.start(game_thread)
    defer thread.destroy(check_dll_thread)
    defer thread.destroy(game_thread)
    
    for {
        sync.mutex_lock(&lock)
        defer sync.mutex_unlock(&lock)
        
        sync.wait(&should_rebuild, &lock)

        count, ok := dynlib.initialize_symbols(&sym, "./out/game.dll", "", "minesweeper_handle")
        fmt.printf("(DLL Reload) ok: %v. %v symbols loaded from %v (%p).\n", ok, count, DLL, sym.minesweeper_handle)
        thread.terminate(game_thread, 0)
        thread.destroy(game_thread)
        game_thread = thread.create(run)
        thread.start(game_thread)
    }
}


run :: proc(_: ^thread.Thread) {
    sym.start()
}


check_dll_creation_date :: proc(_: ^thread.Thread) {
    for {
        time.sleep(auto_cast time.duration_seconds(2))
        file_info, err := os.stat("./out/game.dll")
        if err != os.ERROR_NONE {
            fmt.eprintf("Could not load the file. Error: %v\n", err)
            os.exit(1)
        }

        if file_info.creation_time._nsec != previous_build._nsec {
            sync.cond_signal(&should_rebuild)
            previous_build._nsec = file_info.creation_time._nsec
        }
    }
}