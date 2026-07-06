package main

import "vendor:raylib"

Sprites :: struct {
	apple:            raylib.Texture2D,
	foul_apple:       raylib.Texture2D,
	head:             [Direction]raylib.Texture2D,
	tail:             [Direction]raylib.Texture2D,
	body_horizontal:  raylib.Texture2D,
	body_vertical:    raylib.Texture2D,
	body_topleft:     raylib.Texture2D,
	body_topright:    raylib.Texture2D,
	body_bottomleft:  raylib.Texture2D,
	body_bottomright: raylib.Texture2D,
	grass:            raylib.Texture2D,
	wall:             raylib.Texture2D,
	puddle:           raylib.Texture2D,
}

Sounds :: struct {
    game_over: raylib.Sound,
	eat: raylib.Sound,
	split: raylib.Sound,
	gate_open: raylib.Sound,
	level_complete: raylib.Sound,
}

Assets :: struct {
    sprites: Sprites,
    sounds: Sounds
}


load_assets :: proc() -> Assets {
    assets := Assets{}
    assets.sprites = load_sprites()
    assets.sounds = load_sounds()
    return assets
}

unload_assets :: proc(assets: Assets) {
    unload_sprites(assets.sprites)
    unload_sounds(assets.sounds)
}

load_sounds :: proc() -> Sounds {
    sounds := Sounds{}
	sounds.game_over = raylib.LoadSound("assets/sounds/mixkit-arcade-retro-game-over-213.wav")
	sounds.eat = raylib.LoadSound("assets/sounds/mixkit-retro-game-notification-212.wav")
	sounds.split = raylib.LoadSound("assets/sounds/mixkit-robot-system-fail-2960.wav")
	sounds.gate_open = raylib.LoadSound("assets/sounds/mixkit-arcade-bonus-alert-767.wav")
	sounds.level_complete = raylib.LoadSound("assets/sounds/mixkit-arcade-game-complete-or-approved-mission-205.wav")
    return sounds
}

unload_sounds :: proc(sounds: Sounds) {
	raylib.UnloadSound(sounds.game_over)
	raylib.UnloadSound(sounds.eat)
	raylib.UnloadSound(sounds.split)
	raylib.UnloadSound(sounds.gate_open)
	raylib.UnloadSound(sounds.level_complete)
}

load_sprites :: proc() -> Sprites {
	load_tex :: proc(path: cstring) -> raylib.Texture2D {
		img := raylib.LoadImage(path)
		defer raylib.UnloadImage(img)
		raylib.ImageResizeNN(&img, CELL_SIZE, CELL_SIZE)
		tex := raylib.LoadTextureFromImage(img)
		raylib.SetTextureFilter(tex, .POINT)
		return tex
	}

	load_tinted_tex :: proc(path: cstring, tint: raylib.Color) -> raylib.Texture2D {
		img := raylib.LoadImage(path)
		defer raylib.UnloadImage(img)
		raylib.ImageResizeNN(&img, CELL_SIZE, CELL_SIZE)
		raylib.ImageColorTint(&img, tint)
		tex := raylib.LoadTextureFromImage(img)
		raylib.SetTextureFilter(tex, .POINT)
		return tex
	}

	s := Sprites{}
	s.apple = load_tex("assets/graphics/apple.png")
	s.foul_apple = load_tinted_tex("assets/graphics/apple.png", {110, 50, 15, 255})

	s.head[.Up] = load_tex("assets/graphics/head_up.png")
	s.head[.Down] = load_tex("assets/graphics/head_down.png")
	s.head[.Left] = load_tex("assets/graphics/head_left.png")
	s.head[.Right] = load_tex("assets/graphics/head_right.png")

	s.tail[.Down] = load_tex("assets/graphics/tail_up.png")
	s.tail[.Up] = load_tex("assets/graphics/tail_down.png")
	s.tail[.Right] = load_tex("assets/graphics/tail_left.png")
	s.tail[.Left] = load_tex("assets/graphics/tail_right.png")

	s.body_horizontal = load_tex("assets/graphics/body_horizontal.png")
	s.body_vertical = load_tex("assets/graphics/body_vertical.png")
	s.body_topleft = load_tex("assets/graphics/body_topleft.png")
	s.body_topright = load_tex("assets/graphics/body_topright.png")
	s.body_bottomleft = load_tex("assets/graphics/body_bottomleft.png")
	s.body_bottomright = load_tex("assets/graphics/body_bottomright.png")

	color_tex :: proc(color: raylib.Color) -> raylib.Texture2D {
		img := raylib.GenImageColor(CELL_SIZE, CELL_SIZE, color)
		defer raylib.UnloadImage(img)
		tex := raylib.LoadTextureFromImage(img)
		raylib.SetTextureFilter(tex, .POINT)
		return tex
	}

	s.grass = color_tex({46, 90, 30, 255})
	s.wall = color_tex({80, 70, 60, 255})
	s.puddle = color_tex({30, 100, 180, 200})

	return s
}

unload_sprites :: proc(s: Sprites) {
	raylib.UnloadTexture(s.apple)
	raylib.UnloadTexture(s.foul_apple)
	for d in Direction {
		raylib.UnloadTexture(s.head[d])
		raylib.UnloadTexture(s.tail[d])
	}
	raylib.UnloadTexture(s.body_horizontal)
	raylib.UnloadTexture(s.body_vertical)
	raylib.UnloadTexture(s.body_topleft)
	raylib.UnloadTexture(s.body_topright)
	raylib.UnloadTexture(s.body_bottomleft)
	raylib.UnloadTexture(s.body_bottomright)
	raylib.UnloadTexture(s.grass)
	raylib.UnloadTexture(s.wall)
	raylib.UnloadTexture(s.puddle)
}

