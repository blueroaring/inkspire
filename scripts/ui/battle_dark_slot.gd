extends Control
## A persistent smoke veil on an occupied or empty blocked hand slot.
var age := 0.0
var animate_in := false

func _ready() -> void:
	size = Vector2(420, 50)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	if animate_in:
		modulate.a = 0.0
		Settings.battle_tween(self).tween_property(self, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	age += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.02, 0.055, 0.57))
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.31, 0.24, 0.46, 0.32), false, 1.5)
	for i in 11:
		var drift := sin(age * (0.7 + float(i % 3) * 0.12) + float(i) * 2.1)
		var x := float(i) * 43.0 - 18.0 + drift * 18.0
		var y := 25.0 + sin(age * 0.9 + float(i) * 1.8) * 12.0
		for layer in 3:
			var radius := 29.0 - layer * 7.0
			var alpha := 0.13 + layer * 0.045
			draw_circle(Vector2(x, y), radius, Color(0.035, 0.025, 0.075, alpha))
	for i in 5:
		var start := Vector2(float(i) * 92.0 - 16.0 + sin(age + i) * 14.0, 10.0 + sin(age * 1.3 + i) * 5.0)
		draw_line(start, start + Vector2(54, 24), Color(0.25, 0.20, 0.38, 0.23), 5.0)
