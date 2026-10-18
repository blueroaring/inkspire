extends Control
## Reserved footer instruments: art, readout and hover share local bounds.
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const FONT := preload("res://assets/fonts/noto_serif_sc/battle_ui.tres")
const NUMBER_FONT := preload("res://assets/fonts/noto_sans_sc/NotoSansSC-Regular.otf")
const ART := "res://assets/graphics/battle/finale/meters/"
const WIDTH := 326.0
const STEP := 334.0
const HEIGHT := 88.0
var values := [-1, -1, -1]
var limits := [10, 10, 5]
var accents := [Color("ef8a9f"), Color("ffe1a4"), Color("b8b6ee")]
var labels: Array[Label] = []
var captions: Array[Label] = []
var deltas: Array[Label] = []
var pulses := [0.0, 0.0, 0.0]
var shown := [0.0, 0.0, 0.0]
var age := 0.0
var plates: Array[Texture2D] = []

func _ready() -> void:
	name = "FinaleMeters"
	size = Vector2(STEP * 2 + WIDTH, HEIGHT)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in ["edge", "hope", "countdown"]: plates.append(load(ART + key + ".webp"))
	for i in 3:
		var x := i * STEP
		var hit := Control.new()
		hit.name = "FinaleMeter_%d" % i
		hit.position = Vector2(x, 0)
		hit.size = Vector2(WIDTH, HEIGHT)
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.tooltip_text = ["边缘达到10，战斗失败。攻击本体每张牌+1（反伤不计），回合结束+1；消灭召唤物、后退一步可降低边缘。", "希望达到10，战斗胜利。消灭召唤物积累希望；清除假黎明后，以“不，我拒绝！”获得最后一点希望。", "倒计时每推进1点，熄灭一枚封印。达到5时立即释放“最后通牒”；每击杀一只召唤物减少1点（最低为0）；全部击杀并转阶段时清零。这里显示的是推进点数，不是剩余回合。"][i]
		add_child(hit)
		var title := V.text(hit, ["边缘", "希望", "倒计时"][i], Rect2(96, 11, 100, 34), 22, accents[i])
		title.add_theme_font_override("font", FONT)
		title.add_theme_color_override("font_shadow_color", Color("05060d"))
		title.add_theme_constant_override("shadow_offset_y", 2)
		captions.append(V.text(hit, "", Rect2(96, 40, 143, 19), 13, Color("d0c7bc")))
		labels.append(V.text(hit, "", Rect2(243, 12, 43, 44), 30, Color("fff1d9"), true))
		labels[i].add_theme_font_override("font", NUMBER_FONT)
		labels[i].text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		V.text(hit, "/%d" % limits[i], Rect2(286, 31, 25, 20), 13, Color("baa992"))
		deltas.append(V.text(hit, "", Rect2(200, 17, 40, 25), 16, accents[i], true))
		deltas[i].visible = false

func update_values(e: Dictionary) -> void:
	var next := [int(e.edge), int(e.hope), int(e.countdown)]
	for i in 3:
		if values[i] == next[i]: continue
		var previous: int = values[i]
		values[i] = next[i]
		if previous < 0: shown[i] = float(next[i])
		else:
			pulses[i] = 1.0
			deltas[i].text = "%+d" % (next[i] - previous)
			deltas[i].visible = true
		labels[i].text = str(values[i])
		captions[i].text = _caption(i)
	queue_redraw()

func _caption(i: int) -> String:
	match i:
		0: return "即将坠落" if values[i] >= 8 else "正在逼近深渊" if values[i] >= 5 else "稳住脚步"
		1: return "黎明已至" if values[i] >= 10 else "只差最后的回答" if values[i] == 9 else "羽光渐盛" if values[i] >= 5 else "微光尚在"
	return "最后通牒将至" if values[i] >= 4 else "封印正在松动" if values[i] > 0 else "五重封印完整"

func _process(delta: float) -> void:
	age += delta
	for i in 3:
		pulses[i] = maxf(0, pulses[i] - delta * 0.8)
		shown[i] = move_toward(shown[i], float(maxi(0, values[i])), delta * 9)
		deltas[i].modulate.a = minf(1, pulses[i] * 2)
		deltas[i].position.y = 17 - (1 - pulses[i]) * 3
	queue_redraw()

func _draw() -> void:
	for i in 3:
		var x := i * STEP
		var accent: Color = accents[i]
		var danger: bool = (i == 0 and values[i] >= 8) or (i == 2 and values[i] >= 4)
		var glow := maxf(float(pulses[i]), (0.35 + 0.25 * sin(age * 4)) if danger else 0.0)
		# Artwork includes its own icon, bezel and inset; never stretch an unrelated frame.
		draw_texture_rect(plates[i], Rect2(x + 2, 2, WIDTH - 4, HEIGHT - 4), false)
		var c := Vector2(x + 46, 44)
		if glow > 0:
			draw_circle(c, 21, Color(accent, glow * 0.09))
			draw_arc(c, 28, -PI * 0.7, PI * 0.7, 40, Color(accent, glow * 0.7), 1.5, true)
		# The progression lives entirely inside the blank well of the painted frame.
		var total: int = limits[i]
		var pitch := 207.0 / total
		for n in total:
			var lit := clampf(shown[i] - n, 0, 1)
			if i == 2: lit = 1 - lit # Seals extinguish as the countdown advances.
			var left := x + 96 + n * pitch
			var right := left + pitch - 3
			var gem := PackedVector2Array([Vector2(left + 2, 62), Vector2(right, 62), Vector2(right - 2, 69), Vector2(left, 69)])
			draw_colored_polygon(gem, Color("302c38"))
			draw_colored_polygon(gem, Color(accent, 0.12 + lit * 0.85))
			draw_line(Vector2(left + 2, 62), Vector2(right, 62), Color("fff1d2", 0.12 + lit * 0.65), 1, true)
			if i == 2 and lit < 0.5:
				draw_line(Vector2(left + 12, 63), Vector2(right - 12, 68), Color("9e6f86"), 1, true)
		if pulses[i] > 0:
			var cursor := x + 96 + clampf(shown[i] / total, 0, 1) * 204
			draw_line(Vector2(cursor, 61), Vector2(cursor - 2, 70), Color("fff9e5", pulses[i]), 2, true)
