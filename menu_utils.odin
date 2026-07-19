package main

import "core:math/rand"

spawn_demo_npc :: proc(m: ^Menu_Context) {
	npc_dirs := [3]Direction{.Right, .Left, .Down}
	npc_offsets := [3]Vec2{{-1, 0}, {1, 0}, {0, -1}}
	idx := len(m.demo_npcs) % 3
	pos: Vec2
	found := false
	for attempt := 0; attempt < 50; attempt += 1 {
		p := Vec2{rand.int_max(GRID_WIDTH), rand.int_max(GRID_HEIGHT)}
		if is_grass(m.tilemap, p) && p != m.tilemap.start_pos {
			pos = p
			found = true
			break
		}
	}
	if !found {
		pos = Vec2{5 + idx * 5, 5 + idx * 3}
	}

	npc_body := make([dynamic]Vec2)
	npc_dirs_arr := make([dynamic]Direction)
	append(&npc_body, pos)
	append(&npc_body, pos + npc_offsets[idx])
	append(&npc_body, pos + npc_offsets[idx] * 2)
	append(&npc_dirs_arr, npc_dirs[idx])
	append(&npc_dirs_arr, npc_dirs[idx])
	append(&npc_dirs_arr, npc_dirs[idx])
	append(
		&m.demo_npcs,
		NpcSnake {
			body = npc_body,
			head_dirs = npc_dirs_arr,
			direction = npc_dirs[idx],
			tint = npc_tint(idx),
		},
	)
}
