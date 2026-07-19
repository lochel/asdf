package main

import "core:c"
import "core:math/rand"
import "engine"
import rl "vendor:raylib"

Menu_Context :: struct {
	using scene:    engine.Scene_Context,
	demo_npcs:      [dynamic]NpcSnake,
	demo_food:      Food,
	tilemap:        Tilemap,
	tilemap_loaded: bool,
	option_focus:   int,
	mode_single:    bool,
	selected_level: int,
	tilemap_actor:  TilemapActor,
	npc_actor:      NpcSnakeCollectionActor,
	food_actor:     FoodActor,
}

spawn_demo_npc :: proc(m: ^Menu_Context) {
	npc_dirs := [3]Direction{.Right, .Left, .Down}
	npc_offsets := [3]Vec2{{-1, 0}, {1, 0}, {0, -1}}
	idx := len(m.demo_npcs) % 3
	pos: Vec2
	found := false
	for attempt := 0; attempt < 50; attempt += 1 {
		p := Vec2{rand.int_max(GRID_WIDTH), rand.int_max(GRID_HEIGHT)}
		if is_grass(m.tilemap, p) && p != m.tilemap.start_pos {
			pos = p
			found = true
			break
		}
	}
	if !found {
		pos = Vec2{5 + idx * 5, 5 + idx * 3}
	}

	npc_body := make([dynamic]Vec2)
	npc_dirs_arr := make([dynamic]Direction)
	append(&npc_body, pos)
	append(&npc_body, pos + npc_offsets[idx])
	append(&npc_body, pos + npc_offsets[idx] * 2)
	append(&npc_dirs_arr, npc_dirs[idx])
	append(&npc_dirs_arr, npc_dirs[idx])
	append(&npc_dirs_arr, npc_dirs[idx])
	append(
		&m.demo_npcs,
		NpcSnake {
			body = npc_body,
			head_dirs = npc_dirs_arr,
			direction = npc_dirs[idx],
			tint = npc_tint(idx),
		},
	)
}

menu_enter :: proc(ctx: ^engine.Scene_Context) {
	mc := cast(^Menu_Context)ctx
	mc.option_focus = 0
	mc.mode_single = start_single_level_mode
	mc.selected_level = clamp(start_level_index, 0, max(0, len(LEVELS) - 1))

	if mc.tilemap_loaded {
		unload_tilemap(&mc.tilemap)
		mc.tilemap_loaded = false
	}
	if len(LEVELS) == 0 {
		for npc in mc.demo_npcs {
			delete(npc.body)
			delete(npc.head_dirs)
			delete(npc.debug_path)
		}
		clear(&mc.demo_npcs)
		mc.demo_food = {-1, -1}
		return
	}

	mc.tilemap = load_tilemap(LEVELS[0].file)
	mc.tilemap_loaded = true
	resize_for_tilemap(mc.tilemap, mc.eng)

	clear(&snake_global.body)
	clear(&snake_global.head_dirs)
	s := mc.tilemap.start_pos
	if !mc.tilemap.has_start {
		s = Vec2{GRID_WIDTH / 2, GRID_HEIGHT / 2}
	}
	append(&snake_global.body, s)
	append(&snake_global.head_dirs, Direction.Right)
	snake_global.direction = .Right
	snake_global.next_direction = .Right

	spawn_food(&snake_global, &mc.demo_food, mc.tilemap, nil)

	mc.tilemap_actor = TilemapActor {
		actor = {scene = &mc.scene, render = tilemap_actor_render},
		tilemap = &mc.tilemap,
		assets = &assets_global,
		remaining = LEVELS[0].gate_score,
	}
	mc.npc_actor = NpcSnakeCollectionActor {
		actor = {scene = &mc.scene, render = npc_snake_collection_render},
		snakes = &mc.demo_npcs,
		assets = &assets_global,
	}
	mc.food_actor = FoodActor {
		actor = {scene = &mc.scene, render = food_actor_render},
		food = &mc.demo_food,
		assets = &assets_global,
	}

	spawn_demo_npc(mc)
	spawn_demo_npc(mc)
	spawn_demo_npc(mc)
}

menu_leave :: proc(ctx: ^engine.Scene_Context) {
	mc := cast(^Menu_Context)ctx

	for npc in mc.demo_npcs {
		delete(npc.body)
		delete(npc.head_dirs)
		delete(npc.debug_path)
	}
	delete(mc.demo_npcs)
	mc.demo_npcs = nil

	delete(snake_global.body)
	delete(snake_global.head_dirs)
	snake_global.body = nil
	snake_global.head_dirs = nil

	if mc.tilemap_loaded {
		unload_tilemap(&mc.tilemap)
		mc.tilemap_loaded = false
	}
}

