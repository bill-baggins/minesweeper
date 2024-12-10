package web

import g ".."
import "base:runtime"
import "core:math/rand"
import "core:mem"
import rl "libs:raylib"

foreign import "odin_env"

ctx: runtime.Context

tempAllocatorData: [mem.Megabyte * 8]byte
tempAllocatorArena: mem.Arena

mainMemoryData: [mem.Megabyte * 32]byte
mainMemoryArena: mem.Arena

@(export, link_name = "web_game_init")
web_game_init :: proc "c" () {
	ctx = runtime.default_context()
	context = ctx

	mem.arena_init(&mainMemoryArena, mainMemoryData[:])
	mem.arena_init(&tempAllocatorArena, tempAllocatorData[:])

	ctx.allocator = mem.arena_allocator(&mainMemoryArena)
	ctx.temp_allocator = mem.arena_allocator(&tempAllocatorArena)
	g.game_init()
}

@(export, link_name = "web_game_update")
web_game_update :: proc "contextless" () {
	context = ctx
	g.game_update()
}

@(export, link_name = "web_game_dispose")
web_game_dispose :: proc "contextless" () {
	context = ctx
	g.game_shutdown()
}
