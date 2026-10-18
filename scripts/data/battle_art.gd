extends RefCounted
const COSTUMES := preload("res://scripts/data/battle_costume_data.gd")
const ROOT := "res://assets/graphics/battle/fc_art/"
const REFINED := ROOT + "refined/"
const SKILL_IDS := ["N01","N02","N03","N04","N05","N06","N07","N08","N09","N10","N11","N12","N13","red_pen","ultimate_zhoumingyuan","self_loss","A01","A02","A03","A04","A05","A06","A07","A08","A09","A10","A11","A12","A13","hang_on","ultimate_alyina","blessing_mote","W01","W02","W03","W04","W05","W06","W07","W08","W09","W10","W11","W12","W13","ultimate_wang","enchant_true","magic_card","M01","M02","M03","M04","M05","M06","M07","M08","M09","M10","M11","M12","M13","ultimate_math","lemma","pursuit"]
const FX_FAMILIES := ["slash", "blessing", "math", "magic", "barrier", "poison", "ink", "anya_bound", "anya_phoenix"]
const FX_CELL := 384
const FX_COLUMNS := 4
const FX_COUNT := 12
# Relative exposure per drawing: short anticipation, a held contact, a longer tail.
const FX_EXPOSURES := [0.6, 0.6, 0.6, 0.6, 0.48, 1.6, 0.85, 0.9, 1.0, 1.1, 1.2, 1.3]
const FX_FPS := 24.0
const FX_CONTACT := 0.12
static var _frames: Dictionary = {}
const STATUS_ICONS := [
	"shield", "lifesteal", "resilience", "rally", "noticed",
	"shiver", "no_guard", "labor", "sleep_bad", "downed",
	"dead", "buff", "debuff", "temporary_guard", "taunt",
	"chinese", "math", "english", "science", "social",
]
static func icon(id: String) -> Texture2D:
	var path := icon_path(id)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func icon_path(id: String) -> String:
	if id.begins_with("LA") or id.begins_with("LP"): return "res://assets/graphics/battle/anya/icons/" + id + ".webp"
	if id.begins_with("Y") and id.substr(1).is_valid_int(): return REFINED + "liu_icons/icon-%d.webp" % int(id.substr(1))
	if id == "ultimate_liu": return REFINED + "liu_icons/icon-17.webp"
	if id.begins_with("D") and id.substr(1).is_valid_int(): return REFINED + "su_icons/icon-%d.webp" % int(id.substr(1))
	if id == "ultimate_su": return REFINED + "su_icons/icon-14.webp"
	if id.begins_with("C"): id = String({"C03":"A12", "C04":"A09", "C05":"N03", "C06":"A10", "C08":"A08", "C09":"N11", "C10":"M04", "C11":"N07", "C12":"A02", "C13":"W05"}.get(id, "A03"))
	if id.begins_with("X"): id = String({"X01":"N01", "X02":"N05", "X03":"N02", "X04":"M05", "X05":"W06", "X06":"N08", "X07":"N11", "X08":"W13", "X09":"N04", "X10":"N06", "X11":"N10", "X12":"W10", "X13":"M10"}.get(id, "N06"))
	return REFINED + "icons/" + id + ".webp"

static func effect_frames(kind: String) -> SpriteFrames:
	if _frames.has(kind): return _frames[kind]
	var path := REFINED + "fx_" + kind + "/sheet-transparent.webp"
	if kind.begins_with("anya_"): path = "res://assets/graphics/battle/anya/fx_" + kind.trim_prefix("anya_") + ".webp"
	if not ResourceLoader.exists(path): return null
	var sheet := load(path) as Texture2D
	var result := SpriteFrames.new()
	result.set_animation_loop("default", false)
	result.set_animation_speed("default", FX_FPS)
	for i in FX_COUNT:
		var region := AtlasTexture.new()
		region.atlas = sheet
		region.region = Rect2((i % FX_COLUMNS) * FX_CELL, int(i / FX_COLUMNS) * FX_CELL, FX_CELL, FX_CELL)
		result.add_frame("default", region, FX_EXPOSURES[i])
	_frames[kind] = result
	return result

static func actor(key: String) -> Texture2D:
	if key.begins_with("anya_"): return load("res://assets/graphics/battle/anya/actor_" + key.trim_prefix("anya_") + ".webp") as Texture2D
	if COSTUMES.LOOKS.has(key): return load(COSTUMES.actor_path(key)) as Texture2D
	var suffix := String({"zhou_wuji":"wuji", "zhou_math":"math"}.get(key, key))
	var path := REFINED + "cg/actor_" + suffix + ".webp"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func profile(id: String) -> Dictionary:
	# Character families share animation vocabulary, while key skills have distinct direction and force.
	var result := {"scale":1.0, "rotation":0.0, "echoes":0, "tint":Color.WHITE}
	match id:
		"N02", "N06", "N10": result.merge({"scale":1.4, "rotation":-0.25}, true)
		"N04": result.merge({"rotation":0.2, "echoes":1}, true)
		"N08", "N13": result.merge({"scale":1.25, "rotation":0.65, "echoes":1}, true)
		"red_pen": result.merge({"rotation":0.8, "tint":Color("ffbea8")}, true)
		"N03", "N07", "N11": result["tint"] = Color("ffc7ae")
		"A08", "A10", "A12": result["scale"] = 1.3
		"W06", "W10", "W12": result.merge({"scale":1.25, "echoes":1}, true)
		"M07", "M09", "M10": result.merge({"scale":1.2, "echoes":1}, true)
		"pursuit", "enchant_true": result["scale"] = 0.85
	return result

