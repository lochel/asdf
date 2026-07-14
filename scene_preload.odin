package main

import "core:c"
import "engine"
import rl "vendor:raylib"

Preload_Context :: struct {
	using scene: engine.Scene_Context,
	loaded:     bool,
}

preload_init :: proc(ctx: ^engine.Scene_Context) {
	pc := cast(^Preload_Context)ctx

	level_files := init_level_files()
	defer delete(level_files)

	LEVELS = make([]LevelDef, len(level_files))
	for f, i in level_files {
		LEVELS[i] = load_level_meta(f)
	}

	assets_global = load_assets()

	pc.loaded = true
}

preload_render :: proc(ctx: ^engine.Scene_Context) {
	pc := cast(^Preload_Context)ctx

	sw := pc.eng.config.width
	sh := pc.eng.config.height

	rl.ClearBackground(rl.Color{20, 20, 30, 255})

	text: cstring = "Loading..."
	fsize: c.int = 40
	tw := rl.MeasureText(text, fsize)
	rl.DrawText(text, (sw - tw) / 2, sh / 2 - fsize / 2, fsize, rl.WHITE)

	if pc.loaded {
		engine.switch_scene(pc.eng, engine.getScene(pc.eng, "menu"), .Fade, 1.5)
	}
}
