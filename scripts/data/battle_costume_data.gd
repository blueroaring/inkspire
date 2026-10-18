extends RefCounted
## One costume contract keeps the cut-in, portrait and actual body frames together.
const ROOT := "res://assets/graphics/battle/costumes/20261015/"
const LOOKS := {
	"zhou_wuji": {"body":"zhou_strike", "eye":Rect2(419, 165, 141, 65), "hand":Vector2(315, 85)},
	"zhou_math": {"body":"zhou_cast", "eye":Rect2(408, 145, 145, 65), "hand":Vector2(296, 123)},
	"chen": {"body":"chen_cast", "eye":Rect2(440, 110, 115, 70), "hand":Vector2(252, 210)},
	"xu": {"body":"xu_strike", "eye":Rect2(195, 185, 140, 65), "hand":Vector2(302, 168)},
	"su": {"body":"su_cast", "eye":Rect2(402, 185, 155, 80), "hand":Vector2(292, 125)},
	"liu": {"body":"liu_cast", "eye":Rect2(430, 135, 115, 65), "hand":Vector2(272, 163)},
}

static func body_key(module: String) -> String:
	for key: String in LOOKS:
		if LOOKS[key].body == module: return key
	return ""

static func actor_path(key: String) -> String:
	return ROOT + key + "/cutin.webp" if LOOKS.has(key) else ""

static func body_path(module: String) -> String:
	var key := body_key(module)
	return ROOT + key + "/body/sheet-transparent.webp" if not key.is_empty() else ""
