extends Node2D
## Short portal burst used when the bullied phantom calls a minion into battle.
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()

func _init() -> void:
	name = "PhantomSummonFX"

func burst(center: Vector2, diameter: float = 260.0) -> void:
	if String(get_meta("source", "")) != "cast":
		preload("res://scripts/ui/battle_enemy_audio.gd").emit(get_parent(), "bullied_phantom", "summon")
	position = center
	scale = Vector2.ONE * (diameter / 260.0)
	progress = 0.0
	var motion := Settings.battle_tween(self)
	motion.tween_property(self, "progress", 1.0, 0.78).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_callback(queue_free)

func _draw() -> void:
	var opening := minf(1.0, progress * 3.2)
	var fading := minf(1.0, (1.0 - progress) * 3.0)
	var radius := 18.0 + 96.0 * opening
	var center := Vector2(0, 34)
	draw_set_transform(center, 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, radius * 0.72, Color(0.055, 0.025, 0.12, 0.55 * fading))
	for ring in 3:
		draw_arc(Vector2.ZERO, radius * (0.62 + ring * 0.17), -PI * 0.92 + progress * (ring + 1), PI * 0.75 + progress * (ring + 1), 48, Color(0.67, 0.41 + ring * 0.08, 0.87, (0.85 - ring * 0.2) * fading), 4.0 - ring, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 11:
		var angle := TAU * float(i) / 11.0 + progress * 0.55
		var base := center + Vector2(cos(angle) * radius * 0.72, sin(angle) * radius * 0.27)
		var tip := base + Vector2(cos(angle + 0.5) * (20.0 + 23.0 * opening), -30.0 - 52.0 * opening)
		draw_line(base, tip, Color(0.37, 0.20, 0.54, 0.72 * fading), 7.0 * (1.0 - progress * 0.55), true)
		draw_circle(tip, 2.0 + 2.0 * opening, Color(0.87, 0.69, 0.95, 0.85 * fading))
