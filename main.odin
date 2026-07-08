package main

import "engine"

main :: proc() {
	default_cfg := engine.Config {
		width      = 800,
		height     = 600,
		fullscreen = false,
		resizable  = true,
		target_fps = 60,
	}
	app := engine.create("Diggle", default_cfg)
	defer engine.destroy(&app)

	menu := Menu_Context {
		scene = {
			init = menu_init,
			deinit = menu_deinit,
			enter = menu_enter,
			leave = menu_leave,
			update = menu_update,
			render = menu_render,
		},
	}

	game := Game_Context {
		scene = {
			init = game_init,
			deinit = game_deinit,
			update = game_update,
			render = game_render,
		},
	}

	engine.addScene(&app, "menu", &menu.scene)
	engine.addScene(&app, "game", &game.scene)

	engine.run(&app, "menu")
}
