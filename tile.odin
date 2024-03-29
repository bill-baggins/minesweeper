package main

import rl "vendor:raylib"

TileType :: enum {
    EMPTY,
    ONE,
    TWO,
    THREE,
    FOUR,
    FIVE,
    SIX,
    SEVEN,
    EIGHT,
    BOMB,
    BOMB_WRONG,
    FLAG,
    UNSELECTED,
}


Tile :: struct {
    type: TileType,
    revealed: bool,
    flagged: bool,
    tint: rl.Color,
}