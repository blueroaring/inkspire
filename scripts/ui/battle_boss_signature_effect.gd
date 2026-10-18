extends Node2D
## A rain-to-mirror athletic duel, or the curtained infirmary's trapped echoes.
const ART := preload("res://scripts/ui/battle_enemy_art.gd")
var _echo_texture: Texture2D
var _echo_size := Vector2.ZERO
var boss_id := ""
var stage := 1
var effect := ""
var mode := "idle"
var progress := 0.0
var age := 0.0
var center := Vector2.ZERO
var targets: Array[Vector2] = []

func _ready() -> void:
	name = "BossSignatureEffect"
	z_index = 48

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	age += delta
	queue_redraw()

func windup(actor: TextureRect, intent: Dictionary) -> void:
	boss_id = actor.enemy_id
	_echo_texture = actor.texture
	_echo_size = actor.size
	stage = int(intent.get("boss_phase", 1))
	effect = String(intent.get("effect", ""))
	center = actor.rest_position + actor.size * Vector2(0.5, 0.48)
	mode = "windup"
	progress = 0.0
	var duration := 0.66 if boss_id == "inverse_limit" else 0.58
	var motion := Settings.battle_tween(self).set_parallel(true)
	motion.tween_property(self, "progress", 1.0, duration)
	motion.tween_property(actor, "motion_frame", 2.0, duration * 0.85)
	motion.tween_property(actor, "scale", Vector2.ONE * 1.045, duration)
	await motion.finished

func impact(points: Array[Vector2]) -> void:
	targets = points
	mode = "impact"
	progress = 0.0
	Settings.battle_tween(self).tween_property(self, "progress", 1.0, 0.48)

func rebirth(actor: TextureRect, next_stage: int) -> void:
	preload("res://scripts/ui/battle_generated_audio.gd").of(get_parent()).rebirth(actor.enemy_id, next_stage)
	var audio := preload("res://scripts/ui/battle_enemy_audio.gd")
	audio.emit(get_parent(), actor.enemy_id, "collapse")
	Settings.battle_timer(0.32).timeout.connect(func() -> void:
		if is_instance_valid(self): audio.emit(get_parent(), boss_id, "rebirth")
	)
	boss_id = actor.enemy_id
	stage = next_stage
	center = actor.rest_position + actor.size * Vector2(0.5, 0.48)
	mode = "transition"
	progress = 0.0
	actor.animating = true
	var motion := Settings.battle_tween(self).set_parallel(true)
	motion.tween_property(self, "progress", 1.0, 0.88)
	motion.tween_property(actor, "modulate:a", 0.35, 0.28)
	motion.tween_property(actor, "modulate:a", 1.0, 0.44).set_delay(0.32)
	motion.tween_property(actor, "scale", Vector2.ONE * 1.07, 0.35)
	await motion.finished
	actor.scale = Vector2.ONE
	actor.reset_pose()
	queue_free()

func finish() -> void:
	await Settings.battle_tween(self).tween_property(self, "modulate:a", 0.0, 0.2).finished
	queue_free()

func _draw() -> void:
	if mode == "idle": return
	if boss_id == "inverse_limit" and stage == 3 and _echo_texture != null:
		var echo_alpha := progress * 0.22 if mode == "windup" else (1-progress) * 0.28
		for side in [-1.0, 1.0]:
			var at := center + Vector2(side * (65 + progress * 100), 0)
			draw_texture_rect(_echo_texture, Rect2(at - _echo_size * 0.5, _echo_size), false, Color(0.7, 1.0, 1.0, echo_alpha))
	if boss_id == "inverse_limit": _draw_inverse()
	elif boss_id == "bullied_phantom": _draw_bullied()

func _draw_inverse() -> void:
	var tint := Color("70b8c8") if stage == 1 else Color("d47883") if stage == 2 else Color("d9f1ef")
	var alpha := progress if mode == "windup" else sin(progress * PI) if mode == "transition" else 1.0 - progress
	var focal := center
	if mode == "impact" and not targets.is_empty(): focal = targets[0]
	var key := "fx_inverse_rain" if stage == 1 else "fx_inverse_injury" if stage == 2 else "fx_inverse_mirror"
	if ART.stamp(self, key, focal, Vector2(620, 520), alpha):
		if mode == "impact":
			for at in targets: ART.stamp(self, key, at, Vector2(340, 310), alpha)
		return
	if stage == 1:
		draw_colored_polygon(PackedVector2Array([focal + Vector2(-270, -260), focal + Vector2(270, -260), focal + Vector2(230, 255), focal + Vector2(-230, 255)]), Color("092c38", alpha * 0.2))
		for i in 37:
			var x := focal.x - 270.0 + i * 15.0
			var offset := fmod(age * 400.0 + i * 67.0, 480.0)
			var start := Vector2(x + offset * 0.10, focal.y + 230.0 - offset)
			draw_line(start, start + Vector2(14, -58), Color("d7faff", alpha * 0.72), 2.4, true)
			if i % 3 == 0: draw_line(start + Vector2(4, 6), start + Vector2(18, -52), Color(tint, alpha * 0.35), 6.0, true)
		_draw_track(focal, tint, alpha)
	elif stage == 2:
		_draw_track(focal, tint, alpha * 0.5)
		for i in 6:
			var y := focal.y - 110.0 + i * 38.0
			var x := focal.x - 115.0 + sin(i * 2.4 + age) * 24.0
			draw_line(Vector2(x, y), Vector2(x + 180, y - 8), Color(tint, alpha * 0.66), 5.0, true)
			draw_line(Vector2(x + 14, y + 10), Vector2(x + 166, y + 1), Color("f1d6d3", alpha * 0.5), 1.5, true)
	else:
		_draw_mirror(focal, tint, alpha)
	if mode == "impact":
		for at in targets:
			if stage == 3: _draw_mirror(at, tint, alpha * 0.75)
			else: draw_arc(at, 24.0 + progress * 74.0, PI * 0.14, PI * 0.86, 34, Color(tint, alpha * 0.7), 3.0, true)