static func module(unit: Dictionary) -> String:
	if unit.get("id", "") == "li_anya": return "anya_phoenix" if bool(unit.get("anya_phoenix", false)) else "anya_bound"
	if unit.get("id", "") == "zhoumingyuan": return "zhou_math" if unit.get("attribute", "none") == "math" else "zhou_wuji"
	return String({"chenmo":"chen", "xumingming":"xu", "wangjiaqi":"wang", "suwanqing":"su", "liudanya":"liu"}.get(unit.get("id", ""), "alyina"))

const FIELD_ICONS := ["thunder_rule", "field_rain", "field_wound", "field_mirror", "helpless", "no_escape", "finale_power"]
const ENEMY_RULE_ICONS := ["shadow_taunt", "exam_function", "score_rule", "countdown_rule", "damage_cap", "evasion", "blood_draw", "hacker_stolen", "summon_hits", "paper_split", "limit"]

static func status_icon(key: String, debuff: bool = false, art_key: String = "") -> Texture2D:
	if key == "finale_defiance": return load("res://assets/graphics/battle/finale/defiance/icon.webp") as Texture2D
	var anya_icons := {"anya_abuser":"abuser", "anya_buffer":"buffer", "anya_unbroken":"LP11", "anya_rally":"LP12", "anya_shelter":"LP01"}
	if anya_icons.has(key): return load("res://assets/graphics/battle/anya/icons/" + String(anya_icons[key]) + ".webp") as Texture2D
	if key == "self_seal": return load("res://assets/graphics/battle/field_rules/self_seal.webp") as Texture2D
	var field_key := art_key if not art_key.is_empty() else "field_rain" if key == "challenge_field" else key
	if field_key in FIELD_ICONS:
		var field_path := "res://assets/graphics/battle/field_rules/%s.webp" % field_key
		if ResourceLoader.exists(field_path): return load(field_path) as Texture2D
	if key in ENEMY_RULE_ICONS:
		var rule_path := "res://assets/graphics/battle/enemy_rules/%s.webp" % key
		if ResourceLoader.exists(rule_path): return load(rule_path) as Texture2D
	key = preload("res://scripts/fight/status_rules.gd").canonical(key)
	var symbol := "res://assets/graphics/battle/status_symbols/%s.svg" % key
	if ResourceLoader.exists(symbol): return load(symbol) as Texture2D
	var equipment_icons := {"cleanseable_immunity":"ward_pouch", "item_exposed":"battle_ink"}
	if equipment_icons.has(key): return FightEquipmentData.texture(String(equipment_icons[key]))
	var painting_icons := {"armor_break":7, "shield_strength":18, "swift":19, "sketch":15, "debuff_immunity":11}
	if painting_icons.has(key): return load(REFINED + "liu_icons/icon-%d.webp" % int(painting_icons[key])) as Texture2D
	var poison_icons := {"poison":15, "poison_counter":2, "offstage":16, "grudge":7, "hair_pull":12, "backlash":12, "perishing":13, "gossip_draw":11, "poison_guard":10, "debuff_immunity":13, "poison_weakness":7}
	if poison_icons.has(key): return load(REFINED + "su_icons/icon-%d.webp" % int(poison_icons[key])) as Texture2D
	key = String({"latent_marks":"science", "reflect":"shield", "reflect_double":"shield", "trust":"rally", "trust_pending":"rally", "restraint":"resilience", "damage_record":"temporary_guard", "calculation_pending":"noticed", "pain_guard":"shield", "last_stand":"no_guard", "pb_lock":"labor", "athlete_burst":"science"}.get(key, key))
	if key == "tired": key = "labor"
	var index := STATUS_ICONS.find(key)
	if index < 0: index = STATUS_ICONS.find("debuff" if debuff else "buff")
	var path := ROOT + "status_icons/icon-%d.webp" % (index + 1)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func accent(key: String) -> Color:
	if key.begins_with("anya_"): return Color("ffd98e") if key == "anya_phoenix" else Color("b1bdff")
	if key == "liu": return Color("e3b8a0")
	return {"zhou_wuji":Color("f1af79"), "zhou_math":Color("80deef"), "alyina":Color("a2e9d1"), "wang":Color("bca3f1"), "chen":Color("75a4e8"), "xu":Color("f39759"), "su":Color("65d691")}.get(key, Color("edcf91"))

static func cutin(key: String) -> Texture2D:
	if key.begins_with("anya_"): return actor(key)
	if COSTUMES.LOOKS.has(key): return actor(key)
	var path := ROOT + "cg/" + key + ".webp"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func family(id: String, side: String) -> String:
	if id.begins_with("LA"): return "anya_bound"
	if id.begins_with("LP") or id == "anya_buffer": return "anya_phoenix"
	if id == "poison_burst": return "poison_burst"
	if id.begins_with("Y") or id == "ultimate_liu": return "ink"
	if id.begins_with("D") or id.begins_with("poison_") or id == "ultimate_su": return "poison"
	if id.begins_with("C") or id == "ultimate_chen": return "barrier"
	if id.begins_with("X") or id == "ultimate_xu": return "slash" if side == "enemy" else "barrier"
	if id in ["block", "N03", "A02", "A03", "A12", "W03"]: return "barrier"
	if id.begins_with("A") or id in ["heal", "angel_guard", "help_me", "hang_on", "ultimate_alyina", "N05"]: return "blessing"
	if id.begins_with("W") or id in ["enchant_true", "ultimate_wang"]: return "magic"
	if id.begins_with("M") or id in ["pursuit", "lemma", "ultimate_math", "enemy_bounce"]: return "math"
	return "slash" if side == "enemy" or id.begins_with("enemy_") or id == "self_loss" else "barrier"
