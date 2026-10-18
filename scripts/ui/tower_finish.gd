extends Control
## Architectural brass + stitched school folio. Decoration never intercepts input.
const MOTIF := preload("res://scripts/ui/battle_frame_motif.gd")
var compact := false
var primary := false
var hovered := false
var family := "quill"
const BRASS := Color("b39760")
const INK := Color("304853")

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	if get_parent() is Button:
		get_parent().mouse_entered.connect(func(): hovered = true; queue_redraw())
		get_parent().mouse_exited.connect(func(): hovered = false; queue_redraw())

func _draw() -> void:
	var w := size.x
	var h := size.y
	var gold := BRASS.lightened(0.24) if hovered else BRASS
	if compact:
		# Ticket edges, pressed brass corners and a small library-index notch.
		for side in [-1, 1]:
			var x := 6.0 if side == 1 else w - 6.0
			draw_polyline(PackedVector2Array([Vector2(x + side * 18, 4), Vector2(x + side * 5, 4), Vector2(x, 10), Vector2(x, h - 10), Vector2(x + side * 5, h - 4), Vector2(x + side * 18, h - 4)]), Color(gold, 0.72), 1, true)
		draw_line(Vector2(28, h - 6), Vector2(w - 28, h - 6), Color(gold, 0.35), 1, true)
		return
	# The folio's spine has cloth, inset rails and stitches; the opposite edge
	# exposes several offset sheets instead of a generic rounded rectangle.
	draw_style_box(preload("res://scripts/ui/battle_theme.gd").frame(INK, BRASS, 1, 4), Rect2(0, 0, 14, h))
	for y in range(20, int(h) - 15, 16):
		draw_line(Vector2(5, y), Vector2(9, y + 5), Color(gold, 0.65), 1, true)
	for i in 3:
		draw_line(Vector2(w - 4 - i * 3, 22), Vector2(w - 4 - i * 3, h - 18), Color(INK, 0.22 + i * 0.08), 1, true)
	# Stepped, inset tower corners echo a school clock tower's buttresses.
	for item in [[Vector2(18, 9), Vector2.ONE], [Vector2(w - 15, 9), Vector2(-1, 1)], [Vector2(18, h - 9), Vector2(1, -1)], [Vector2(w - 15, h - 9), Vector2(-1, -1)]]:
		var o: Vector2 = item[0]
		var d: Vector2 = item[1]
		var points := PackedVector2Array()
		for p in [Vector2(0, 45), Vector2(0, 16), Vector2(7, 16), Vector2(7, 7), Vector2(16, 7), Vector2(16, 0), Vector2(55, 0)]: points.append(o + p * d)
		draw_polyline(points, gold, 2, true)
		draw_circle(o + Vector2(13, 13) * d, 2.2, INK)
		draw_circle(o + Vector2(13, 13) * d, 1.1, gold.lightened(0.4))
	draw_line(Vector2(86, 10), Vector2(w - 83, 10), Color(gold, 0.42), 1, true)
	draw_line(Vector2(86, h - 10), Vector2(w - 83, h - 10), Color(gold, 0.42), 1, true)
	# Tiny finial at the bottom binding, kept outside content rectangles.
	var c := Vector2(w * 0.5, h - 10)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(4, 0), c + Vector2(0, 6), c + Vector2(-4, 0)]), gold)

static func decorate(node: Control) -> void:
	node.get_node("SurfaceArt").hide()
	var material_layer := ColorRect.new()
	material_layer.name = "FolioPaper"
	material_layer.position = Vector2(5, 3)
	material_layer.size = node.size - Vector2(10, 6)
	material_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://assets/shaders/battle_result_material.gdshader")
	shader.set_shader_parameter("surface_size", material_layer.size)
	shader.set_shader_parameter("base_tint", Color("dfdfd1"))
	shader.set_shader_parameter("metal_tint", Color("b79863"))
	shader.set_shader_parameter("finish", 0)
	shader.set_shader_parameter("radius", 6.0)
	material_layer.material = shader
	node.add_child(material_layer)
	var finish: Control = load("res://scripts/ui/tower_finish.gd").new()
	finish.size = node.size
	node.add_child(finish)
