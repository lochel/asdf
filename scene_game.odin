package main

import "engine"

import "core:c"
import "core:math"
import "core:math/rand"
import "core:strings"

import rl "vendor:raylib"

FloatingLabel :: struct {
	pos:   Vec2,
	timer: f32,
	life:  f32,
	text:  cstring,
}

Game_Context :: struct {
	using scene:    engine.Scene_Context,
	playing:        Playing,
	snake:          Snake,
	food:           Food,
	tilemap:        Tilemap,
	tilemap_loaded: bool,
	game_over:      bool,
	final_score:    int,
	prev_level:     int,
	entered:        bool,
	labels:         [dynamic]FloatingLabel,
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
	delete(gd.playing.pending_labels)
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
	delete(gd.playing.pending_labels)

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
		apples           = 0,
		foul_kills       = 0,
		npc_kills        = 0,
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
		pending_labels   = {},
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

	if rl.IsKeyPressed(.ESCAPE) ||
	   rl.IsKeyPressed(.P) ||
	   gp_button_pressed(.MIDDLE_LEFT, 0) ||
	   joy_button_pressed(7) {
		playing.paused = !playing.paused
	}
	if rl.IsKeyPressed(.H) {show_hint = !show_hint}
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

game_step :: proc(ctx: ^engine.Scene_Context, step: int) -> f32 {
	gd := cast(^Game_Context)ctx

	if gd.game_over || gd.playing.paused {
		return move_delay
	}

	playing := &gd.playing
	dt := move_delay

	for i := len(playing.foul_foods) - 1; i >= 0; i -= 1 {
		playing.foul_foods[i].timer -= dt
		if playing.foul_foods[i].timer <= 0 {
			unordered_remove(&playing.foul_foods, i)
		}
	}

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

	for pl in playing.pending_labels {
		append(&gd.labels, FloatingLabel{pos = pl.pos, life = 0.8, text = pl.text})
	}
	clear(&playing.pending_labels)

	return move_delay
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
		draw_hud(gd.playing)
		if gd.tilemap_loaded {
			rl.BeginMode2D(camera)
			draw_background(gd.tilemap, assets_global, 0)
			rl.EndMode2D()
		} else {
			rl.ClearBackground(rl.Color{20, 20, 30, 255})
		}
		draw_game_over(gd.final_score, gd.playing)
		return
	}

	playing := gd.playing

	draw_hud(playing)
	rl.BeginMode2D(camera)
	gate_threshold := LEVELS[playing.current_level].gate_score + playing.gate_extra
	remaining := max(0, gate_threshold - playing.apples)
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
		tw := rl.MeasureText(label.text, font_size)
		rl.DrawText(
			label.text,
			c.int(fx) - tw / 2,
			c.int(fy) - font_size / 2,
			font_size,
			rl.Color{255, 255, 100, alpha},
		)
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
		rl.DrawText(
			"PAUSED",
			c.int((SCREEN_WIDTH - tw1) / 2),
			c.int(HUD_HEIGHT + (int(SCREEN_HEIGHT) - fs1) / 2 - CELL_SIZE),
			c.int(fs1),
			rl.RAYWHITE,
		)
		fs2 := CELL_SIZE / 2
		tw2 := rl.MeasureText("Press ESC or P to resume", c.int(fs2))
		rl.DrawText(
			"Press ESC or P to resume",
			c.int((SCREEN_WIDTH - tw2) / 2),
			c.int(HUD_HEIGHT + (int(SCREEN_HEIGHT) - fs2) / 2 + CELL_SIZE),
			c.int(fs2),
			rl.Color{200, 200, 200, 255},
		)
	}
}
CELL_SIZE :: 50
GRID_WIDTH :: 20
GRID_HEIGHT :: 20
FOUL_FOOD_LIFETIME :: 3.0
HUD_HEIGHT :: CELL_SIZE * 2

init_game :: proc(snake: ^Snake, food: ^Food, tm: ^Tilemap) {
	clear(&snake.body)
	clear(&snake.head_dirs)
	s := tm.start_pos
	if !tm.has_start {
		s = Vec2{GRID_WIDTH / 2, GRID_HEIGHT / 2}
	}
	append(&snake.body, s)
	append(&snake.head_dirs, Direction.Right)
	snake.direction = .Right
	snake.next_direction = .Right
}

spawn_food :: proc(snake: ^Snake, food: ^Food, tm: Tilemap, playing: ^Playing) {
	occupied := make(map[Vec2]bool)
	defer delete(occupied)

	for seg in snake.body {
		occupied[seg] = true
	}

	if playing != nil {
		for npc in playing.npc_snakes {
			for seg in npc.body {
				occupied[seg] = true
			}
		}
		for ff in playing.foul_foods {
			occupied[ff.pos] = true
		}
	}

	free_cells: [dynamic]Vec2
	defer delete(free_cells)

	for x in 0 ..< GRID_WIDTH {
		for y in 0 ..< GRID_HEIGHT {
			pos := Vec2{x, y}
			if !occupied[pos] && is_grass(tm, pos) {
				append(&free_cells, pos)
			}
		}
	}

	if len(free_cells) > 0 {
		food^ = free_cells[rand.int_max(len(free_cells))]
	}
}

