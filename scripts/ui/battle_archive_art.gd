extends Control
## Resolution-independent engraving for the battle notebook.
const MOTIF := preload("res://scripts/ui/battle_frame_motif.gd")
var accent := Color("d5ba84")
var emblem := false
var card_frame := false
var item := ""
var family := "orbit"
var seal := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if item != "":
		_draw_item()
		return
	var w := size.x
	var h := size.y
	if seal:
		MOTIF.draw_mark(self, family, size * 0.5, minf(w, h) * 0.42, accent)
		return
	if card_frame:
		draw_polyline(PackedVector2Array([Vector2(7, 35), Vector2(7, 14), Vector2(14, 7), Vector2(35, 7)]), Color(accent, 0.8), 1, true)
		MOTIF.draw_corner(self, family, Vector2(w - 7, h - 7), -Vector2.ONE, Color(accent, 0.8))
		draw_line(Vector2(20, 230), Vector2(w - 20, 230), Color(accent, 0.2), 1, true)
		_diamond(Vector2(w * 0.5, 230), 2.5, Color(accent, 0.65))
		MOTIF.draw_mark(self, family, Vector2(w * 0.5, 17), 9, Color(accent, 0.9))
		for x in [10.0, w - 10]:
			draw_line(Vector2(x, 56), Vector2(x, 140), Color(accent, 0.20), 1, true)
			draw_circle(Vector2(x, 48), 2, Color(accent, 0.7))
		return
	if emblem:
		var c := size * 0.5
		var r := minf(w, h) * 0.43
		for ring in [1.0, 0.89, 0.67]:
			draw_arc(c, r * ring, 0, TAU, 96, Color(accent, 0.2 if ring < 1 else 0.45), 1.2, true)
		for i in 12:
			var d := Vector2.from_angle(i * TAU / 12.0)
			draw_line(c + d * r * 0.92, c + d * r, Color(accent, 0.65), 2, true)
		for i in 4:
			var p := c + Vector2.from_angle(i * PI / 2) * r * 0.91
			MOTIF.draw_mark(self, family, p, 5, Color(accent, 0.8))
		return
	# Ink cloth, fine ruled grain and a restrained brass perimeter.
	for y in range(2, int(h) - 2, 4):
		var light := 0.005 + 0.008 * pow(1.0 - float(y) / h, 3)
		draw_line(Vector2(2, y), Vector2(w - 2, y), Color(accent, light), 1)
	for x in range(20, int(w), 36):
		draw_line(Vector2(x, 4), Vector2(x, h - 4), Color(accent, 0.016), 1)
	for p in [Vector2(12, 12), Vector2(w - 12, 12), Vector2(12, h - 12), Vector2(w - 12, h - 12)]:
		var d := Vector2(1 if p.x < w / 2 else -1, 1 if p.y < h / 2 else -1)
		draw_polyline(PackedVector2Array([p + Vector2(0, d.y * 32), p, p + Vector2(d.x * 46, 0)]), Color(accent, 0.65), 1, true)
		_diamond(p + d * 5, 3, accent)
	draw_line(Vector2(32, 96), Vector2(w - 32, 96), Color(accent, 0.28), 1)
	draw_line(Vector2(32, h - 58), Vector2(w - 32, h - 58), Color(accent, 0.28), 1)
	_diamond(Vector2(w / 2, 96), 4, accent)
	# A large, quiet astrolabe watermark in the header.
	var c := Vector2(w - 225, 44)
	for r in [42, 57, 72]:
		draw_arc(c, r, PI * 0.06, PI * 0.94, 48, Color(accent, 0.08), 1, true)

func _diamond(p: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), color)

func _draw_item() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / 128.0)
	if item == "battle_bandage":
		var points := PackedVector2Array([Vector2(25, 30), Vector2(45, 18), Vector2(102, 86), Vector2(88, 108)])
		draw_colored_polygon(points, Color("e7dbc2"))
		draw_polyline(points + PackedVector2Array([points[0]]), Color("8a8177"), 2, true)
		points = PackedVector2Array([Vector2(89, 18), Vector2(108, 36), Vector2(41, 107), Vector2(20, 90)])
		draw_colored_polygon(points, Color("fff1d6"))
		draw_polyline(points + PackedVector2Array([points[0]]), Color("aa9c82"), 2, true)
		for i in 4:
			draw_line(Vector2(35 + i * 5, 82 - i * 5), Vector2(45 + i * 5, 91 - i * 5), Color("c7bda6"), 1, true)
		draw_circle(Vector2(64, 64), 22, Color("d39189"))
		draw_rect(Rect2(58, 48, 12, 32), Color("fff6e5"))
		draw_rect(Rect2(48, 58, 32, 12), Color("fff6e5"))
	else:
		var tint := Color("8cdbea") if item == "battle_energy" else Color("f3c481")
		var bottle := PackedVector2Array([Vector2(47, 30), Vector2(81, 30), Vector2(81, 43), Vector2(100, 59), Vector2(96, 100), Vector2(83, 112), Vector2(45, 112), Vector2(32, 100), Vector2(28, 59), Vector2(47, 43)])
		draw_colored_polygon(bottle, Color("253c51"))
		draw_polyline(bottle + PackedVector2Array([bottle[0]]), tint, 2.5, true)
		draw_colored_polygon(PackedVector2Array([Vector2(35, 67), Vector2(93, 67), Vector2(89, 98), Vector2(80, 104), Vector2(48, 104), Vector2(40, 96)]), tint.darkened(0.38))
		draw_line(Vector2(36, 65), Vector2(93, 65), tint.lightened(0.4), 2, true)
		draw_line(Vector2(38, 58), Vector2(42, 86), Color("e9ffff", 0.65), 3, true)
		draw_rect(Rect2(44, 16, 40, 17), Color("b9af92"))
		for i in 5: draw_line(Vector2(48 + 7 * i, 18), Vector2(48 + 7 * i, 30), Color("746e62"), 2, true)
		if item == "battle_energy":
			draw_colored_polygon(PackedVector2Array([Vector2(68, 71), Vector2(53, 88), Vector2(63, 88), Vector2(58, 102), Vector2(77, 81), Vector2(66, 81)]), Color("edffef"))
		else:
			for i in 8:
				var d := Vector2.from_angle(i * TAU / 8)
				draw_line(Vector2(64, 84) + d * 6, Vector2(64, 84) + d * 16, Color("fff1b6"), 2, true)
			_diamond(Vector2(64, 84), 9, Color("fff6d1"))
