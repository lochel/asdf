package main

free_npc_parts :: proc(npc: ^NpcSnake) {
	delete(npc.body)
	delete(npc.head_dirs)
	delete(npc.debug_path)
}

clear_npc_snakes :: proc(snakes: ^[dynamic]NpcSnake) {
	for i in 0 ..< len(snakes^) {
		free_npc_parts(&snakes^[i])
	}
	clear(snakes)
}

delete_npc_snakes :: proc(snakes: ^[dynamic]NpcSnake) {
	for i in 0 ..< len(snakes^) {
		free_npc_parts(&snakes^[i])
	}
	delete(snakes^)
	snakes^ = nil
}

score_from_playing :: proc(playing: Playing) -> int {
	return playing.apples + playing.foul_kills * 5 + playing.npc_kills * 10
}

recompute_score :: proc(playing: ^Playing) {
	playing.score = score_from_playing(playing^)
}

add_pending_label :: proc(playing: ^Playing, pos: Vec2, text: cstring) {
	append(&playing.pending_labels, PendingLabel{pos = pos, text = text})
}

drop_pending_plus10 :: proc(playing: ^Playing) {
	for i := len(playing.pending_labels) - 1; i >= 0; i -= 1 {
		if playing.pending_labels[i].text == "+10" {
			unordered_remove(&playing.pending_labels, i)
		}
	}
}

drop_visible_plus10 :: proc(labels: ^[dynamic]FloatingLabel) {
	for i := len(labels^) - 1; i >= 0; i -= 1 {
		if labels^[i].text == "+10" {
			unordered_remove(labels, i)
		}
	}
}

release_playing_runtime :: proc(playing: ^Playing, release_level_stats: bool = false) {
	delete_npc_snakes(&playing.npc_snakes)
	delete(playing.foul_foods)
	playing.foul_foods = nil
	delete(playing.splits_triggered)
	playing.splits_triggered = {}
	delete(playing.pending_labels)
	playing.pending_labels = nil
	if release_level_stats {
		delete(playing.level_stats)
		playing.level_stats = nil
	}
}
