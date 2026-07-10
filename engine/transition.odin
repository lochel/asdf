package engine

import rl "vendor:raylib"

Transition_Kind :: enum {
	Fade,
	Slide_Left,
	Slide_Right,
	None,
}

Transition :: struct {
	active:   bool,
	timer:    f32,
	duration: f32,
	kind:     Transition_Kind,
}

update_transition :: proc(e: ^Engine_Context, dt: f32) {
	if !e.trans.active {return}
	e.trans.timer += dt
	if e.trans.timer >= e.trans.duration {
		e.trans.active = false
		e.current = e.next
		e.current.step_acc = 0
		e.current.step_count = 0
		e.next = nil
		if e.current != nil && e.current.enter != nil {
			e.current.enter(e.current)
		}
	}
}

render_transition :: proc(e: ^Engine_Context, dst: rl.Rectangle) {
	log_w := f32(e.config.width)
	log_h := f32(e.config.height)
	src := rl.Rectangle{0, 0, log_w, -log_h}
	progress := min(e.trans.timer / e.trans.duration, 1.0)

	switch e.trans.kind {
	case .Slide_Right:
		if e.current != nil {
			dst := rl.Rectangle{dst.x - progress * dst.width, dst.y, dst.width, dst.height}
			rl.DrawTexturePro(e.current.target.texture, src, dst, {}, 0, rl.WHITE)
		}
		if e.next != nil {
			dst := rl.Rectangle{(1.0 - progress) * dst.width + dst.x, dst.y, dst.width, dst.height}
			rl.DrawTexturePro(e.next.target.texture, src, dst, {}, 0, rl.WHITE)
		}

	case .Slide_Left:
		if e.current != nil {
			dst := rl.Rectangle{dst.x + progress * dst.width, dst.y, dst.width, dst.height}
			rl.DrawTexturePro(e.current.target.texture, src, dst, {}, 0, rl.WHITE)
		}
		if e.next != nil {
			dst := rl.Rectangle {
				-(1.0 - progress) * dst.width + dst.x,
				dst.y,
				dst.width,
				dst.height,
			}
			rl.DrawTexturePro(e.next.target.texture, src, dst, {}, 0, rl.WHITE)
		}

	case .Fade:
		if e.current != nil {
			rl.DrawTexturePro(e.current.target.texture, src, dst, {}, 0, rl.WHITE)
		}
		if e.next != nil {
			rl.DrawTexturePro(e.next.target.texture, src, dst, {}, 0, rl.Fade(rl.WHITE, progress))
		}

	case .None:
		if e.current != nil {
			rl.DrawTexturePro(e.current.target.texture, src, dst, {}, 0, rl.WHITE)
		}
	}
}
