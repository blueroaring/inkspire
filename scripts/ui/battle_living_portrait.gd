extends "res://scripts/ui/anya_living_portrait.gd"
const DEFORMATION := preload("res://scripts/ui/battle_living_portrait.gdshader")
static var profiles: Dictionary = {}
var portrait_texture: Texture2D
var profile_key := ""
var pixel_art := false

static func key_for(hero: String, attribute: String) -> String:
	if hero == "zhoumingyuan": return "zhou_math" if attribute == "math" else "zhou_wuji"
	return String({"chenmo":"chen", "xumingming":"xu", "suwanqing":"su", "liudanya":"liu", "wangjiaqi":"wang", "li_anya":"anya"}.get(hero, hero))

static func profile(key: String) -> Dictionary:
	if profiles.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_living_portraits.json"))
		if data is Array:
			for entry: Dictionary in data: profiles[entry.key] = entry
	return profiles.get(key, {})

func _ready() -> void:
	if portrait_texture != null: source_size = portrait_texture.get_size()
	phase_offset = float(posmod(hash(profile_key), 560)) / 100.0
	super()
	name = "BattleLivingPortrait"
	drawing.texture = portrait_texture
	rig.shader = DEFORMATION
	var data := profile(profile_key)
	var closed: Texture2D = portrait_texture
	if not pixel_art and not data.is_empty(): closed = load(String(data.blink))
	rig.set_shader_parameter("closed_eyes", closed)
	rig.set_shader_parameter("pixel_art", pixel_art)
	rig.set_shader_parameter("phase", phase_offset)
	if not data.is_empty():
		var eyes: Array = data.eyes
		var base := Vector2(data["size"][0], data["size"][1])
		var center := Vector2.ZERO
		for i in 2:
			var e: Array = eyes[i]
			var normalized := Vector4(e[0] / base.x, e[1] / base.y, e[2] / base.x, e[3] / base.y)
			rig.set_shader_parameter("eye_a" if i == 0 else "eye_b", normalized)
			center += Vector2(normalized.x, normalized.y) * 0.5
		rig.set_shader_parameter("head_center", center - Vector2(0, 0.05))
		rig.set_shader_parameter("neck", center + Vector2(0.025, 0.23))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixel_art else CanvasItem.TEXTURE_FILTER_LINEAR
	_process(0)
