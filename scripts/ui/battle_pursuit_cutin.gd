extends Control
## A separate, unskippable short ribbon precedes every pursuit's actual hit.
signal finished
const ART := preload("res://scripts/data/battle_art.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const ATTRIBUTE_HINT := preload("res://scripts/ui/battle_attribute_hint.gd")
const ACCENT := Color("80deef")
const HOLD_TIME := 0.72
var target_name := ""
var target_attribute := "none"
var sequence := 1
var ammo_name := ""

func _ready() -> void:
	name = "PursuitCutin"
	z_index = 110
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color(0.01, 0.03, 0.07, 0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var ribbon := Control.new()
	ribbon.name = "PursuitRibbon"
	ribbon.position = Vector2(-2000, 350)
	ribbon.size = Vector2(1920, 330)
	ribbon.clip_contents = true
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ribbon)
	_polygon(ribbon, [Vector2(0, 44), Vector2(1920, 6), Vector2(1920, 278), Vector2(0, 322)], Color(ACCENT, 0.28))
	_polygon(ribbon, [Vector2(0, 52), Vector2(1920, 14), Vector2(1920, 268), Vector2(0, 312)], Color("071724"))
	_polygon(ribbon, [Vector2(0, 60), Vector2(1920, 22), Vector2(1920, 256), Vector2(0, 300)], Color("123747"))
	for i in 10:
		var x := 105.0 + i * 185.0
		_polygon(ribbon, [Vector2(x, 56), Vector2(x + 2, 56), Vector2(x + 100, 285), Vector2(x + 98, 285)], Color(ACCENT, 0.09))
	# Reuse Zhou's equipped costume, with the head and upper body framed inside the ribbon.
	var actor := V.icon(ribbon, ART.actor("zhou_math"), Rect2(160, -10, 660, 660))
	actor.name = "PursuitCG"
	actor.rotation = -0.045
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.03, 0.09, 0.14, 0), Color("071724")])
	var wash := GradientTexture2D.new()
	wash.gradient = gradient
	wash.fill_from = Vector2.ZERO
	wash.fill_to = Vector2.RIGHT
	V.icon(ribbon, wash, Rect2(575, 35, 220, 255)).stretch_mode = TextureRect.STRETCH_SCALE
	V.text(ribbon, "周明远 · 数学    /    第 %02d 次验算" % sequence, Rect2(805, 54, 930, 32), 21, ACCENT)
	var title := V.text(ribbon, "追 击", Rect2(798, 90, 340, 96), 68, Color("f1fbff"))
	title.add_theme_font_override("font", preload("res://assets/fonts/noto_serif_sc/battle_title.tres"))
	V.icon(ribbon, ART.icon("pursuit"), Rect2(1110, 108, 60, 60))
	var matchup := ATTRIBUTE_HINT.matchup(ribbon, [{"attribute":"math", "target_attribute":target_attribute}], Rect2(1215, 111, 535, 48), 28)
	matchup.name = "PursuitAttribute"
	V.text(ribbon, "属性修正 · 其他增减伤另计", Rect2(1224, 165, 540, 24), 18, Color("c4cfda"))
	var target := V.text(ribbon, "锁定  →  " + target_name, Rect2(807, 194, 980, 42), 29, Color("f1e4d2"))
	target.name = "PursuitTarget"
	V.text(ribbon, ammo_name, Rect2(808, 246, 930, 30), 19, Color("a3c3ce"))
	var enter := Settings.battle_tween(self).set_parallel(true)
	enter.tween_property(ribbon, "position:x", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	enter.tween_property(shade, "color:a", 0.20, 0.22)
	await enter.finished
	var drift := Settings.battle_tween(self)
	drift.tween_property(actor, "position:x", 190.0, HOLD_TIME)
	await Settings.battle_timer(HOLD_TIME).timeout
	var leave := Settings.battle_tween(self).set_parallel(true)
	leave.tween_property(ribbon, "position:x", 2000.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	leave.tween_property(shade, "color:a", 0.0, 0.22)
	await leave.finished
	hide()
	finished.emit()
	queue_free()

func _polygon(parent: Node, points: Array, color: Color) -> void:
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array(points)
	shape.color = color
	parent.add_child(shape)
