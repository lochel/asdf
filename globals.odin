package main

import "engine"

LEVEL_FILES := []string {
	"assets/levels/map1.txt",
	"assets/levels/map2.txt",
	"assets/levels/map3.txt",
	"assets/levels/map4.txt",
	"assets/levels/map5.txt",
}

LEVELS: []LevelDef

snake_global: Snake
assets_global: Assets
move_delay: f32 = 0.2

SCREEN_WIDTH: i32 = i32(CELL_SIZE * GRID_WIDTH)
SCREEN_HEIGHT: i32 = i32(CELL_SIZE * GRID_HEIGHT) + HUD_HEIGHT

resize_for_tilemap :: proc(tm: Tilemap, eng: ^engine.Engine_Context) {
	SCREEN_WIDTH = i32(tm.width * CELL_SIZE)
	SCREEN_HEIGHT = i32(tm.height * CELL_SIZE) + HUD_HEIGHT
	engine.resize(eng, SCREEN_WIDTH, SCREEN_HEIGHT)
}
