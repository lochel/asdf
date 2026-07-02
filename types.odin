package main

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

NpcSnake :: struct {
	body:       [dynamic]Vec2,
	head_dirs:  [dynamic]Direction,
	direction:  Direction,
	stun:       int,
	debug_path: [dynamic]Vec2,
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
	file:          string,
	label:         string,
	gate_score:    int,
	split_scores:  []int,
}

LevelHeader :: struct {
	label:        string,
	gate_score:   int   `json:"gate_score"`,
	split_scores: []int `json:"split_scores"`,
}
