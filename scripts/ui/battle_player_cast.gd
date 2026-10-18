extends Node2D
## Body frames, feet shadow and hand emission share one battlefield coordinate space.
signal released(origin: Vector2, travel: float)
signal finished
const ROOT := "res://assets/graphics/battle/actors/"
const COSTUMES := preload("res://scripts/data/battle_costume_data.gd")
const CELL := 384
const BODY_SCALE := 1.38 # Uniform atlas padding is removed from the on-stage body scale.
const HAND_ANCHORS := {"zhou_strike":Vector2(282, 216), "zhou_cast":Vector2(268, 204), "alyina_cast":Vector2(257, 192), "wang_cast":Vector2(271, 171), "chen_cast":Vector2(293, 137), "xu_strike":Vector2(302, 131), "su_cast":Vector2(281, 114), "liu_cast":Vector2(277, 148)}
const EXPOSURES := [0.9, 0.85, 0.75, 0.7, 1.65, 1.1, 0.85, 0.8]
const PARTICLES := preload("res://scripts/vfx/native_particles.gd")
static var _frames: Dictionary = {}
var module := ""
var phase := "anticipation"
var sprite: AnimatedSprite2D
var melee := false
var attacking := false
var facing := 1.0
var accent := Color.WHITE
var actor_scale := 1.0
var body_scale := BODY_SCALE
var feet_anchor := Vector2(192, 356)
var hand_anchor := Vector2.ZERO
var light := 0.0
var _emitted := false
var _age := 0.0
var _home := Vector2.ZERO
var _contact := Vector2.ZERO
var _motion: Tween

func configure(unit: Dictionary, effects: Array, owner_rect: Rect2) -> void:
	var enemy_rect := Rect2()
	for effect: Dictionary in effects:
		if effect.side == "enemy":
			enemy_rect = effect.rect
			break
	module = "alyina_cast" if unit.id == "alyina" else "wang_cast" if unit.id == "wangjiaqi" else "zhou_cast" if unit.get("attribute", "none") == "math" else "zhou_strike"
	if unit.id == "chenmo": module = "chen_cast"
	if unit.id == "xumingming": module = "xu_strike"
	if unit.id == "suwanqing": module = "su_cast"
	if unit.id == "liudanya": module = "liu_cast"
	if unit.id == "li_anya": module = "anya_phoenix" if bool(unit.get("anya_phoenix", false)) else "anya_bound"
	if module in ["chen_cast", "xu_strike", "su_cast", "liu_cast"]:
		body_scale = 0.98
		feet_anchor = Vector2(192, 331)
	if module == "liu_cast": feet_anchor = Vector2(192, 358)
	hand_anchor = HAND_ANCHORS.get(module, Vector2(280, 160))
	if module.begins_with("anya_"):
		body_scale = 1.10
		feet_anchor = Vector2(192, 352)
	var costume_key := COSTUMES.body_key(module)
	if not costume_key.is_empty():
		body_scale = 0.98
		feet_anchor = Vector2(192, 358)
		hand_anchor = COSTUMES.LOOKS[costume_key].hand
	melee = module in ["zhou_strike", "xu_strike"] and enemy_rect.has_area()
	attacking = enemy_rect.has_area()
	accent = Color("ffc296") if module == "zhou_strike" else Color("8adce9") if module == "zhou_cast" else Color("aee4d0") if module == "alyina_cast" else Color("c3a7ee")
	if module == "chen_cast": accent = Color("75a4e8")
	if module == "xu_strike": accent = Color("f39759")
	if module == "su_cast": accent = Color("65d691")
	if module == "liu_cast": accent = Color("d2bca4")
	if module.begins_with("anya_"): accent = Color("ffd98e") if module == "anya_phoenix" else Color("b1bdff")
	# Attacks keep a readable foreground body even in the six-enemy layout.
	actor_scale = (1.22 if enemy_rect.size.y < 300 else 1.42) if attacking else 0.98
	if melee:
		# Align the fist with the enemy body, with feet on the same floor plane.
		var hand_offset: Vector2 = (hand_anchor - feet_anchor) * actor_scale * body_scale
		facing = -1.0 if enemy_rect.get_center().x < 940 else 1.0
		hand_offset.x *= facing
		_contact = enemy_rect.get_center() - hand_offset
		# In the lower compact row, aim at the upper body so feet clear the party HUD.
		if enemy_rect.size.y < 300:
			_contact.y = minf(_contact.y, 826.0)
		position = _contact - Vector2(78 * actor_scale * facing, 0)
	else:
		position = Vector2(clampf(owner_rect.get_center().x, 680, 1450), 782)
		var target: Vector2 = enemy_rect.get_center() if enemy_rect.has_area() else effects[0].rect.get_center() if not effects.is_empty() else position + Vector2(300, -180)
		if enemy_rect.has_area() and absf(target.x - position.x) < 240:
			position.x = target.x - 300 if target.x > 860 else target.x + 300
		facing = -1.0 if target.x < position.x else 1.0
	_home = position

