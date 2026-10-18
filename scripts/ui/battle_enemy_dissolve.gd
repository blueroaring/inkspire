extends Node2D
## Freeze the actual body frame, erode its silhouette and lift fragments from it.
var progress := 0.0:
	set(value):
		progress = value
		if is_instance_valid(body): body.material.set_shader_parameter("progress", value)
		queue_redraw()
var body: Sprite2D
var fragments: Array[Dictionary] = []
var duration := 3.2

func configure(source: AnimatedSprite2D) -> void:
	name = "BossDissolve"
	var texture := source.sprite_frames.get_frame_texture(source.animation, source.frame)
	var pixels := texture.get_image()
	body = Sprite2D.new()
	body.texture = ImageTexture.create_from_image(pixels)
	body.centered = false
	body.offset = source.offset
	body.position = source.position
	body.scale = source.scale
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://assets/shaders/enemy_dissolve.gdshader")
	body.material = shader
	add_child(body)
	# A local seed gives a stable pattern without changing combat randomness.
	var random := RandomNumberGenerator.new()
	random.seed = 72317
	for y in range(6, pixels.get_height(), 12):
		for x in range(6, pixels.get_width(), 12):
			var color := pixels.get_pixel(x, y)
			if color.a < 0.5 or random.randf() > 0.62: continue
			fragments.append({
				"origin":source.position + (source.offset + Vector2(x, y)) * source.scale,
				"start":float(y) / pixels.get_height() * 0.58 + random.randf_range(0.0, 0.2),
				"drift":Vector2(random.randf_range(-70, 70), random.randf_range(-140, -65)),
				"size":random.randf_range(1.0, 3.2),
				"color":Color("b69aea").lerp(Color("ffe6b1"), random.randf() * 0.8),
			})

func play() -> void:
	await Settings.battle_tween(self).tween_property(self, "progress", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).finished
	queue_free()

func _draw() -> void:
	for fragment in fragments:
		var age := (progress - float(fragment.start)) / 0.25
		if age <= 0.0 or age >= 1.0: continue
		var point: Vector2 = fragment.origin + fragment.drift * age
		point.x += sin(age * 5.0 + fragment.origin.y) * 7.0
		var color: Color = fragment.color
		color.a = sin(age * PI) * 0.85
		draw_circle(point, float(fragment.size) * (1.0 - age * 0.5), color)