update :: proc(
	snake: ^Snake,
	food: ^Food,
	playing: ^Playing,
	assets: ^Assets,
	tm: ^Tilemap,
	npcs_only: bool,
) -> bool {
	// Delayed spawning: wait until no NPC is within 3 tiles of start
	if playing.spawning_delayed && playing.spawning == 0 && !npcs_only {
		start := tm.start_pos
		if !tm.has_start {
			start = Vec2{GRID_WIDTH / 2, GRID_HEIGHT / 2}
		}
		can_spawn := true
		for npc in playing.npc_snakes {
			for seg in npc.body {
				if abs(seg.x - start.x) + abs(seg.y - start.y) <= 3 {
					can_spawn = false
					break
				}
			}
			if !can_spawn {break}
		}
		if can_spawn {
			playing.spawning = 0
			playing.spawning_delayed = true
			playing.spawning_delayed = false
		}
	}

	if !npcs_only {
		input_used = false
		snake.direction = snake.next_direction

		head := snake.body[len(snake.body) - 1]
		new_head := head

		switch snake.direction {
		case .Up:
			new_head.y -= 1
		case .Down:
			new_head.y += 1
		case .Left:
			new_head.x -= 1
		case .Right:
			new_head.x += 1
		}

		if new_head.x < 0 do new_head.x = GRID_WIDTH - 1
		if new_head.x >= GRID_WIDTH do new_head.x = 0
		if new_head.y < 0 do new_head.y = GRID_HEIGHT - 1
		if new_head.y >= GRID_HEIGHT do new_head.y = 0

		if is_wall(tm^, new_head) {
			return player_died(snake, food, playing, assets, tm)
		}

		if is_gate(tm^, new_head) && !playing.gate_open {
			return player_died(snake, food, playing, assets, tm)
		}

		if is_gate(tm^, new_head) && playing.gate_open {
			return advance_level(snake, food, playing, assets, tm)
		}

		if is_puddle(tm^, new_head) {
			if tp, ok := teleport(tm^, new_head); ok {
				new_head = tp
			}
		}

		for seg in snake.body {
			if seg == new_head {
				return player_died(snake, food, playing, assets, tm)
			}
		}

		snake.head_dirs[len(snake.head_dirs) - 1] = snake.direction
		append(&snake.body, new_head)
		append(&snake.head_dirs, snake.direction)

		for i in 0 ..< len(playing.foul_foods) {
			if new_head == playing.foul_foods[i].pos {
				unordered_remove(&playing.foul_foods, i)
				return player_died(snake, food, playing, assets, tm)
			}
		}

		if new_head == food^ {
			playing.apples += 1
			playing.score = playing.apples + playing.foul_kills * 5 + playing.npc_kills * 10
			append(&playing.pending_labels, PendingLabel{pos = new_head, text = "+1"})
			rl.PlaySound(assets^.sounds.eat)

			if !playing.gate_open {
				gate_threshold := LEVELS[playing.current_level].gate_score + playing.gate_extra
				playing.gate_open = playing.apples >= gate_threshold
				if playing.gate_open {
					food^ = {-1, -1}
					rl.PlaySound(assets^.sounds.gate_open)
				} else {
					spawn_food(snake, food, tm^, playing)
				}
			}

			check_split(snake, playing, assets)
		} else if playing.spawning == 0 {
			for i in 0 ..< len(snake.body) - 1 {
				snake.body[i] = snake.body[i + 1]
				snake.head_dirs[i] = snake.head_dirs[i + 1]
			}
			pop(&snake.body)
			pop(&snake.head_dirs)
		} else {
			playing.spawning -= 1
			if playing.spawning == 0 {
				if tm.has_start {
					tm.tiles[tm.start_pos.y][tm.start_pos.x] = .Grass
				}
				if !playing.gate_open {
					spawn_food(snake, food, tm^, playing)
				}
			}
		}

	}

	{
		i := 0
		for i < len(playing.npc_snakes) {
			player_head := snake.body[len(snake.body) - 1]
			alive, ate := move_npc(
				&playing.npc_snakes[i],
				food^,
				snake,
				playing,
				playing.gate_open,
				tm^,
			)
			if !alive {
				delete(playing.npc_snakes[i].body)
				delete(playing.npc_snakes[i].head_dirs)
				delete(playing.npc_snakes[i].debug_path)
				unordered_remove(&playing.npc_snakes, i)
				continue
			}

			npc_head := playing.npc_snakes[i].body[len(playing.npc_snakes[i].body) - 1]

			if ate {
				if !playing.gate_open {
					spawn_food(snake, food, tm^, playing)
					rl.PlaySound(assets^.sounds.eat)
				} else {
					food^ = {-1, -1}
				}
			}

			if playing.gate_open && npc_head == tm.gate_pos {
				return player_died(snake, food, playing, assets, tm)
			}

			// NPC head hits player body → NPC dies
			npc_dies := false
			for seg in snake.body {
				if npc_head == seg {
					playing.npc_kills += 1
					playing.score =
						playing.apples + playing.foul_kills * 5 + playing.npc_kills * 10
					append(&playing.pending_labels, PendingLabel{pos = npc_head, text = "+10"})
					delete(playing.npc_snakes[i].body)
					delete(playing.npc_snakes[i].head_dirs)
					delete(playing.npc_snakes[i].debug_path)
					unordered_remove(&playing.npc_snakes, i)
					npc_dies = true
					break
				}
			}
			if npc_dies do continue

			// Player head hits NPC body → both die
			if !npcs_only {
				for seg in playing.npc_snakes[i].body {
					if player_head == seg {
						playing.npc_kills += 1
						playing.score =
							playing.apples + playing.foul_kills * 5 + playing.npc_kills * 10
						delete(playing.npc_snakes[i].body)
						delete(playing.npc_snakes[i].head_dirs)
						delete(playing.npc_snakes[i].debug_path)
						unordered_remove(&playing.npc_snakes, i)
						npc_dies = true
						break
					}
				}
			}
			if npc_dies {
				player_died(snake, food, playing, assets, tm)
				append(&playing.pending_labels, PendingLabel{pos = npc_head, text = "+10"})
				return playing.lives <= 0
			}

			i += 1
		}
	}

	// NPC vs NPC collisions
	{
		dead := make(map[int]bool)
		defer delete(dead)

		for i in 0 ..< len(playing.npc_snakes) {
			head_i := playing.npc_snakes[i].body[len(playing.npc_snakes[i].body) - 1]
			for j in 0 ..< len(playing.npc_snakes) {
				if j == i do continue
				for k in 0 ..< len(playing.npc_snakes[j].body) {
					if head_i == playing.npc_snakes[j].body[k] {
						if k == len(playing.npc_snakes[j].body) - 1 {
							dead[i] = true
							dead[j] = true
						} else {
							dead[i] = true
						}
						break
					}
				}
				if dead[i] do break
			}
		}

		for i := len(playing.npc_snakes) - 1; i >= 0; i -= 1 {
			if dead[i] {
				playing.npc_kills += 1
				playing.score = playing.apples + playing.foul_kills * 5 + playing.npc_kills * 10
				append(&playing.pending_labels, PendingLabel{pos = playing.npc_snakes[i].body[len(playing.npc_snakes[i].body) - 1], text = "+10"})
				delete(playing.npc_snakes[i].body)
				delete(playing.npc_snakes[i].head_dirs)
				delete(playing.npc_snakes[i].debug_path)
				unordered_remove(&playing.npc_snakes, i)
			}
		}
	}

	return false
}

