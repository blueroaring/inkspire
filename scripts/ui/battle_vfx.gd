extends Node2D
## Texture animation is bounded even when a skill resolves hundreds of hits.
const ART := preload("res://scripts/data/battle_art.gd")
var animations: Dictionary = {}
var played := 0
var peak_sprites := 0
const MAX_SPRITES := 24
const SIMPLE_IMPACT := preload("res://scripts/ui/battle_simple_impact.gd")
const AUDIO := preload("res://scripts/ui/battle_generated_audio.gd")
const ACCENT := {"slash":Color("ffd2a1"), "math":Color("80e7ff"), "magic":Color("d6adff"), "blessing":Color("a7f3d2"), "barrier":Color("84cfff"), "poison":Color("65d691"), "poison_burst":Color("c391ff"), "ink":Color("e6d9bb"), "anya_bound":Color("b1bdff"), "anya_phoenix":Color("ffd98e")}
const POISON_DETONATION := preload("res://scripts/ui/battle_poison_detonation.gd")
const MOTION := preload("res://scripts/ui/battle_impact.gd")
const PARTICLES := preload("res://scripts/vfx/native_particles.gd")
var _particle_root: Node2D
var _sounds: Dictionary = {}
var _sound_until := 0

func _ready() -> void:
	for family in ART.FX_FAMILIES:
		var frames := ART.effect_frames(family)
		if frames != null: animations[family] = frames

func impact_delay(family: String, target: Vector2, origin: Vector2, travel_override: float = -1.0) -> float:
	if Settings.simple_battle_effects(): return 0.0
	if family == "poison_burst": return POISON_DETONATION.CONTACT_TIME
	return (travel_override if travel_override >= 0 else _travel_time(family, target, origin)) + ART.FX_CONTACT

func _travel_time(family: String, target: Vector2, origin: Vector2) -> float:
	return 0.08 if family in ["slash", "math", "magic", "poison"] and target.distance_to(origin) > 100 else 0.0

func play_effect(family: String, target: Vector2, origin: Vector2, big: bool = false, hits: int = 1, skill_id: String = "", travel_override: float = -1.0, sound_enabled: bool = true) -> void:
	if Settings.simple_battle_effects():
		play_simple_contact(target)
		return
	# Bound art, trails, echoes and sounds even for thousand-hit pursuit chains.
	if get_child_count() > MAX_SPRITES - 6: return
	if family == "poison_burst":
		_play_poison_detonation(target, big, hits, skill_id, sound_enabled)
		return
	if not animations.has(family): return
	played += 1
	var travel := travel_override if travel_override >= 0 else _travel_time(family, target, origin)
	var style := ART.profile(skill_id)
	var sprite := _sprite(family, target, big, hits, style)
	sprite.set_meta("skill_id", skill_id)
	sprite.visible = travel <= 0.0
	if travel > 0.0:
		var trail := MOTION.new()
		trail.name = "SkillTravel_" + family
		trail.family = family
		trail.flight = true
		trail.origin = origin
		trail.destination = target
		trail.duration = travel + ART.FX_CONTACT
		trail.accent = ACCENT[family]
		add_child(trail)
	var sequence := Settings.battle_tween(sprite)
	if travel > 0.0: sequence.tween_interval(travel)
	sequence.tween_callback(func() -> void:
		if is_instance_valid(sprite):
			sprite.visible = true
			sprite.play()
	)
	sequence.tween_interval(ART.FX_CONTACT)
	sequence.tween_callback(func() -> void:
		_native_impact(family, target, (target - origin).normalized(), big)
		var burst := MOTION.new()
		burst.name = "SkillImpact_" + family
		burst.position = target
		burst.family = family
		burst.accent = ACCENT[family]
		burst.direction = (target - origin).normalized()
		burst.big = big
		burst.hits = hits
		burst.z_index = 9
		if get_child_count() < MAX_SPRITES: add_child(burst)
		else: burst.free()
		if sound_enabled: _play_sound(family, big)
		peak_sprites = maxi(peak_sprites, get_child_count())
	)
	if int(style.echoes) > 0 or hits > 1:
		sequence.tween_interval(0.065)
		sequence.tween_callback(func() -> void:
			if get_child_count() >= MAX_SPRITES: return
			var echo := _sprite(family, target + Vector2(18, -12), false, hits, style)
			echo.name = "SkillEcho_" + family
			echo.scale *= 0.8
			echo.modulate.a = 0.58
			if family == "slash": echo.rotation += 1.1
			echo.play()
			echo.set_frame_and_progress(4, 0.0)
			peak_sprites = maxi(peak_sprites, get_child_count())
		)
	peak_sprites = maxi(peak_sprites, get_child_count())

