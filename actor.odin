package main

import "core:c"
import "engine"
import rl "vendor:raylib"

Actor :: struct {
	scene:  ^engine.Scene_Context,
	step:   proc(self: ^Actor, step: int),
	update: proc(self: ^Actor, dt: f32),
	render: proc(self: ^Actor),
}

TilemapActor :: struct {
	using actor: Actor,
	tilemap:     ^Tilemap,
	assets:      ^Assets,
	remaining:   int,
}

SnakeActor :: struct {
	using actor: Actor,
	snake:       ^Snake,
	assets:      ^Assets,
}

NpcSnakeCollectionActor :: struct {
	using actor: Actor,
	snakes:      ^[dynamic]NpcSnake,
	assets:      ^Assets,
}

FoodActor :: struct {
	using actor: Actor,
	food:        ^Food,
	assets:      ^Assets,
}

tilemap_actor_render :: proc(self: ^Actor) {
	ta := cast(^TilemapActor)self
	draw_tilemap(ta.tilemap^, ta.assets^, ta.remaining)
}

snake_actor_render :: proc(self: ^Actor) {
	sa := cast(^SnakeActor)self
	draw_snake(sa.snake^, sa.assets^)
}

npc_snake_collection_render :: proc(self: ^Actor) {
	ca := cast(^NpcSnakeCollectionActor)self
	for npc in ca.snakes^ {
		draw_npc_snake(npc, ca.assets^)
	}
}

food_actor_render :: proc(self: ^Actor) {
	fa := cast(^FoodActor)self
	if fa.food^.x >= 0 {
		draw_food(fa.food^, fa.assets^)
	}
}

label_render :: proc(self: ^Actor) {
	label := cast(^FloatingLabel)self
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
