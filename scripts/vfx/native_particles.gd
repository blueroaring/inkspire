extends RefCounted
## Shared, bounded CPU particle presets for the Compatibility renderer.
static var _soft: GradientTexture2D
static var _spark: GradientTexture2D
static var _meshes: Dictionary = {}

static func texture(streak: bool = false) -> GradientTexture2D:
	if streak and _spark != null: return _spark
	if not streak and _soft != null: return _soft
	var result := GradientTexture2D.new()
	result.width = 8 if streak else 32
	result.height = 32
	result.fill = GradientTexture2D.FILL_RADIAL
	result.fill_from = Vector2(0.5, 0.5)
	result.fill_to = Vector2(0.5, 1.0)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.16, 0.48, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.92), Color(1, 1, 1, 0.26), Color(1, 1, 1, 0)])
	result.gradient = gradient
	if streak: _spark = result
	else: _soft = result
	return result

static func ramp(color: Color) -> Gradient:
	var result := Gradient.new()
	result.offsets = PackedFloat32Array([0.0, 0.12, 0.5, 1.0])
	result.colors = PackedColorArray([Color(color, 0), color.lightened(0.5), color, Color(color, 0)])
	return result

static func size_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(0.15, 1))
	curve.add_point(Vector2(0.7, 0.6))
	curve.add_point(Vector2(1, 0))
	return curve

static func mesh() -> QuadMesh:
	if _meshes.has("mote"): return _meshes.mote
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture()
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	_meshes.mote = quad
	return quad

static func world(parent: Node3D, at: Vector3, color: Color, count: int = 24, loop: bool = false) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "NativeMotes3D"
	particles.emitting = false
	particles.mesh = mesh()
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.position = at
	particles.amount = clampi(count, 1, 96)
	particles.lifetime = 2.4 if loop else 0.85
	particles.one_shot = not loop
	particles.explosiveness = 0.0 if loop else 1.0
	particles.preprocess = 2.4 if loop else 0.0
	particles.local_coords = true
	particles.direction = Vector3.UP
	particles.spread = 32 if loop else 105
	particles.gravity = Vector3(0, 0.08 if loop else -0.65, 0)
	particles.initial_velocity_min = 0.08 if loop else 0.35
	particles.initial_velocity_max = 0.25 if loop else 1.45
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.25 if loop else 0.12
	particles.scale_amount_min = 0.035 if loop else 0.035
	particles.scale_amount_max = 0.065 if loop else 0.10
	particles.scale_amount_curve = size_curve()
	particles.color_ramp = ramp(color)
	parent.add_child(particles)
	if not loop:
		particles.finished.connect(particles.queue_free)
		# CPU simulation can be skipped when a viewport is hidden or headless.
		particles.create_tween().tween_interval(particles.lifetime + 0.1).finished.connect(particles.queue_free)
	particles.emitting = true
	return particles

static func screen(parent: Node2D, at: Vector2, color: Color, direction: Vector2, big: bool = false, support: bool = false) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "NativeSparks2D"
	particles.speed_scale = Settings.battle_effect_speed()
	particles.emitting = false
	particles.position = at
	particles.texture = texture(not support)
	particles.particle_flag_align_y = not support
	particles.amount = (24 if support else 52) if big else (12 if support else 28)
	particles.lifetime = 0.62 if support else 0.6
	particles.one_shot = true
	particles.explosiveness = 0.8 if support else 1.0
	particles.direction = Vector2.UP if support else direction
	particles.spread = 40 if support else 145
	particles.gravity = Vector2(0, -35 if support else 150)
	particles.initial_velocity_min = 35 if support else 90
	particles.initial_velocity_max = 90 if support else (420 if big else 280)
	particles.damping_min = 35
	particles.damping_max = 65
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 24 if support else 8
	particles.scale_amount_min = 0.12 if support else 0.24
	particles.scale_amount_max = (0.38 if big else 0.25) if support else (0.65 if big else 0.48)
	particles.scale_amount_curve = size_curve()
	particles.color_ramp = ramp(color)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = material
	particles.z_index = 10
	parent.add_child(particles)
	particles.finished.connect(particles.queue_free)
	Settings.battle_tween(particles).tween_interval(particles.lifetime * (2.0 - particles.explosiveness) + 0.04).finished.connect(particles.queue_free)
	particles.emitting = true
	return particles
