package engine

import "core:encoding/json"
import "core:os"

Config :: struct {
	width:      i32,
	height:     i32,
	fullscreen: bool,
	resizable:  bool,
	target_fps: i32,
}

load_config :: proc() -> (Config, bool) {
	data, err := os.read_entire_file("data/config.json", context.allocator)
	if err != nil {
		return Config{}, false
	}
	defer delete(data)

	cfg: Config
	json.unmarshal(data, &cfg)
	return cfg, true
}

save_config :: proc(cfg: Config) {
	data, err := json.marshal(cfg)
	if err != nil {
		return
	}
	defer delete(data)
	os.make_directory("data")
	_ = os.write_entire_file("data/config.json", data)
}