player_died :: proc(
	snake: ^Snake,
	food: ^Food,
	playing: ^Playing,
	assets: ^Assets,
	tm: ^Tilemap,
) -> bool {
	rl.PlaySound(assets^.sounds.game_over)
	playing.lives -= 1

	if playing.lives <= 0 {
		for npc in playing.npc_snakes {
			delete(npc.body)
			delete(npc.head_dirs)
			delete(npc.debug_path)
		}
		delete(playing.npc_snakes)
		delete(playing.foul_foods)
		delete(playing.splits_triggered)
		delete(playing.pending_labels)
		return true
	}

	clear(&playing.foul_foods)
	clear(&playing.pending_labels)
	playing.foul_apples = 0
	input_used = false

	clear(&snake.body)
	clear(&snake.head_dirs)
	s := tm.start_pos
	if !tm.has_start {
		s = Vec2{GRID_WIDTH / 2, GRID_HEIGHT / 2}
	}
	append(&snake.body, s)
	append(&snake.head_dirs, Direction.Right)
	snake.direction = .Right
	snake.next_direction = .Right
	if tm.has_start {
		tm.tiles[tm.start_pos.y][tm.start_pos.x] = .Start
	}
	playing.countdown = 4.0
	playing.spawning = 2
	food^ = {-1, -1}

	playing.gate_open = playing.apples >= LEVELS[playing.current_level].gate_score
	if playing.gate_open {
		playing.gate_extra += 1
	}
	playing.gate_open =
		playing.apples >= LEVELS[playing.current_level].gate_score + playing.gate_extra

	return false
}

advance_level :: proc(
	snake: ^Snake,
	food: ^Food,
	playing: ^Playing,
	assets: ^Assets,
	tm: ^Tilemap,
) -> bool {
	playing.current_level += 1

	if playing.current_level >= len(LEVELS) {
		for npc in playing.npc_snakes {
			delete(npc.body)
			delete(npc.head_dirs)
			delete(npc.debug_path)
		}
		delete(playing.npc_snakes)
		delete(playing.foul_foods)
		delete(playing.splits_triggered)
		delete(playing.pending_labels)
		return true
	}

	playing.total_score += playing.score

	unload_tilemap(tm)
	tm^ = load_tilemap(LEVELS[playing.current_level].file)

	s := tm.start_pos
	if !tm.has_start {
		s = Vec2{GRID_WIDTH / 2, GRID_HEIGHT / 2}
	}

	preserved_len := len(snake.body)
	clear(&snake.body)
	clear(&snake.head_dirs)
	append(&snake.body, s)
	append(&snake.head_dirs, Direction.Right)
	snake.direction = .Right
	snake.next_direction = .Right
	food^ = {-1, -1}

	for npc in playing.npc_snakes {
		delete(npc.body)
		delete(npc.head_dirs)
		delete(npc.debug_path)
	}
	clear(&playing.npc_snakes)

	playing.apples = 0
	playing.foul_kills = 0
	playing.npc_kills = 0
	playing.score = 0
	clear(&playing.splits_triggered)
	playing.countdown = 4.0
	playing.spawning = max(0, preserved_len - 1)
	clear(&playing.foul_foods)
	clear(&playing.pending_labels)
	playing.foul_apples = 0

	playing.gate_open = false
	playing.gate_extra = 0

	playing.lives = min(playing.lives + 1, 3)

	rl.PlaySound(assets^.sounds.level_complete)

	return false
}

