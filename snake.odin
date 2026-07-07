package main

import "core:c"
import "core:math"
import "core:math/rand"
import "core:strings"
import "vendor:raylib"

CELL_SIZE :: 50
GRID_WIDTH :: 20
GRID_HEIGHT :: 20
FOUL_FOOD_LIFETIME :: 3.0
SCREEN_WIDTH :: CELL_SIZE * GRID_WIDTH
SCREEN_HEIGHT :: CELL_SIZE * GRID_HEIGHT
HUD_HEIGHT :: CELL_SIZE * 2
WINDOW_HEIGHT :: SCREEN_HEIGHT + HUD_HEIGHT

init_game :: proc(snake: ^Snake, food: ^Food, tm: ^Tilemap) {
	clear(&snake.body)
	clear(&snake.head_dirs)
	s := tm.start_pos
	if !tm.has_start {
		s = Vec2{GRID_WIDTH / 2, GRID_HEIGHT / 2}
	}
	append(&snake.body, s)
	append(&snake.head_dirs, Direction.Right)
	snake.direction = .Right
	snake.next_direction = .Right
}

spawn_food :: proc(snake: ^Snake, food: ^Food, tm: Tilemap, playing: ^Playing) {
	occupied := make(map[Vec2]bool)
	defer delete(occupied)

	for seg in snake.body {
		occupied[seg] = true
	}

	if playing != nil {
		for npc in playing.npc_snakes {
			for seg in npc.body {
				occupied[seg] = true
			}
		}
		for ff in playing.foul_foods {
			occupied[ff.pos] = true
		}
	}

	free_cells: [dynamic]Vec2
	defer delete(free_cells)

	for x in 0 ..< GRID_WIDTH {
		for y in 0 ..< GRID_HEIGHT {
			pos := Vec2{x, y}
			if !occupied[pos] && is_grass(tm, pos) {
				append(&free_cells, pos)
			}
		}
	}

	if len(free_cells) > 0 {
		food^ = free_cells[rand.int_max(len(free_cells))]
	}
}

draw_grid :: proc() {
	for x in 0 ..= GRID_WIDTH {
		raylib.DrawLine(
			c.int(x * CELL_SIZE),
			0,
			c.int(x * CELL_SIZE),
			c.int(SCREEN_HEIGHT),
			raylib.Color{50, 50, 50, 255},
		)
	}
	for y in 0 ..= GRID_HEIGHT {
		raylib.DrawLine(
			0,
			c.int(y * CELL_SIZE),
			c.int(SCREEN_WIDTH),
			c.int(y * CELL_SIZE),
			raylib.Color{50, 50, 50, 255},
		)
	}
}

