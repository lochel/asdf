package main

import "engine"
import rl "vendor:raylib"

ITEM_COUNT :: 4
PLAYER_SIZE :: 20
ITEM_RADIUS :: 10

Game_Context :: struct {
	using scene: engine.Scene_Context,
	player:      rl.Vector2,
	items:       [ITEM_COUNT]rl.Vector2,
	item_active: [ITEM_COUNT]bool,
	score:       int,
	won:         bool,
}

game_init :: proc(ctx: ^engine.Scene_Context) {
	gd := cast(^Game_Context)ctx
	gd.player = {f32(gd.eng.config.width / 2), f32(gd.eng.config.height / 2)}
	gd.score = 0
	gd.won = false

	padding := i32(50)
	for i in 0 ..< ITEM_COUNT {
		gd.items[i] = rl.Vector2 {
			f32(rl.GetRandomValue(padding, gd.eng.config.width - padding)),
			f32(rl.GetRandomValue(padding, gd.eng.config.height - padding)),
		}
		gd.item_active[i] = true
	}
}

game_deinit :: proc(ctx: ^engine.Scene_Context) {
}

game_input :: proc(ctx: ^engine.Scene_Context, dt: f32) {
	gd := cast(^Game_Context)ctx

	if rl.IsKeyReleased(.E) {
		engine.switch_scene(gd.eng, engine.getScene(gd.eng, "menu"), .Slide_Left, 0.6)
	}
	if gd.won {
		if rl.IsKeyPressed(.ENTER) {
			engine.switch_scene(gd.eng, engine.getScene(gd.eng, "menu"), .Slide_Left, 0.6)
		}
		return
	}

	speed := f32(280)
	if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) {gd.player.y -= speed * dt}
	if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {gd.player.y += speed * dt}
	if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) {gd.player.x -= speed * dt}
	if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) {gd.player.x += speed * dt}
}

game_update :: proc(ctx: ^engine.Scene_Context, dt: f32) {
	gd := cast(^Game_Context)ctx

	gd.player.x = clamp(gd.player.x, PLAYER_SIZE, f32(gd.eng.config.width - PLAYER_SIZE))
	gd.player.y = clamp(gd.player.y, PLAYER_SIZE, f32(gd.eng.config.height - PLAYER_SIZE))

	for i in 0 ..< ITEM_COUNT {
		if !gd.item_active[i] {continue}
		if rl.Vector2Distance(gd.player, gd.items[i]) < PLAYER_SIZE + ITEM_RADIUS {
			gd.item_active[i] = false
			gd.score += 1
			if gd.score >= ITEM_COUNT {
				gd.won = true
			}
		}
	}
}

game_render :: proc(ctx: ^engine.Scene_Context) {
	gd := cast(^Game_Context)ctx
	rl.DrawRectangle(0, 0, gd.eng.config.width, gd.eng.config.height, rl.Color{20, 20, 25, 255})
	c := rl.Color{35, 35, 45, 255}
	for x := i32(0); x <= gd.eng.config.width; x += 40 {
		rl.DrawLine(x, 0, x, gd.eng.config.height, c)
	}
	for y := i32(0); y <= gd.eng.config.height; y += 40 {
		rl.DrawLine(0, y, gd.eng.config.width, y, c)
	}

	for i in 0 ..< ITEM_COUNT {
		if !gd.item_active[i] {continue}
		rl.DrawCircleV(gd.items[i], ITEM_RADIUS + 4, rl.Color{50, 230, 80, 60})
		rl.DrawCircleV(gd.items[i], ITEM_RADIUS, rl.Color{80, 255, 120, 255})
		rl.DrawCircleV(gd.items[i], ITEM_RADIUS * 0.5, rl.Color{180, 255, 200, 255})
	}

	rect := rl.Rectangle {
		gd.player.x - PLAYER_SIZE,
		gd.player.y - PLAYER_SIZE,
		PLAYER_SIZE * 2,
		PLAYER_SIZE * 2,
	}
	rl.DrawRectangleRounded(rect, 0.3, 8, rl.Color{100, 150, 255, 255})
	rl.DrawRectangleRoundedLinesEx(rect, 0.3, 8, 2, rl.Color{150, 200, 255, 200})

	rl.DrawText(rl.TextFormat("Collected: %d/%d", gd.score, ITEM_COUNT), 15, 15, 20, rl.WHITE)

	if gd.won {
		wt := rl.MeasureText("YOU WIN!", 48)
		rl.DrawText(
			"YOU WIN!",
			gd.eng.config.width / 2 - wt / 2,
			gd.eng.config.height / 2 - 40,
			48,
			rl.Color{80, 255, 120, 255},
		)
		st := rl.MeasureText("Press ENTER for menu", 18)
		rl.DrawText(
			"Press ENTER for menu",
			gd.eng.config.width / 2 - st / 2,
			gd.eng.config.height / 2 + 20,
			18,
			rl.LIGHTGRAY,
		)
	}
}