perform_split :: proc(snake: ^Snake, playing: ^Playing, split_score: int, assets: ^Assets) {
	playing.splits_triggered[split_score] = true
	playing.foul_apples += 1

	mid := len(snake.body) / 2
	if mid < 1 do return

	npc_body := make([dynamic]Vec2)
	npc_dirs := make([dynamic]Direction)
	for i in 0 ..< mid {
		append(&npc_body, snake.body[i])
		append(&npc_dirs, snake.head_dirs[i])
	}

	new_body := make([dynamic]Vec2)
	new_dirs := make([dynamic]Direction)
	for i in mid ..< len(snake.body) {
		append(&new_body, snake.body[i])
		append(&new_dirs, snake.head_dirs[i])
	}

	delete(snake.body)
	delete(snake.head_dirs)
	snake.body = new_body
	snake.head_dirs = new_dirs

	rl.PlaySound(assets.sounds.split)

	npc := NpcSnake {
		body      = npc_body,
		head_dirs = npc_dirs,
		direction = npc_dirs[len(npc_dirs) - 1],
		stun      = 3,
		tint      = npc_tint(len(playing.npc_snakes)),
	}
	append(&playing.npc_snakes, npc)
}

check_split :: proc(snake: ^Snake, playing: ^Playing, assets: ^Assets) {
	level := LEVELS[playing.current_level]
	for split_score in level.split_scores {
		if playing.score >= split_score && !playing.splits_triggered[split_score] {
			perform_split(snake, playing, split_score, assets)
			break
		}
	}
}

show_hint: bool

find_path :: proc(snake: ^Snake, playing: ^Playing, tm: ^Tilemap, food: Vec2) -> [dynamic]Vec2 {
	result: [dynamic]Vec2
	head := snake.body[len(snake.body) - 1]

	target: Vec2
	has_target := false
	if playing.gate_open && tm.has_gate {
		target = tm.gate_pos
		has_target = true
	} else if food.x >= 0 {
		target = food
		has_target = true
	}
	if !has_target {return result}

	m_dist :: proc(a, b: Vec2) -> int {
		dx := abs(a.x - b.x)
		dy := abs(a.y - b.y)
		return min(dx, GRID_WIDTH - dx) + min(dy, GRID_HEIGHT - dy)
	}

	dirs := [4]Vec2{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}

	blocked := make(map[Vec2]bool)
	defer delete(blocked)

	for x in 0 ..< GRID_WIDTH {
		for y in 0 ..< GRID_HEIGHT {
			pos := Vec2{x, y}
			if is_wall(tm^, pos) || (is_gate(tm^, pos) && !playing.gate_open) {
				blocked[pos] = true
			}
		}
	}
	for seg in snake.body {blocked[seg] = true}
	for npc in playing.npc_snakes {
		for seg in npc.body {blocked[seg] = true}
	}

	AStarNode :: struct {
		pos: Vec2,
		g:   int,
		f:   int,
	}
	open_set: [dynamic]AStarNode
	defer delete(open_set)
	closed_set := make(map[Vec2]bool)
	defer delete(closed_set)
	g_scores := make(map[Vec2]int)
	defer delete(g_scores)
	came_from := make(map[Vec2]Vec2)
	defer delete(came_from)

	h := m_dist(head, target)
	append(&open_set, AStarNode{head, 0, h})
	g_scores[head] = 0

	for len(open_set) > 0 {
		best_idx := 0
		for j in 1 ..< len(open_set) {
			if open_set[j].f < open_set[best_idx].f {best_idx = j}
		}
		current := open_set[best_idx]
		unordered_remove(&open_set, best_idx)

		if closed_set[current.pos] {continue}
		closed_set[current.pos] = true

		if current.pos == target {
			p := current.pos
			for p != head {
				append(&result, p)
				p = came_from[p]
			}
			for i in 0 ..< len(result) / 2 {
				j := len(result) - 1 - i
				result[i], result[j] = result[j], result[i]
			}
			return result
		}

		for d in dirs {
			np := current.pos + d
			if np.x < 0 {np.x += GRID_WIDTH}
			if np.x >= GRID_WIDTH {np.x -= GRID_WIDTH}
			if np.y < 0 {np.y += GRID_HEIGHT}
			if np.y >= GRID_HEIGHT {np.y -= GRID_HEIGHT}

			if is_puddle(tm^, np) {
				if tp, ok := teleport(tm^, np); ok {np = tp}
			}

			if closed_set[np] {continue}
			if blocked[np] {continue}

			tentative_g := current.g + 1
			if old_g, ok := g_scores[np]; ok && tentative_g >= old_g {continue}

			g_scores[np] = tentative_g
			came_from[np] = current.pos
			append(&open_set, AStarNode{np, tentative_g, tentative_g + m_dist(np, target)})
		}
	}

	return result
}

