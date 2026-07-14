package main

import "engine"

main :: proc() {
	default_cfg := engine.Config {
		width      = 800,
		height     = 600,
		fullscreen = false,
		resizable  = false,
		target_fps = 60,
	}
	app := engine.create("Diggle", default_cfg)
	defer engine.destroy(&app)

	engine.enable_audio(&app)

	preload := Preload_Context {
		scene = {
			init   = preload_init,
			deinit = preload_deinit,
			update = preload_update,
			render = preload_render,
		},
	}

	menu := Menu_Context {
		scene = {
			enter  = menu_enter,
			leave  = menu_leave,
			input  = menu_input,
			step   = menu_step,
			render = menu_render,
		},
	}

	game := Game_Context {
		scene = {
			enter  = game_enter,
			leave  = game_leave,
			input  = game_input,
			step   = game_step,
			update = game_update,
			render = game_render,
		},
	}

	engine.addScene(&app, "preload", &preload.scene)
	engine.addScene(&app, "menu", &menu.scene)
	engine.addScene(&app, "game", &game.scene)

	engine.run(&app, "preload")
}
