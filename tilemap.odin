package main

import "core:encoding/json"
import "core:os"
import "core:strings"
import "core:c"
import "vendor:raylib"

load_level_meta :: proc(path: string) -> LevelDef {
	data, err := os.read_entire_file_from_path(path, context.allocator)
	if err != nil {
		panic("Failed to load level metadata")
	}
	defer delete(data)

	content := string(data)
	lines := strings.split_lines(content)
	defer delete(lines)

	json_parts: [dynamic]string
	defer delete(json_parts)

	for line in lines {
		trimmed := strings.trim_space(line)
		if trimmed == "" {
			if len(json_parts) > 0 {
				break
			}
			continue
		}
		if trimmed[0] == '{' || trimmed[0] == '}' || strings.contains(trimmed, ":") {
			append(&json_parts, trimmed)
		} else {
			break
		}
	}

	json_str := strings.join(json_parts[:], "")
	defer delete(json_str)

	header: LevelHeader
	parse_err := json.unmarshal(transmute([]byte)json_str, &header)
	if parse_err != nil {
		panic("Failed to parse level JSON header")
	}

	return LevelDef{
		file = path,
		label = header.label,
		gate_score = header.gate_score,
		split_scores = header.split_scores,
	}
}

load_tilemap :: proc(path: string) -> Tilemap {
	data, err := os.read_entire_file_from_path(path, context.allocator)
	if err != nil {
		panic("Failed to load tilemap")
	}
	defer delete(data)

	content := string(data)
	lines := strings.split_lines(content)
	defer delete(lines)

	map_start := 0
	for map_start < len(lines) {
		line := strings.trim_right(lines[map_start], "\r\n")
		stripped := strings.trim_space(line)
		if stripped == "" || stripped[0] == '{' || stripped[0] == '}' || stripped[0] == '"' {
			map_start += 1
		} else {
			break
		}
	}

	line_buf: [20]string
	line_count := 0
	width := 0
	for i in map_start ..< len(lines) {
		line := strings.trim_right(lines[i], "\r\n")
		if len(line) == 0 do continue
		line_buf[line_count] = line
		if len(line) > width {
			width = len(line)
		}
		line_count += 1
	}
	height := line_count

	tiles := make([][]TileType, height)
	for y in 0 ..< height {
		tiles[y] = make([]TileType, width)
	}

	positions: [10][dynamic]Vec2
	defer {
		for i in 0 ..< 10 {
			delete(positions[i])
		}
	}

	gate_pos: Vec2
	has_gate := false
	start_pos: Vec2
	has_start := false

	for y in 0 ..< height {
		line := line_buf[y]
		for x in 0 ..< min(len(line), width) {
			ch := line[x]
			if ch == '#' {
				tiles[y][x] = .Gate
				gate_pos = Vec2{x, y}
				has_gate = true
			} else if ch == 'S' {
				tiles[y][x] = .Start
				start_pos = Vec2{x, y}
				has_start = true
			} else if ch >= '0' && ch <= '9' {
				tiles[y][x] = .Puddle
				append(&positions[ch - '0'], Vec2{x, y})
			} else {
				switch ch {
				case 'x':
					tiles[y][x] = .Wall
				case '.':
					tiles[y][x] = .Grass
				}
			}
		}
	}

	pairs: [dynamic]PuddlePair

	for i in 0 ..< 10 {
		count := len(positions[i])
		if count == 0 do continue
		if count % 2 != 0 {
			panic("Invalid map: a puddle digit appears an odd number of times")
		}
		for j := 0; j < count; j += 2 {
			append(&pairs, PuddlePair{positions[i][j], positions[i][j + 1]})
		}
	}

	return Tilemap{tiles, width, height, pairs, gate_pos, has_gate, start_pos, has_start}
}

unload_tilemap :: proc(tm: ^Tilemap) {
	for y in 0 ..< tm.height {
		delete(tm.tiles[y])
	}
	delete(tm.tiles)
	delete(tm.pairs)
}

is_wall :: proc(tm: Tilemap, pos: Vec2) -> bool {
	if pos.x < 0 || pos.x >= tm.width || pos.y < 0 || pos.y >= tm.height {
		return true
	}
	return tm.tiles[pos.y][pos.x] == .Wall
}

is_gate :: proc(tm: Tilemap, pos: Vec2) -> bool {
	if pos.x < 0 || pos.x >= tm.width || pos.y < 0 || pos.y >= tm.height {
		return false
	}
	return tm.tiles[pos.y][pos.x] == .Gate
}