draw_path :: proc(path: [dynamic]Vec2, tint: rl.Color, head: Vec2, target: Vec2) {
	for pos in path {
		if pos == head || pos == target {continue}
		cx := c.int(pos.x * CELL_SIZE + CELL_SIZE / 2)
		cy := c.int(pos.y * CELL_SIZE + CELL_SIZE / 2)
		rl.DrawCircle(cx, cy, 6, tint)
	}
}

move_npc :: proc(
	npc: ^NpcSnake,
	food: Vec2,
	snake: ^Snake,
	playing: ^Playing,
	gate_open: bool,
	tm: Tilemap,
) -> (
	bool,
	bool,
) {
	if npc.stun > 0 {
		npc.stun -= 1
		return true, false
	}

	head := npc.body[len(npc.body) - 1]

	m_dist :: proc(a, b: Vec2) -> int {
		dx := abs(a.x - b.x)
		dy := abs(a.y - b.y)
		return min(dx, GRID_WIDTH - dx) + min(dy, GRID_HEIGHT - dy)
	}

	dirs := [4]Direction{.Up, .Down, .Left, .Right}
	dir_vecs := [4]Vec2{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}

	// Build obstacle set: all walls, closed gate, and all snake bodies
	blocked := make(map[Vec2]bool)
	defer delete(blocked)

	for x in 0 ..< GRID_WIDTH {
		for y in 0 ..< GRID_HEIGHT {
			pos := Vec2{x, y}
			if is_wall(tm, pos) || (is_gate(tm, pos) && !gate_open) {
				blocked[pos] = true
			}
		}
	}

	for seg in snake.body {
		blocked[seg] = true
	}

	for &other in playing.npc_snakes {
		for seg in other.body {
			blocked[seg] = true
		}
	}

	target: Vec2
	if gate_open {
		target = tm.gate_pos
	} else if len(playing.foul_foods) > 0 {
		best_ff := playing.foul_foods[0].pos
		best_d := m_dist(head, best_ff)
		for i := 1; i < len(playing.foul_foods); i += 1 {
			d := m_dist(head, playing.foul_foods[i].pos)
			if d < best_d {
				best_d = d
				best_ff = playing.foul_foods[i].pos
			}
		}
		if best_d < m_dist(head, food) {
			target = best_ff
		} else {
			target = food
		}
	} else {
		target = food
	}

	best_dir := npc.direction
	found_path := false

	{
		AStarNode :: struct {
			pos:       Vec2,
			first_dir: Direction,
			g:         int,
			f:         int,
		}

		open_set: [dynamic]AStarNode
		defer delete(open_set)

		closed_set := make(map[Vec2]bool)
		defer delete(closed_set)

		g_scores := make(map[Vec2]int)
		defer delete(g_scores)

		came_from := make(map[Vec2]Vec2)
		defer delete(came_from)

		h := m_dist(head, target)
		append(&open_set, AStarNode{head, {}, 0, h})
		g_scores[head] = 0

		for len(open_set) > 0 {
			best_idx := 0
			for j in 1 ..< len(open_set) {
				if open_set[j].f < open_set[best_idx].f {
					best_idx = j
				}
			}
			current := open_set[best_idx]
			unordered_remove(&open_set, best_idx)

			if closed_set[current.pos] {continue}
			closed_set[current.pos] = true

			if current.pos == target {
				clear(&npc.debug_path)
				p := current.pos
				for p != head {
					append(&npc.debug_path, p)
					p = came_from[p]
				}
				for i in 0 ..< len(npc.debug_path) / 2 {
					j := len(npc.debug_path) - 1 - i
					npc.debug_path[i], npc.debug_path[j] = npc.debug_path[j], npc.debug_path[i]
				}
				best_dir = current.first_dir
				found_path = true
				break
			}

			for d, idx in dirs {
				if current.pos == head {
					if d == .Up && npc.direction == .Down {continue}
					if d == .Down && npc.direction == .Up {continue}
					if d == .Left && npc.direction == .Right {continue}
					if d == .Right && npc.direction == .Left {continue}
				}

				np := current.pos + dir_vecs[idx]

				// Boundary wrapping
				if np.x < 0 {np.x += GRID_WIDTH}
				if np.x >= GRID_WIDTH {np.x -= GRID_WIDTH}
				if np.y < 0 {np.y += GRID_HEIGHT}
				if np.y >= GRID_HEIGHT {np.y -= GRID_HEIGHT}

				// Teleport via puddles
				if is_puddle(tm, np) {
					if tp, ok := teleport(tm, np); ok {
						np = tp
					}
				}

				if closed_set[np] {continue}
				if blocked[np] {continue}

				tentative_g := current.g + 1
				if old_g, ok := g_scores[np]; ok && tentative_g >= old_g {continue}

				g_scores[np] = tentative_g
				came_from[np] = current.pos
				first_dir := current.first_dir
				if current.pos == head {first_dir = d}
				append(
					&open_set,
					AStarNode{np, first_dir, tentative_g, tentative_g + m_dist(np, target)},
				)
			}
		}

		if !found_path {
			clear(&npc.debug_path)
		}
	}

	if !found_path {
		best_score := -999
		for dir in dirs {
			if dir == .Up && npc.direction == .Down {continue}
			if dir == .Down && npc.direction == .Up {continue}
			if dir == .Left && npc.direction == .Right {continue}
			if dir == .Right && npc.direction == .Left {continue}

			np := head
			switch dir {
			case .Up:
				np.y -= 1
			case .Down:
				np.y += 1
			case .Left:
				np.x -= 1
			case .Right:
				np.x += 1
			}

			if np.x < 0 {np.x += GRID_WIDTH}
			if np.x >= GRID_WIDTH {np.x -= GRID_WIDTH}
			if np.y < 0 {np.y += GRID_HEIGHT}
			if np.y >= GRID_HEIGHT {np.y -= GRID_HEIGHT}

			if is_puddle(tm, np) {
				if tp, ok := teleport(tm, np); ok {
					np = tp
				}
			}

			if blocked[np] {continue}

			score := 0
			if dir == npc.direction {score += 1}
			cur_player_dist := m_dist(head, snake.body[len(snake.body) - 1])
			new_player_dist := m_dist(np, snake.body[len(snake.body) - 1])
			if new_player_dist >
			   cur_player_dist {score += 1} else if new_player_dist < cur_player_dist {score -= 1}

			if score > best_score {
				best_score = score
				best_dir = dir
			}
		}

		if best_score == -999 {
			return false, false
		}
	}

	if best_dir == .Up && npc.direction == .Down {best_dir = npc.direction}
	if best_dir == .Down && npc.direction == .Up {best_dir = npc.direction}
	if best_dir == .Left && npc.direction == .Right {best_dir = npc.direction}
	if best_dir == .Right && npc.direction == .Left {best_dir = npc.direction}

	npc.direction = best_dir
	new_head := head
	switch npc.direction {
	case .Up:
		new_head.y -= 1
	case .Down:
		new_head.y += 1
	case .Left:
		new_head.x -= 1
	case .Right:
		new_head.x += 1
	}

	// Boundary wrapping
	if new_head.x < 0 {new_head.x += GRID_WIDTH}
	if new_head.x >= GRID_WIDTH {new_head.x -= GRID_WIDTH}
	if new_head.y < 0 {new_head.y += GRID_HEIGHT}
	if new_head.y >= GRID_HEIGHT {new_head.y -= GRID_HEIGHT}

	// Teleport via puddles
	if is_puddle(tm, new_head) {
		if tp, ok := teleport(tm, new_head); ok {
			new_head = tp
		}
	}

	ate := new_head == food
	for i in 0 ..< len(playing.foul_foods) {
		if new_head == playing.foul_foods[i].pos {
			unordered_remove(&playing.foul_foods, i)
			playing.foul_kills += 1
			playing.score = playing.apples + playing.foul_kills * 5 + playing.npc_kills * 10
			append(&playing.pending_labels, PendingLabel{pos = new_head, text = "+5"})
			return false, false
		}
	}

	npc.head_dirs[len(npc.head_dirs) - 1] = npc.direction
	append(&npc.body, new_head)
	append(&npc.head_dirs, npc.direction)
	if !ate {
		for i in 0 ..< len(npc.body) - 1 {
			npc.body[i] = npc.body[i + 1]
			npc.head_dirs[i] = npc.head_dirs[i + 1]
		}
		pop(&npc.body)
		pop(&npc.head_dirs)
	}

	return true, ate
}

