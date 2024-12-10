#include <stdio.h>
#include <emscripten/emscripten.h>

extern void web_game_init();
extern void web_game_update();
extern void web_game_dispose();

int main() {
    web_game_init();
    emscripten_set_main_loop(web_game_update, 0, 1);
    web_game_dispose();
    return 0;
}