menu_input :: proc(ctx: ^engine.Scene_Context, dt: f32) {
	mc := cast(^Menu_Context)ctx

	if rl.IsKeyPressed(.ESCAPE) {
		engine.close(mc.eng)
		return
	}

	if len(LEVELS) == 0 {
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) || controller_confirm() {
			engine.close(mc.eng)
		}
		return
	}

	move_up :=
		rl.IsKeyPressed(.UP) ||
		rl.IsKeyPressed(.W) ||
		gp_button_pressed(.LEFT_FACE_UP, 0) ||
		joy_button_pressed(11)
	move_down :=
		rl.IsKeyPressed(.DOWN) ||
		rl.IsKeyPressed(.S) ||
		gp_button_pressed(.LEFT_FACE_DOWN, 0) ||
		joy_button_pressed(12)
	move_left :=
		rl.IsKeyPressed(.LEFT) ||
		rl.IsKeyPressed(.A) ||
		gp_button_pressed(.LEFT_FACE_LEFT, 0) ||
		joy_button_pressed(13)
	move_right :=
		rl.IsKeyPressed(.RIGHT) ||
		rl.IsKeyPressed(.D) ||
		gp_button_pressed(.LEFT_FACE_RIGHT, 0) ||
		joy_button_pressed(14)
	max_focus := 0
	if mc.mode_single {
		max_focus = 1
	}

	if move_up {
		mc.option_focus = max(0, mc.option_focus - 1)
	}
	if move_down {
		mc.option_focus = min(max_focus, mc.option_focus + 1)
	}

	if move_left || move_right {
		if mc.option_focus == 0 {
			mc.mode_single = !mc.mode_single
			if !mc.mode_single {
				mc.option_focus = 0
			}
		} else if mc.mode_single {
			delta := -1
			if move_right {
				delta = 1
			}
			mc.selected_level = (mc.selected_level + delta + len(LEVELS)) % len(LEVELS)
		}
	}

	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) || controller_confirm() {
		start_single_level_mode = mc.mode_single
		start_level_index = mc.selected_level
		engine.switch_scene(mc.eng, engine.getScene(mc.eng, "game"), .Slide_Right, 0.6)
		return
	}
}

menu_step :: proc(ctx: ^engine.Scene_Context, step: int) -> f32 {
	mc := cast(^Menu_Context)ctx

	demo_play := Playing {
		npc_snakes = mc.demo_npcs,
		foul_foods = {},
	}
	for i := len(mc.demo_npcs) - 1; i >= 0; i -= 1 {
		food_pos := mc.demo_food
		alive, ate, _ := move_npc(
			&mc.demo_npcs[i],
			food_pos,
			&snake_global,
			&demo_play,
			false,
			mc.tilemap,
		)
		if !alive {
			delete(mc.demo_npcs[i].body)
			delete(mc.demo_npcs[i].head_dirs)
			delete(mc.demo_npcs[i].debug_path)
			unordered_remove(&mc.demo_npcs, i)
			spawn_demo_npc(mc)
			continue
		}
		if ate {
			spawn_food(&snake_global, &mc.demo_food, mc.tilemap, &demo_play)
		}
	}
	delete(demo_play.pending_labels)

	return 0.04
}

