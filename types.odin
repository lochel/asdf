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

TileType :: enum {
	Grass,
	Wall,
	Puddle,
	Gate,
	Start,
}

FoulFood :: struct {
	pos:   Vec2,
	timer: f32,
}

PuddlePair :: struct {
	a, b: Vec2,
}

Tilemap :: struct {
	tiles:     [][]TileType,
	width:     int,
	height:    int,
	pairs:     [dynamic]PuddlePair,
	gate_pos:  Vec2,
	has_gate:  bool,
	start_pos: Vec2,
	has_start: bool,
}

LevelDef :: struct {
	file:         string,
	label:        string,
	gate_score:   int `json:"gate_score"`,
	split_scores: []int `json:"split_scores"`,
}
