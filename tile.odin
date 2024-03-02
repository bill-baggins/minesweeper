package main

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
    FLAG,
    UNSELECTED,
}

Tile :: struct {
    type: TileType,
    revealed: bool,
    flagged: bool,
}