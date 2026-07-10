package main

import "core:fmt"
import "core:math"
import "engine"
import rl "vendor:raylib"

Menu_Context :: struct {
	using scene: engine.Scene_Context,
	pulse:       f32,
	stars:       [50]rl.Vector2,
}

menu_init :: proc(ctx: ^engine.Scene_Context) {
	fmt.println("menu_init")
	mc := cast(^Menu_Context)ctx
	for i in 0 ..< len(mc.stars) {
		mc.stars[i] = rl.Vector2 {
			f32(rl.GetRandomValue(0, mc.eng.config.width)),
			f32(rl.GetRandomValue(0, mc.eng.config.height)),
		}
	}
}

menu_deinit :: proc(ctx: ^engine.Scene_Context) {
	fmt.println("menu_deinit")
}

menu_enter :: proc(ctx: ^engine.Scene_Context) {
	fmt.println("menu_on_enter")
}

menu_leave :: proc(ctx: ^engine.Scene_Context) {
	fmt.println("menu_on_leave")
}

menu_input :: proc(ctx: ^engine.Scene_Context, dt: f32) {
	mc := cast(^Menu_Context)ctx

	if rl.IsKeyPressed(.ENTER) {
		engine.switch_scene(mc.eng, engine.getScene(mc.eng, "game"), .Slide_Right, 0.6)
	}
	if rl.IsKeyPressed(.F11) {
		engine.toggle_fullscreen(mc.eng)
	}
	if rl.IsKeyReleased(.T) {
		engine.resize(mc.eng, 1200, 1200)
		return
	}
	if rl.IsKeyReleased(.R) {
		engine.resize(mc.eng, 800, 600)
		return
	}
}

menu_update :: proc(ctx: ^engine.Scene_Context, dt: f32) {
	mc := cast(^Menu_Context)ctx
	mc.pulse += dt * 5
}

menu_render :: proc(ctx: ^engine.Scene_Context) {
	mc := cast(^Menu_Context)ctx
	rl.DrawRectangle(0, 0, mc.eng.config.width, mc.eng.config.height, rl.Color{15, 15, 30, 255})
	for star in mc.stars {
		b := u8(100 + 155 * (0.5 + 0.5 * math.sin(star.x + star.y + mc.pulse)))
		rl.DrawCircleV(star, 1.5, rl.Color{b, b, b, 255})
	}

	tw := rl.MeasureText("DIGGLE", 64)
	rl.DrawText("DIGGLE", mc.eng.config.width / 2 - tw / 2 + 3, 123, 64, rl.Color{0, 0, 0, 80})
	rl.DrawText("DIGGLE", mc.eng.config.width / 2 - tw / 2, 120, 64, rl.WHITE)

	sw := rl.MeasureText("collect everything", 18)
	rl.DrawText("collect everything", mc.eng.config.width / 2 - sw / 2, 195, 18, rl.LIGHTGRAY)

	pulse := 0.5 + 0.5 * math.sin(mc.pulse)
	alpha := u8(100 + 155 * pulse)
	iw := rl.MeasureText("Press ENTER to play", 22)
	rl.DrawText(
		"Press ENTER to play",
		mc.eng.config.width / 2 - iw / 2,
		300,
		22,
		rl.Color{255, 255, 255, alpha},
	)

	hw := rl.MeasureText("WASD to move  |  ESC to quit", 14)
	rl.DrawText("WASD to move  |  ESC to quit", mc.eng.config.width / 2 - hw / 2, 370, 14, rl.GRAY)

	fw := rl.MeasureText("F11 to toggle fullscreen", 14)
	rl.DrawText("F11 to toggle fullscreen", mc.eng.config.width / 2 - fw / 2, 390, 14, rl.GRAY)
}
