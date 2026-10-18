extends Button
## Circular four-sector charge dial with a raised fist and broken cuff.
var charges := 0:
	set(value):
		charges = clampi(value, 0, 4)
		set_meta("lit_blocks", charges)
		queue_redraw()
var available := false:
	set(value):
		available = value
		queue_redraw()

func _ready() -> void:
	name = "PhantomAssistRelease"
	size = Vector2(88, 88)
	custom_minimum_size = size
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _draw() -> void:
	var lit := Color("f4be75")
	var edge := Color("f6d4a1") if available else Color("937a70")
	var center := Vector2(44, 44)
	draw_circle(center, 41, Color("161e2b"))
	draw_arc(center, 41, 0, TAU, 80, edge, 2.0, true)
	for i in 4:
		var start := -PI * 0.5 + i * PI * 0.5 + 0.045
		var end := start + PI * 0.5 - 0.09
		var sector := PackedVector2Array([center])
		for step in 25: sector.append(center + Vector2.from_angle(lerpf(start, end, step / 24.0)) * 36)
		draw_colored_polygon(sector, lit if i < charges else Color("343b49"))
		draw_arc(center, 33, start, end, 24, Color("ffedbf", 0.38) if i < charges else Color("777e88", 0.2), 1, true)
	# Fist and broken cuff distinguish this aid from Anya's winged spark.
	draw_colored_polygon(PackedVector2Array([Vector2(34,61),Vector2(32,48),Vector2(25,42),Vector2(25,34),Vector2(32,34),Vector2(32,25),Vector2(39,23),Vector2(44,25),Vector2(49,23),Vector2(56,26),Vector2(60,33),Vector2(59,47),Vector2(53,54),Vector2(54,61)]), Color("242534"))
	draw_line(Vector2(39,27), Vector2(39,37), edge, 1.5, true)
	draw_line(Vector2(47,27), Vector2(47,37), edge, 1.5, true)
	draw_line(Vector2(55,29), Vector2(55,38), edge, 1.5, true)
	draw_line(Vector2(29,38), Vector2(40,44), edge, 2, true)
	draw_line(Vector2(29,64), Vector2(40,66), edge, 3, true)
	draw_line(Vector2(48,66), Vector2(59,63), edge, 3, true)
	if is_hovered() or has_focus(): draw_arc(center, 43, 0, TAU, 80, Color("fff0ca"), 2, true)

func _has_point(point: Vector2) -> bool:
	return point.distance_to(Vector2(44, 44)) <= 43
