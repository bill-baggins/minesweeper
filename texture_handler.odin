package main

import rl "vendor:raylib"
import "core:fmt"
import "core:c"

TextureHandler :: struct {
	atlas: rl.Texture,
	rect_map: map[TileType]rl.Rectangle,
    dest_rec: rl.Rectangle,
}

texture_handler_new :: proc(scale: f32) -> ^TextureHandler {
    assert(scale > 0.0, "Cannot input a scale less than or equal to 0.")
    // Some notes:
    // Tiles:
    // start at (10, 30), end at (373, 30)
    // 3px gap between each tile
    // Flag:
    // (10, 180) start
    th : ^TextureHandler = new(TextureHandler)
    atlas_im := rl.LoadImage("assets/minesweeper.png")
    rl.ImageResize(&atlas_im, cast(c.int)(cast(f32)atlas_im.width * scale), cast(c.int)(cast(f32)atlas_im.height * scale))
    rl.ImageColorReplace(&atlas_im, {0x99, 0xbb, 0xec, 0xff}, {})
    defer rl.UnloadImage(atlas_im)

    width := 30.0 * scale
    height := 30.0 * scale
    w := width
    h := height

    th.dest_rec = rl.Rectangle{0, 0, w, h}

    gap := 3. * scale

    th.atlas = rl.LoadTextureFromImage(atlas_im)

    using TileType
    th.rect_map = map[TileType]rl.Rectangle {
        UNSELECTED = rl.Rectangle{(10. * scale), h, w, h},
        EMPTY = rl.Rectangle{(10. * scale) + (1 * w) + (gap * 1), h, w, h},
        ONE = rl.Rectangle{(10. * scale) + (2 * w) + (gap * 2), h, w, h},
        TWO = rl.Rectangle{(10. * scale) + (3 * w) + (gap * 3), h, w, h},
        THREE = rl.Rectangle{(10. * scale) + (4 * w) + (gap * 4), h, w, h},
        FOUR = rl.Rectangle{(10. * scale) + (5 * w) + (gap * 5), h, w, h},
        FIVE = rl.Rectangle{(10. * scale) + (6 * w) + (gap * 6), h, w, h},
        SIX = rl.Rectangle{(10. * scale) + (7 * w) + (gap * 7), h, w, h},
        SEVEN = rl.Rectangle{(10. * scale) + (8 * w) + (gap * 8), h, w, h},
        EIGHT = rl.Rectangle{(10. * scale) + (9 * w) + (gap * 9), h, w, h},
        BOMB = rl.Rectangle{(10. * scale) +(10 * w) + (gap * 10), h, w, h},
        FLAG = rl.Rectangle{167, 99,  w,  h},
    }

    bomb_icon := rl.ImageFromImage(atlas_im, th.rect_map[BOMB])
    rl.SetWindowIcon(bomb_icon)

    return th
}

texture_handler_free :: proc(th: ^TextureHandler) {
    using th
    
    rl.UnloadTexture(atlas)
    delete(rect_map)
    free(th)
}

texture_handler_draw :: proc(th: ^TextureHandler, type: TileType, location: rl.Vector2) {
    using th
    rec := rect_map[type]
    dest_rec.x = location[0]
    dest_rec.y = location[1]
    rl.DrawTexturePro(atlas, rec, dest_rec, rl.Vector2{}, 0, rl.WHITE)
}