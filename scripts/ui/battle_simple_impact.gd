extends Node2D
## One lightweight contact mark shared by every side, element and attack strength.
const DURATION := 0.22
const TINT := Color("f4dfb1")
var age := 0.0

func _ready() -> void:
	name = "SimpleBattleImpact"
	z_index = 9
	queue_redraw()

func _process(delta: float) -> void:
	age += delta * Settings.battle_effect_speed()
	if age >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(age / DURATION, 0.0, 1.0)
	var tint := Color(TINT, 1.0 - t)
	var radius := lerpf(12.0, 42.0, t)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 24, tint, 2.0, true)
	for i in 4:
		var direction := Vector2.from_angle(PI * 0.25 + i * PI * 0.5)
		draw_line(direction * (radius + 4), direction * (radius + 14), tint, 3.0, true)