func _draw_track(at: Vector2, tint: Color, alpha: float) -> void:
	for lane in 3:
		var y := at.y + 72.0 + lane * 36.0
		draw_arc(Vector2(at.x, y), 175.0 + lane * 40.0, PI * 1.1, PI * 1.9, 48, Color("061d26", alpha * 0.72), 8.0, true)
		draw_arc(Vector2(at.x, y), 175.0 + lane * 40.0, PI * 1.1, PI * 1.9, 48, Color("b7f6ef", alpha * (0.84 - lane * 0.14)), 3.0, true)
	for i in 5:
		var x := at.x - 145.0 + i * 72.0
		draw_line(Vector2(x, at.y + 42), Vector2(x + 24, at.y + 42), Color("edf7ea", alpha * 0.65), 2.0, true)

func _draw_mirror(at: Vector2, tint: Color, alpha: float) -> void:
	for i in 9:
		var angle := -PI * 0.9 + i * TAU / 9.0
		var direction := Vector2.from_angle(angle)
		var start := at + direction * 34.0
		var joint := at + direction * (96.0 + i % 3 * 18.0) + direction.orthogonal() * (16.0 if i % 2 == 0 else -16.0)
		var end := at + direction * (186.0 + i % 4 * 16.0)
		draw_polyline(PackedVector2Array([start, joint, end]), Color(tint, alpha * 0.85), 3.0, true)
		draw_colored_polygon(PackedVector2Array([joint, end, end + direction.orthogonal() * 24.0]), Color(tint, alpha * 0.11))
	draw_line(at + Vector2(-54, 0), at + Vector2(54, 0), Color("f4fffb", alpha * 0.8), 2.0, true)

func _draw_bullied() -> void:
	var alpha := progress if mode == "windup" else 1.0 - progress
	var tint := Color("dfe9df")
	var curtain_left := center.x - 260.0 + progress * 38.0
	var curtain_right := center.x + 260.0 - progress * 38.0
	draw_line(Vector2(curtain_left - 20, center.y - 240), Vector2(curtain_right + 20, center.y - 240), Color("152d2e", alpha * 0.78), 12.0, true)
	draw_line(Vector2(curtain_left - 20, center.y - 240), Vector2(curtain_right + 20, center.y - 240), Color("dceee3", alpha * 0.8), 4.0, true)
	for side in [-1.0, 1.0]:
		var x := curtain_left if side < 0 else curtain_right
		var hem := PackedVector2Array([Vector2(x, center.y - 240), Vector2(x + side * 26, center.y - 110), Vector2(x - side * 13, center.y + 60), Vector2(x + side * 12, center.y + 205)])
		var outer := PackedVector2Array()
		for point in hem: outer.append(point + Vector2(side * 102.0, 0))
		var fabric := PackedVector2Array(hem)
		for i in range(outer.size() - 1, -1, -1): fabric.append(outer[i])
		draw_colored_polygon(fabric, Color("dbeae3", alpha * 0.26))
		draw_polyline(hem, Color("132e30", alpha * 0.8), 12.0, true)
		draw_polyline(hem, Color(tint, alpha * 0.9), 6.0, true)
		draw_polyline(outer, Color("dfeee7", alpha * 0.34), 3.0, true)
		for fold in 3:
			var offset: float = side * (22.0 + fold * 27.0)
			draw_line(Vector2(x + offset, center.y - 220), Vector2(x + offset + side * 12.0, center.y + 195), Color("e9f4e9", alpha * (0.32 if fold % 2 == 0 else 0.16)), 4.0, true)
	for i in 8:
		var y := center.y - 115.0 + i * 36.0
		var drift := sin(age * 2.8 + i * 0.7) * 18.0
		draw_line(Vector2(center.x - 115 + drift, y), Vector2(center.x + 85 + drift, y - 14), Color("b9d7cf", alpha * 0.19), 9.0, true)
	if effect == "phantom_summon" or mode == "transition":
		for i in 6:
			var angle := i * TAU / 6.0 + age * 0.17
			var hand := center + Vector2.from_angle(angle) * (100.0 + progress * 58.0)
			draw_line(hand, hand + Vector2.from_angle(angle) * 55.0, Color("a987a7", alpha * 0.65), 13.0, true)
			for finger in [-1.0, 0.0, 1.0]:
				draw_line(hand + Vector2.from_angle(angle) * 52.0, hand + Vector2.from_angle(angle) * 82.0 + Vector2.from_angle(angle).orthogonal() * finger * 15.0, Color("d4bbcd", alpha * 0.72), 4.0, true)
	if mode == "impact":
		for at in targets:
			for i in 4:
				var y := at.y - 48.0 + i * 28.0
				draw_line(Vector2(at.x - 70, y), Vector2(at.x + 70, y - 9), Color(tint, alpha * 0.55), 3.0, true)