draw_background :: proc(tm: Tilemap, assets: Assets, remaining: int) {
	draw_tilemap(tm, assets, remaining)
}

body_texture :: proc(s: Sprites, dir_in, dir_out: Vec2) -> rl.Texture2D {
	R := Vec2{1, 0}
	L := Vec2{-1, 0}
	U := Vec2{0, -1}
	D := Vec2{0, 1}

	if dir_in == R && dir_out == U || dir_in == D && dir_out == L {return s.body_topleft}
	if dir_in == L && dir_out == U || dir_in == D && dir_out == R {return s.body_topright}
	if dir_in == R && dir_out == D || dir_in == U && dir_out == L {return s.body_bottomleft}
	if dir_in == L && dir_out == D || dir_in == U && dir_out == R {return s.body_bottomright}
	if dir_in.x != 0 {return s.body_horizontal}
	return s.body_vertical
}

dir_to_vec :: proc(d: Direction) -> Vec2 {
	switch d {
	case .Up:
		return {0, -1}
	case .Down:
		return {0, 1}
	case .Left:
		return {-1, 0}
	case .Right:
		return {1, 0}
	}
	return {}
}

draw_snake :: proc(snake: Snake, assets: Assets) {
	n := len(snake.body)
	if n == 0 do return

	draw_texture_at :: proc(tex: rl.Texture2D, pos: Vec2) {
		rl.DrawTexture(tex, c.int(pos.x * CELL_SIZE), c.int(pos.y * CELL_SIZE), rl.WHITE)
	}

	head_idx := n - 1

	for i in 0 ..< n {
		pos := snake.body[i]

		if i == head_idx {
			draw_texture_at(assets.sprites.head[snake.direction], pos)
		} else if i == 0 {
			draw_texture_at(assets.sprites.tail[snake.head_dirs[0]], pos)
		} else {
			dir_in := dir_to_vec(snake.head_dirs[i - 1])
			dir_out := dir_to_vec(snake.head_dirs[i])
			tex := body_texture(assets.sprites, dir_in, dir_out)
			draw_texture_at(tex, pos)
		}
	}
}

