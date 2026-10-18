extends Control
## Small vector HUD symbols, drawn at viewport resolution.
var kind := "energy"
var accent := Color("edc66c")
var paper_style := false
const REBIRTH_ICON := preload("res://assets/graphics/battle/anya/icons/rebirth.webp")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var factor := minf(size.x, size.y) / 64.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * factor)
	match kind:
		"": pass
		"darkness":
			_poly([Vector2(12, 6), Vector2(48, 6), Vector2(52, 58), Vector2(16, 58)], accent.darkened(0.6))
			_line([Vector2(12, 6), Vector2(48, 6), Vector2(52, 58), Vector2(16, 58), Vector2(12, 6)], accent, 2)
			draw_arc(Vector2(32, 32), 15, PI * 1.1, PI * 1.9, 24, accent, 3, true)
			draw_arc(Vector2(32, 24), 15, PI * 0.1, PI * 0.9, 24, accent, 3, true)
			_line([Vector2(12, 49), Vector2(52, 13)], accent.lightened(0.6), 4)
		"curse":
			_poly([Vector2(14, 5), Vector2(48, 5), Vector2(48, 47), Vector2(39, 58), Vector2(14, 58)], accent.darkened(0.45))
			_line([Vector2(14, 5), Vector2(48, 5), Vector2(48, 47), Vector2(39, 58), Vector2(14, 58), Vector2(14, 5)], accent, 2)
			_poly([Vector2(32, 14), Vector2(45, 39), Vector2(19, 39)], accent)
			draw_line(Vector2(32, 22), Vector2(32, 30), Color("172534"), 3, true)
			draw_circle(Vector2(32, 35), 1.8, Color("172534"))
		"trojan":
			_poly([Vector2(14, 6), Vector2(50, 6), Vector2(50, 58), Vector2(14, 58)], accent.darkened(0.55))
			_line([Vector2(14, 6), Vector2(50, 6), Vector2(50, 58), Vector2(14, 58), Vector2(14, 6)], accent, 2)
			draw_circle(Vector2(32, 34), 10, accent)
			draw_circle(Vector2(32, 20), 6, accent)
			for y in [25, 34, 43]:
				_line([Vector2(10, y - 4), Vector2(22, y), Vector2(42, y), Vector2(54, y - 4)], accent, 2)
			draw_line(Vector2(32, 25), Vector2(32, 43), accent.darkened(0.65), 2, true)
		"rebirth":
			draw_texture_rect(REBIRTH_ICON, Rect2(1, 1, 62, 62), false, Color(1, 1, 1, 0.95))
			draw_circle(Vector2(32, 32), 18, Color(0.06, 0.08, 0.14, 0.88))
			draw_arc(Vector2(32, 32), 19, 0, TAU, 40, Color("e7bd7a"), 1.5, true)
		"stun":
			draw_arc(Vector2(32, 32), 20, 0.2, TAU - 0.5, 48, accent, 3, true)
			draw_arc(Vector2(32, 32), 11, -PI, PI * 0.6, 32, accent, 3, true)
			draw_circle(Vector2(32, 32), 3, accent)
			for point in [Vector2(13, 12), Vector2(53, 20), Vector2(25, 56)]:
				_poly([point + Vector2(0, -7), point + Vector2(2, -2), point + Vector2(7, 0), point + Vector2(2, 2), point + Vector2(0, 7), point + Vector2(-2, 2), point + Vector2(-7, 0), point + Vector2(-2, -2)], accent)
		"attribute_none":
			# Yin and yang stays legible at the small attribute badge size.
			var dark := Color("172534")
			var light := Color("f1e7ce")
			draw_circle(Vector2(32, 32), 27, dark)
			var half: Array[Vector2] = [Vector2(32, 32)]
			for i in 33: half.append(Vector2(32, 32) + Vector2.from_angle(-PI*0.5+PI*i/32.0)*27)
			_poly(half, light)
			draw_circle(Vector2(32, 18.5), 13.5, light)
			draw_circle(Vector2(32, 45.5), 13.5, dark)
			draw_circle(Vector2(32, 18.5), 4.5, dark)
			draw_circle(Vector2(32, 45.5), 4.5, light)
			draw_arc(Vector2(32, 32), 28, 0, TAU, 64, Color("d5b475"), 2.5, true)
		"energy":
			draw_circle(Vector2(32, 34), 29, Color(0, 0, 0, 0.18 if paper_style else 0.45))
			for radius in range(28, 0, -1):
				var color := Color("aebfc0").lerp(accent, 0.28 - float(28 - radius) / 28.0 * 0.16) if paper_style else Color("263c54").lerp(accent.darkened(0.3), float(28 - radius) / 28.0)
				draw_circle(Vector2(32, 31), radius, color)
			draw_arc(Vector2(32, 31), 27, 0, TAU, 64, accent.darkened(0.25) if paper_style else accent, 1.5, true)
			draw_arc(Vector2(32, 31), 22, PI * 1.1, PI * 1.8, 32, Color("8fb2c0") if paper_style else accent.lightened(0.6), 1.0, true)
			_poly([Vector2(39, 11), Vector2(22, 33), Vector2(31, 33), Vector2(25, 52), Vector2(45, 27), Vector2(35, 27)], Color(accent, 0.18))
		"attack":
			draw_circle(Vector2(33, 30), 28, Color(accent, 0.10))
			_poly([Vector2(19, 39), Vector2(42, 9), Vector2(55, 5), Vector2(55, 19), Vector2(29, 46)], accent)
			draw_line(Vector2(28, 37), Vector2(49, 14), accent.lightened(0.75), 3, true)
			_line([Vector2(13, 35), Vector2(35, 53)], Color("ffe3b1"), 5)
			_line([Vector2(23, 46), Vector2(12, 58)], Color("c98263"), 6)
		"debuff":
			_poly([Vector2(32, 6), Vector2(54, 17), Vector2(49, 40), Vector2(32, 56), Vector2(15, 40), Vector2(10, 17)], accent)
			_line([Vector2(32, 16), Vector2(32, 42)], Color("171528"), 6)
			_line([Vector2(23, 33), Vector2(32, 43), Vector2(41, 33)], Color("171528"), 6)
		"split":
			_line([Vector2(32, 56), Vector2(32, 32), Vector2(13, 12)], accent, 6)
			_line([Vector2(32, 32), Vector2(51, 12)], accent, 6)
			_poly([Vector2(8, 28), Vector2(8, 7), Vector2(29, 7)], accent)
			_poly([Vector2(35, 7), Vector2(56, 7), Vector2(56, 28)], accent)
		"healing":
			draw_circle(Vector2(32, 32), 27, Color(accent, 0.12))
			_poly([Vector2(25, 10), Vector2(39, 10), Vector2(39, 25), Vector2(54, 25), Vector2(54, 39), Vector2(39, 39), Vector2(39, 54), Vector2(25, 54), Vector2(25, 39), Vector2(10, 39), Vector2(10, 25), Vector2(25, 25)], accent)
			draw_line(Vector2(29, 14), Vector2(29, 29), accent.lightened(0.7), 2, true)
			draw_line(Vector2(14, 29), Vector2(29, 29), accent.lightened(0.7), 2, true)
		"shield", "temporary", "shield_break":
			_poly([Vector2(32, 5), Vector2(55, 14), Vector2(50, 42), Vector2(32, 59), Vector2(14, 42), Vector2(9, 14)], accent.darkened(0.55))
			_line([Vector2(32, 5), Vector2(55, 14), Vector2(50, 42), Vector2(32, 59), Vector2(14, 42), Vector2(9, 14), Vector2(32, 5)], accent, 3)
			if kind == "temporary":
				_line([Vector2(23, 19), Vector2(41, 19), Vector2(23, 44), Vector2(41, 44), Vector2(23, 19)], accent.lightened(0.6), 3)
			elif kind == "shield_break":
				_line([Vector2(37, 10), Vector2(25, 27), Vector2(38, 32), Vector2(26, 53)], Color("f4dfbf"), 3)
			else:
				_line([Vector2(32, 16), Vector2(32, 47)], accent.lightened(0.65), 3)
		"all":
			for point in [Vector2(14, 28), Vector2(32, 18), Vector2(50, 28)]:
				draw_circle(point, 5, accent)
				draw_arc(point + Vector2(0, 15), 8, PI, TAU, 16, accent, 4, true)
		"bounce":
			_line([Vector2(6, 42), Vector2(22, 21), Vector2(39, 42), Vector2(57, 19)], accent, 4)
			_poly([Vector2(45, 18), Vector2(58, 18), Vector2(57, 31)], accent)
		"wait":
			for x in [16, 32, 48]: draw_circle(Vector2(x, 32), 5, accent)
		"target":
			draw_arc(Vector2(32, 32), 16, 0, TAU, 32, accent, 3, true)
			draw_line(Vector2(32, 7), Vector2(32, 23), accent, 3, true)
			draw_line(Vector2(32, 41), Vector2(32, 57), accent, 3, true)
			draw_line(Vector2(7, 32), Vector2(23, 32), accent, 3, true)
			draw_line(Vector2(41, 32), Vector2(57, 32), accent, 3, true)
		"retain":
			_poly([Vector2(16, 6), Vector2(48, 6), Vector2(48, 58), Vector2(32, 46), Vector2(16, 58)], accent.darkened(0.2))
			_line([Vector2(20, 11), Vector2(44, 11), Vector2(44, 49), Vector2(32, 40), Vector2(20, 49), Vector2(20, 11)], accent.lightened(0.6), 2)
			_line([Vector2(26, 21), Vector2(38, 21)], accent.lightened(0.8), 3)
		"enchant":
			_poly([Vector2(31, 8), Vector2(48, 29), Vector2(31, 53), Vector2(14, 29)], accent)
			_poly([Vector2(31, 8), Vector2(31, 53), Vector2(22, 29)], accent.lightened(0.7))
			_line([Vector2(51, 5), Vector2(51, 17)], Color("fff1c0"), 2)
			_line([Vector2(45, 11), Vector2(57, 11)], Color("fff1c0"), 2)
			draw_circle(Vector2(9, 49), 3, Color("fff1c0"))
		"curtain":
			_poly([Vector2(8, 12), Vector2(56, 12), Vector2(52, 39), Vector2(42, 53), Vector2(22, 53), Vector2(12, 39)], accent)
			_line([Vector2(17, 26), Vector2(26, 29)], Color("19182e"), 5)
			_line([Vector2(38, 29), Vector2(47, 26)], Color("19182e"), 5)
			draw_arc(Vector2(32, 35), 9, 0, PI, 16, Color("fff1d0"), 3, true)
		"sealed":
			draw_arc(Vector2(32, 24), 14, PI, TAU, 24, accent.lightened(0.6), 6, true)
			_poly([Vector2(12, 24), Vector2(52, 24), Vector2(52, 56), Vector2(12, 56)], accent)
			draw_circle(Vector2(32, 36), 5, Color("152136"))
			_line([Vector2(32, 38), Vector2(32, 47)], Color("152136"), 4)
		"exhaust":
			_poly([Vector2(16, 7), Vector2(46, 7), Vector2(51, 44), Vector2(39, 39), Vector2(31, 49), Vector2(22, 43), Vector2(13, 52)], accent.darkened(0.25))
			_poly([Vector2(23, 50), Vector2(24, 38), Vector2(31, 29), Vector2(34, 42), Vector2(43, 37), Vector2(39, 55), Vector2(32, 60)], Color("ffcd8e"))
			draw_circle(Vector2(49, 55), 3, accent.lightened(0.5))
			draw_circle(Vector2(14, 60), 2, accent.lightened(0.5))
		"innate":
			for angle in 8:
				var direction := Vector2.from_angle(float(angle) * TAU / 8)
				draw_line(Vector2(32, 32) + direction * 22, Vector2(32, 32) + direction * 28, accent, 3, true)
			_poly([Vector2(32, 13), Vector2(38, 26), Vector2(51, 32), Vector2(38, 38), Vector2(32, 51), Vector2(26, 38), Vector2(13, 32), Vector2(26, 26)], accent.lightened(0.5))
		"counterfeit":
			_poly([Vector2(8, 6), Vector2(37, 6), Vector2(37, 45), Vector2(8, 45)], accent.darkened(0.5))
			_poly([Vector2(24, 19), Vector2(55, 19), Vector2(55, 58), Vector2(24, 58)], accent)
			_line([Vector2(32, 30), Vector2(47, 30)], accent.lightened(0.7), 3)
		_:
			# Unknown future symbols remain visible instead of silently drawing nothing.
			_line([Vector2(32, 6), Vector2(58, 32), Vector2(32, 58), Vector2(6, 32), Vector2(32, 6)], accent, 3)
			draw_line(Vector2(32, 19), Vector2(32, 34), accent, 4, true)
			draw_circle(Vector2(32, 44), 3, accent)

func _poly(points: Array[Vector2], color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _line(points: Array[Vector2], color: Color, width: float) -> void:
	draw_polyline(PackedVector2Array(points), Color(0.02, 0.025, 0.055, 0.9), width + 3, true)
	draw_polyline(PackedVector2Array(points), color, width, true)
