package main

PendingLabel :: struct {
	pos:  Vec2,
	text: cstring,
}

LevelStats :: struct {
	label:      string,
	apples:     int,
	foul_kills: int,
	npc_kills:  int,
	score:      int,
}

Playing :: struct {
	lives:            int,
	current_level:    int,
	apples:           int,
	foul_kills:       int,
	npc_kills:        int,
	score:            int,
	total_score:      int,
	npc_snakes:       [dynamic]NpcSnake,
	gate_open:        bool,
	splits_triggered: map[int]bool,
	countdown:        f32,
	spawning:         int,
	spawning_delayed: bool,
	foul_foods:       [dynamic]FoulFood,
	foul_apples:      int,
	gate_extra:       int,
	paused:           bool,
	pending_labels:   [dynamic]PendingLabel,
	level_stats:      [dynamic]LevelStats,
	level_just_completed: bool,
}
