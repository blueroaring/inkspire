extends Button
## A winged spark inside a circular seal, matching the finale's hope ornament.
var charges := 0
var first_gain := false
var age := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(72, 72)
	size = custom_minimum_size
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())

func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= size.x * 0.5

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	age += delta
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var gold := Color("ffe0a0") if not disabled else Color("857c8b")
	var pulse := (0.5 + 0.5 * sin(age * 3.8)) if first_gain and not disabled else 0.0
	if first_gain and not disabled:
		for ring in 6:
			draw_arc(c, 37.0 + ring * 1.6, 0, TAU, 64, Color(gold, (0.12 + pulse * 0.12) * (1.0 - ring / 6.0)), 2.5, true)
	draw_circle(c, 35, Color("201e30"))
	draw_circle(c, 31, Color("634c45") if is_hovered() and not disabled else Color("39303c"))
	draw_arc(c, 34, 0, TAU, 64, gold, 2.0 + pulse, true)
	draw_arc(c, 29, 0, TAU, 64, Color(gold, 0.35), 1.0, true)
	var offset := Vector2(0, 2) if button_pressed else Vector2.ZERO
	for side in [-1, 1]:
		for feather in 3:
			var a := c + offset + Vector2(side * (5 + feather * 3), 11 - feather * 2)
			var b := c + offset + Vector2(side * (23 - feather * 3), -12 - feather * 3)
			draw_line(a, b, gold, 3.0, true)
	var spark := c + offset + Vector2(0, -3)
	draw_colored_polygon(PackedVector2Array([spark + Vector2(0, -21), spark + Vector2(7, 0), spark + Vector2(0, 19), spark + Vector2(-7, 0)]), gold)
	draw_line(spark + Vector2(0, -12), spark + Vector2(0, 9), Color("fff7df"), 2, true)
	if has_focus(): draw_arc(c, 39, 0, TAU, 64, Color.WHITE, 2, true)
	if charges > 0:
		var badge := Vector2(61, 60)
		draw_circle(badge, 12, Color("201e30"))
		draw_arc(badge, 12, 0, TAU, 32, gold, 1.5, true)
		var font := get_theme_font("font")
		var words := str(charges)
		var width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(font, badge + Vector2(-width * 0.5, 6), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, gold)
