extends Node2D
## Red-pen score written on the animated examination dial.
const FONT := preload("res://assets/fonts/noto_serif_sc/battle_ui.tres")
const RED := Color("bd2236")
var score := 0:
	set(value):
		score = clampi(value, 0, 100)
		queue_redraw()

func _draw() -> void:
	var number := str(score)
	var size := 56 if score < 100 else 48
	var width := FONT.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := Vector2(-width * 0.5 - 5, 9)
	draw_set_transform(Vector2.ZERO, -0.075)
	draw_string(FONT, baseline + Vector2(1.5, 1), number, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("7c182a", 0.34))
	draw_string(FONT, baseline, number, HORIZONTAL_ALIGNMENT_LEFT, -1, size, RED)
	draw_string(FONT, Vector2(-24, 29), "/100", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(RED, 0.88))
	var tick := PackedVector2Array([Vector2(28, 9), Vector2(38, 18), Vector2(54, -13)])
	draw_polyline(tick, Color(RED, 0.87), 4.0, true)
	draw_line(Vector2(39, 18), Vector2(57, -14), Color(RED, 0.40), 1.5, true)