update :: proc(
	snake: ^Snake,
	food: ^Food,
	playing: ^Playing,
	state: ^GameState,
	assets: ^Assets,
	tm: ^Tilemap,
	npcs_only: bool,
) {
	// Delayed spawning: wait until no NPC is within 3 tiles of start
	if playing.spawning_delayed && playing.spawning == 0 && !npcs_only {
		start := tm.start_pos
		if !tm.has_start {
			start = Vec2{GRID_WIDTH / 2, GRID_HEIGHT / 2}
		}
		can_spawn := true
		for npc in playing.npc_snakes {
			for seg in npc.body {
				if abs(seg.x - start.x) + abs(seg.y - start.y) <= 3 {
					can_spawn = false
					break
				}
			}
			if !can_spawn {break}
		}
		if can_spawn {
			playing.spawning = 0
			playing.spawning_delayed = true
			playing.spawning_delayed = false
		}
	}

	if !npcs_only {
		input_used = false
		snake.direction = snake.next_direction

		head := snake.body[len(snake.body) - 1]
		new_head := head

		switch snake.direction {
		case .Up:
			new_head.y -= 1
		case .Down:
			new_head.y += 1
		case .Left:
			new_head.x -= 1
		case .Right:
			new_head.x += 1
		}

		if new_head.x < 0 do new_head.x = GRID_WIDTH - 1
		if new_head.x >= GRID_WIDTH do new_head.x = 0
		if new_head.y < 0 do new_head.y = GRID_HEIGHT - 1
		if new_head.y >= GRID_HEIGHT do new_head.y = 0

		if is_wall(tm^, new_head) {
			player_died(snake, food, playing, state, assets, tm)
			return
		}

		if is_gate(tm^, new_head) && !playing.gate_open {
			player_died(snake, food, playing, state, assets, tm)
			return
		}

		if is_gate(tm^, new_head) && playing.gate_open {
			advance_level(snake, food, playing, state, assets, tm)
			return
		}

		if is_puddle(tm^, new_head) {
			if tp, ok := teleport(tm^, new_head); ok {
				new_head = tp
			}
		}

		for seg in snake.body {
			if seg == new_head {
				player_died(snake, food, playing, state, assets, tm)
				return
			}
		}

		snake.head_dirs[len(snake.head_dirs) - 1] = snake.direction
		append(&snake.body, new_head)
		append(&snake.head_dirs, snake.direction)

		for i in 0 ..< len(playing.foul_foods) {
			if new_head == playing.foul_foods[i].pos {
				unordered_remove(&playing.foul_foods, i)
				player_died(snake, food, playing, state, assets, tm)
				return
			}
		}

		if new_head == food^ {
			playing.score += 1
			raylib.PlaySound(assets^.sounds.eat)

			if !playing.gate_open {
				gate_threshold := LEVELS[playing.current_level].gate_score + playing.gate_extra
				playing.gate_open = playing.score >= gate_threshold
				if playing.gate_open {
					food^ = {-1, -1}
					raylib.PlaySound(assets^.sounds.gate_open)
				} else {
					spawn_food(snake, food, tm^, playing)
				}
			}

			check_split(snake, playing, assets)
		} else if playing.spawning == 0 {
			for i in 0 ..< len(snake.body) - 1 {
				snake.body[i] = snake.body[i + 1]
				snake.head_dirs[i] = snake.head_dirs[i + 1]
			}
			pop(&snake.body)
			pop(&snake.head_dirs)
		} else {
			playing.spawning -= 1
			if playing.spawning == 0 {
				if tm.has_start {
					tm.tiles[tm.start_pos.y][tm.start_pos.x] = .Grass
				}
				if !playing.gate_open {
					spawn_food(snake, food, tm^, playing)
				}
			}
		}

	}

	{
		i := 0
		for i < len(playing.npc_snakes) {
			player_head := snake.body[len(snake.body) - 1]
			alive, ate := move_npc(
				&playing.npc_snakes[i],
				food^,
				snake,
				playing,
				playing.gate_open,
				tm^,
			)
			if !alive {
				delete(playing.npc_snakes[i].body)
				delete(playing.npc_snakes[i].head_dirs)
				delete(playing.npc_snakes[i].debug_path)
				unordered_remove(&playing.npc_snakes, i)
				continue
			}

			npc_head := playing.npc_snakes[i].body[len(playing.npc_snakes[i].body) - 1]

			if ate {
				if !playing.gate_open {
					spawn_food(snake, food, tm^, playing)
					raylib.PlaySound(assets^.sounds.eat)
				} else {
					food^ = {-1, -1}
				}
			}

			if playing.gate_open && npc_head == tm.gate_pos {
				player_died(snake, food, playing, state, assets, tm)
				return
			}

			// NPC head hits player body → NPC dies
			npc_dies := false
			for seg in snake.body {
				if npc_head == seg {
					playing.score += 10
					delete(playing.npc_snakes[i].body)
					delete(playing.npc_snakes[i].head_dirs)
					delete(playing.npc_snakes[i].debug_path)
					unordered_remove(&playing.npc_snakes, i)
					npc_dies = true
					break
				}
			}
			if npc_dies do continue

			// Player head hits NPC body → player dies
			if !npcs_only {
				for seg in playing.npc_snakes[i].body {
					if player_head == seg {
						player_died(snake, food, playing, state, assets, tm)
						return
					}
				}
			}

			i += 1
		}
	}

	// NPC vs NPC collisions
	{
		dead := make(map[int]bool)
		defer delete(dead)

		for i in 0 ..< len(playing.npc_snakes) {
			head_i := playing.npc_snakes[i].body[len(playing.npc_snakes[i].body) - 1]
			for j in 0 ..< len(playing.npc_snakes) {
				if j == i do continue
				for k in 0 ..< len(playing.npc_snakes[j].body) {
					if head_i == playing.npc_snakes[j].body[k] {
						if k == len(playing.npc_snakes[j].body) - 1 {
							dead[i] = true
							dead[j] = true
						} else {
							dead[i] = true
						}
						break
					}
				}
				if dead[i] do break
			}
		}

		for i := len(playing.npc_snakes) - 1; i >= 0; i -= 1 {
			if dead[i] {
				delete(playing.npc_snakes[i].body)
				delete(playing.npc_snakes[i].head_dirs)
				delete(playing.npc_snakes[i].debug_path)
				unordered_remove(&playing.npc_snakes, i)
			}
		}
	}
}

