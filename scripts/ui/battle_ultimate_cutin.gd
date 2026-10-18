extends Control
signal finished
signal released
const ART := preload("res://scripts/data/battle_art.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const PARTICLES := preload("res://scripts/ui/battle_cinematic_particles.gd")
const LETTERING := preload("res://scripts/ui/battle_ultimate_lettering.gd")
const DURATION := 2.25
const PRESENTATION := preload("res://scripts/data/battle_presentation.gd")
var module := "zhou_wuji"
var title := ""
var elapsed := 0.0
var completed := false
var art: TextureRect
var pane: Control
var background: TextureRect
var eye_strip: Control
var title_group: Control
var flash: ColorRect
var actor_material: ShaderMaterial
var _burst_started := false
var minimum_seconds := 0.0
var _real_elapsed := 0.0

func _ready() -> void:
	name = "UltimateCutin"
	z_index = 150
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rect(self, Rect2(Vector2.ZERO, size), Color("050b14"))
	pane = Control.new()
	pane.name = "CinematicLayers"
	pane.size = size
	pane.clip_contents = true
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pane)
	var tint := ART.accent(module)
	background = V.icon(pane, load(PRESENTATION.ultimate_path(module)), Rect2(-80, -40, 2080, 1170))
	background.name = "ParallaxBackground"
	background.modulate = Color(0.78, 0.78, 0.80, 1)
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Left-side readability, with a soft horizontal gradient rather than an opaque card.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("071020"), Color(0.02, 0.05, 0.09, 0)])
	var wash := GradientTexture2D.new()
	wash.gradient = gradient
	wash.fill_from = Vector2.ZERO
	wash.fill_to = Vector2.RIGHT
	V.icon(pane, wash, Rect2(0, 0, 1180, 1080)).stretch_mode = TextureRect.STRETCH_SCALE
	var behind := PARTICLES.new()
	behind.name = "BackgroundOrbits"
	behind.module = module
	pane.add_child(behind)
	var title_echo := LETTERING.new()
	title_echo.name = "TitleBehindCharacter"
	title_echo.module = module
	title_echo.title = title
	title_echo.behind_actor = true
	pane.add_child(title_echo)
	art = V.icon(pane, ART.actor(module), Rect2(700, -110, 1250, 1250))
	var costume := ART.COSTUMES.LOOKS.has(module)
	var actor_home := 810.0 if costume else 700.0
	if costume:
		art.position = Vector2(actor_home, 112)
		art.size = Vector2(1000, 890)
	art.name = "UltimateCG"
	art.pivot_offset = art.size * 0.5
	actor_material = ShaderMaterial.new()
	actor_material.shader = preload("res://assets/shaders/battle_cutin_actor.gdshader")
	actor_material.set_shader_parameter("rim", tint)
	actor_material.set_shader_parameter("reveal", 0.0)
	art.material = actor_material
	var front := PARTICLES.new()
	front.name = "ForegroundFragments"
	front.module = module
	front.foreground = true
	pane.add_child(front)
	# Feathered bottom wash follows the title across the body, preserving its face and hands.
	var ink_gradient := Gradient.new()
	ink_gradient.colors = PackedColorArray([Color(0.01, 0.025, 0.05, 0), Color(0.01, 0.025, 0.05, 0.68)])
	var ink := GradientTexture2D.new()
	ink.gradient = ink_gradient
	ink.fill_from = Vector2(0.5, 0)
	ink.fill_to = Vector2(0.5, 1)
	V.icon(pane, ink, Rect2(0, 605, 1920, 385)).stretch_mode = TextureRect.STRETCH_SCALE
	_build_eye_strip(tint)
	_build_title()
	for y in [0, 990]:
		_rect(self, Rect2(0, y, 1920, 90), Color("040a12"))
	for y in [89, 990]:
		_rect(self, Rect2(88, y, 1744, 1), Color(tint, 0.35))
	V.text(self, "点击 / Esc 跳过", Rect2(1540, 1020, 290, 25), 16, Color("8299af"), true)
	flash = _rect(pane, Rect2(Vector2.ZERO, size), Color(tint, 0))
	flash.name = "ReleaseFlash"
	var reveal := Settings.battle_tween(self)
	reveal.tween_interval(0.08)
	reveal.tween_property(actor_material, "shader_parameter/reveal", 1.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	art.position.x = actor_home + 200
	art.rotation = 0.025
	var entrance := Settings.battle_tween(self).set_parallel(true)
	entrance.tween_property(art, "position:x", actor_home, 0.52).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	entrance.tween_property(art, "rotation", 0.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entrance.tween_property(art, "scale", Vector2.ONE * 1.035, DURATION)

func _build_eye_strip(tint: Color) -> void:
	eye_strip = Control.new()
	eye_strip.name = "EyeCloseup"
	eye_strip.position = Vector2(85, 230)
	eye_strip.size = Vector2(780, 180)
	eye_strip.rotation = -0.075
	eye_strip.clip_contents = true
	eye_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pane.add_child(eye_strip)
	var original := ART.cutin(module)
	if original != null:
		var crop := AtlasTexture.new()
		crop.atlas = original
		crop.region = Rect2(original.get_size() * Vector2(0.30, 0.20), original.get_size() * Vector2(0.42, 0.27))
		if module == "chen": crop.region = Rect2(375, 240, 350, 150)
		if module == "xu": crop.region = Rect2(200, 265, 380, 150)
		if module == "su": crop.region = Rect2(360, 285, 300, 125)
		if module == "liu": crop.region = Rect2(210, 110, 150, 72)
		if ART.COSTUMES.LOOKS.has(module): crop.region = ART.COSTUMES.LOOKS[module].eye
		var closeup := V.icon(eye_strip, crop, Rect2(-15, -25, 810, 220))
		closeup.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		closeup.modulate = Color(tint, 0.7)
		var soft_mask := ShaderMaterial.new()
		soft_mask.shader = preload("res://assets/shaders/battle_cutin_closeup.gdshader")
		closeup.material = soft_mask

func _build_title() -> void:
	title_group = LETTERING.new()
	title_group.name = "UltimateTitle"
	title_group.module = module
	title_group.title = title
	pane.add_child(title_group)

func _rect(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var layer := ColorRect.new()
	layer.position = rect.position
	layer.size = rect.size
	layer.color = color
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	return layer

func _process(delta: float) -> void:
	_real_elapsed += delta
	delta *= Settings.battle_effect_speed()
	elapsed += delta
	if _real_elapsed < minimum_seconds: elapsed = minf(elapsed, 1.90)
	if completed: return
	actor_material.set_shader_parameter("clock", elapsed)
	background.position.x = -80 - elapsed * 13
	eye_strip.position.x = 100 + elapsed * 24
	eye_strip.modulate.a = smoothstep(0.02, 0.13, elapsed) * (1.0 - smoothstep(0.34, 0.62, elapsed)) * 0.65
	if elapsed >= 0.56 and not _burst_started:
		_burst_started = true
		_play_release()
	var pulse := maxf(0, 1.0 - absf(elapsed - 0.59) / 0.06)
	flash.color.a = pulse * 0.11
	if elapsed > 1.93:
		modulate.a = clampf((DURATION - elapsed) / 0.32, 0, 1)
	if elapsed >= DURATION and _real_elapsed >= minimum_seconds: complete()

func _play_release() -> void:
	released.emit()
	var family := String({"zhou_wuji":"slash", "zhou_math":"math", "alyina":"blessing", "wang":"magic", "chen":"barrier", "xu":"slash", "su":"poison", "liu":"ink"}.get(module, "slash"))
	var frames := ART.effect_frames(family)
	if frames == null: return
	var burst := AnimatedSprite2D.new()
	burst.name = "UltimateSequence"
	burst.sprite_frames = frames
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	burst.position = Vector2(1200, 595)
	burst.scale = Vector2.ONE * 3.1
	burst.speed_scale = 0.62 * Settings.battle_effect_speed()
	if module == "su":
		burst.position = Vector2(1160, 690)
		burst.scale = Vector2.ONE * 1.75
		burst.modulate.a = 0.46
	pane.add_child(burst)
	# Keep the strongest painted effect behind the face, readable around the silhouette.
	pane.move_child(burst, art.get_index())
	burst.play()
	burst.set_frame_and_progress(3, 0)
	burst.animation_finished.connect(burst.queue_free)

func _input(event: InputEvent) -> void:
	if completed: return
	if (event is InputEventMouseButton and event.pressed) or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		complete()

func complete() -> void:
	if completed: return
	if not _burst_started:
		_burst_started = true
		released.emit()
	completed = true
	hide()
	finished.emit()
	queue_free()
