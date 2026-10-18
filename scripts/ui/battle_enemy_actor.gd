extends TextureRect
## Authored body poses, with one shared anatomical scale across idle / attack / cast.
## TextureRect keeps targeting, hit flash and persistent battle layout intact.
const MOTIONS := preload("res://scripts/data/enemy_animation_data.gd")
const SCORE_STAMP := preload("res://scripts/ui/battle_enemy_score_stamp.gd")
const COUNTDOWN_PAGE := preload("res://scripts/ui/battle_enemy_countdown_page.gd")
const FLASH := "shader_type canvas_item; uniform float hit_flash = 0.0; void fragment() { COLOR = vec4(mix(COLOR.rgb, vec3(1.0, 0.93, 0.79), hit_flash), COLOR.a); }"
var enemy_id := ""
var phase_index := 0
var animating := false
var rest_position := Vector2.ZERO
var motion_name := "idle"
var motion_frame := 0.0:
	set(value):
		motion_frame = value
		if is_instance_valid(_body):
			_body.frame = clampi(int(value), 0, _body.sprite_frames.get_frame_count(_body.animation) - 1)
var _body: AnimatedSprite2D
var _motion: Dictionary
var _ghost: Sprite2D
var _previous_texture: Texture2D
var _previous_offset := Vector2.ZERO
var _blend: Tween
var _score_stamp: Node2D
var _countdown_page: Node2D

func _process(_delta: float) -> void:
	if animating: return
	var breath := sin((float(Time.get_ticks_msec()) * 0.001 + phase_index * 0.71) * TAU / 3.6)
	if is_instance_valid(_body):
		_body.position = Vector2(size.x * 0.5, size.y * 0.96 - breath * 1.5)
	elif not _motion.is_empty():
		return
	else:
		position.y = rest_position.y - breath * 1.5

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader := Shader.new()
	shader.code = FLASH
	var flash := ShaderMaterial.new()
	flash.shader = preload("res://scripts/ui/battle_enemy_blend.gdshader") if enemy_id == "terminal_echo" else shader
	material = flash
	if enemy_id == "terminal_echo": flash.set_shader_parameter("pose_mix",1.0)
	_motion = MOTIONS.get_motion(enemy_id)
	if _motion.is_empty():
		if enemy_id == "gaokao_countdown":
			_countdown_page = COUNTDOWN_PAGE.new()
			_countdown_page.name = "CountdownOnCalendar"
			add_child(_countdown_page)
			_layout_countdown_page()
		return
	self_modulate.a = 0.0
	_body = AnimatedSprite2D.new()
	_body.name = "EnemyBodyAnimation"
	_body.centered = false
	_body.sprite_frames = _motion.frames
	_body.speed_scale = Settings.battle_effect_speed()
	_body.use_parent_material = true
	_ghost = Sprite2D.new()
	_ghost.name = "PoseTransition"
	_ghost.centered = false
	_ghost.use_parent_material = true
	add_child(_ghost)
	_body.frame_changed.connect(_blend_frame)
	add_child(_body)
	if enemy_id == "perfect_score":
		_score_stamp = SCORE_STAMP.new()
		_score_stamp.name = "ScoreOnDial"
		_body.add_child(_score_stamp)
	resized.connect(_layout_body)
	_layout_body()
	_play_idle(true)

func _blend_frame() -> void:
	_align_frame()
	if not is_instance_valid(_body) or not _body.sprite_frames.has_animation(_body.animation): return
	var next_texture := _body.sprite_frames.get_frame_texture(_body.animation, _body.frame)
	if next_texture == _previous_texture and _body.offset == _previous_offset: return
	if is_instance_valid(_blend): _blend.kill()
	if enemy_id == "terminal_echo":
		_blend_boss(next_texture)
		_previous_texture = next_texture
		_previous_offset = _body.offset
		return
	_ghost.hide()
	_body.modulate.a = 1.0
	_previous_texture = next_texture
	_previous_offset = _body.offset

func _blend_boss(next_texture: Texture2D) -> void:
	# Mix both drawings in one shader: two alpha-faded sprites darken on every frame.
	_ghost.hide()
	_body.modulate.a = 1.0
	if _previous_texture == null: return
	var old := _previous_texture as AtlasTexture
	var now := next_texture as AtlasTexture
	if old == null or now == null: return
	var shader := material as ShaderMaterial
	var old_size := old.atlas.get_size()
	var now_size := now.atlas.get_size()
	shader.set_shader_parameter("previous_tex",old.atlas)
	shader.set_shader_parameter("previous_region",Vector4(old.region.position.x/old_size.x,old.region.position.y/old_size.y,old.region.size.x/old_size.x,old.region.size.y/old_size.y))
	shader.set_shader_parameter("current_region",Vector4(now.region.position.x/now_size.x,now.region.position.y/now_size.y,now.region.size.x/now_size.x,now.region.size.y/now_size.y))
	shader.set_shader_parameter("previous_size",old.region.size)
	shader.set_shader_parameter("current_size",now.region.size)
	shader.set_shader_parameter("previous_anchor",_previous_offset)
	shader.set_shader_parameter("current_anchor",_body.offset)
	shader.set_shader_parameter("pose_mix",0.0)
	_blend = Settings.battle_tween(self)
	_blend.tween_property(shader,"shader_parameter/pose_mix",1.0,.16 if animating else .28)

