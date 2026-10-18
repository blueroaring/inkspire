extends RefCounted
## Character emblems share a scale, but use distinct line and silhouette language.
static func draw_corner(canvas: CanvasItem, family: String, origin: Vector2, direction: Vector2, tint: Color) -> void:
	var paths: Array[PackedVector2Array] = []
	match family:
		"serpent":
			paths = [PackedVector2Array([Vector2(0, 34), Vector2(0, 14), Vector2(7, 5), Vector2(19, 0), Vector2(39, 0)]), PackedVector2Array([Vector2(5, 26), Vector2(15, 24), Vector2(20, 18), Vector2(15, 12), Vector2(8, 14), Vector2(9, 20), Vector2(17, 20), Vector2(25, 8), Vector2(32, 7)])]
		"shield":
			paths = [PackedVector2Array([Vector2(0, 34), Vector2(0, 10), Vector2(10, 0), Vector2(39, 0)]), PackedVector2Array([Vector2(7, 7), Vector2(22, 7), Vector2(22, 18), Vector2(14, 26), Vector2(7, 18), Vector2(7, 7)])]
		"track":
			for i in 3:
				paths.append(PackedVector2Array([Vector2(i * 5, 34), Vector2(i * 5, 18 + i * 5), Vector2(18 + i * 5, i * 5), Vector2(39, i * 5)]))
		"wing":
			paths = [PackedVector2Array([Vector2(0, 34), Vector2(0, 17), Vector2(7, 8), Vector2(21, 4), Vector2(39, 4)]), PackedVector2Array([Vector2(5, 24), Vector2(10, 16), Vector2(29, 10)]), PackedVector2Array([Vector2(10, 26), Vector2(16, 19), Vector2(27, 16)])]
		"diamond":
			paths = [PackedVector2Array([Vector2(0, 30), Vector2(0, 13), Vector2(13, 0), Vector2(39, 0)]), PackedVector2Array([Vector2(6, 30), Vector2(6, 17), Vector2(17, 6), Vector2(39, 6)]), PackedVector2Array([Vector2(3, 6), Vector2(6, 0), Vector2(9, 6), Vector2(6, 12), Vector2(3, 6)])]
		"quill":
			paths = [PackedVector2Array([Vector2(0, 30), Vector2(0, 7), Vector2(7, 0), Vector2(39, 0)]), PackedVector2Array([Vector2(7, 24), Vector2(18, 8), Vector2(12, 9), Vector2(7, 17)]), PackedVector2Array([Vector2(22, 6), Vector2(39, 6)])]
		_:
			paths = [PackedVector2Array([Vector2(0, 34), Vector2(0, 13), Vector2(13, 0), Vector2(39, 0)]), PackedVector2Array([Vector2(5, 30), Vector2(5, 16), Vector2(16, 5), Vector2(33, 5)])]
			for i in 3:
				paths.append(PackedVector2Array([Vector2(21 + i * 6, 0), Vector2(21 + i * 6, 4)]))
	for path in paths:
		var transformed := PackedVector2Array()
		for p in path: transformed.append(origin + p * direction)
		canvas.draw_polyline(transformed, tint, 1.2, true)

static func draw_mark(canvas: CanvasItem, family: String, center: Vector2, radius: float, tint: Color) -> void:
	match family:
		"serpent":
			var coil := PackedVector2Array()
			for i in 35:
				var t := float(i) / 34.0
				coil.append(center + Vector2(sin(t * TAU) * 0.60, 0.90 - t * 1.8) * radius)
			canvas.draw_polyline(coil, tint, 1.5, true)
			canvas.draw_polyline(PackedVector2Array([coil[-1] + Vector2(-3, 3), coil[-1] + Vector2(0, -3), coil[-1] + Vector2(5, 0), coil[-1] + Vector2(-3, 3)]), tint, 1.1, true)
		"shield":
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-0.7, -0.75) * radius, center + Vector2(0.7, -0.75) * radius, center + Vector2(0.65, 0.3) * radius, center + Vector2(0, 0.95) * radius, center + Vector2(-0.65, 0.3) * radius, center + Vector2(-0.7, -0.75) * radius]), tint, 1.3, true)
			canvas.draw_line(center + Vector2(0, -0.5) * radius, center + Vector2(0, 0.5) * radius, tint, 1.2, true)
		"track":
			for i in 3:
				var shift := Vector2(-0.55 + i * 0.48, 0) * radius
				canvas.draw_polyline(PackedVector2Array([center + shift + Vector2(-0.25, 0.7) * radius, center + shift + Vector2(0.25, 0) * radius, center + shift + Vector2(-0.25, -0.7) * radius]), tint, 1.3, true)
		"wing":
			for side in [-1, 1]:
				for feather in 3:
					var reach := radius * (1.0 - feather * 0.18)
					canvas.draw_polyline(PackedVector2Array([center + Vector2(side * 2, radius * 0.45), center + Vector2(side * reach * 0.7, -radius * 0.05 + feather * radius * 0.22), center + Vector2(side * reach, -radius * 0.7 + feather * radius * 0.24)]), tint, 1.2, true)
			canvas.draw_arc(center + Vector2(0, -radius * 0.52), radius * 0.22, 0, TAU, 24, tint, 1, true)
		"quill":
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-radius * 0.7, radius * 0.75), center + Vector2(radius * 0.6, -radius * 0.8), center + Vector2(radius * 0.4, radius * 0.05), center + Vector2(-radius * 0.22, radius * 0.34)]), tint, 1.3, true)
			for i in 3:
				var p := center + Vector2(-0.15 + i * 0.19, 0.15 - i * 0.23) * radius
				canvas.draw_line(p, p + Vector2(-0.45, -0.08) * radius, tint, 1, true)
			canvas.draw_line(center + Vector2(-radius, radius * 0.8), center + Vector2(radius * 0.7, radius * 0.8), Color(tint, tint.a * 0.55), 1, true)
		"diamond":
			for scale in [1.0, 0.53]:
				canvas.draw_polyline(PackedVector2Array([center + Vector2(0, -radius * scale), center + Vector2(radius * 0.63 * scale, 0), center + Vector2(0, radius * scale), center + Vector2(-radius * 0.63 * scale, 0), center + Vector2(0, -radius * scale)]), tint, 1.1, true)
			for side in [-1, 1]:
				canvas.draw_circle(center + Vector2(side * radius, 0), 1.6, tint)
		_:
			canvas.draw_arc(center, radius * 0.7, 0, TAU, 36, Color(tint, tint.a * 0.65), 1, true)
			canvas.draw_polyline(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0), center + Vector2(0, -radius)]), tint, 1.2, true)
			canvas.draw_line(center + Vector2(-radius * 0.3, 0), center + Vector2(radius * 0.3, 0), tint, 1, true)
			canvas.draw_line(center + Vector2(0, -radius * 0.3), center + Vector2(0, radius * 0.3), tint, 1, true)
