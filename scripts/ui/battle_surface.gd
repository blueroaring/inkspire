extends Control
## Static tactile overlay. Its own shader never touches text, icons or input.
const MATERIAL := preload("res://assets/shaders/battle_material.gdshader")
var accent := Color("c1aa79")
var ornate := false
var family := "paper"
var profile := "panel"
var corner_radius := 6.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = MATERIAL
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 12 or h < 12: return
	material.set_shader_parameter("surface_size", size)
	material.set_shader_parameter("accent", accent)
	material.set_shader_parameter("family", {"quill":1, "orbit":2, "wing":3, "diamond":4, "shield":5, "track":6, "serpent":7}.get(family, 0))
	material.set_shader_parameter("strength", 1.35 if ornate else 0.85)
	var points := PackedVector2Array()
	if profile == "ticket":
		points = PackedVector2Array([Vector2(13, 2), Vector2(w - 19, 2), Vector2(w - 2, h / 2), Vector2(w - 19, h - 2), Vector2(13, h - 2), Vector2(2, h / 2)])
	elif profile == "energy":
		points = PackedVector2Array([Vector2(30, 9), Vector2(w - 9, 9), Vector2(w - 2, 16), Vector2(w - 2, h - 11), Vector2(w - 9, h - 4), Vector2(30, h - 4)])
	elif profile in ["ally", "turn", "utility", "guard_badge", "guard_personal"]:
		var cut := 12.0 if profile == "ally" else 6.0
		var left := 2.0
		points = PackedVector2Array([Vector2(left + cut, 2), Vector2(w - cut - 2, 2), Vector2(w - 2, cut + 2), Vector2(w - 2, h - cut - 2), Vector2(w - cut - 2, h - 2), Vector2(left + cut, h - 2), Vector2(left, h - cut - 2), Vector2(left, cut + 2)])
	else:
		var r := clampf(corner_radius, 2.0, minf(w, h) * 0.5 - 2)
		var centers := [Vector2(w - r - 2, r + 2), Vector2(w - r - 2, h - r - 2), Vector2(r + 2, h - r - 2), Vector2(r + 2, r + 2)]
		for corner in 4:
			for step in 7:
				points.append(centers[corner] + Vector2.from_angle(-PI * 0.5 + corner * PI * 0.5 + step * PI / 12.0) * r)
	# Capsule-sized panels make adjacent corner endpoints coincide. Repeated
	# vertices break canvas triangulation during layout and short badge renders.
	var outline := PackedVector2Array()
	for point in points:
		if outline.is_empty() or outline[-1].distance_squared_to(point) > 0.0001:
			outline.append(point)
	if outline.size() > 1 and outline[0].distance_squared_to(outline[-1]) <= 0.0001:
		outline.remove_at(outline.size() - 1)
	var uv := PackedVector2Array()
	for point in outline: uv.append(point / size)
	draw_polygon(outline, PackedColorArray([Color.WHITE]), uv)
