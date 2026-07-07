package main

import "core:c"
import "core:math/rand"
import "vendor:raylib"

LEVEL_FILES := []string {
	"assets/levels/map1.txt",
	"assets/levels/map2.txt",
	"assets/levels/map3.txt",
	"assets/levels/map4.txt",
	"assets/levels/map5.txt",
}

LEVELS: []LevelDef

spawn_demo_npc :: proc(m: ^Menu, tm: Tilemap) {
	npc_dirs := [3]Direction{.Right, .Left, .Down}
	npc_offsets := [3]Vec2{{-1, 0}, {1, 0}, {0, -1}}
	idx := len(m.demo_npcs) % 3
	pos: Vec2
	found := false
	for attempt := 0; attempt < 50; attempt += 1 {
		p := Vec2{rand.int_max(GRID_WIDTH), rand.int_max(GRID_HEIGHT)}
		if is_grass(tm, p) && p != tm.start_pos {
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
	append(&npc_dirs_arr, npc_dirs[idx])
	append(&npc_dirs_arr, npc_dirs[idx])
	append(&m.demo_npcs, NpcSnake{
		body      = npc_body,
		head_dirs = npc_dirs_arr,
		direction = npc_dirs[idx],
		tint      = npc_tint(idx),
	})
}

main :: proc() {
	raylib.SetTraceLogLevel(.NONE)
	raylib.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})

	raylib.InitWindow(SCREEN_WIDTH, WINDOW_HEIGHT, "Snake")
	raylib.SetExitKey(.KEY_NULL)
	raylib.SetTargetFPS(600)
	defer raylib.CloseWindow()

	raylib.InitAudioDevice()
	defer raylib.CloseAudioDevice()

	defer close_joystick()

	assets := load_assets()
	defer unload_assets(assets)

	render_tex := raylib.LoadRenderTexture(SCREEN_WIDTH, WINDOW_HEIGHT)
	defer raylib.UnloadRenderTexture(render_tex)

	LEVELS = make([]LevelDef, len(LEVEL_FILES))
	for f, i in LEVEL_FILES {
		LEVELS[i] = load_level_meta(f)
	}
	defer {
		for l in LEVELS {
			delete(l.label)
			delete(l.split_scores)
		}
		delete(LEVELS)
	}

	raylib.SetRandomSeed(u32(raylib.GetTime() * 1000))

	snake: Snake
	food: Food = {-1, -1}
	state: GameState = Menu{}
	move_timer: f32 = 0
	move_delay: f32 = 0.2
	frame_count: u64 = 0
	fullscreen := false

	tilemap_loaded := false
	tilemap: Tilemap

	for !raylib.WindowShouldClose() {
		dt := raylib.GetFrameTime()
		read_joystick()

		if raylib.IsKeyPressed(.F) {
			fullscreen = !fullscreen
			if fullscreen {
				m := raylib.GetCurrentMonitor()
				raylib.SetWindowSize(raylib.GetMonitorWidth(m), raylib.GetMonitorHeight(m))
				raylib.SetWindowPosition(0, 0)
			} else {
				raylib.SetWindowSize(SCREEN_WIDTH, WINDOW_HEIGHT)
			}
		}

		switch s in state {
		case Menu:
			m := &state.(Menu)

			if !tilemap_loaded {
				tilemap = load_tilemap(LEVELS[0].file)
				tilemap_loaded = true

				clear(&snake.body)
				clear(&snake.head_dirs)
				s := tilemap.start_pos
				if !tilemap.has_start {
					s = Vec2{GRID_WIDTH / 2, GRID_HEIGHT / 2}
				}
				append(&snake.body, s)
				append(&snake.head_dirs, Direction.Right)
				snake.direction = .Right
				snake.next_direction = .Right

				spawn_food(&snake, &m.demo_food, tilemap, nil)

				spawn_demo_npc(m, tilemap)
				spawn_demo_npc(m, tilemap)
				spawn_demo_npc(m, tilemap)
			}

			if raylib.IsKeyPressed(.SPACE) || raylib.IsKeyPressed(.ENTER) || controller_confirm() {
				for npc in m.demo_npcs {
					delete(npc.body)
					delete(npc.head_dirs)
					delete(npc.debug_path)
				}
				clear(&m.demo_npcs)

				state = Playing {
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
				init_game(&snake, &food, &tilemap)
				move_timer = 0
			}

			move_timer += dt
			if move_timer >= move_delay {
				demo_play := Playing {
					npc_snakes = m.demo_npcs,
					foul_foods = {},
				}
				for i := len(m.demo_npcs) - 1; i >= 0; i -= 1 {
					food_pos := m.demo_food
					alive, ate := move_npc(&m.demo_npcs[i], food_pos, &snake, &demo_play, false, tilemap)
					if !alive {
						delete(m.demo_npcs[i].body)
						delete(m.demo_npcs[i].head_dirs)
						delete(m.demo_npcs[i].debug_path)
						unordered_remove(&m.demo_npcs, i)
						spawn_demo_npc(m, tilemap)
						continue
					}
					if ate {
						spawn_food(&snake, &m.demo_food, tilemap, &demo_play)
					}
				}
				move_timer = 0
			}

		case Playing:
			playing := &state.(Playing)
			if raylib.IsKeyPressed(.ESCAPE) || raylib.IsKeyPressed(.P) || gp_button_pressed(.MIDDLE_LEFT, 0) || joy_button_pressed(7) {
				playing.paused = !playing.paused
			}
			if !playing.paused {
			for i := len(playing.foul_foods) - 1; i >= 0; i -= 1 {
				playing.foul_foods[i].timer -= dt
				if playing.foul_foods[i].timer <= 0 {
					unordered_remove(&playing.foul_foods, i)
				}
			}
			if playing.countdown > 0 {
				playing.countdown -= dt
				move_timer += dt
				if move_timer >= move_delay {
					update(&snake, &food, playing, &state, &assets, &tilemap, true)
					move_timer = 0
				}
			} else {
				handle_input(&snake, state)
				if playing.foul_apples > 0 {
					dump :=
						raylib.IsKeyPressed(.E) ||
						gp_button_pressed(.RIGHT_FACE_RIGHT, 0) ||
						joy_button_pressed(1)
					if dump {
						append(
							&playing.foul_foods,
							FoulFood{pos = snake.body[0], timer = FOUL_FOOD_LIFETIME},
						)
						playing.foul_apples -= 1
					}
				}
				move_timer += dt
				if move_timer >= move_delay {
					update(&snake, &food, playing, &state, &assets, &tilemap, false)
		move_timer = 0
			}
		}
		}

		case GameOver:
			if raylib.IsKeyPressed(.SPACE) || raylib.IsKeyPressed(.ENTER) || controller_confirm() {
				if tilemap_loaded {
					unload_tilemap(&tilemap)
					tilemap_loaded = false
				}
				state = Menu{}
			}
		}

		frame_count += 1

		raylib.BeginTextureMode(render_tex)
		raylib.ClearBackground(raylib.BLACK)

		camera := raylib.Camera2D {
			offset   = {0, f32(HUD_HEIGHT)},
			target   = {0, 0},
			rotation = 0,
			zoom     = 1,
		}

		switch s in state {
		case Menu:
			m := &state.(Menu)
			if tilemap.has_start {
				tilemap.tiles[tilemap.start_pos.y][tilemap.start_pos.x] = .Grass
			}
			raylib.BeginMode2D(camera)
			draw_background(tilemap, assets, LEVELS[0].gate_score)
			if m.demo_food.x >= 0 {
				draw_food(m.demo_food, assets)
			}
			for npc in m.demo_npcs {
				draw_npc_snake(npc, assets)
			}
			if m.demo_food.x >= 0 {
				best_len := max(int)
				best_npc_path: [dynamic]Vec2
				best_tint: raylib.Color
				best_head: Vec2 = {-1, -1}
				food_pos := m.demo_food
				for npc in m.demo_npcs {
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
			raylib.EndMode2D()
			if tilemap.has_start {
				tilemap.tiles[tilemap.start_pos.y][tilemap.start_pos.x] = .Start
			}
			raylib.DrawRectangle(0, 0, SCREEN_WIDTH, WINDOW_HEIGHT, raylib.Color{0, 0, 0, 100})

			raylib.DrawRectangle(0, 0, SCREEN_WIDTH, HUD_HEIGHT, raylib.Color{42, 112, 20, 255})
			raylib.DrawLine(0, HUD_HEIGHT - 1, SCREEN_WIDTH, HUD_HEIGHT - 1, raylib.Color{30, 80, 14, 255})

			fs_big: c.int = 60
			fs_sml: c.int = 30
			y: c.int = 20
			x: c.int = 12
			for i in 0 ..< min(len(m.demo_npcs), 3) {
				label := raylib.TextFormat("NPC%d: ", i + 1)
				raylib.DrawText(label, x, y + 10, fs_sml, raylib.Color{180, 230, 160, 255})
				x += raylib.MeasureText(label, fs_sml) + 4
				val := raylib.TextFormat("%d", len(m.demo_npcs[i].body))
				raylib.DrawText(val, x, y, fs_big, raylib.RAYWHITE)
				x += raylib.MeasureText(val, fs_big) + 24
			}

			hint: cstring = "Press SPACE to start"
			hint_size: c.int = CELL_SIZE
			hw := raylib.MeasureText(hint, hint_size)
			raylib.DrawText(
				hint,
				(SCREEN_WIDTH - hw) / 2,
				WINDOW_HEIGHT - CELL_SIZE * 3,
				hint_size,
				raylib.GREEN,
			)

		case Playing:
			if raylib.IsKeyPressed(.H) { show_hint = !show_hint }
			playing := &state.(Playing)
			draw_hud(s)
			raylib.BeginMode2D(camera)
			gate_threshold := LEVELS[s.current_level].gate_score + s.gate_extra
			remaining := max(0, gate_threshold - s.score)
			draw_background(tilemap, assets, remaining)
			draw_food(food, assets)
			for ff in s.foul_foods {
				draw_foul_food(ff.pos, assets)
			}
			if s.countdown <= 0 {
				draw_snake(snake, assets)
			}
			for npc in s.npc_snakes {
				draw_npc_snake(npc, assets)
			}
			target: Vec2
			has_target := false
			if playing.gate_open && tilemap.has_gate {
				target = tilemap.gate_pos
				has_target = true
			} else if food.x >= 0 {
				target = food
				has_target = true
			}
			if has_target {
				best_path: [dynamic]Vec2
				best_tint: raylib.Color
				best_len := max(int)
				best_head: Vec2 = {-1, -1}
				delete_paths: [dynamic][dynamic]Vec2

				if show_hint {
					p := find_path(&snake, playing, &tilemap, target)
					if len(p) > 1 && len(p) < best_len {
						best_len = len(p)
						best_path = p
						best_tint = raylib.Color{80, 140, 255, 140}
						best_head = snake.body[len(snake.body) - 1]
					}
					append(&delete_paths, p)
				}

				for npc in s.npc_snakes {
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
			raylib.EndMode2D()
			if s.countdown > 0 {
				draw_countdown(s.countdown)
			}
			if playing.paused {
				raylib.DrawRectangle(0, HUD_HEIGHT, SCREEN_WIDTH, SCREEN_HEIGHT, raylib.Color{0, 0, 0, 120})
				fs1 := CELL_SIZE * 2
				tw1 := raylib.MeasureText("PAUSED", c.int(fs1))
				raylib.DrawText("PAUSED", c.int((SCREEN_WIDTH - tw1) / 2), c.int(HUD_HEIGHT + (SCREEN_HEIGHT - fs1) / 2 - CELL_SIZE), c.int(fs1), raylib.RAYWHITE)
				fs2 := CELL_SIZE / 2
				tw2 := raylib.MeasureText("Press ESC or P to resume", c.int(fs2))
				raylib.DrawText("Press ESC or P to resume", c.int((SCREEN_WIDTH - tw2) / 2), c.int(HUD_HEIGHT + (SCREEN_HEIGHT - fs2) / 2 + CELL_SIZE), c.int(fs2), raylib.Color{200, 200, 200, 255})
			}

		case GameOver:
			if tilemap_loaded {
				raylib.BeginMode2D(camera)
				draw_background(tilemap, assets, 0)
				raylib.EndMode2D()
			} else {
				raylib.ClearBackground(raylib.Color{20, 20, 30, 255})
			}
			draw_game_over(s.final_score)
		}

		draw_debug_overlay(frame_count)
		raylib.EndTextureMode()

		raylib.BeginDrawing()
		sw := f32(raylib.GetScreenWidth())
		sh := f32(raylib.GetScreenHeight())
		tw := f32(SCREEN_WIDTH)
		th := f32(WINDOW_HEIGHT)
		scale := min(sw / tw, sh / th)
		dw := tw * scale
		dh := th * scale
		dx := (sw - dw) / 2
		dy := (sh - dh) / 2
		raylib.ClearBackground(raylib.BLACK)
		raylib.DrawTexturePro(
			render_tex.texture,
			raylib.Rectangle{0, 0, tw, -th},
			raylib.Rectangle{dx, dy, dw, dh},
			{0, 0}, 0, raylib.WHITE,
		)
		raylib.EndDrawing()
		save_joy_button_state()
	}

	if p, ok := &state.(Playing); ok {
		for npc in p.npc_snakes {
			delete(npc.body)
			delete(npc.head_dirs)
			delete(npc.debug_path)
		}
		delete(p.npc_snakes)
		delete(p.foul_foods)
		delete(p.splits_triggered)
	}
	if m, ok := &state.(Menu); ok {
		for npc in m.demo_npcs {
			delete(npc.body)
			delete(npc.head_dirs)
			delete(npc.debug_path)
		}
		delete(m.demo_npcs)
	}
	delete(snake.body)
	delete(snake.head_dirs)
	if tilemap_loaded {
		unload_tilemap(&tilemap)
	}
}