func _play_poison_detonation(target: Vector2, big: bool, hits: int, skill_id: String, sound_enabled: bool = true) -> void:
	played += 1
	var burst := POISON_DETONATION.new()
	burst.name = "SkillVFX_poison_burst"
	burst.position = target
	burst.big = big
	burst.set_meta("skill_id", skill_id)
	burst.set_meta("hit_count", hits)
	burst.detonated.connect(func() -> void:
		_native_impact("poison_burst", target, Vector2.UP, big)
		if sound_enabled: _play_sound("poison_burst", big)
		peak_sprites = maxi(peak_sprites, get_child_count())
	, CONNECT_ONE_SHOT)
	add_child(burst)
	peak_sprites = maxi(peak_sprites, get_child_count())

func _sprite(family: String, target: Vector2, big: bool, hits: int, style: Dictionary) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.name = "SkillVFX_" + family
	sprite.set_meta("hit_count", hits)
	sprite.sprite_frames = animations[family]
	sprite.speed_scale = Settings.battle_effect_speed()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = target
	sprite.scale = Vector2.ONE * (2.05 if big else 1.30) * float(style.scale)
	sprite.rotation = float(style.rotation)
	sprite.modulate = style.tint
	sprite.z_index = 8
	add_child(sprite)
	sprite.animation_finished.connect(sprite.queue_free)
	return sprite

func play_enemy_contact(family: String, target: Vector2, origin: Vector2, heavy: bool, damaging: bool, sound: bool = true) -> void:
	if Settings.simple_battle_effects():
		play_simple_contact(target)
		return
	# Enemy motion carries the attack. Keep the contact small enough to read the HUD.
	if get_child_count() >= MAX_SPRITES: return
	_native_impact(family if damaging else "barrier", target, (target - origin).normalized(), false, true)
	var contact := MOTION.new()
	contact.name = "EnemyContact"
	contact.position = target
	contact.family = family if damaging else "barrier"
	contact.accent = ACCENT.get(family, Color.WHITE)
	contact.direction = (target - origin).normalized()
	contact.scale = Vector2.ONE * (0.55 if heavy else 0.38)
	contact.duration = 0.24
	add_child(contact)
	if sound: _play_sound(family if damaging else "barrier", heavy)
	peak_sprites = maxi(peak_sprites, get_child_count())

func play_simple_contact(target: Vector2) -> void:
	# Simultaneous area hits share one sound; each target still receives a contact mark.
	AUDIO.of(self).play_simple_hit()
	if get_child_count() >= MAX_SPRITES: return
	var contact := SIMPLE_IMPACT.new()
	contact.position = target
	add_child(contact)
	played += 1
	peak_sprites = maxi(peak_sprites, get_child_count())

func _native_impact(family: String, target: Vector2, direction: Vector2, big: bool, compact: bool = false) -> void:
	if not is_instance_valid(_particle_root) or _particle_root.is_queued_for_deletion():
		_particle_root = Node2D.new()
		_particle_root.name = "NativeBattleParticles"
		add_child(_particle_root)
	if _particle_root.get_child_count() >= 8: return
	var particles := PARTICLES.screen(_particle_root, target, ACCENT.get(family, Color.WHITE), direction, big, family in ["blessing", "barrier"])
	if family == "poison_burst":
		particles.name = "PoisonDetonationSparks"
		particles.spread = 180
		particles.gravity = Vector2(0, 35)
		particles.initial_velocity_max = 340 if big else 280
	var root := _particle_root
	particles.tree_exited.connect(func() -> void:
		if is_instance_valid(root) and not root.is_queued_for_deletion() and root.get_child_count() == 0: root.queue_free()
	)
	if compact:
		particles.amount = 12
		particles.initial_velocity_max *= 0.45
		particles.lifetime = 0.4

func _play_sound(family: String, big: bool) -> void:
	if Time.get_ticks_msec() < _sound_until or get_child_count() >= MAX_SPRITES: return
	_sound_until = Time.get_ticks_msec() + Settings.battle_msec(90)
	var support := family in ["blessing", "barrier"]
	var detonation := family == "poison_burst"
	var key := "poison" if detonation else "support" if support else "hit"
	if not _sounds.has(key):
		_sounds[key] = load("res://assets/audio/sfx/battle_fresh/impact_" + key + ".wav")
	var sound := AudioStreamPlayer.new()
	sound.stream = _sounds[key]
	sound.volume_db = -14 if support else -10 if big else -13
	sound.pitch_scale = 0.85 if big else 1.0
	if AudioServer.get_bus_index("SFX") >= 0: sound.bus = "SFX"
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