menu_render :: proc(ctx: ^engine.Scene_Context) {
	mc := cast(^Menu_Context)ctx
	if len(LEVELS) == 0 {
		sw := mc.eng.config.width
		sh := mc.eng.config.height
		rl.ClearBackground(rl.Color{20, 20, 30, 255})
		t1: cstring = "No levels found"
		t2: cstring = "Add .txt maps under assets/levels"
		fs1: c.int = CELL_SIZE
		fs2: c.int = CELL_SIZE / 2 + 4
		w1 := rl.MeasureText(t1, fs1)
		w2 := rl.MeasureText(t2, fs2)
		rl.DrawText(t1, (sw - w1) / 2, sh / 2 - fs1, fs1, rl.RAYWHITE)
		rl.DrawText(t2, (sw - w2) / 2, sh / 2 + 8, fs2, rl.GRAY)
		return
	}

	camera := rl.Camera2D {
		offset   = {0, f32(HUD_HEIGHT)},
		target   = {0, 0},
		rotation = 0,
		zoom     = 1,
	}

	if mc.tilemap.has_start {
		mc.tilemap.tiles[mc.tilemap.start_pos.y][mc.tilemap.start_pos.x] = .Grass
	}
	rl.BeginMode2D(camera)
	mc.tilemap_actor.actor.render(&mc.tilemap_actor.actor)
	mc.food_actor.actor.render(&mc.food_actor.actor)
	mc.npc_actor.actor.render(&mc.npc_actor.actor)
	if mc.demo_food.x >= 0 {
		best_len := max(int)
		best_npc_path: [dynamic]Vec2
		best_tint: rl.Color
		best_head: Vec2 = {-1, -1}
		food_pos := mc.demo_food
		for npc in mc.demo_npcs {
			if len(npc.debug_path) > 1 && len(npc.debug_path) < best_len {
				best_len = len(npc.debug_path)
				best_npc_path = npc.debug_path
				best_tint = npc.tint
				best_head = npc.body[len(npc.body) - 1]
			}
		}
		if best_npc_path != nil {
			draw_path(best_npc_path, best_tint, best_head, food_pos)
		}
	}
	rl.EndMode2D()
	if mc.tilemap.has_start {
		mc.tilemap.tiles[mc.tilemap.start_pos.y][mc.tilemap.start_pos.x] = .Start
	}
	sw := mc.eng.config.width
	sh := mc.eng.config.height
	rl.DrawRectangle(0, 0, sw, sh, rl.Color{0, 0, 0, 65})

	rl.DrawRectangle(0, 0, sw, HUD_HEIGHT, rl.Color{42, 112, 20, 255})
	rl.DrawLine(0, HUD_HEIGHT - 1, sw, HUD_HEIGHT - 1, rl.Color{30, 80, 14, 255})

	fs_big: c.int = 60
	fs_sml: c.int = 30
	y: c.int = 20
	x: c.int = 12
	for i in 0 ..< min(len(mc.demo_npcs), 3) {
		label := rl.TextFormat("NPC%d: ", i + 1)
		rl.DrawText(label, x, y + 10, fs_sml, rl.Color{180, 230, 160, 255})
		x += rl.MeasureText(label, fs_sml) + 4
		val := rl.TextFormat("%d", len(mc.demo_npcs[i].body))
		rl.DrawText(val, x, y, fs_big, rl.RAYWHITE)
		x += rl.MeasureText(val, fs_big) + 24
	}

	title: cstring = "SNAKE"
	title_size: c.int = CELL_SIZE * 4
	tw_title := rl.MeasureText(title, title_size)
	rl.DrawText(title, (sw - tw_title) / 2, CELL_SIZE * 4, title_size, rl.GREEN)

	opt_fs: c.int = CELL_SIZE / 2 + 6
	opt_y: c.int = CELL_SIZE * 10
	opt_x: c.int = sw / 2 - 220

	mode_name: cstring = "Normal (All Levels)"
	if mc.mode_single {
		mode_name = "Single Level"
	}
	mode_row := rl.TextFormat("Mode: %s", mode_name)
	mode_col := rl.Color{190, 220, 170, 255}
	if mc.option_focus == 0 {
		mode_col = rl.Color{255, 230, 90, 255}
	}
	rl.DrawText(mode_row, opt_x, opt_y, opt_fs, mode_col)

	help: cstring = "Use LEFT/RIGHT to change mode"
	if mc.mode_single {
		level_row := rl.TextFormat(
			"Level: %d/%d  (%s)",
			mc.selected_level + 1,
			len(LEVELS),
			LEVELS[mc.selected_level].label,
		)
		level_col := rl.Color{140, 170, 130, 255}
		if mc.option_focus == 1 {
			level_col = rl.Color{255, 230, 90, 255}
		}
		rl.DrawText(level_row, opt_x, opt_y + opt_fs + 12, opt_fs, level_col)
		help = "Use UP/DOWN to select, LEFT/RIGHT to change"
	}

	help_w := rl.MeasureText(help, opt_fs - 6)
	rl.DrawText(help, (sw - help_w) / 2, opt_y + (opt_fs + 12) * 2 + 6, opt_fs - 6, rl.GRAY)

	hint: cstring = "Press SPACE to start"
	hint_size: c.int = CELL_SIZE
	hint_w := rl.MeasureText(hint, hint_size)
	rl.DrawText(hint, (sw - hint_w) / 2, sh - CELL_SIZE * 3, hint_size, rl.GREEN)
}