player_died :: proc(
	snake: ^Snake,
	food: ^Food,
	playing: ^Playing,
	state: ^GameState,
	assets: ^Assets,
	tm: ^Tilemap,
) {
	raylib.PlaySound(assets^.sounds.game_over)
	playing.lives -= 1

	if playing.lives <= 0 {
		for npc in playing.npc_snakes {
			delete(npc.body)
			delete(npc.head_dirs)
			delete(npc.debug_path)
		}
		delete(playing.npc_snakes)
		delete(playing.foul_foods)
		delete(playing.splits_triggered)
		state^ = GameOver {
			final_score = playing.total_score + playing.score,
		}
		return
	}

	clear(&playing.foul_foods)
	playing.foul_apples = 0
	input_used = false

	clear(&snake.body)
	clear(&snake.head_dirs)
	s := tm.start_pos
	if !tm.has_start {
		s = Vec2{GRID_WIDTH / 2, GRID_HEIGHT / 2}
	}
	append(&snake.body, s)
	append(&snake.head_dirs, Direction.Right)
	snake.direction = .Right
	snake.next_direction = .Right
	if tm.has_start {
		tm.tiles[tm.start_pos.y][tm.start_pos.x] = .Start
	}
	playing.countdown = 4.0
	playing.spawning = 2
	food^ = {-1, -1}

	playing.gate_open = playing.score >= LEVELS[playing.current_level].gate_score
	if playing.gate_open {
		playing.gate_extra += 1
	}
	playing.gate_open =
		playing.score >= LEVELS[playing.current_level].gate_score + playing.gate_extra
}

advance_level :: proc(
	snake: ^Snake,
	food: ^Food,
	playing: ^Playing,
	state: ^GameState,
	assets: ^Assets,
	tm: ^Tilemap,
) {
	playing.current_level += 1

	if playing.current_level >= len(LEVELS) {
		for npc in playing.npc_snakes {
			delete(npc.body)
			delete(npc.head_dirs)
			delete(npc.debug_path)
		}
		delete(playing.npc_snakes)
		delete(playing.foul_foods)
		delete(playing.splits_triggered)
		state^ = GameOver {
			final_score = playing.total_score + playing.score,
		}
		return
	}

	playing.total_score += playing.score
	playing.total_score += playing.lives * 10

	unload_tilemap(tm)
	tm^ = load_tilemap(LEVELS[playing.current_level].file)

	s := tm.start_pos
	if !tm.has_start {
		s = Vec2{GRID_WIDTH / 2, GRID_HEIGHT / 2}
	}

	preserved_len := len(snake.body)
	clear(&snake.body)
	clear(&snake.head_dirs)
	append(&snake.body, s)
	append(&snake.head_dirs, Direction.Right)
	snake.direction = .Right
	snake.next_direction = .Right
	food^ = {-1, -1}

	for npc in playing.npc_snakes {
		delete(npc.body)
		delete(npc.head_dirs)
	}
	clear(&playing.npc_snakes)

	playing.score = 0
	clear(&playing.splits_triggered)
	playing.countdown = 4.0
	playing.spawning = max(0, preserved_len - 1)
	clear(&playing.foul_foods)
	playing.foul_apples = 0

	playing.gate_open = false
	playing.gate_extra = 0

	playing.lives = min(playing.lives + 1, 3)

	raylib.PlaySound(assets^.sounds.level_complete)
}

perform_split :: proc(snake: ^Snake, playing: ^Playing, split_score: int, assets: ^Assets) {
	playing.splits_triggered[split_score] = true
	playing.foul_apples += 1

	mid := len(snake.body) / 2
	if mid < 1 do return

	npc_body := make([dynamic]Vec2)
	npc_dirs := make([dynamic]Direction)
	for i in 0 ..< mid {
		append(&npc_body, snake.body[i])
		append(&npc_dirs, snake.head_dirs[i])
	}

	new_body := make([dynamic]Vec2)
	new_dirs := make([dynamic]Direction)
	for i in mid ..< len(snake.body) {
		append(&new_body, snake.body[i])
		append(&new_dirs, snake.head_dirs[i])
	}

	delete(snake.body)
	delete(snake.head_dirs)
	snake.body = new_body
	snake.head_dirs = new_dirs

	raylib.PlaySound(assets.sounds.split)

	npc := NpcSnake {
		body      = npc_body,
		head_dirs = npc_dirs,
		direction = npc_dirs[len(npc_dirs) - 1],
		stun      = 3,
	}
	append(&playing.npc_snakes, npc)
}

check_split :: proc(snake: ^Snake, playing: ^Playing, assets: ^Assets) {
	level := LEVELS[playing.current_level]
	for split_score in level.split_scores {
		if playing.score >= split_score && !playing.splits_triggered[split_score] {
			perform_split(snake, playing, split_score, assets)
			break
		}
	}
}

