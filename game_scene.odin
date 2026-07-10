package main

import "core:c"
import "engine"
import rl "vendor:raylib"

FloatingLabel :: struct {
	pos:   Vec2,
	timer: f32,
	life:  f32,
}

Game_Context :: struct {
	using scene:    engine.Scene_Context,
	playing:       Playing,
	snake:         Snake,
	food:          Food,
	tilemap:       Tilemap,
	tilemap_loaded: bool,
	game_over:     bool,
	final_score:   int,
	prev_level:    int,
	entered:       bool,
	labels:        [dynamic]FloatingLabel,
}

game_init :: proc(ctx: ^engine.Scene_Context) {
	gd := cast(^Game_Context)ctx

	assets_global = load_assets()
}

game_deinit :: proc(ctx: ^engine.Scene_Context) {
	gd := cast(^Game_Context)ctx

	for npc in gd.playing.npc_snakes {
		delete(npc.body)
		delete(npc.head_dirs)
		delete(npc.debug_path)
	}
	delete(gd.playing.npc_snakes)
	delete(gd.playing.foul_foods)
	delete(gd.playing.splits_triggered)
	delete(gd.snake.body)
	delete(gd.snake.head_dirs)
	delete(gd.labels)
	if gd.tilemap_loaded {
		unload_tilemap(&gd.tilemap)
	}

	unload_assets(assets_global)

	for l in LEVELS {
		delete(l.label)
		delete(l.split_scores)
	}
	delete(LEVELS)
}

game_enter :: proc(ctx: ^engine.Scene_Context) {
	gd := cast(^Game_Context)ctx

	if gd.entered do return
	gd.entered = true

	for npc in gd.playing.npc_snakes {
		delete(npc.body)
		delete(npc.head_dirs)
		delete(npc.debug_path)
	}
	delete(gd.playing.npc_snakes)
	delete(gd.playing.foul_foods)
	delete(gd.playing.splits_triggered)

	if gd.tilemap_loaded {
		unload_tilemap(&gd.tilemap)
		gd.tilemap_loaded = false
	}

	gd.tilemap = load_tilemap(LEVELS[0].file)
	gd.tilemap_loaded = true
	resize_for_tilemap(gd.tilemap, gd.eng)

	gd.playing = Playing {
		lives            = 3,
		current_level    = 0,
		score            = 0,
		total_score      = 0,
		npc_snakes       = {},
		gate_open        = false,
		splits_triggered = {},
		countdown        = 4.0,
		spawning         = 2,
		foul_foods       = {},
		foul_apples      = 0,
		gate_extra       = 0,
		paused           = false,
	}

	init_game(&gd.snake, &gd.food, &gd.tilemap)
	gd.game_over = false
	gd.final_score = 0
	gd.prev_level = 0
	clear(&gd.labels)
}

game_input :: proc(ctx: ^engine.Scene_Context, dt: f32) {
	gd := cast(^Game_Context)ctx

	if gd.game_over {
		if rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.ENTER) || controller_confirm() {
			gd.entered = false
			engine.switch_scene(gd.eng, engine.getScene(gd.eng, "menu"), .Slide_Left, 0.6)
		}
		return
	}

	playing := &gd.playing

	if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.P) || gp_button_pressed(.MIDDLE_LEFT, 0) || joy_button_pressed(7) {
		playing.paused = !playing.paused
	}
	if rl.IsKeyPressed(.H) { show_hint = !show_hint }
	if !playing.paused && playing.countdown <= 0 {
		handle_input(&gd.snake)
		if playing.foul_apples > 0 {
			dump :=
				rl.IsKeyPressed(.E) ||
				gp_button_pressed(.RIGHT_FACE_RIGHT, 0) ||
				joy_button_pressed(1)
			if dump {
				append(
					&playing.foul_foods,
					FoulFood{pos = gd.snake.body[0], timer = FOUL_FOOD_LIFETIME},
				)
				playing.foul_apples -= 1
			}
		}
	}
}

game_step :: proc(ctx: ^engine.Scene_Context, step: int) {
	gd := cast(^Game_Context)ctx

	if gd.game_over || gd.playing.paused {
		return
	}

	playing := &gd.playing
	dt := gd.fixed_step

	for i := len(playing.foul_foods) - 1; i >= 0; i -= 1 {
		playing.foul_foods[i].timer -= dt
		if playing.foul_foods[i].timer <= 0 {
			unordered_remove(&playing.foul_foods, i)
		}
	}

	prev_score := playing.score
	food_before := gd.food

	if playing.countdown > 0 {
		playing.countdown -= dt
		if update(&gd.snake, &gd.food, playing, &assets_global, &gd.tilemap, true) {
			gd.game_over = true
			gd.final_score = playing.total_score + playing.score
		}
	} else {
		if update(&gd.snake, &gd.food, playing, &assets_global, &gd.tilemap, false) {
			gd.game_over = true
			gd.final_score = playing.total_score + playing.score
		}
		if playing.current_level != gd.prev_level {
			resize_for_tilemap(gd.tilemap, gd.eng)
			gd.prev_level = playing.current_level
		}
	}

	if playing.score > prev_score && food_before.x >= 0 {
		append(&gd.labels, FloatingLabel{pos = food_before, life = 0.8})
	}
}

