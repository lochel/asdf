package main

import "core:c"
import "engine"
import rl "vendor:raylib"

Preload_Context :: struct {
	using scene: engine.Scene_Context,
}

preload_init :: proc(ctx: ^engine.Scene_Context) {
	level_files := init_level_files()
	defer delete(level_files)

	LEVELS = make([]LevelDef, len(level_files))
	for f, i in level_files {
		LEVELS[i] = load_level_meta(f)
	}

	assets_global = load_assets()
}

preload_deinit :: proc(ctx: ^engine.Scene_Context) {
	unload_assets(assets_global)

	for l in LEVELS {
		delete(l.label)
		delete(l.split_scores)
	}
	delete(LEVELS)
}

preload_update :: proc(ctx: ^engine.Scene_Context, dt: f32) {
	_ = dt
	engine.switch_scene(ctx.eng, engine.getScene(ctx.eng, "menu"), .Fade, 1.5)
}

preload_render :: proc(ctx: ^engine.Scene_Context) {
	sw := ctx.eng.config.width
	sh := ctx.eng.config.height

	rl.ClearBackground(rl.Color{20, 20, 30, 255})

	text: cstring = "Loading..."
	fsize: c.int = 40
	tw := rl.MeasureText(text, fsize)
	rl.DrawText(text, (sw - tw) / 2, sh / 2 - fsize / 2, fsize, rl.WHITE)
}
