extends Control
## Visible settlement beats use the actual before/after combat snapshots.
signal finished
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const ART := preload("res://scripts/data/battle_art.gd")
var kind := "enter"
var actor_index := 0
var before: Array = []
var after: Array = []
var regions: Dictionary = {}
var elapsed := 0.0
var duration := 1.8
var focus := Vector2(1175, 912)
var sources: Array[Vector2] = []
var captions: Array[Label] = []
var feather: AtlasTexture
var completed := false

func _ready() -> void:
	name = "AnyaResolution_" + kind
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 110
	feather = AtlasTexture.new()
	feather.atlas = preload("res://assets/graphics/battle/anya/phoenix_ui_material.webp")
	feather.region = Rect2(88, 12, 170, 280)
	if kind == "downed":
		duration = 1.15
		focus = (regions.get("ally_%d" % actor_index, Rect2(592, 824, 280, 224)) as Rect2).get_center()
		_caption("濒死", focus + Vector2(-110, -110), Color("ffc0be"), 34, 220)
		_caption("羽光将熄……", focus + Vector2(-140, -67), Color("dfadb2"), 21, 280)
		return
	if kind == "enter":
		focus = Vector2(720, 916)
		for i in before.size():
			if i == actor_index or bool(before[i].get("dead", false)): continue
			var source := Vector2(592 + i * 310 + 135, 902)
			sources.append(source)
			_caption("生命汇入 %d" % maxi(0, int(before[i].hp)), source + Vector2(-110, -112), Color("ffdda2"), 24, 220)
		_caption("涅槃重生", Vector2(830, 671), Color("fff1cf"), 38, 470)
		_caption("生命 %d / %d  ·  重生 %d" % [after[actor_index].hp, after[actor_index].max_hp, after[actor_index].rebirth], Vector2(790, 724), Color("ffda9b"), 25, 650)
	else:
		focus = Vector2(1175, 840)
		for i in after.size():
			if i >= before.size() or (i != actor_index and not bool(before[i].get("anya_hidden", false))): continue
			var target := (regions.get("ally_%d" % i, Rect2(592 + i * 310, 824, 280, 224)) as Rect2).get_center()
			sources.append(target)
			var words := "濒死回场" if bool(after[i].get("downed", false)) else "回复至 %d" % after[i].hp if i == actor_index else "回场 · 生命 %d" % after[i].hp
			_caption(words, target + Vector2(-150, -140), Color("ffc3b3") if kind == "defeated" else Color("caffda"), 24, 300)
			_caption("负面净化" + (" · 充能 +3" if i == actor_index else ""), target + Vector2(-150, -104), Color("ffe5b8"), 20, 300)
	var wings := AnimatedSprite2D.new()
	wings.sprite_frames = ART.effect_frames("anya_phoenix")
	wings.position = focus + Vector2(0, -80)
	wings.scale = Vector2.ONE * (1.8 if kind == "enter" else 1.35)
	wings.speed_scale = 0.7
	wings.modulate = Color(1.0, 0.86, 0.66, 0.72)
	add_child(wings)
	move_child(wings, 0)
	wings.play()

func _caption(words: String, at: Vector2, color: Color, font: int, width: float) -> void:
	var label := V.text(self, words, Rect2(at, Vector2(width, 46)), font, color, true)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color("241320"))
	captions.append(label)

func _process(delta: float) -> void:
	elapsed += delta
	var fade := smoothstep(0.0, 0.18, elapsed) * (1.0 - smoothstep(duration - 0.35, duration, elapsed))
	for label in captions:
		label.modulate.a = fade
		label.position.y -= delta * 12.0
	queue_redraw()
	if elapsed >= duration:
		complete()

func complete() -> void:
	if completed: return
	completed = true
	set_process(false)
	finished.emit()
	queue_free()

func _draw() -> void:
	var t := clampf(elapsed / duration, 0, 1)
	var fade := sin(t * PI)
	if kind == "downed":
		for layer in 5:
			draw_circle(focus, 110 - layer * 14, Color(0.45, 0.03, 0.11, fade * 0.045))
		draw_arc(focus, 85 * (1.0 - t * 0.35), 0, TAU, 64, Color("f19093", fade * 0.65), 2, true)
		return
	for source in sources:
		var start := source if kind == "enter" else focus
		var end := focus if kind == "enter" else source
		var curve := PackedVector2Array()
		for step in 25:
			var fraction := float(step) / 24.0
			curve.append(start.lerp(end, fraction) + Vector2(0, -sin(fraction * PI) * 145))
		draw_polyline(curve, Color("f19056", fade * 0.12), 15, true)
		draw_polyline(curve, Color("ffe2a2", fade * 0.55), 2, true)
		for particle in 5:
			var fraction := fmod(t * 1.55 + particle * 0.17, 1.0)
			var pos := start.lerp(end, fraction) + Vector2(0, -sin(fraction * PI) * 145)
			draw_circle(pos, 8, Color("ffd19b", fade * 0.14))
			draw_circle(pos, 2.5, Color("fff5dc", fade))
		if kind != "enter":
			draw_arc(source, 45 + t * 80, PI, TAU, 48, Color("b6ffd3", fade * 0.6), 3, true)
	for i in 16:
		var pos := focus + Vector2(sin(i * 4.71) * (80 + t * 220), -30 - t * (110 + i % 5 * 35))
		draw_set_transform(pos, sin(i * 2.4) * 0.5)
		draw_texture_rect(feather, Rect2(-7, -15, 14, 30), false, Color(1, 0.8, 0.5, fade * 0.7))
	draw_set_transform(Vector2.ZERO)
	if kind == "enter":
		draw_arc(focus, 80 + t * 120, PI, TAU, 64, Color("ffe9b6", fade * 0.8), 4, true)
