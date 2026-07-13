package main

import "vendor:raylib"

Vec2 :: [2]int
Food :: Vec2

Direction :: enum {
	Up,
	Down,
	Left,
	Right,
}

Snake :: struct {
	body:           [dynamic]Vec2,
	head_dirs:      [dynamic]Direction,
	direction:      Direction,
	next_direction: Direction,
}

npc_tint :: proc(idx: int) -> raylib.Color {
	tints := []raylib.Color {
		{240, 80, 80, 255},
		{220, 60, 40, 255},
		{255, 120, 90, 255},
		{200, 50, 60, 255},
		{255, 80, 120, 255},
	}
	return tints[idx % len(tints)]
}

NpcSnake :: struct {
	body:       [dynamic]Vec2,
	head_dirs:  [dynamic]Direction,
	direction:  Direction,
	stun:       int,
	debug_path: [dynamic]Vec2,
	tint:       raylib.Color,
}

FoulFood :: struct {
	pos:   Vec2,
	timer: f32,
}