show_hint: bool

find_path :: proc(snake: ^Snake, playing: ^Playing, tm: ^Tilemap, food: Vec2) -> [dynamic]Vec2 {
	result: [dynamic]Vec2
	head := snake.body[len(snake.body) - 1]

	target: Vec2
	has_target := false
	if playing.gate_open && tm.has_gate {
		target = tm.gate_pos
		has_target = true
	} else if food.x >= 0 {
		target = food
		has_target = true
	}
	if !has_target {return result}

	m_dist :: proc(a, b: Vec2) -> int {
		dx := abs(a.x - b.x)
		dy := abs(a.y - b.y)
		return min(dx, GRID_WIDTH - dx) + min(dy, GRID_HEIGHT - dy)
	}

	dirs := [4]Vec2{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}

	blocked := make(map[Vec2]bool)
	defer delete(blocked)

	for x in 0 ..< GRID_WIDTH {
		for y in 0 ..< GRID_HEIGHT {
			pos := Vec2{x, y}
			if is_wall(tm^, pos) || (is_gate(tm^, pos) && !playing.gate_open) {
				blocked[pos] = true
			}
		}
	}
	for seg in snake.body {blocked[seg] = true}
	for npc in playing.npc_snakes {
		for seg in npc.body {blocked[seg] = true}
	}

	AStarNode :: struct {
		pos: Vec2,
		g:   int,
		f:   int,
	}
	open_set: [dynamic]AStarNode
	defer delete(open_set)
	closed_set := make(map[Vec2]bool)
	defer delete(closed_set)
	g_scores := make(map[Vec2]int)
	defer delete(g_scores)
	came_from := make(map[Vec2]Vec2)
	defer delete(came_from)

	h := m_dist(head, target)
	append(&open_set, AStarNode{head, 0, h})
	g_scores[head] = 0

	for len(open_set) > 0 {
		best_idx := 0
		for j in 1 ..< len(open_set) {
			if open_set[j].f < open_set[best_idx].f {best_idx = j}
		}
		current := open_set[best_idx]
		unordered_remove(&open_set, best_idx)

		if closed_set[current.pos] {continue}
		closed_set[current.pos] = true

		if current.pos == target {
			p := current.pos
			for p != head {
				append(&result, p)
				p = came_from[p]
			}
			for i in 0 ..< len(result) / 2 {
				j := len(result) - 1 - i
				result[i], result[j] = result[j], result[i]
			}
			return result
		}

		for d in dirs {
			np := current.pos + d
			if np.x < 0 {np.x += GRID_WIDTH}
			if np.x >= GRID_WIDTH {np.x -= GRID_WIDTH}
			if np.y < 0 {np.y += GRID_HEIGHT}
			if np.y >= GRID_HEIGHT {np.y -= GRID_HEIGHT}

			if is_puddle(tm^, np) {
				if tp, ok := teleport(tm^, np); ok {np = tp}
			}

			if closed_set[np] {continue}
			if blocked[np] {continue}

			tentative_g := current.g + 1
			if old_g, ok := g_scores[np]; ok && tentative_g >= old_g {continue}

			g_scores[np] = tentative_g
			came_from[np] = current.pos
			append(&open_set, AStarNode{np, tentative_g, tentative_g + m_dist(np, target)})
		}
	}

	return result
}

draw_hint :: proc(path: [dynamic]Vec2) {
	if len(path) > 1 {
		for pos in path[0:len(path) - 1] {
			cx := c.int(pos.x * CELL_SIZE + CELL_SIZE / 2)
			cy := c.int(pos.y * CELL_SIZE + CELL_SIZE / 2)
			raylib.DrawCircle(cx, cy, 6, raylib.Color{80, 140, 255, 140})
		}
    }
}

