extends RefCounted
## Authored sheets are processed with one fixed scale per species.
const ROOT := "res://assets/graphics/battle/enemy_motion/"
const PROFILES := {
	"terminal_echo": {"idle_fps":3.0, "height_ratio":0.97},
	"whisper_silhouette": {"idle_fps":1.3, "idle_frames":[0, 5], "height_ratio":0.82},
	"terminal_choir": {"idle_fps":1.2, "idle_frames":[0, 5], "height_ratio":0.84},
	"false_dawn": {"idle_fps":1.2, "idle_frames":[0, 5], "height_ratio":0.85},
	"paper_large": {"idle_fps":1.2, "idle_frames":[0, 5], "idle_offsets_x":[0, 1], "height_ratio":0.86},
	"paper_small": {"idle_fps":1.6, "idle_frames":[0, 5], "idle_offsets_x":[0, -1], "height_ratio":0.64},
	"noise": {"idle_fps":1.0, "idle_frames":[0, 5], "idle_offsets_x":[0, 5], "height_ratio":0.86},
	"cupid": {"idle_fps":4.0, "height_ratio":0.88},
	"zeus_dean": {"idle_fps":3.4, "height_ratio":0.90},
	"biting_book": {"idle_fps":4.0, "height_ratio":0.82},
	"nightmare": {"idle_fps":3.0, "height_ratio":0.90},
	"panic_throat": {"idle_fps":3.0, "height_ratio":0.94},
	"snicker_shadow": {"idle_fps":1.3, "idle_frames":[0, 5], "height_ratio":0.78},
	"math_exam": {"idle_fps":3.0, "height_ratio":0.90},
	"perfect_score": {"idle_fps":3.0, "height_ratio":0.86},
	"inverse_limit": {"idle_fps":3.0, "height_ratio":0.94},
}
static var _cache: Dictionary = {}

static func get_motion(enemy_id: String) -> Dictionary:
	var key := String({"ink_wolf":"paper_large", "ink_wolf_echo":"paper_small"}.get(enemy_id, enemy_id))
	if not PROFILES.has(key): return {}
	if _cache.has(key): return _cache[key]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var anchors := {}
	var body_bounds := {}
	var reference_size := Vector2.ONE
	for action: String in ["idle", "attack", "cast"]:
		if action == "cast" and key == "noise": continue
		var source_action := "idle" if key in ["snicker_shadow", "whisper_silhouette", "terminal_choir", "false_dawn"] else action
		var sheet := load(ROOT + key + "/" + source_action + "/sheet.webp") as Texture2D
		if sheet == null: return {}
		var pixels := sheet.get_image()
		frames.add_animation(action)
		frames.set_animation_loop(action, action == "idle")
		frames.set_animation_speed(action, float(PROFILES[key].idle_fps) if action == "idle" else 10.0)
		anchors[action] = []
		body_bounds[action] = []
		# Only the two near-neutral poses belong in idle. Raised claws, head turns
		# and the open-mouth pose were making an inactive enemy look mid-attack.
		var legacy := key in ["paper_large", "paper_small", "noise"]
		var order: Array = [int(PROFILES[key].get("idle_frames", [0])[0])] if action == "idle" else range(9 if action == "attack" and legacy else 6)
		for index in order.size():
			var source_index := int(order[index])
			var region := Rect2i((source_index % 3) * 512, (source_index / 3) * 512, 512, 512)
			var bounds := pixels.get_region(region).get_used_rect()
			var texture := AtlasTexture.new()
			texture.atlas = sheet
			texture.region = region
			texture.filter_clip = true
			frames.add_frame(action, texture)
			# Translation only: steady contact plane, freely changing limbs and torso.
			var offsets: Array = PROFILES[key].get("idle_offsets_x", [])
			var idle_offset := float(offsets[index]) if action == "idle" and index < offsets.size() else 0.0
			anchors[action].append(Vector2(256 - idle_offset, bounds.end.y))
			body_bounds[action].append(Rect2(bounds))
			if action == "idle" and index == 0: reference_size = bounds.size
	_cache[key] = {"frames":frames, "anchors":anchors, "bounds":body_bounds, "reference_size":reference_size, "height_ratio":PROFILES[key].height_ratio}
	return _cache[key]
