package main

import "engine"
import "core:c"
import "core:math"
import "core:math/rand"
import "core:strings"
import rl "vendor:raylib"

CONFETTI_COUNT :: 80

Confetti_Particle :: struct {
	x, y:       f32,
	vx, vy:     f32,
	color:      rl.Color,
	size:       f32,
	rotation:   f32,
	rot_speed:  f32,
	life:       f32,
	max_life:   f32,
}

Victory_Context :: struct {
	using scene:     engine.Scene_Context,
	total_score:     int,
	level_stats:     [dynamic]LevelStats,
	elapsed:         f32,
	confetti:        [CONFETTI_COUNT]Confetti_Particle,
}

confetti_colors: [8]rl.Color = {
	{255, 80, 80, 255},
	{80, 200, 255, 255},
	{255, 220, 50, 255},
	{50, 255, 120, 255},
	{255, 130, 255, 255},
	{255, 170, 60, 255},
	{100, 255, 200, 255},
	{220, 160, 255, 255},
}

spawn_confetti :: proc(p: ^Confetti_Particle, sw: i32) {
	p.x = f32(rand.int_max(int(sw)))
	p.y = -f32(rand.int_max(200))
	p.vx = (f32(rand.int_max(100)) - 50) / 40.0
	p.vy = f32(rand.int_max(100)) / 60.0 + 1.0
	p.color = confetti_colors[rand.int_max(len(confetti_colors))]
	p.size = f32(rand.int_max(8) + 4)
	p.rotation = f32(rand.int_max(360))
	p.rot_speed = (f32(rand.int_max(200)) - 100) / 10.0
	p.life = f32(rand.int_max(100)) / 100.0 * 3.0 + 2.0
	p.max_life = p.life
}

victory_enter :: proc(ctx: ^engine.Scene_Context) {
	vc := cast(^Victory_Context)ctx

	vc.total_score = victory_score
	vc.level_stats = victory_stats
	victory_stats = nil
	vc.elapsed = 0

	engine.resize(vc.eng, 800, 600)

	sw := vc.eng.config.width
	for i in 0 ..< CONFETTI_COUNT {
		spawn_confetti(&vc.confetti[i], sw)
		vc.confetti[i].y = f32(rand.int_max(600))
	}
}

victory_leave :: proc(ctx: ^engine.Scene_Context) {
	vc := cast(^Victory_Context)ctx
	delete(vc.level_stats)
	vc.level_stats = nil
}

victory_input :: proc(ctx: ^engine.Scene_Context, dt: f32) {
	_ = dt
	vc := cast(^Victory_Context)ctx

	if rl.IsKeyPressed(.ESCAPE) {
		engine.close(vc.eng)
		return
	}
	if rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.ENTER) || controller_confirm() {
		engine.switch_scene(vc.eng, engine.getScene(vc.eng, "menu"), .Slide_Left, 0.6)
		return
	}
}

victory_update :: proc(ctx: ^engine.Scene_Context, dt: f32) {
	vc := cast(^Victory_Context)ctx
	vc.elapsed += dt

	sw := vc.eng.config.width
	sh := vc.eng.config.height
	for i in 0 ..< CONFETTI_COUNT {
		p := &vc.confetti[i]
		p.x += p.vx
		p.y += p.vy
		p.vy += 15.0 * dt
		p.rotation += p.rot_speed
		p.life -= dt
		if p.life <= 0 || p.y > f32(sh) + 20 {
			spawn_confetti(p, sw)
			p.y = -10
		}
	}
}

