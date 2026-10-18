extends Control
## Compression contacts the hand area; the persistent counter survives this cue.
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const ART := preload("res://scripts/data/battle_art.gd")
var previous_limit := 8
var current_limit := 6
var age := 0.0

func _ready() -> void:
	name = "HandLimitCompressionFX"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	size = Vector2(1920, 1080)
	var pane := V.panel(self, Rect2(500, 186, 410, 140), Color("241f27"), Color("dfa66e"), 8)
	pane.name = "HandLimitChangeNotice"
	V.icon(pane, ART.status_icon("no_escape"), Rect2(14, 22, 72, 72))
	V.text(pane, "空间压缩 · 手牌上限", Rect2(102, 8, 296, 34), 22, Color("f4ce9e"))
	var value := V.text(pane, "%d → %d 张" % [previous_limit, current_limit], Rect2(102, 42, 296, 48), 32, Color("ffe1af"))
	value.name = "HandLimitChangeValue"
	V.text(pane, "超出上限的末端手牌进入弃牌堆" if previous_limit > current_limit else "已达最低上限 · 不会继续降低", Rect2(20, 103, 380, 28), 17, Color("c6b3a4"))
	pane.pivot_offset = pane.size * 0.5
	pane.scale = Vector2(1.08, 0.88)
	var motion := Settings.battle_tween(self)
	motion.tween_property(pane, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.tween_interval(1.35)
	motion.tween_property(self, "modulate:a", 0.0, 0.40)
	motion.tween_callback(queue_free)

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	age += delta
	queue_redraw()

func _draw() -> void:
	var t := smoothstep(0.0, 0.38, age)
	var height := lerpf(float(previous_limit), float(current_limit), t) * 57.0 + 8.0
	var flash := (1.0 - smoothstep(0.75, 1.6, age)) * 0.8
	var rect := Rect2(34, 177, 436, height)
	draw_rect(rect, Color(0.88, 0.55, 0.31, flash * 0.10))
	var tint := Color(0.96, 0.71, 0.41, flash)
	for x in [rect.position.x, rect.end.x]:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), tint, 3.0, true)
		var inward := 22.0 if x == rect.position.x else -22.0
		for y in [rect.position.y, rect.end.y]: draw_line(Vector2(x, y), Vector2(x + inward, y), tint, 3.0, true)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, tint, 2.0, true)
