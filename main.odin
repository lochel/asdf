package main

import "core:c"
import "vendor:raylib"

LEVEL_FILES := []string {
	"assets/levels/map1.txt",
	"assets/levels/map2.txt",
	"assets/levels/map3.txt",
	"assets/levels/map4.txt",
	"assets/levels/map5.txt",
}

LEVELS: []LevelDef

main :: proc() {
	raylib.SetTraceLogLevel(.NONE)
	raylib.SetConfigFlags({.VSYNC_HINT})

	raylib.InitWindow(SCREEN_WIDTH, WINDOW_HEIGHT, "Snake")
	raylib.SetTargetFPS(60)
	defer raylib.CloseWindow()

	raylib.InitAudioDevice()
	defer raylib.CloseAudioDevice()

	defer close_joystick()

	assets := load_assets()
	defer unload_assets(assets)

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

	tilemap_loaded := false
	tilemap: Tilemap

	for !raylib.WindowShouldClose() {
		dt := raylib.GetFrameTime()
		read_joystick()

		switch s in state {
		case Menu:
			if raylib.IsKeyPressed(.SPACE) || raylib.IsKeyPressed(.ENTER) || controller_confirm() {
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
			}
				tilemap = load_tilemap(LEVELS[0].file)
				tilemap_loaded = true
				init_game(&snake, &food, &tilemap)
				move_timer = 0
			}

		case Playing:
			playing := &state.(Playing)
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

		raylib.BeginDrawing()

		camera := raylib.Camera2D {
			offset   = {0, f32(HUD_HEIGHT)},
			target   = {0, 0},
			rotation = 0,
			zoom     = 1,
		}

		switch s in state {
		case Menu:
			if tilemap_loaded {
				raylib.BeginMode2D(camera)
				draw_background(tilemap, assets, LEVELS[0].gate_score)
				if len(snake.body) > 0 {
					draw_food(food, assets)
					draw_snake(snake, assets)
				}
				raylib.EndMode2D()
				raylib.DrawRectangle(0, 0, SCREEN_WIDTH, WINDOW_HEIGHT, raylib.Color{0, 0, 0, 100})
			} else {
				raylib.ClearBackground(raylib.Color{20, 20, 30, 255})
			}

			title: cstring = "SNAKE"
			title_size: c.int = CELL_SIZE * 3
			tw := raylib.MeasureText(title, title_size)
			raylib.DrawText(
				title,
				(SCREEN_WIDTH - tw) / 2,
				CELL_SIZE * 2,
				title_size,
				raylib.GREEN,
			)

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
			if show_hint {
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
					m_dist :: proc(a, b: Vec2) -> int {
						dx := abs(a.x - b.x)
						dy := abs(a.y - b.y)
						return min(dx, 20 - dx) + min(dy, 20 - dy)
					}
					head := snake.body[len(snake.body) - 1]
					player_dist := m_dist(head, target)
					npc_closer := false
					for npc in playing.npc_snakes {
						if len(npc.body) == 0 { continue }
						npc_head := npc.body[len(npc.body) - 1]
						if m_dist(npc_head, target) < player_dist {
							npc_closer = true
							break
						}
					}
					if !npc_closer {
						path := find_path(&snake, playing, &tilemap, food)
						draw_hint(path)
						delete(path)
					}
				}
			}
			raylib.EndMode2D()
			if s.countdown > 0 {
				draw_countdown(s.countdown)
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
		raylib.EndDrawing()
		save_joy_button_state()
	}

	if playing, ok := &state.(Playing); ok {
		for npc in playing.npc_snakes {
			delete(npc.body)
			delete(npc.head_dirs)
			delete(npc.debug_path)
		}
		delete(playing.npc_snakes)
		delete(playing.foul_foods)
		delete(playing.splits_triggered)
	}
	delete(snake.body)
	delete(snake.head_dirs)
	if tilemap_loaded {
		unload_tilemap(&tilemap)
	}
}
