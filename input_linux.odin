package main

import "core:sys/posix"
import "core:strings"

@(private)
joy_fd: posix.FD = -1

@(private)
joy_axis: [8]i16

@(private)
joy_buttons: u32

@(private)
prev_joy_buttons: u32

@(private)
prev_joy_up, prev_joy_down, prev_joy_left, prev_joy_right: bool

JS_EVENT_AXIS :: 2
JS_EVENT_BUTTON :: 1
JS_EVENT_INIT :: 0x80

JsEvent :: struct #packed {
	time:   u32,
	value:  i16,
	_type:  u8,
	number: u8,
}

open_joystick :: proc() {
	if int(joy_fd) >= 0 {return}
	devs := [4]string{"/dev/input/js0", "/dev/input/js1", "/dev/input/js2", "/dev/input/js3"}
	for i in 0 ..< len(devs) {
		cpath := strings.clone_to_cstring(devs[i])
		fd := posix.open(cpath, posix.O_Flags{.NONBLOCK})
		delete(cpath)
		if int(fd) >= 0 {
			joy_fd = fd
			return
		}
	}
}

close_joystick :: proc() {
	if int(joy_fd) >= 0 {
		posix.close(joy_fd)
		joy_fd = -1
	}
}

read_joystick :: proc() {
	if int(joy_fd) < 0 {
		open_joystick()
		if int(joy_fd) < 0 {return}
	}
	for {
		ev: JsEvent
		n := posix.read(joy_fd, ([^]byte)(&ev), size_of(JsEvent))
		if n < size_of(JsEvent) {break}
		if ev._type & JS_EVENT_INIT != 0 {continue}

		switch ev._type {
		case JS_EVENT_AXIS:
			if int(ev.number) < len(joy_axis) {
				joy_axis[ev.number] = ev.value
			}
		case JS_EVENT_BUTTON:
			if int(ev.number) < 32 {
				mask := u32(1) << uint(ev.number)
				if ev.value != 0 {
					joy_buttons |= mask
				} else {
					joy_buttons &~= mask
				}
			}
		}
	}
}

joy_button_pressed :: proc(btn: int) -> bool {
	if joy_fd < 0 || btn < 0 || btn >= 32 {return false}
	mask := u32(1) << uint(btn)
	return (joy_buttons & mask) != 0 && (prev_joy_buttons & mask) == 0
}

save_joy_button_state :: proc() {
	prev_joy_buttons = joy_buttons
}
