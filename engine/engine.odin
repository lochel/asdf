package engine

import "core:fmt"
import rl "vendor:raylib"

Engine_Context :: struct {
	config:         Config,
	default_config: Config,
	title:          cstring,
	clear_color:    rl.Color,
	current:        ^Scene_Context,
	next:           ^Scene_Context,
	trans:          Transition,
	scenes:         map[string]^Scene_Context,
	audio_enabled:  bool,
	should_close:   bool,
}

enable_audio :: proc(e: ^Engine_Context) {
	rl.InitAudioDevice()
	e.audio_enabled = true
}

create :: proc(title: cstring, default_cfg: Config) -> Engine_Context {
	cfg, ok := load_config()
	if !ok {
		cfg = default_cfg
	}

	return Engine_Context {
		config = cfg,
		default_config = default_cfg,
		title = title,
		clear_color = rl.PINK,
		scenes = make(map[string]^Scene_Context),
		audio_enabled = false,
	}
}

reload_render_textures :: proc(e: ^Engine_Context) {
	for _, scene in e.scenes {
		rl.UnloadRenderTexture(scene.target)
		scene.target = rl.LoadRenderTexture(e.config.width, e.config.height)
	}
}

resize :: proc(e: ^Engine_Context, width, height: i32) {
	e.config.width = width
	e.config.height = height
	save_config(e.config)
	reload_render_textures(e)
}

toggle_fullscreen :: proc(e: ^Engine_Context) {
	if !rl.IsWindowFullscreen() {
		mon := rl.GetCurrentMonitor()
		rl.SetWindowSize(rl.GetMonitorWidth(mon), rl.GetMonitorHeight(mon))
	}
	rl.ToggleFullscreen()
	if !rl.IsWindowFullscreen() {
		rl.SetWindowSize(e.default_config.width, e.default_config.height)
	}
	e.config.fullscreen = rl.IsWindowFullscreen()
}

destroy :: proc(e: ^Engine_Context) {
	save_config(e.config)
	if e.audio_enabled {
		rl.CloseAudioDevice()
	}
	delete(e.scenes)
}

close :: proc(e: ^Engine_Context) {
	e.should_close = true
}

run :: proc(e: ^Engine_Context, first: string) {
	flags: rl.ConfigFlags = {}
	if e.config.resizable {
		flags += {.WINDOW_RESIZABLE}
	}
	rl.SetConfigFlags(flags)

	rl.InitWindow(e.config.width, e.config.height, e.title)
	defer rl.CloseWindow()

	rl.SetTargetFPS(e.config.target_fps)
	rl.SetExitKey(.KEY_NULL)

	if e.config.fullscreen {
		toggle_fullscreen(e)
	}

	for _, scene in e.scenes {
		if scene.init != nil {
			scene.init(scene)
		}
		scene.target = rl.LoadRenderTexture(e.config.width, e.config.height)
	}

	e.current = e.scenes[first]
	if e.current == nil {return}

	for !e.should_close && !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		if rl.IsWindowFullscreen() != e.config.fullscreen {
			e.config.fullscreen = rl.IsWindowFullscreen()
		}

		update_transition(e, dt)

		if e.current != nil && e.current.input != nil {
			e.current.input(e.current, dt)
		}

		if e.current != nil && e.current.step != nil {
			e.current.step_acc -= dt
			max_iter := 5
			for max_iter > 0 && e.current.step_acc <= 0 {
				max_iter -= 1
				e.current.step_acc += e.current.step(e.current, e.current.step_count)
				e.current.step_count += 1
			}
			if max_iter <= 0 {
				fmt.println("death spiral prevented")
			}
		}
		if e.trans.active && e.next != nil && e.next.step != nil {
			e.next.step_acc -= dt
			max_iter := 5
			for max_iter > 0 && e.next.step_acc <= 0 {
				max_iter -= 1
				e.next.step_acc += e.next.step(e.next, e.next.step_count)
				e.next.step_count += 1
			}
			if max_iter <= 0 {
				fmt.println("death spiral prevented")
			}
		}

		if e.current != nil && e.current.update != nil {
			e.current.update(e.current, dt)
		}
		if e.trans.active && e.next != nil && e.next.update != nil {
			e.next.update(e.next, dt)
		}

		if e.current != nil && e.current.render != nil {
			rl.BeginTextureMode(e.current.target)
			rl.ClearBackground(e.clear_color)
			e.current.render(e.current)
			rl.EndTextureMode()
		}
		if e.trans.active && e.next != nil && e.next.render != nil {
			rl.BeginTextureMode(e.next.target)
			rl.ClearBackground(e.clear_color)
			e.next.render(e.next)
			rl.EndTextureMode()
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		win_w := f32(rl.GetScreenWidth())
		win_h := f32(rl.GetScreenHeight())
		log_w := f32(e.config.width)
		log_h := f32(e.config.height)
		scale := min(win_w / log_w, win_h / log_h)
		dst_w := log_w * scale
		dst_h := log_h * scale
		dst_x := (win_w - dst_w) * 0.5
		dst_y := (win_h - dst_h) * 0.5
		src := rl.Rectangle{0, 0, log_w, -log_h}
		dst := rl.Rectangle{dst_x, dst_y, dst_w, dst_h}

		if e.trans.active {
			render_transition(e, dst)
		} else if e.current != nil {
			rl.DrawTexturePro(e.current.target.texture, src, dst, {}, 0, rl.WHITE)
		}

		rl.EndDrawing()
	}

	for _, scene in e.scenes {
		if scene.deinit != nil {
			scene.deinit(scene)
		}
		rl.UnloadRenderTexture(scene.target)
	}
}
