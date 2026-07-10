package main

Playing :: struct {
	lives:            int,
	current_level:    int,
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
}

GameOver :: struct {
	final_score: int,
}
