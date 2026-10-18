extends RefCounted
## Cosmetic preference only; independent of story portraits, saves and battle rules.
const PIXEL_ROOT := "res://assets/graphics/battle/pixel_portraits/"
const IDS := ["zhoumingyuan", "alyina", "wangjiaqi", "chenmo", "xumingming", "suwanqing", "liudanya", "li_anya"]

static func pixel_enabled(hero_id: String) -> bool:
	return Settings.portrait_style(hero_id) == "retro_pixel"

static func path(hero_id: String, attribute: String, original: String) -> String:
	if not pixel_enabled(hero_id) or hero_id not in IDS: return original
	var key := "zhou_math" if hero_id == "zhoumingyuan" and attribute == "math" else hero_id
	return PIXEL_ROOT + key + ".webp"

static func is_pixel(texture: Texture2D) -> bool:
	return texture != null and texture.resource_path.begins_with(PIXEL_ROOT)