move_npc :: proc(
	npc: ^NpcSnake,
	food: Vec2,
	snake: ^Snake,
	playing: ^Playing,
	gate_open: bool,
	tm: Tilemap,
) -> (
	bool,
	bool,
) {
	if npc.stun > 0 {
		npc.stun -= 1
		return true, false
	}

	head := npc.body[len(npc.body) - 1]

	m_dist :: proc(a, b: Vec2) -> int {
		dx := abs(a.x - b.x)
		dy := abs(a.y - b.y)
		return min(dx, GRID_WIDTH - dx) + min(dy, GRID_HEIGHT - dy)
	}

	dirs := [4]Direction{.Up, .Down, .Left, .Right}
	dir_vecs := [4]Vec2{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}

	// Build obstacle set: all walls, closed gate, and all snake bodies
	blocked := make(map[Vec2]bool)
	defer delete(blocked)

	for x in 0 ..< GRID_WIDTH {
		for y in 0 ..< GRID_HEIGHT {
			pos := Vec2{x, y}
			if is_wall(tm, pos) || (is_gate(tm, pos) && !gate_open) {
				blocked[pos] = true
			}
		}
	}

	for seg in snake.body {
		blocked[seg] = true
	}

	for &other in playing.npc_snakes {
		for seg in other.body {
			blocked[seg] = true
		}
	}

	target: Vec2
	if gate_open {
		target = tm.gate_pos
	} else if len(playing.foul_foods) > 0 {
		best_ff := playing.foul_foods[0].pos
		best_d := m_dist(head, best_ff)
		for i := 1; i < len(playing.foul_foods); i += 1 {
			d := m_dist(head, playing.foul_foods[i].pos)
			if d < best_d {
				best_d = d
				best_ff = playing.foul_foods[i].pos
			}
		}
		if best_d < m_dist(head, food) {
			target = best_ff
		} else {
			target = food
		}
	} else {
		target = food
	}

	best_dir := npc.direction
	found_path := false

	{
		AStarNode :: struct {
			pos:       Vec2,
			first_dir: Direction,
			g:         int,
			f:         int,
		}

		open_set: [dynamic]AStarNode
		defer delete(open_set)

		closed_set := make(map[Vec2]bool)
		defer delete(closed_set)

		g_scores := make(map[Vec2]int)
		defer delete(g_scores)

		came_from := make(map[Vec2]Vec2)
		defer delete(came_from)

		h := m_dist(head, target)
		append(&open_set, AStarNode{head, {}, 0, h})
		g_scores[head] = 0

		for len(open_set) > 0 {
			best_idx := 0
			for j in 1 ..< len(open_set) {
				if open_set[j].f < open_set[best_idx].f {
					best_idx = j
				}
			}
			current := open_set[best_idx]
			unordered_remove(&open_set, best_idx)

			if closed_set[current.pos] {continue}
			closed_set[current.pos] = true

			if current.pos == target {
				clear(&npc.debug_path)
				p := current.pos
				for p != head {
					append(&npc.debug_path, p)
					p = came_from[p]
				}
				for i in 0 ..< len(npc.debug_path) / 2 {
					j := len(npc.debug_path) - 1 - i
					npc.debug_path[i], npc.debug_path[j] = npc.debug_path[j], npc.debug_path[i]
				}
				best_dir = current.first_dir
				found_path = true
				break
			}

			for d, idx in dirs {
				if current.pos == head {
					if d == .Up && npc.direction == .Down {continue}
					if d == .Down && npc.direction == .Up {continue}
					if d == .Left && npc.direction == .Right {continue}
					if d == .Right && npc.direction == .Left {continue}
				}

				np := current.pos + dir_vecs[idx]

				// Boundary wrapping
				if np.x < 0 {np.x += GRID_WIDTH}
				if np.x >= GRID_WIDTH {np.x -= GRID_WIDTH}
				if np.y < 0 {np.y += GRID_HEIGHT}
				if np.y >= GRID_HEIGHT {np.y -= GRID_HEIGHT}

				// Teleport via puddles
				if is_puddle(tm, np) {
					if tp, ok := teleport(tm, np); ok {
						np = tp
					}
				}

				if closed_set[np] {continue}
				if blocked[np] {continue}

				tentative_g := current.g + 1
				if old_g, ok := g_scores[np]; ok && tentative_g >= old_g {continue}

				g_scores[np] = tentative_g
				came_from[np] = current.pos
				first_dir := current.first_dir
				if current.pos == head {first_dir = d}
				append(
					&open_set,
					AStarNode{np, first_dir, tentative_g, tentative_g + m_dist(np, target)},
				)
			}
		}

		if !found_path {
			clear(&npc.debug_path)
		}
	}

	if !found_path {
		best_score := -999
		for dir in dirs {
			if dir == .Up && npc.direction == .Down {continue}
			if dir == .Down && npc.direction == .Up {continue}
			if dir == .Left && npc.direction == .Right {continue}
			if dir == .Right && npc.direction == .Left {continue}

			np := head
			switch dir {
			case .Up:
				np.y -= 1
			case .Down:
				np.y += 1
			case .Left:
				np.x -= 1
			case .Right:
				np.x += 1
			}

			if np.x < 0 {np.x += GRID_WIDTH}
			if np.x >= GRID_WIDTH {np.x -= GRID_WIDTH}
			if np.y < 0 {np.y += GRID_HEIGHT}
			if np.y >= GRID_HEIGHT {np.y -= GRID_HEIGHT}

			if is_puddle(tm, np) {
				if tp, ok := teleport(tm, np); ok {
					np = tp
				}
			}

			if blocked[np] {continue}

			score := 0
			if dir == npc.direction {score += 1}
			cur_player_dist := m_dist(head, snake.body[len(snake.body) - 1])
			new_player_dist := m_dist(np, snake.body[len(snake.body) - 1])
			if new_player_dist >
			   cur_player_dist {score += 1} else if new_player_dist < cur_player_dist {score -= 1}

			if score > best_score {
				best_score = score
				best_dir = dir
			}
		}

		if best_score == -999 {
			return false, false
		}
	}

	if best_dir == .Up && npc.direction == .Down {best_dir = npc.direction}
	if best_dir == .Down && npc.direction == .Up {best_dir = npc.direction}
	if best_dir == .Left && npc.direction == .Right {best_dir = npc.direction}
	if best_dir == .Right && npc.direction == .Left {best_dir = npc.direction}

	npc.direction = best_dir
	new_head := head
	switch npc.direction {
	case .Up:
		new_head.y -= 1
	case .Down:
		new_head.y += 1
	case .Left:
		new_head.x -= 1
	case .Right:
		new_head.x += 1
	}

	// Boundary wrapping
	if new_head.x < 0 {new_head.x += GRID_WIDTH}
	if new_head.x >= GRID_WIDTH {new_head.x -= GRID_WIDTH}
	if new_head.y < 0 {new_head.y += GRID_HEIGHT}
	if new_head.y >= GRID_HEIGHT {new_head.y -= GRID_HEIGHT}

	// Teleport via puddles
	if is_puddle(tm, new_head) {
		if tp, ok := teleport(tm, new_head); ok {
			new_head = tp
		}
	}

	ate := new_head == food
	for i in 0 ..< len(playing.foul_foods) {
		if new_head == playing.foul_foods[i].pos {
			unordered_remove(&playing.foul_foods, i)
			playing.score += 5
			return false, false
		}
	}

	npc.head_dirs[len(npc.head_dirs) - 1] = npc.direction
	append(&npc.body, new_head)
	append(&npc.head_dirs, npc.direction)
	if !ate {
		for i in 0 ..< len(npc.body) - 1 {
			npc.body[i] = npc.body[i + 1]
			npc.head_dirs[i] = npc.head_dirs[i + 1]
		}
		pop(&npc.body)
		pop(&npc.head_dirs)
	}

	return true, ate
}