func place(rect: Rect2) -> void:
	size = rect.size
	_layout_countdown_page()
	if rest_position != rect.position:
		rest_position = rect.position
		if not animating: position = rest_position
	set_meta("rest_x", rest_position.x)
	pivot_offset = Vector2(size.x * 0.5, size.y * 0.96)

func _layout_body() -> void:
	if not is_instance_valid(_body) or size.x <= 0: return
	# A minion stays smaller even when the encounter gives it a wide slot.
	var factor := minf(size.x * 0.83 / _motion.reference_size.x, size.y * _motion.height_ratio / _motion.reference_size.y)
	_body.scale = Vector2.ONE * factor
	_body.position = Vector2(size.x * 0.5, size.y * 0.96)
	_align_frame()

func _align_frame() -> void:
	if not is_instance_valid(_body): return
	var anchors: Array = _motion.anchors.get(String(_body.animation), [])
	if _body.frame < anchors.size():
		_body.offset = -anchors[_body.frame]
		if is_instance_valid(_score_stamp):
			_score_stamp.position = Vector2(265, 312) - anchors[_body.frame]

func set_score(value: int) -> void:
	if is_instance_valid(_score_stamp): _score_stamp.score = value

func set_countdown(value: int) -> void:
	if is_instance_valid(_countdown_page): _countdown_page.remaining = value

func _layout_countdown_page() -> void:
	if not is_instance_valid(_countdown_page) or texture == null: return
	var source := texture.get_size()
	var factor := minf(size.x / source.x, size.y / source.y)
	_countdown_page.scale = Vector2.ONE * factor
	_countdown_page.position = (size - source * factor) * 0.5

func _play_idle(initial: bool = false) -> void:
	motion_name = "idle"
	if not is_instance_valid(_body): return
	_body.play("idle")
	# Same-species encounters do not breathe in lockstep.
	_body.set_frame_and_progress(phase_index % _body.sprite_frames.get_frame_count("idle") if initial else 0, fmod(phase_index * 0.37, 1.0) if initial else 0.0)
	_blend_frame()
	_align_frame()

func begin_action(action: String) -> void:
	animating = true
	motion_name = action
	position = rest_position
	if not is_instance_valid(_body): return
	_body.position = Vector2(size.x * 0.5, size.y * 0.96)
	_body.stop()
	_body.animation = action if _body.sprite_frames.has_animation(action) else "attack"
	motion_frame = 0.0
	_align_frame()

func reset_pose() -> void:
	animating = false
	position = rest_position
	scale = Vector2.ONE
	rotation = 0.0
	z_index = 0
	modulate = Color.WHITE
	_play_idle()

func tear_apart(seconds: float) -> void:
	if not is_instance_valid(_body): return
	var source := _body.sprite_frames.get_frame_texture(_body.animation, _body.frame) as AtlasTexture
	var tween := Settings.battle_tween(self).set_parallel(true)
	for side in 2:
		var piece := Sprite2D.new()
		var crop := AtlasTexture.new()
		crop.atlas = source.atlas
		crop.region = Rect2(source.region.position + Vector2(side * 256, 0), Vector2(256, 512))
		piece.texture = crop
		piece.centered = false
		piece.offset = _body.offset + Vector2(side * 256, 0)
		piece.position = _body.position
		piece.scale = _body.scale
		add_child(piece)
		var direction := -1.0 if side == 0 else 1.0
		tween.tween_property(piece, "position", piece.position + Vector2(direction * size.x * 0.25, 22), seconds)
		tween.tween_property(piece, "rotation", direction * 0.2, seconds)
		tween.tween_property(piece, "modulate:a", 0.0, seconds)
	_body.hide()
	await tween.finished

func dissolve() -> void:
	if not is_instance_valid(_body):
		await Settings.battle_tween(self).tween_property(self, "modulate:a", 0.0, 2.5).finished
		hide()
		return
	animating = true
	_body.pause()
	if is_instance_valid(_blend): _blend.kill()
	var effect := preload("res://scripts/ui/battle_enemy_dissolve.gd").new()
	add_child(effect)
	effect.configure(_body)
	if is_instance_valid(_score_stamp):
		var stamp := SCORE_STAMP.new()
		stamp.score = _score_stamp.score
		stamp.position = _score_stamp.position
		effect.body.add_child(stamp)
		Settings.battle_tween(stamp).tween_property(stamp, "modulate:a", 0.0, effect.duration * 0.65)
	_body.hide()
	_ghost.hide()
	await effect.play()
	hide()

func emission_point() -> Vector2:
	if not is_instance_valid(_body): return get_transform() * (size * 0.5)
	# Release belongs to the animated mouth / paper hand, not the control rectangle.
	var point := Vector2(0.51, 0.42) if enemy_id == "noise" else Vector2(0.33, 0.70)
	if enemy_id == "cupid": point = Vector2(0.83, 0.35)
	elif enemy_id == "biting_book": point = Vector2(0.5, 0.45)
	elif enemy_id in ["zeus_dean", "math_exam", "perfect_score"]: point = Vector2(0.32, 0.48)
	elif enemy_id in ["nightmare", "panic_throat", "inverse_limit"]: point = Vector2(0.5, 0.4)
	if motion_name == "cast": point = Vector2(0.52, 0.50)
	var bounds: Rect2 = _motion.bounds[String(_body.animation)][_body.frame]
	return get_transform() * (_body.transform * (_body.offset + bounds.position + bounds.size * point))
