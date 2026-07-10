package main

open_joystick :: proc() {}
close_joystick :: proc() {}
read_joystick :: proc() {}
joy_button_pressed :: proc(btn: int) -> bool { return false }
save_joy_button_state :: proc() {}