draw_background :: proc(tm: Tilemap, assets: Assets, remaining: int) {
	draw_tilemap(tm, assets, remaining)
	draw_grid()
}

body_texture :: proc(s: Sprites, dir_in, dir_out: Vec2) -> raylib.Texture2D {
	R := Vec2{1, 0}
	L := Vec2{-1, 0}
	U := Vec2{0, -1}
	D := Vec2{0, 1}

	if dir_in == R && dir_out == U || dir_in == D && dir_out == L {return s.body_topleft}
	if dir_in == L && dir_out == U || dir_in == D && dir_out == R {return s.body_topright}
	if dir_in == R && dir_out == D || dir_in == U && dir_out == L {return s.body_bottomleft}
	if dir_in == L && dir_out == D || dir_in == U && dir_out == R {return s.body_bottomright}
	if dir_in.x != 0 {return s.body_horizontal}
	return s.body_vertical
}

dir_to_vec :: proc(d: Direction) -> Vec2 {
	switch d {
	case .Up:
		return {0, -1}
	case .Down:
		return {0, 1}
	case .Left:
		return {-1, 0}
	case .Right:
		return {1, 0}
	}
	return {}
}

draw_snake :: proc(snake: Snake, assets: Assets) {
	n := len(snake.body)
	if n == 0 do return

	draw_texture_at :: proc(tex: raylib.Texture2D, pos: Vec2) {
		raylib.DrawTexture(tex, c.int(pos.x * CELL_SIZE), c.int(pos.y * CELL_SIZE), raylib.WHITE)
	}

	head_idx := n - 1

	for i in 0 ..< n {
		pos := snake.body[i]

		if i == head_idx {
			draw_texture_at(assets.sprites.head[snake.direction], pos)
		} else if i == 0 {
			draw_texture_at(assets.sprites.tail[snake.head_dirs[0]], pos)
		} else {
			dir_in := dir_to_vec(snake.head_dirs[i - 1])
			dir_out := dir_to_vec(snake.head_dirs[i])
			tex := body_texture(assets.sprites, dir_in, dir_out)
			draw_texture_at(tex, pos)
		}
	}
}