func _ready() -> void:
	if Settings.simple_battle_effects():
		hide()
		set_process(false)
		_finish_simple_cast.call_deferred()
		return
	z_index = 36
	var frames := _load_frames(module)
	if frames == null:
		released.emit(position, 0.08)
		finished.emit()
		queue_free()
		return
	sprite = AnimatedSprite2D.new()
	sprite.name = "PlayerBodyAnimation"
	sprite.sprite_frames = frames
	sprite.speed_scale = Settings.battle_effect_speed()
	sprite.centered = false
	sprite.offset = -feet_anchor
	sprite.scale = Vector2(facing, 1) * actor_scale * body_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.modulate = Color("f2f1ff")
	add_child(sprite)
	sprite.frame_changed.connect(_frame_changed)
	sprite.animation_finished.connect(_recover)
	modulate.a = 0.0
	var appear := Settings.battle_tween(self)
	appear.tween_property(self, "modulate:a", 1.0, 0.07)
	sprite.play()
	if attacking:
		_motion = Settings.battle_tween(self)
		_motion.tween_property(self, "position:x", _home.x - 18 * facing, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _finish_simple_cast() -> void:
	_emitted = true
	phase = "release"
	released.emit(position, 0.0)
	finished.emit()
	queue_free()

static func _load_frames(key: String) -> SpriteFrames:
	if _frames.has(key): return _frames[key]
	var path := ROOT + key + "/sheet-transparent.webp"
	if key.begins_with("anya_"): path = "res://assets/graphics/battle/anya/body_" + key.trim_prefix("anya_") + ".webp"
	var costume_path := COSTUMES.body_path(key)
	if not costume_path.is_empty(): path = costume_path
	if not ResourceLoader.exists(path): return null
	var sheet := load(path) as Texture2D
	var result := SpriteFrames.new()
	result.set_animation_loop("default", false)
	result.set_animation_speed("default", 14.0)
	for i in 8:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2((i % 4) * CELL, int(i / 4) * CELL, CELL, CELL)
		result.add_frame("default", frame, EXPOSURES[i])
	_frames[key] = result
	return result

func _frame_changed() -> void:
	if sprite.frame == 3 and melee:
		if _motion != null and _motion.is_valid(): _motion.kill()
		_motion = Settings.battle_tween(self)
		_motion.tween_property(self, "position", _contact, 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if sprite.frame >= 4 and not _emitted:
		# Release from the exact contact pose, independent of frame/tween scheduling.
		if melee:
			if _motion != null and _motion.is_valid(): _motion.kill()
			position = _contact
		_emitted = true
		phase = "release"
		light = 1.0
		PARTICLES.screen(self, emission_point() - position, accent, Vector2(facing, -0.2), false, not melee)
		released.emit(emission_point(), 0.0 if melee else 0.18)
	if sprite.frame == 6:
		phase = "recovery"
		if attacking:
			_motion = Settings.battle_tween(self)
			_motion.tween_property(self, "position:x", position.x - 25 * facing, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func emission_point() -> Vector2:
	var hand: Vector2 = hand_anchor - feet_anchor
	return position + Vector2(hand.x * facing, hand.y) * actor_scale * body_scale

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	_age += delta
	light = move_toward(light, 0, delta * 3.8)
	queue_redraw()

func _draw() -> void:
	# Layered contact shadow and a faint reflected cast light anchor the feet.
	draw_set_transform(Vector2(0, 3), 0, Vector2(1, 0.22) * actor_scale)
	for i in range(7, 0, -1): draw_circle(Vector2.ZERO, 47 + i * 4, Color(0.02, 0.025, 0.05, 0.032))
	draw_circle(Vector2.ZERO, 45, Color(0.01, 0.015, 0.025, 0.32))
	if not melee:
		draw_arc(Vector2.ZERO, 64, 0, TAU, 64, Color(accent, 0.16 + light * 0.3), 2, true)
		draw_arc(Vector2.ZERO, 72, _age, _age + PI * 1.3, 48, Color(accent, 0.22), 1, true)
	if light > 0: draw_circle(Vector2.ZERO, 70, Color(accent, light * 0.09))
	draw_set_transform(Vector2.ZERO)
	if light > 0 and not melee:
		var hand := emission_point() - position
		for i in range(4, 0, -1): draw_circle(hand, 4 + i * 4, Color(accent, light * 0.05))

func _recover() -> void:
	phase = "recovery"
	var exit := Settings.battle_tween(self)
	exit.tween_interval(0.07)
	exit.tween_property(self, "modulate:a", 0.0, 0.13)
	await exit.finished
	finished.emit()
	queue_free()
