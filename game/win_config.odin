package main

import rl "vendor:raylib"

@private
WinConfig :: struct {
    width: i32,
    height: i32,
    
    fps: i32,
    title: cstring,
    fullscreen: bool,
}

winconfig_new :: proc(width, height : i32, title: cstring, fps: i32 = 60) -> ^WinConfig {
    wconfig := new(WinConfig)
    wconfig.width = width
    wconfig.height = height
    wconfig.title = title
    wconfig.fps = fps
    wconfig.fullscreen = false

    return wconfig
}

winconfig_apply :: proc(wconfig: ^WinConfig, init: bool = false) {
    using wconfig

    if init {
        rl.InitWindow(width, height, title)
        rl.SetTargetFPS(fps)
        if fullscreen {
            rl.ToggleFullscreen()
        }
    } else {
        rl.SetWindowSize(width, height)
        rl.SetWindowTitle(title)
        if fullscreen {
            rl.ToggleFullscreen()
        }
    }
}

winconfig_free :: proc(wconfig: ^WinConfig) {
    free(wconfig)
    rl.CloseWindow()
}