victory_render :: proc(ctx: ^engine.Scene_Context) {
	vc := cast(^Victory_Context)ctx
	sw := vc.eng.config.width
	sh := vc.eng.config.height

	rl.ClearBackground(rl.Color{15, 15, 30, 255})

	for i in 0 ..< CONFETTI_COUNT {
		p := vc.confetti[i]
		alpha := u8(255)
		if p.life < 0.5 {
			alpha = u8(f32(255) * p.life / 0.5)
		}
		c := p.color
		c.a = alpha
		rl.DrawRectanglePro(
			rl.Rectangle{p.x, p.y, p.size, p.size * 0.6},
			rl.Vector2{p.size / 2, p.size * 0.3},
			p.rotation,
			c,
		)
	}

	title: cstring = "CONGRATULATIONS!"
	fsize_title: c.int = 48
	pulse := 1.0 + 0.05 * math.sin(vc.elapsed * 3.0)
	tw := rl.MeasureText(title, fsize_title)
	tx := (sw - tw) / 2
	ty := c.int(f32(50) * pulse)
	glow_alpha := u8(f32(180) + 75.0 * math.sin(vc.elapsed * 4.0))
	rl.DrawText(title, tx + 2, ty + 2, fsize_title, rl.Color{0, 0, 0, glow_alpha})
	rl.DrawText(title, tx, ty, fsize_title, rl.Color{50, 255, 80, 255})

	sub: cstring = rl.TextFormat("All %d levels completed!", len(vc.level_stats))
	fsize_sub: c.int = 24
	wsub := rl.MeasureText(sub, fsize_sub)
	rl.DrawText(sub, (sw - wsub) / 2, ty + fsize_title + 16, fsize_sub, rl.Color{200, 230, 180, 255})

	cy := ty + fsize_title + 60

	fs_col: c.int = 18
	fs_val: c.int = 22
	row_h := fs_val + 8
	col_x: [5]c.int
	col_x[0] = 40
	col_x[1] = col_x[0] + 280
	col_x[2] = col_x[1] + 80
	col_x[3] = col_x[2] + 80
	col_x[4] = col_x[3] + 80

	rl.DrawRectangle(30, cy - 4, sw - 60, row_h + 4, rl.Color{30, 50, 30, 180})
	headers: [5]cstring = {"Level", "Apples", "Foul", "NPC", "Score"}
	for hi in 0 ..< 5 {
		rl.DrawText(headers[hi], col_x[hi], cy, fs_col, rl.Color{150, 200, 140, 255})
	}
	cy += row_h

	total_apples := 0
	total_foul := 0
	total_npc := 0
	total := 0

	for ls, idx in vc.level_stats {
		bg := idx % 2 == 0
		if bg {
			rl.DrawRectangle(30, cy - 2, sw - 60, row_h, rl.Color{25, 35, 25, 120})
		}

		rl.DrawText(strings.clone_to_cstring(ls.label), col_x[0], cy, fs_val, rl.RAYWHITE)
		rl.DrawText(rl.TextFormat("%d", ls.apples), col_x[1], cy, fs_val, rl.RAYWHITE)
		rl.DrawText(rl.TextFormat("%d", ls.foul_kills), col_x[2], cy, fs_val, rl.RAYWHITE)
		rl.DrawText(rl.TextFormat("%d", ls.npc_kills), col_x[3], cy, fs_val, rl.RAYWHITE)
		rl.DrawText(rl.TextFormat("%d", ls.score), col_x[4], cy, fs_val, rl.Color{255, 220, 80, 255})
		cy += row_h

		total_apples += ls.apples
		total_foul += ls.foul_kills
		total_npc += ls.npc_kills
		total += ls.score
	}

	cy += 4
	rl.DrawLine(40, cy, sw - 40, cy, rl.Color{80, 120, 70, 255})
	cy += 8

	rl.DrawText("Total", col_x[0], cy, fs_val, rl.Color{255, 220, 80, 255})
	rl.DrawText(rl.TextFormat("%d", total_apples), col_x[1], cy, fs_val, rl.Color{255, 220, 80, 255})
	rl.DrawText(rl.TextFormat("%d", total_foul), col_x[2], cy, fs_val, rl.Color{255, 220, 80, 255})
	rl.DrawText(rl.TextFormat("%d", total_npc), col_x[3], cy, fs_val, rl.Color{255, 220, 80, 255})
	rl.DrawText(rl.TextFormat("%d", total), col_x[4], cy, fs_val, rl.Color{255, 220, 80, 255})
	cy += row_h + 20

	// Total score big
	ts_text := rl.TextFormat("Final Score: %d", vc.total_score)
	fsize_ts: c.int = 36
	wts := rl.MeasureText(ts_text, fsize_ts)
	rl.DrawText(ts_text, (sw - wts) / 2, cy, fsize_ts, rl.RAYWHITE)
	cy += fsize_ts + 30

	hint: cstring = "Press SPACE to return to menu"
	fsize_hint: c.int = 20
	wh := rl.MeasureText(hint, fsize_hint)
	hint_alpha := u8(f32(200) + 55.0 * math.sin(vc.elapsed * 2.5))
	rl.DrawText(hint, (sw - wh) / 2, cy, fsize_hint, rl.Color{180, 180, 180, hint_alpha})
}
