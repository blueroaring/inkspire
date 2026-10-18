extends Control
## Draws the advancing char line over a card travelling to the exhausted pile.
var progress := 0.0
var reason := "消耗"

func _ready() -> void:
	name = "CardBurn"
	size = Vector2(420, 50)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption := Label.new()
	caption.name = "BurnReason"
	caption.text = reason
	caption.position = Vector2(280, 7)
	caption.size = Vector2(126, 36)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_color", Color("ffd4a0"))
	caption.add_theme_color_override("font_outline_color", Color("24131a"))
	caption.add_theme_constant_override("outline_size", 4)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)

func _draw() -> void:
	var edge := size.x * clampf(progress, 0.0, 1.0)
	if edge <= 0.0: return
	draw_rect(Rect2(0, 0, edge, size.y), Color(0.08, 0.055, 0.09, 0.92))
	for i in 7:
		var y := 5.0 + i * 7.0
		var tip := edge + 5.0 + sin(float(i) * 2.7 + progress * 14.0) * 9.0
		draw_line(Vector2(edge - 15, y), Vector2(tip, y - 4), Color("ff9756", 0.88), 3.0)
		draw_circle(Vector2(tip + 4, y - 7 - sin(progress * 11.0 + i) * 5.0), 2.5, Color("ffe4a4", 0.8))
	draw_line(Vector2(edge, 0), Vector2(edge, size.y), Color("ffcf75", 0.86), 3.0)