draw_npc_snake :: proc(npc: NpcSnake, assets: Assets) {
	n := len(npc.body)
	if n == 0 do return

	tint := raylib.Color{255, 100, 100, 255}
	head_idx := n - 1

	t := f32(raylib.GetTime())
	t = t - f32(int(t / 1000)) * 1000

	pulse := f32(math.sin(f64(t) * 3.0) * 0.3 + 0.7)
	glow_alpha := u8(pulse * 60)
	glow_tint := raylib.Color{200, 60, 60, glow_alpha}
	glow_offset := c.int((GLOW_SIZE - CELL_SIZE) / 2)

	for i in 0 ..< n {
		pos := npc.body[i]
		gx := c.int(pos.x * CELL_SIZE) - glow_offset
		gy := c.int(pos.y * CELL_SIZE) - glow_offset
		raylib.DrawTexture(assets.sprites.glow, gx, gy, glow_tint)
	}

	raylib.SetShaderValue(assets.sprites.npc_glow_shader, assets.sprites.npc_glow_time_loc, &t, .FLOAT)
	raylib.BeginShaderMode(assets.sprites.npc_glow_shader)

	for i in 0 ..< n {
		pos := npc.body[i]
		if i == head_idx {
			raylib.DrawTexture(assets.sprites.head[npc.head_dirs[head_idx]], c.int(pos.x * CELL_SIZE), c.int(pos.y * CELL_SIZE), tint)
		} else if i == 0 {
			raylib.DrawTexture(assets.sprites.tail[npc.head_dirs[0]], c.int(pos.x * CELL_SIZE), c.int(pos.y * CELL_SIZE), tint)
		} else {
			dir_in := dir_to_vec(npc.head_dirs[i - 1])
			dir_out := dir_to_vec(npc.head_dirs[i])
			tex := body_texture(assets.sprites, dir_in, dir_out)
			raylib.DrawTexture(tex, c.int(pos.x * CELL_SIZE), c.int(pos.y * CELL_SIZE), tint)
		}
	}

	raylib.EndShaderMode()

	if len(npc.debug_path) > 2 {
		for pos in npc.debug_path[1:len(npc.debug_path) - 1] {
			cx := c.int(pos.x * CELL_SIZE + CELL_SIZE / 2)
			cy := c.int(pos.y * CELL_SIZE + CELL_SIZE / 2)
			raylib.DrawCircle(cx, cy, 6, raylib.Color{100, 255, 100, 180})
		}
	}
}

draw_food :: proc(food: Food, assets: Assets) {
	raylib.DrawTexture(
		assets.sprites.apple,
		c.int(food.x * CELL_SIZE),
		c.int(food.y * CELL_SIZE),
		raylib.WHITE,
	)
}

draw_foul_food :: proc(pos: Vec2, assets: Assets) {
	raylib.DrawTexture(
		assets.sprites.foul_apple,
		c.int(pos.x * CELL_SIZE),
		c.int(pos.y * CELL_SIZE),
		raylib.WHITE,
	)
}

draw_hud :: proc(playing: Playing) {
	level := LEVELS[playing.current_level]

	raylib.DrawRectangle(0, 0, SCREEN_WIDTH, HUD_HEIGHT, raylib.Color{42, 112, 20, 255})
	raylib.DrawLine(0, HUD_HEIGHT - 1, SCREEN_WIDTH, HUD_HEIGHT - 1, raylib.Color{30, 80, 14, 255})

	y: c.int = 20
	fs_big: c.int = 60
	fs_sml: c.int = 30

	// Score (left-aligned)
	x_l: c.int = 12
	score_txt := raylib.TextFormat("%d", playing.score)
	raylib.DrawText("Score", x_l, y + 10, fs_sml, raylib.Color{180, 230, 160, 255})
	x_l += raylib.MeasureText("Score", fs_sml) + 6
	raylib.DrawText(score_txt, x_l, y, fs_big, raylib.RAYWHITE)
	x_l += raylib.MeasureText(score_txt, fs_big) + 24

	// Lives + gate (right-aligned)
	sq := c.int(28)
	sp := sq + 6

	gate_total := level.gate_score + playing.gate_extra
	gate_w: c.int = 0
	if !playing.gate_open {
		gate_w = c.int(gate_total) * sp - 6
	}

	lives_w: c.int = c.int(playing.lives) * 32

	right := c.int(SCREEN_WIDTH) - 12

	if !playing.gate_open {
		right -= gate_w
		x_g := right

		for i in 0 ..< gate_total {
			sx := x_g + c.int(i) * sp
			sy := y + 10

			collected := playing.score > i

			is_split := false
			for s in level.split_scores {
				if s == i + 1 {
					is_split = true
					break
				}
			}

			color: raylib.Color
			if collected {
				color = raylib.Color{70, 70, 70, 255}
			} else if is_split {
				color = raylib.Color{255, 200, 40, 255}
			} else {
				color = raylib.Color{200, 230, 180, 255}
			}

			raylib.DrawRectangle(sx, sy, sq, sq, color)
			raylib.DrawRectangleLines(sx, sy, sq, sq, raylib.Color{30, 60, 30, 255})
		}
		right = x_g - 24
	} else {
		raylib.DrawText("GATE OPEN", x_l, y, fs_big, raylib.Color{255, 200, 0, 255})
		right -= 24
	}

	right -= lives_w
	x_lives := right
	for i in 0 ..< playing.lives {
		sx := x_lives + c.int(i) * 32
		raylib.DrawRectangle(sx, y + 10, 28, 28, raylib.RED)
		raylib.DrawRectangleLines(sx, y + 10, 28, 28, raylib.Color{160, 30, 30, 255})
	}

	// Foul indicator (separate line, bottom of HUD)
	if playing.foul_apples > 0 {
		foul_txt := raylib.TextFormat("[E] Foul x%d", playing.foul_apples)
		raylib.DrawText(foul_txt, 12, HUD_HEIGHT - 34, fs_sml, raylib.Color{180, 80, 220, 255})
	}
}