draw_npc_snake :: proc(npc: NpcSnake, assets: Assets) {
	n := len(npc.body)
	if n == 0 do return

	tint := npc.tint
	head_idx := n - 1

	t := f32(rl.GetTime())
	t = t - f32(int(t / 1000)) * 1000

	pulse := f32(math.sin(f64(t) * 3.0) * 0.3 + 0.7)
	glow_alpha := u8(pulse * 60)
	glow_tint := rl.Color{200, 60, 60, glow_alpha}
	glow_offset := c.int((GLOW_SIZE - CELL_SIZE) / 2)

	for i in 0 ..< n {
		pos := npc.body[i]
		gx := c.int(pos.x * CELL_SIZE) - glow_offset
		gy := c.int(pos.y * CELL_SIZE) - glow_offset
		rl.DrawTexture(assets.sprites.glow, gx, gy, glow_tint)
	}

	if assets.sprites.npc_glow_shader_valid {
		if assets.sprites.npc_glow_time_loc >= 0 {
			rl.SetShaderValue(
				assets.sprites.npc_glow_shader,
				assets.sprites.npc_glow_time_loc,
				&t,
				.FLOAT,
			)
		}
		rl.BeginShaderMode(assets.sprites.npc_glow_shader)
	}

	for i in 0 ..< n {
		pos := npc.body[i]
		if i == head_idx {
			rl.DrawTexture(
				assets.sprites.head[npc.head_dirs[head_idx]],
				c.int(pos.x * CELL_SIZE),
				c.int(pos.y * CELL_SIZE),
				tint,
			)
		} else if i == 0 {
			rl.DrawTexture(
				assets.sprites.tail[npc.head_dirs[0]],
				c.int(pos.x * CELL_SIZE),
				c.int(pos.y * CELL_SIZE),
				tint,
			)
		} else {
			dir_in := dir_to_vec(npc.head_dirs[i - 1])
			dir_out := dir_to_vec(npc.head_dirs[i])
			tex := body_texture(assets.sprites, dir_in, dir_out)
			rl.DrawTexture(tex, c.int(pos.x * CELL_SIZE), c.int(pos.y * CELL_SIZE), tint)
		}
	}

	if assets.sprites.npc_glow_shader_valid {
		rl.EndShaderMode()
	}
}

draw_food :: proc(food: Food, assets: Assets) {
	rl.DrawTexture(
		assets.sprites.apple,
		c.int(food.x * CELL_SIZE),
		c.int(food.y * CELL_SIZE),
		rl.WHITE,
	)
}

draw_foul_food :: proc(pos: Vec2, assets: Assets) {
	rl.DrawTexture(
		assets.sprites.foul_apple,
		c.int(pos.x * CELL_SIZE),
		c.int(pos.y * CELL_SIZE),
		rl.WHITE,
	)
}

draw_hud :: proc(playing: Playing) {
	level := LEVELS[playing.current_level]

	rl.DrawRectangle(0, 0, SCREEN_WIDTH, HUD_HEIGHT, rl.Color{42, 112, 20, 255})
	rl.DrawLine(0, HUD_HEIGHT - 1, SCREEN_WIDTH, HUD_HEIGHT - 1, rl.Color{30, 80, 14, 255})

	y: c.int = 20
	fs_big: c.int = 60
	fs_sml: c.int = 30

	// Score (left-aligned)
	x_l: c.int = 12
	score_txt := rl.TextFormat("%d", playing.score)
	rl.DrawText("Score", x_l, y + 10, fs_sml, rl.Color{180, 230, 160, 255})
	x_l += rl.MeasureText("Score", fs_sml) + 6
	rl.DrawText(score_txt, x_l, y, fs_big, rl.RAYWHITE)
	x_l += rl.MeasureText(score_txt, fs_big) + 24

	// Lives + gate (right-aligned)
	sq := c.int(28)
	sp := sq + 6

	gate_total := level.gate_score + playing.gate_extra
	gate_w: c.int = 0
	if !playing.gate_open {
		gate_w = c.int(gate_total) * sp - 6
	}

	lives_w: c.int = c.int(playing.lives) * 32

	right := c.int(SCREEN_WIDTH) - 12

	if !playing.gate_open {
		right -= gate_w
		x_g := right

		for i in 0 ..< gate_total {
			sx := x_g + c.int(i) * sp
			sy := y + 10

			collected := playing.apples > i

			is_split := false
			for s in level.split_scores {
				if s == i + 1 {
					is_split = true
					break
				}
			}

			color: rl.Color
			if collected {
				color = rl.Color{70, 70, 70, 255}
			} else if is_split {
				color = rl.Color{255, 200, 40, 255}
			} else {
				color = rl.Color{200, 230, 180, 255}
			}

			rl.DrawRectangle(sx, sy, sq, sq, color)
			rl.DrawRectangleLines(sx, sy, sq, sq, rl.Color{30, 60, 30, 255})
		}
		right = x_g - 24
	} else {
		rl.DrawText("GATE OPEN", x_l, y, fs_big, rl.Color{255, 200, 0, 255})
		right -= 24
	}

	right -= lives_w
	x_lives := right
	for i in 0 ..< playing.lives {
		sx := x_lives + c.int(i) * 32
		rl.DrawRectangle(sx, y + 10, 28, 28, rl.RED)
		rl.DrawRectangleLines(sx, y + 10, 28, 28, rl.Color{160, 30, 30, 255})
	}

	// Foul indicator (separate line, bottom of HUD)
	if playing.foul_apples > 0 {
		foul_txt := rl.TextFormat("[E] Foul x%d", playing.foul_apples)
		rl.DrawText(foul_txt, 12, HUD_HEIGHT - 34, fs_sml, rl.Color{180, 80, 220, 255})
	}
}

