package main

import "core:c"
import "vendor:raylib"

GAMEPAD_DEADZONE :: 0.5

@(private)
prev_axis_up, prev_axis_down, prev_axis_left, prev_axis_right: bool
@(private)
input_used: bool

gp_button_pressed :: proc(btn: raylib.GamepadButton, gamepad: c.int = 0) -> bool {
	return raylib.IsGamepadAvailable(gamepad) && raylib.IsGamepadButtonPressed(gamepad, btn)
}

controller_confirm :: proc() -> bool {
	if gp_button_pressed(.RIGHT_FACE_DOWN, 0) {return true}
	if joy_button_pressed(0) {return true}
	return false
}

apply_dir :: proc(snake: ^Snake, dir: Direction) {
	switch dir {
	case .Up:    if snake.direction != .Down { snake.next_direction = dir }
	case .Down:  if snake.direction != .Up   { snake.next_direction = dir }
	case .Left:  if snake.direction != .Right { snake.next_direction = dir }
	case .Right: if snake.direction != .Left  { snake.next_direction = dir }
	}
}

handle_input :: proc(snake: ^Snake) {
	if input_used do return

	last: Maybe(Direction)

	if raylib.IsKeyPressed(.UP) || raylib.IsKeyPressed(.W) {
		last = .Up
	}
	if raylib.IsKeyPressed(.DOWN) || raylib.IsKeyPressed(.S) {
		last = .Down
	}
	if raylib.IsKeyPressed(.LEFT) || raylib.IsKeyPressed(.A) {
		last = .Left
	}
	if raylib.IsKeyPressed(.RIGHT) || raylib.IsKeyPressed(.D) {
		last = .Right
	}

	if raylib.IsGamepadAvailable(0) {
		if raylib.IsGamepadButtonPressed(0, .LEFT_FACE_UP) {
			last = .Up
		}
		if raylib.IsGamepadButtonPressed(0, .LEFT_FACE_DOWN) {
			last = .Down
		}
		if raylib.IsGamepadButtonPressed(0, .LEFT_FACE_LEFT) {
			last = .Left
		}
		if raylib.IsGamepadButtonPressed(0, .LEFT_FACE_RIGHT) {
			last = .Right
		}

		axis_up := raylib.GetGamepadAxisMovement(0, .LEFT_Y) < -GAMEPAD_DEADZONE
		axis_down := raylib.GetGamepadAxisMovement(0, .LEFT_Y) > GAMEPAD_DEADZONE
		axis_left := raylib.GetGamepadAxisMovement(0, .LEFT_X) < -GAMEPAD_DEADZONE
		axis_right := raylib.GetGamepadAxisMovement(0, .LEFT_X) > GAMEPAD_DEADZONE

		if axis_up && !prev_axis_up { last = .Up }
		if axis_down && !prev_axis_down { last = .Down }
		if axis_left && !prev_axis_left { last = .Left }
		if axis_right && !prev_axis_right { last = .Right }

		prev_axis_up = axis_up
		prev_axis_down = axis_down
		prev_axis_left = axis_left
		prev_axis_right = axis_right
	}

	when ODIN_OS != .Windows {
		if joy_fd >= 0 {
			JZ :: 16384
			jup := joy_axis[1] < -JZ || joy_axis[7] < -JZ
			jdown := joy_axis[1] > JZ || joy_axis[7] > JZ
			jleft := joy_axis[0] < -JZ || joy_axis[6] < -JZ
			jright := joy_axis[0] > JZ || joy_axis[6] > JZ

			if jup && !prev_joy_up { last = .Up }
			if jdown && !prev_joy_down { last = .Down }
			if jleft && !prev_joy_left { last = .Left }
			if jright && !prev_joy_right { last = .Right }

			prev_joy_up = jup
			prev_joy_down = jdown
			prev_joy_left = jleft
			prev_joy_right = jright
		}
	}

	if last != nil {
		apply_dir(snake, last.?)
		input_used = true
	}
}
