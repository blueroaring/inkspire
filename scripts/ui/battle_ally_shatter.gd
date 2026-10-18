extends Node2D
signal finished
var texture: Texture2D
var fragments: Array[Dictionary] = []
var age := 0.0
var duration := 1.35
var accent := Color("c9b9ef")

func configure(source: Texture2D, rect: Rect2, seed_value: int) -> void:
	texture = source
	position = rect.position
	z_index = 65
	var fit := minf(rect.size.x / texture.get_width(), rect.size.y / texture.get_height())
	var extent := texture.get_size() * fit
	var offset := (rect.size - extent) * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var points: Array[Vector2] = []
	for y in 7:
		for x in 5:
			var uv := Vector2(x / 4.0, y / 6.0)
			if x > 0 and x < 4: uv.x += rng.randf_range(-0.06, 0.06)
			if y > 0 and y < 6: uv.y += rng.randf_range(-0.05, 0.05)
			points.append(uv)
	var pixels := texture.get_image()
	for y in 6:
		for x in 4:
			var a := y * 5 + x
			for indices in [[a, a + 1, a + 5], [a + 1, a + 6, a + 5]]:
				var uv := PackedVector2Array([points[indices[0]], points[indices[1]], points[indices[2]]])
				var midpoint := (uv[0] + uv[1] + uv[2]) / 3.0
				if pixels.get_pixel(mini(int(midpoint.x * pixels.get_width()), pixels.get_width() - 1), mini(int(midpoint.y * pixels.get_height()), pixels.get_height() - 1)).a < 0.08: continue
				var center := offset + midpoint * extent
				fragments.append({"uv":uv, "points":PackedVector2Array([offset + uv[0] * extent - center, offset + uv[1] * extent - center, offset + uv[2] * extent - center]), "center":center,
					"velocity":(midpoint - Vector2(0.5, 0.45)) * Vector2(95, 80) + Vector2(rng.randf_range(-18, 18), -24), "spin":rng.randf_range(-2.4, 2.4)})

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	age += delta
	queue_redraw()
	if age >= duration:
		finished.emit()
		queue_free()

func _draw() -> void:
	var t := maxf(0.0, age - 0.12)
	var fade := 1.0 - smoothstep(0.45, duration - 0.12, t)
	for fragment in fragments:
		var center: Vector2 = fragment.center + fragment.velocity * t + Vector2(0, 72 * t * t)
		var polygon := PackedVector2Array()
		for point in fragment.points: polygon.append(center + (point as Vector2).rotated(float(fragment.spin) * t))
		draw_polygon(polygon, PackedColorArray([Color(1, 1, 1, fade)]), fragment.uv, texture)
		if age < 0.32:
			draw_polyline(polygon + PackedVector2Array([polygon[0]]), Color(accent, (1.0 - age / 0.32) * 0.85), 1.0, true)