is_puddle :: proc(tm: Tilemap, pos: Vec2) -> bool {
	if pos.x < 0 || pos.x >= tm.width || pos.y < 0 || pos.y >= tm.height {
		return false
	}
	return tm.tiles[pos.y][pos.x] == .Puddle
}

teleport :: proc(tm: Tilemap, pos: Vec2) -> (Vec2, bool) {
	for pair in tm.pairs {
		if pair.a == pos do return pair.b, true
		if pair.b == pos do return pair.a, true
	}
	return pos, false
}

is_start :: proc(tm: Tilemap, pos: Vec2) -> bool {
	if pos.x < 0 || pos.x >= tm.width || pos.y < 0 || pos.y >= tm.height {
		return false
	}
	return tm.tiles[pos.y][pos.x] == .Start
}

is_grass :: proc(tm: Tilemap, pos: Vec2) -> bool {
	if pos.x < 0 || pos.x >= tm.width || pos.y < 0 || pos.y >= tm.height {
		return false
	}
	return tm.tiles[pos.y][pos.x] == .Grass
}

puddle_tint :: proc(pair_idx: int) -> raylib.Color {
	palette := []raylib.Color{
		{100, 180, 255, 255},
		{255, 120, 120, 255},
		{120, 255, 120, 255},
		{255, 255, 100, 255},
		{200, 140, 255, 255},
		{100, 255, 255, 255},
		{255, 180, 80, 255},
		{255, 160, 200, 255},
		{180, 255, 100, 255},
		{200, 200, 200, 255},
	}
	return palette[pair_idx % len(palette)]
}

draw_tilemap :: proc(tm: Tilemap, assets: Assets, remaining: int) {
	for y in 0 ..< tm.height {
		for x in 0 ..< tm.width {
			pos := Vec2{x, y}
			switch tm.tiles[y][x] {
			case .Grass:
				raylib.DrawTexture(assets.sprites.grass, c.int(x * CELL_SIZE), c.int(y * CELL_SIZE), raylib.WHITE)
			case .Wall:
				raylib.DrawTexture(assets.sprites.wall, c.int(x * CELL_SIZE), c.int(y * CELL_SIZE), raylib.WHITE)
			case .Puddle:
				tint := raylib.WHITE
				for pair, idx in tm.pairs {
					if pair.a == pos || pair.b == pos {
						tint = puddle_tint(idx)
						break
					}
				}
				raylib.DrawTexture(assets.sprites.puddle, c.int(x * CELL_SIZE), c.int(y * CELL_SIZE), tint)
			case .Gate:
				if remaining <= 0 {
					raylib.DrawRectangle(c.int(x*CELL_SIZE), c.int(y*CELL_SIZE), CELL_SIZE, CELL_SIZE, raylib.Color{60, 180, 60, 255})
					raylib.DrawRectangleLines(c.int(x*CELL_SIZE), c.int(y*CELL_SIZE), CELL_SIZE, CELL_SIZE, raylib.Color{120, 255, 120, 255})
				} else {
					raylib.DrawRectangle(c.int(x*CELL_SIZE), c.int(y*CELL_SIZE), CELL_SIZE, CELL_SIZE, raylib.Color{120, 40, 40, 255})
					raylib.DrawRectangleLines(c.int(x*CELL_SIZE), c.int(y*CELL_SIZE), CELL_SIZE, CELL_SIZE, raylib.Color{60, 20, 20, 255})
					text := raylib.TextFormat("%d", remaining)
					fsize: c.int = CELL_SIZE - 8
					tw := raylib.MeasureText(text, fsize)
					dx := (CELL_SIZE - int(tw)) / 2
					dy := (CELL_SIZE - int(fsize)) / 2
					raylib.DrawText(text, c.int(x*CELL_SIZE + dx), c.int(y*CELL_SIZE + dy), fsize, raylib.WHITE)
				}
			case .Start:
				raylib.DrawRectangle(c.int(x*CELL_SIZE), c.int(y*CELL_SIZE), CELL_SIZE, CELL_SIZE, raylib.Color{180, 180, 60, 255})
				raylib.DrawRectangleLines(c.int(x*CELL_SIZE), c.int(y*CELL_SIZE), CELL_SIZE, CELL_SIZE, raylib.Color{255, 255, 120, 255})
			}
		}
	}
}
