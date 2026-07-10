package engine

import rl "vendor:raylib"

Scene_Context :: struct {
	eng:        ^Engine_Context,
	target:     rl.RenderTexture2D,
	fixed_step: f32,
	update_acc: f32,
	init:       proc(ctx: ^Scene_Context),
	deinit:     proc(ctx: ^Scene_Context),
	enter:      proc(ctx: ^Scene_Context),
	leave:      proc(ctx: ^Scene_Context),
	input:      proc(ctx: ^Scene_Context, dt: f32),
	update:     proc(ctx: ^Scene_Context, dt: f32),
	render:     proc(ctx: ^Scene_Context),
}

addScene :: proc(e: ^Engine_Context, name: string, scene: ^Scene_Context) {
	scene.eng = e
	e.scenes[name] = scene
}

getScene :: proc(e: ^Engine_Context, name: string) -> ^Scene_Context {
	return e.scenes[name]
}

switch_scene :: proc(
	e: ^Engine_Context,
	scene: ^Scene_Context,
	kind: Transition_Kind = .Fade,
	duration: f32 = 0.5,
) {
	if e.trans.active {return}
	if e.current != nil && e.current.leave != nil {
		e.current.leave(e.current)
	}
	e.next = scene
	e.trans.active = true
	e.trans.timer = 0
	e.trans.duration = duration
	e.trans.kind = kind
	if scene != nil && scene.enter != nil {
		scene.enter(scene)
	}
}
