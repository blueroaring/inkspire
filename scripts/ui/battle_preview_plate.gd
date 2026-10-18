extends Panel
## Forecast plates share the battle's enamel, grain and engraved trim.
const THEME := preload("res://scripts/ui/battle_theme.gd")
const MOTIF := preload("res://scripts/ui/battle_frame_motif.gd")
var kind := "target"
var accent := Color("806037")
var fill := Color("d0c5ad")
var family := "quill"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	resized.connect(queue_redraw)
	if kind != "loss":
		var surface := THEME.decorate(self, accent, true)
		surface.family = family
		surface.profile = "ally"
		surface.modulate.a = 0.65
	queue_redraw()

func _outline(rect: Rect2, cut: float) -> PackedVector2Array:
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([p + Vector2(cut, 0), Vector2(e.x-cut, p.y), Vector2(e.x, p.y+cut), e-Vector2(0, cut), e-Vector2(cut, 0), Vector2(p.x+cut, e.y), Vector2(p.x, e.y-cut), p+Vector2(0, cut)])

func _draw() -> void:
	if size.x < 1 or size.y < 1: return
	if kind == "loss":
		draw_rect(Rect2(Vector2.ZERO, size), Color(accent, 0.28))
		for x in range(-int(size.y), int(size.x), 10):
			var start := Vector2(maxf(x, 0), maxf(-x, 0))
			var end := Vector2(minf(x + size.y, size.x), size.y - maxf(x + size.y - size.x, 0))
			draw_line(start, end, Color(accent, 0.4), 1, true)
		draw_line(Vector2(0, 2), Vector2(0, size.y-2), accent, 2, true)
		draw_line(Vector2(0, size.y-1), size-Vector2(1, 1), accent, 2, true)
		return
	var w := size.x
	var h := size.y
	var cut := 7.0 if kind == "ribbon" else 11.0
	draw_colored_polygon(_outline(Rect2(Vector2(0, 4), size), cut), Color("060d18", 0.38))
	var rim := _outline(Rect2(Vector2.ZERO, size), cut)
	draw_colored_polygon(rim, fill)
	rim.append(rim[0])
	draw_polyline(rim, Color(accent, 0.85), 1.4, true)
	var inset := _outline(Rect2(Vector2(4, 4), size-Vector2(8, 8)), cut-3)
	inset.append(inset[0])
	draw_polyline(inset, Color("faf0d4", 0.45), 1, true)
	draw_line(Vector2(cut+2, 2), Vector2(w-cut-2, 2), Color("fff3d6", 0.7), 1, true)
	draw_line(Vector2(cut+2, h-3), Vector2(w-cut-2, h-3), Color(accent, 0.4), 1, true)
	draw_line(Vector2(2, cut+2), Vector2(2, h-cut-2), accent, 3, true)
	if kind == "target":
		draw_rect(Rect2(6, 6, w-12, 23), Color(accent, 0.08))
		draw_line(Vector2(14, 30), Vector2(w-14, 30), Color(accent, 0.22), 1, true)
		draw_line(Vector2(w*0.5, 40), Vector2(w*0.5, 77), Color(accent, 0.24), 1, true)
		draw_rect(Rect2(7, h-27, w-14, 20), Color(accent, 0.09))
		draw_line(Vector2(w*0.5, h+1), Vector2(w*0.5, h+6), Color(accent, 0.8), 1, true)
	elif kind == "target_compact":
		draw_line(Vector2(w*0.5, 10), Vector2(w*0.5, 30), Color(accent, 0.24), 1, true)
		draw_line(Vector2(14, 35), Vector2(w-14, 35), Color(accent, 0.22), 1, true)
		draw_rect(Rect2(7, 37, w-14, 20), Color(accent, 0.09))
	elif kind == "summary":
		draw_line(Vector2(586, 15), Vector2(586, h-15), Color(accent, 0.3), 1, true)
		MOTIF.draw_corner(self, family, Vector2(w-9, h-9), -Vector2.ONE, Color(accent, 0.65))
	elif kind == "drag":
		draw_line(Vector2(81, 13), Vector2(81, h-13), Color(accent, 0.25), 1, true)
	elif kind == "ribbon":
		for fraction in [0.32, 0.63]:
			draw_line(Vector2(w*fraction, 8), Vector2(w*fraction, h-8), Color(accent, 0.24), 1, true)