draw_score :: proc(score, total: int) {
	text := raylib.TextFormat("Level: %d  Total: %d", score, total)
	raylib.DrawText(text, c.int(CELL_SIZE / 2), c.int(CELL_SIZE / 2), CELL_SIZE, raylib.RAYWHITE)
}

draw_lives :: proc(lives: int) {
	for i in 0 ..< lives {
		raylib.DrawRectangle(
			c.int(SCREEN_WIDTH - CELL_SIZE * (lives - i)),
			c.int(CELL_SIZE / 2),
			CELL_SIZE - 4,
			CELL_SIZE - 4,
			raylib.RED,
		)
	}
}

draw_level_label :: proc(label: string) {
	cstr := strings.clone_to_cstring(label)
	defer delete(cstr)
	raylib.DrawText(
		cstr,
		c.int(SCREEN_WIDTH / 2 - CELL_SIZE * 3),
		c.int(SCREEN_HEIGHT - CELL_SIZE),
		CELL_SIZE,
		raylib.Color{200, 200, 200, 255},
	)
}

draw_countdown :: proc(timer: f32) {
	sec := int(timer) + 1
	if sec < 1 || sec > 4 {
		return
	}
	text: cstring
	switch sec {
	case 4:
		text = "3"
	case 3:
		text = "2"
	case 2:
		text = "1"
	case 1:
		text = "GO!"
	}
	fsize: c.int = CELL_SIZE * 4
	tw := raylib.MeasureText(text, fsize)
	raylib.DrawText(
		text,
		(SCREEN_WIDTH - tw) / 2,
		WINDOW_HEIGHT / 2 - fsize,
		fsize,
		raylib.Color{255, 255, 100, 255},
	)
}

draw_debug_overlay :: proc(frame_count: u64) {
	fps := raylib.GetFPS()
	x: c.int = 10
	y: c.int = WINDOW_HEIGHT - 40
	text := raylib.TextFormat("FPS: %d  Frame: %d", fps, frame_count)
	raylib.DrawText(text, x, y, 20, raylib.Color{255, 255, 255, 200})
}

draw_game_over :: proc(score: int) {
	text1 := raylib.TextFormat("GAME OVER!")
	text2 := raylib.TextFormat("Total Score: %d", score)
	text3 := raylib.TextFormat("Press SPACE to restart")

	fsize1: c.int = CELL_SIZE * 3
	fsize2: c.int = CELL_SIZE * 2
	fsize3: c.int = CELL_SIZE

	w1 := raylib.MeasureText(text1, fsize1)
	w2 := raylib.MeasureText(text2, fsize2)
	w3 := raylib.MeasureText(text3, fsize3)

	raylib.DrawText(
		text1,
		(SCREEN_WIDTH - w1) / 2,
		WINDOW_HEIGHT / 2 - 2 * fsize1,
		fsize1,
		raylib.RED,
	)
	raylib.DrawText(text2, (SCREEN_WIDTH - w2) / 2, WINDOW_HEIGHT / 2, fsize2, raylib.RAYWHITE)
	raylib.DrawText(
		text3,
		(SCREEN_WIDTH - w3) / 2,
		WINDOW_HEIGHT / 2 + fsize2 + fsize3,
		fsize3,
		raylib.GRAY,
	)
}