draw_score :: proc(score, total: int) {
	text := rl.TextFormat("Level: %d  Total: %d", score, total)
	rl.DrawText(text, c.int(CELL_SIZE / 2), c.int(CELL_SIZE / 2), CELL_SIZE, rl.RAYWHITE)
}

draw_lives :: proc(lives: int) {
	for i in 0 ..< lives {
		rl.DrawRectangle(
			c.int(int(SCREEN_WIDTH) - CELL_SIZE * (lives - i)),
			c.int(CELL_SIZE / 2),
			CELL_SIZE - 4,
			CELL_SIZE - 4,
			rl.RED,
		)
	}
}

draw_level_label :: proc(label: string) {
	cstr := strings.clone_to_cstring(label)
	defer delete(cstr)
	rl.DrawText(
		cstr,
		c.int(SCREEN_WIDTH / 2 - CELL_SIZE * 3),
		c.int(SCREEN_HEIGHT - CELL_SIZE),
		CELL_SIZE,
		rl.Color{200, 200, 200, 255},
	)
}

draw_countdown :: proc(timer: f32) {
	sec := int(timer) + 1
	if sec < 1 || sec > 4 {
		return
	}
	text: cstring
	switch sec {
	case 4:
		text = "3"
	case 3:
		text = "2"
	case 2:
		text = "1"
	case 1:
		text = "GO!"
	}
	fsize: c.int = CELL_SIZE * 4
	tw := rl.MeasureText(text, fsize)
	rl.DrawText(
		text,
		(SCREEN_WIDTH - tw) / 2,
		SCREEN_HEIGHT / 2 - fsize,
		fsize,
		rl.Color{255, 255, 100, 255},
	)
}

draw_debug_overlay :: proc(frame_count: u64) {
	fps := rl.GetFPS()
	x: c.int = 10
	y: c.int = SCREEN_HEIGHT - 40
	text := rl.TextFormat("FPS: %d  Frame: %d", fps, frame_count)
	rl.DrawText(text, x, y, 20, rl.Color{255, 255, 255, 200})
}

draw_game_over :: proc(final_score: int, playing: Playing) {
	fsize1: c.int = CELL_SIZE * 3
	fsize2: c.int = CELL_SIZE * 2
	fsize3: c.int = CELL_SIZE
	fsize4: c.int = CELL_SIZE / 2 + 4

	cy: c.int = SCREEN_HEIGHT / 2 - fsize1

	// GAME OVER!
	t1: cstring = "GAME OVER!"
	w1 := rl.MeasureText(t1, fsize1)
	rl.DrawText(t1, (SCREEN_WIDTH - w1) / 2, cy, fsize1, rl.RED)
	cy += fsize1 + 10

	// Total Score
	t2 := rl.TextFormat("Total Score: %d", final_score)
	w2 := rl.MeasureText(t2, fsize2)
	rl.DrawText(t2, (SCREEN_WIDTH - w2) / 2, cy, fsize2, rl.RAYWHITE)
	cy += fsize2 + 20

	// Breakdown
	detail_color := rl.Color{200, 230, 180, 255}
	details: [3]cstring
	details[0] = rl.TextFormat("Apples:      %d  (+%d)", playing.apples, playing.apples)
	details[1] = rl.TextFormat(
		"Foul kills:  %d  (+%d)",
		playing.foul_kills,
		playing.foul_kills * 5,
	)
	details[2] = rl.TextFormat("NPC kills:   %d  (+%d)", playing.npc_kills, playing.npc_kills * 10)
	for &txt in details {
		w := rl.MeasureText(txt, fsize4)
		rl.DrawText(txt, (SCREEN_WIDTH - w) / 2, cy, fsize4, detail_color)
		cy += fsize4 + 6
	}

	cy += 10
	// Press SPACE
	t3: cstring = "Press SPACE to restart"
	w3 := rl.MeasureText(t3, fsize3)
	rl.DrawText(t3, (SCREEN_WIDTH - w3) / 2, cy, fsize3, rl.GRAY)
}
