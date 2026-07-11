package main

import "core:os"
import "core:strings"
import "engine"

LEVELS: []LevelDef

snake_global: Snake
assets_global: Assets
move_delay: f32 = 0.2

SCREEN_WIDTH: i32 = i32(CELL_SIZE * GRID_WIDTH)
SCREEN_HEIGHT: i32 = i32(CELL_SIZE * GRID_HEIGHT) + HUD_HEIGHT

init_level_files :: proc() -> []string {
	entries, err := os.read_all_directory_by_path("assets/levels", context.allocator)
	if err != nil {
		panic("Failed to read assets/levels directory")
	}
	defer delete(entries)

	files: [dynamic]string
	defer delete(files)

	for entry in entries {
		if entry.type != .Regular {continue}
		if !strings.has_suffix(entry.name, ".txt") {continue}
		append(&files, entry.fullpath)
	}

	for i := 1; i < len(files); i += 1 {
		key := files[i]
		j := i - 1
		for j >= 0 && strings.compare(files[j], key) > 0 {
			files[j + 1] = files[j]
			j -= 1
		}
		files[j + 1] = key
	}

	result := make([]string, len(files))
	for f, i in files {
		result[i] = f
	}
	return result
}

resize_for_tilemap :: proc(tm: Tilemap, eng: ^engine.Engine_Context) {
	SCREEN_WIDTH = i32(tm.width * CELL_SIZE)
	SCREEN_HEIGHT = i32(tm.height * CELL_SIZE) + HUD_HEIGHT
	engine.resize(eng, SCREEN_WIDTH, SCREEN_HEIGHT)
}