game_update :: proc(ctx: ^engine.Scene_Context, dt: f32) {
	gd := cast(^Game_Context)ctx

	for i := len(gd.labels) - 1; i >= 0; i -= 1 {
		gd.labels[i].timer += dt
		if gd.labels[i].timer >= gd.labels[i].life {
			unordered_remove(&gd.labels, i)
		}
	}
}

game_render :: proc(ctx: ^engine.Scene_Context) {
	gd := cast(^Game_Context)ctx

	camera := rl.Camera2D {
		offset   = {0, f32(HUD_HEIGHT)},
		target   = {0, 0},
		rotation = 0,
		zoom     = 1,
	}

	if gd.game_over {
		if gd.tilemap_loaded {
			rl.BeginMode2D(camera)
			draw_background(gd.tilemap, assets_global, 0)
			rl.EndMode2D()
		} else {
			rl.ClearBackground(rl.Color{20, 20, 30, 255})
		}
		draw_game_over(gd.final_score)
		return
	}

	playing := gd.playing

	draw_hud(playing)
	rl.BeginMode2D(camera)
	gate_threshold := LEVELS[playing.current_level].gate_score + playing.gate_extra
	remaining := max(0, gate_threshold - playing.score)
	draw_background(gd.tilemap, assets_global, remaining)
	draw_food(gd.food, assets_global)
	for ff in playing.foul_foods {
		draw_foul_food(ff.pos, assets_global)
	}
	if playing.countdown <= 0 {
		draw_snake(gd.snake, assets_global)
	}
	for npc in playing.npc_snakes {
		draw_npc_snake(npc, assets_global)
	}
	for label in gd.labels {
		t := label.timer / label.life
		alpha := u8(255 * (1.0 - t))
		y_off := -t * f32(CELL_SIZE) - CELL_SIZE
		fx := f32(label.pos.x * CELL_SIZE + CELL_SIZE / 2)
		fy := f32(label.pos.y * CELL_SIZE + CELL_SIZE / 2) + y_off
		font_size := c.int(CELL_SIZE)
		tw := rl.MeasureText("+1", font_size)
		rl.DrawText("+1", c.int(fx) - tw / 2, c.int(fy) - font_size / 2, font_size, rl.Color{255, 255, 100, alpha})
	}
	target: Vec2
	has_target := false
	if playing.gate_open && gd.tilemap.has_gate {
		target = gd.tilemap.gate_pos
		has_target = true
	} else if gd.food.x >= 0 {
		target = gd.food
		has_target = true
	}
	if has_target {
		best_path: [dynamic]Vec2
		best_tint: rl.Color
		best_len := max(int)
		best_head: Vec2 = {-1, -1}
		delete_paths: [dynamic][dynamic]Vec2

		if show_hint {
			p := find_path(&gd.snake, &playing, &gd.tilemap, target)
			if len(p) > 1 && len(p) < best_len {
				best_len = len(p)
				best_path = p
				best_tint = rl.Color{80, 140, 255, 140}
				best_head = gd.snake.body[len(gd.snake.body) - 1]
			}
			append(&delete_paths, p)
		}

		for npc in playing.npc_snakes {
			if len(npc.debug_path) > 1 && len(npc.debug_path) < best_len {
				best_len = len(npc.debug_path)
				best_path = npc.debug_path
				best_tint = npc.tint
				best_head = npc.body[len(npc.body) - 1]
			}
		}

		if best_path != nil {
			draw_path(best_path, best_tint, best_head, target)
		}
		for p in delete_paths {
			delete(p)
		}
		delete(delete_paths)
	}
	rl.EndMode2D()
	if playing.countdown > 0 {
		draw_countdown(playing.countdown)
	}
	if playing.paused {
		rl.DrawRectangle(0, HUD_HEIGHT, SCREEN_WIDTH, SCREEN_HEIGHT, rl.Color{0, 0, 0, 120})
		fs1 := CELL_SIZE * 2
		tw1 := rl.MeasureText("PAUSED", c.int(fs1))
		rl.DrawText("PAUSED", c.int((SCREEN_WIDTH - tw1) / 2), c.int(HUD_HEIGHT + (int(SCREEN_HEIGHT) - fs1) / 2 - CELL_SIZE), c.int(fs1), rl.RAYWHITE)
		fs2 := CELL_SIZE / 2
		tw2 := rl.MeasureText("Press ESC or P to resume", c.int(fs2))
		rl.DrawText("Press ESC or P to resume", c.int((SCREEN_WIDTH - tw2) / 2), c.int(HUD_HEIGHT + (int(SCREEN_HEIGHT) - fs2) / 2 + CELL_SIZE), c.int(fs2), rl.Color{200, 200, 200, 255})
	}
}
