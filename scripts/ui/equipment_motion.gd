extends Control
## The actual item travels to its slot/target; settlement occurs at contact.
signal contacted
signal finished
const T := preload("res://scripts/ui/battle_theme.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
var item_id := ""
var origin := Vector2(960, 430)
var destination := Vector2(960, 800)
var targets: Array[Vector2] = []
var caption := ""
var battle_use := false
var elapsed := 0.0
var impact := -1.0
var flying: TextureRect
var label: Label
var tint := Color.WHITE
var _settled := false

func _ready() -> void:
	if battle_use and Settings.simple_battle_effects():
		hide()
		set_process(false)
		_finish_simple.call_deferred()
		return
	name = "EquipmentMotion"
	z_index = 120
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	T.apply(self)
	tint = FightEquipmentData.rarity(item_id).color
	flying = V.icon(self, FightEquipmentData.texture(item_id), Rect2(origin - Vector2(90, 90), Vector2(180, 180)))
	flying.pivot_offset = Vector2(90, 90)
	flying.scale = Vector2.ONE * 0.55
	flying.modulate.a = 0
	var plate := V.panel(self, Rect2(origin + Vector2(-250, 102), Vector2(500, 72)), T.SURFACE, tint, 8)
	plate.name = "ItemNameplate"
	label = V.text(plate, caption, Rect2(12, 10, 476, 52), 27, T.TEXT, true)
	label.add_theme_font_override("font", T.HEADING)
	var tween := Settings.battle_tween(self) if battle_use else create_tween()
	tween.tween_property(flying, "scale", Vector2.ONE, 0.23).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(flying, "modulate:a", 1.0, 0.16)
	tween.tween_interval(0.48 if battle_use else 0.12)
	tween.tween_property(flying, "position", destination - Vector2(90, 90), 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(flying, "scale", Vector2.ONE * 0.48, 0.48)
	tween.parallel().tween_property(plate, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		impact = 0
		_settled = true
		contacted.emit()
	)
	tween.tween_property(flying, "modulate:a", 0.0, 0.28)
	tween.tween_interval(0.45 if battle_use else 0.16)
	tween.tween_callback(func() -> void: finished.emit(); queue_free())

func _finish_simple() -> void:
	_settled = true
	contacted.emit()
	finished.emit()
	queue_free()

func _process(delta: float) -> void:
	if battle_use: delta *= Settings.battle_effect_speed()
	elapsed += delta
	if impact >= 0: impact += delta
	queue_redraw()

func _draw() -> void:
	if battle_use and not _settled: draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.06, 0.28))
	var center := flying.position + Vector2(90, 90) if is_instance_valid(flying) else origin
	if impact < 0:
		for i in 2: draw_arc(center, 96.0 + i * 12, elapsed * (0.8 if i == 0 else -0.6), elapsed * (0.8 if i == 0 else -0.6) + PI * 1.6, 56, Color(tint, 0.45), 1.5, true)
	else:
		var points: Array = targets if not targets.is_empty() else [destination]
		for point in points:
			var fade := maxf(0, 1.0 - impact / 0.75)
			for ring in 2: draw_arc(point, 20 + impact * (140 + ring * 50), 0, TAU, 80, Color(tint, fade * 0.7), 3 - ring, true)
			for i in 12:
				var ray := Vector2.from_angle(TAU * i / 12)
				draw_line(point + ray * (30 + impact * 80), point + ray * (42 + impact * 125), Color(tint, fade), 2, true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
