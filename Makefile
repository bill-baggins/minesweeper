PACKAGE := game

STACK_SIZE := 6291456
HEAP_SIZE := 67108864

clean:
	rm -rf out/debug
	rm -rf out/release
	rm -f *.dll
	rm -f *.pdb
	rm -f *.lib
	rm -f *.exe
	rm -f *.exp

# The batch file needs a copy of the raylib.dll in the directory where the hot_reloaded
# game is running from.
hot:
	cmd /C build_hot_reload.bat

run_hot: hot
	odin run hot_reload --collection:libs=libs

desktop: clean
	mkdir -p out/debug/desktop
	odin build desktop --collection:libs=libs -define:RAYLIB_SHARED=false -out:./out/debug/desktop/$(PACKAGE).exe -no-bounds-check -subsystem:windows -debug

run: build-desktop
	./out/debug/desktop/$(PACKAGE).exe

webweb:
	mkdir -p out/debug/web
	mkdir -p out/debug/.intermediate
	odin build web --collection:libs=libs -target=freestanding_wasm32 -out:"out/debug/.intermediate/$(PACKAGE)" -build-mode:obj -debug -show-system-calls
	emcc -o out/debug/web/index.html web/web.c out/debug/.intermediate/$(PACKAGE).wasm.o libs/raylib/web/libraylib.a -sUSE_GLFW=3 -sASYNCIFY -sGL_ENABLE_GET_PROC_ADDRESS -DWEB_BUILD -sSTACK_SIZE=$(STACK_SIZE) -sTOTAL_MEMORY=$(HEAP_SIZE) -sERROR_ON_UNDEFINED_SYMBOLS=0  -sALLOW_MEMORY_GROWTH=1 --preload-file assets --shell-file=libs/minshell.html

web_release:
	mkdir -p out/release/web
	mkdir -p out/release/.intermediate
	odin build web --collection:libs=libs -target=freestanding_wasm32 -out:"out/release/.intermediate/$(PACKAGE)" -build-mode:obj -o:size
	emcc -o out/release/web/index.html web/web.c out/release/.intermediate/$(PACKAGE).wasm.o libs/raylib/web/libraylib.a -sUSE_GLFW=3 -sASYNCIFY -sGL_ENABLE_GET_PROC_ADDRESS -DWEB_BUILD -sSTACK_SIZE=$(STACK_SIZE) -sTOTAL_MEMORY=$(HEAP_SIZE) -sERROR_ON_UNDEFINED_SYMBOLS=0 -sALLOW_MEMORY_GROWTH=1 --preload-file assets --shell-file=libs/minshell.html
