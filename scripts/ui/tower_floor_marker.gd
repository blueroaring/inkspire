extends Control
var selected := false
var unlocked := true
var milestone := false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _draw() -> void:
	var gold := Color("b09152") if unlocked else Color("a1aaa4")
	var ink := Color("334d58")
	var paper := Color("e8e4ce") if selected else Color("d8dfd5") if unlocked else Color("c9d2cc")
	# One connected architectural rail; each floor is a projecting landing.
	draw_rect(Rect2(30, -5, 82, 91), Color("708c8e"))
	for x in [32, 37, 105, 110]: draw_line(Vector2(x, -5), Vector2(x, 85), Color(gold, 0.7), 1, true)
	var silhouette := PackedVector2Array([Vector2(134, 7), Vector2(518, 7), Vector2(541, 30), Vector2(541, 65), Vector2(134, 65), Vector2(120, 51), Vector2(104, 51), Vector2(104, 28), Vector2(120, 28)])
	draw_colored_polygon(silhouette, paper)
	var outline := silhouette.duplicate()
	outline.append(outline[0])
	draw_polyline(outline, gold, 2 if selected else 1, true)
	draw_line(Vector2(146, 13), Vector2(508, 13), Color(gold, 0.35), 1, true)
	draw_colored_polygon(PackedVector2Array([Vector2(20, 72), Vector2(118, 72), Vector2(130, 80), Vector2(10, 80)]), ink)
	draw_line(Vector2(20, 71), Vector2(118, 71), gold, 2, true)
	var center := Vector2(71, 37)
	draw_circle(center + Vector2(0, 3), 31, Color(ink, 0.45))
	draw_circle(center, 31, ink if unlocked else Color("7d9292"))
	draw_arc(center, 30, 0, TAU, 64, gold, 2, true)
	draw_arc(center, 26, 0, TAU, 64, Color(gold, 0.55), 1, true)
	for i in 12:
		var ray := Vector2.from_angle(TAU * i / 12)
		draw_line(center + ray * 28, center + ray * 31, gold, 1, true)
	if milestone:
		draw_colored_polygon(PackedVector2Array([Vector2(64, 5), Vector2(71, -2), Vector2(78, 5), Vector2(71, 12)]), gold)
