extends Control
## Live typography: the exact skill name stays editable and follows the release beat.
const FACE := preload("res://assets/fonts/noto_serif_sc/battle_title.tres")
const ART := preload("res://scripts/data/battle_art.gd")
var module := "wang"
var title := ""
var behind_actor := false
var elapsed := 0.0
var glyphs: Array[Dictionary] = []
var accent := Color.WHITE
var lead := ""
var phrase := ""
var baseline := Vector2.ZERO
var main_size := 192
var tilt := -0.09
var sweep := Curve2D.new()
var sweep_path := PackedVector2Array()
var sweep_colors := PackedColorArray()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	size = Vector2(1920, 1080)
	accent = ART.accent(module)
	phrase = title
	var comma := title.find("，")
	if comma >= 0:
		lead = title.substr(0, comma + 1)
		phrase = title.substr(comma + 1)
	baseline = Vector2(420, 856)
	match module:
		"su":
			baseline = Vector2(365, 865)
			main_size = 178
			tilt = -0.08
		"chen":
			baseline = Vector2(330, 870)
			main_size = 156
			tilt = -0.04
		"xu":
			baseline = Vector2(400, 865)
			main_size = 182
			tilt = -0.14
		"zhou_wuji":
			baseline = Vector2(372, 872)
			main_size = 178
			tilt = -0.12
		"alyina":
			baseline = Vector2(384, 866)
			main_size = 172
			tilt = -0.055
		"zhou_math":
			baseline = Vector2(415, 852)
			main_size = 186
			tilt = -0.055
	var offset := 0.0
	for i in phrase.length():
		var character := phrase.substr(i, 1)
		var punctuation := character in ["！", "!", "。"]
		var font_size := roundi(main_size * (0.67 if punctuation else 1.10 if i == 0 or i == phrase.length() - 1 else 1.0))
		var dy: float = [0.0, -13.0, 8.0, -2.0, -7.0][i % 5]
		glyphs.append({"text":character, "point":Vector2(offset, dy), "font_size":font_size})
		offset += font_size * (0.72 if punctuation else 0.98)
	# Future longer names still fit inside the cinematic safe area.
	if offset > 1010:
		var ratio := 1010.0 / offset
		for glyph in glyphs:
			glyph.point *= ratio
			glyph.font_size = roundi(float(glyph.font_size) * ratio)
	set_meta("full_title", title)
	sweep.add_point(Vector2(baseline.x - 80, 923), Vector2.ZERO, Vector2(260, -25))
	sweep.add_point(Vector2(1085, 826), Vector2(-220, 82), Vector2(172, -80))
	sweep.add_point(Vector2(1490, 549), Vector2(-120, 190), Vector2.ZERO)
	for i in 70:
		sweep_path.append(sweep.sample_baked(sweep.get_baked_length() * float(i) / 69))
		sweep_colors.append(Color.TRANSPARENT)

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var entrance := smoothstep(0.28, 0.61, elapsed)
	if entrance <= 0.0: return
	var settle := (1.0 - entrance) * 72.0
	var origin := baseline + Vector2(-settle, settle * 0.22)
	if behind_actor:
		# An enlarged contour passes BEHIND the character; the solid title passes in front.
		draw_set_transform(origin + Vector2(55, -100), tilt, Vector2.ONE * 1.18)
		for glyph in glyphs:
			draw_string_outline(FACE, glyph.point, glyph.text, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph.font_size, 2, Color(accent, entrance * 0.18))
		draw_set_transform(Vector2.ZERO)
		return
	_draw_sweep(entrance)
	draw_set_transform(origin, tilt)
	if not lead.is_empty():
		draw_string_outline(FACE, Vector2(6, -201), lead, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, 6, Color("08101f"))
		draw_string(FACE, Vector2(6, -201), lead, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color("fff1d3"))
	for i in glyphs.size():
		var glyph := glyphs[i]
		var reveal := smoothstep(0.31 + i * 0.025, 0.56 + i * 0.025, elapsed)
		var displacement := Vector2(-32, 18) * (1.0 - reveal)
		var point: Vector2 = glyph.point + displacement
		var sheen := maxf(0.0, 1.0 - absf(elapsed - 0.68 - i * 0.05) / 0.13)
		var ink := Color("ffe8b7").lerp(Color.WHITE, sheen * 0.85)
		if module in ["zhou_math", "alyina"]: ink = Color("eafbf5").lerp(Color.WHITE, sheen)
		draw_string_outline(FACE, point + Vector2(0, 7), glyph.text, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph.font_size, 10, Color(0.02, 0.03, 0.06, reveal * 0.75))
		draw_string_outline(FACE, point, glyph.text, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph.font_size, 2, Color(accent.darkened(0.48), reveal))
		draw_string(FACE, point, glyph.text, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph.font_size, Color(ink, reveal))
	var identity := String({"zhou_wuji":"周明远 · 无极", "zhou_math":"周明远 · 数学", "alyina":"艾莉娜", "wang":"王嘉琪"}.get(module, ""))
	draw_line(Vector2(15, 39), Vector2(80, 39), Color(accent, entrance * 0.9), 1.5, true)
	draw_string(FACE, Vector2(99, 49), identity + "   /   终结技", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color(accent.lightened(0.3), entrance))
	draw_set_transform(Vector2.ZERO)

func _draw_sweep(opacity: float) -> void:
	# One continuous tapered light stroke joins the title to the actor's release point.
	for i in sweep_colors.size():
		var t := float(i) / (sweep_colors.size() - 1)
		sweep_colors[i] = Color(accent, sin(t * PI) * opacity * 0.64)
	draw_polyline_colors(sweep_path, sweep_colors, 2.0, true)
	var spark_t := clampf((elapsed - 0.43) / 0.72, 0.0, 1.0)
	var spark := sweep.sample_baked(spark_t * sweep.get_baked_length())
	var alpha := sin(spark_t * PI) * opacity
	draw_line(spark - Vector2(20, -7), spark + Vector2(20, -7), Color("fff9e7", alpha), 2.0, true)
	draw_line(spark - Vector2(3, 12), spark + Vector2(3, 12), Color("fff9e7", alpha), 1.3, true)
