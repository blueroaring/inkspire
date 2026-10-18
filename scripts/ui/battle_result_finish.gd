extends Control
## Stationery and metalwork. These cached canvas strokes sit outside text regions.
var victory := true
var kind := "frame"
var gold := Color("b3955f")

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if kind == "seal":
		_seal(size * 0.5)
		return
	if kind == "slip":
		_slip()
		return
	var dark := Color("4e4338") if victory else Color("534956")
	var light := Color("f5e4b7") if victory else Color("e9d6e5")
	# Paired metal rails and bookbinding seam, with inset highlight/shadow.
	for inset in [5.0, 11.0]:
		draw_style_box(_border(Color(gold, 0.8 if inset == 5 else 0.32), 1, 12), Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2))
	draw_line(Vector2(441, 13), Vector2(441, size.y - 13), Color(dark, 0.7), 5, true)
	draw_line(Vector2(438, 13), Vector2(438, size.y - 13), light, 2, true)
	draw_line(Vector2(444, 16), Vector2(444, size.y - 16), Color(gold, 0.6), 1, true)
	for y in range(26, int(size.y) - 22, 12):
		draw_line(Vector2(426, y), Vector2(429, y + 4), Color(gold, 0.47), 1, true)
	# Gilt corner protectors, engraved with a smaller returning line.
	for corner in [Vector2(17, 17), Vector2(size.x - 17, 17), Vector2(17, size.y - 17), size - Vector2(17, 17)]:
		var direction := Vector2(1 if corner.x < size.x * 0.5 else -1, 1 if corner.y < size.y * 0.5 else -1)
		var shape := PackedVector2Array()
		for point in [Vector2(0, 70), Vector2(0, 0), Vector2(70, 0), Vector2(52, 7), Vector2(15, 7), Vector2(7, 15), Vector2(7, 52)]:
			shape.append(corner + point * direction)
		draw_colored_polygon(shape, gold)
		draw_polyline(PackedVector2Array([corner + Vector2(3, 54) * direction, corner + Vector2(3, 3) * direction, corner + Vector2(54, 3) * direction]), Color(light, 0.8), 1, true)
		var stud: Vector2 = corner + Vector2(14, 14) * direction
		draw_circle(stud + Vector2(0, 1), 3.7, dark, true, -1, true)
		draw_circle(stud, 2.4, light, true, -1, true)
	# A low contrast engraved flourish sits in the empty paper margin below the rows.
	var origin := Vector2(906, 565)
	for side in [-1, 1]:
		var curve := PackedVector2Array()
		for i in 49:
			var t := float(i) / 48.0
			curve.append(origin + Vector2(side * (15 + t * 142), sin(t * TAU) * 5))
		draw_polyline(curve, Color(gold, 0.45), 1, true)
	_diamond(origin, Vector2(6, 4), Color(gold, 0.7))

func _slip() -> void:
	draw_line(Vector2(10, 12), Vector2(10, size.y - 12), Color(gold, 0.7), 2, true)
	draw_line(Vector2(14, 12), Vector2(14, size.y - 12), Color(gold, 0.25), 1, true)
	var at := Vector2(size.x - 20, 20)
	_diamond(at, Vector2(4, 6), Color(gold, 0.65))
	draw_line(Vector2(23, size.y - 7), Vector2(size.x - 24, size.y - 7), Color(gold, 0.24), 1, true)

func _seal(center: Vector2) -> void:
	var dark := Color("785a36") if victory else Color("706176")
	var bright := Color("efe1b5") if victory else Color("dfd3e8")
	draw_circle(center + Vector2(0, 3), 48, Color(dark, 0.19), true, -1, true)
	draw_circle(center, 47, dark, true, -1, true)
	draw_circle(center, 45, gold, true, -1, true)
	draw_circle(center, 40, bright, true, -1, true)
	draw_circle(center, 38, gold, true, -1, true)
	for i in 56:
		var angle := TAU * i / 56.0
		var direction := Vector2.from_angle(angle)
		draw_line(center + direction * 41, center + direction * 44, Color(dark, 0.48), 1, true)
	# A pen-nib emblem ties the medal to the school and ink-fragment setting.
	var nib := PackedVector2Array([center + Vector2(0, -24), center + Vector2(14, 3), center + Vector2(0, 22), center + Vector2(-14, 3)])
	draw_colored_polygon(nib, bright)
	draw_polyline(nib + PackedVector2Array([nib[0]]), Color(dark, 0.7), 1.5, true)
	draw_line(center + Vector2(0, 20), center + Vector2(0, -1), dark, 2, true)
	draw_circle(center + Vector2(0, -3), 3, dark, true, -1, true)
	for side in [-1, 1]:
		for i in 5:
			var angle := -0.85 + i * 0.32
			var stem := center + Vector2(side * cos(angle) * 30, sin(angle) * 30 + 5)
			var leaf := PackedVector2Array([stem, stem + Vector2(side * 7, -9), stem + Vector2(side * 10, -2), stem + Vector2(side * 4, 3)])
			draw_colored_polygon(leaf, Color(bright, 0.85))
	if not victory:
		draw_polyline(PackedVector2Array([center + Vector2(-6, -44), center + Vector2(-12, -29), center + Vector2(-5, -20), center + Vector2(-17, -8)]), Color(dark, 0.8), 1.7, true)

func _diamond(center: Vector2, extent: Vector2, tint: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center - Vector2(extent.x, 0), center - Vector2(0, extent.y), center + Vector2(extent.x, 0), center + Vector2(0, extent.y)]), tint)

func _border(tint: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = tint
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.corner_detail = 12
	return box
