extends Node
## Presentation-only choreography. Rules already resolved; contacts reveal snapshots.
signal phase_changed(actor_index: int, phase: String)
const SIGNATURE := preload("res://scripts/ui/battle_enemy_signature.gd")
const AUDIO := preload("res://scripts/ui/battle_enemy_audio.gd")
const PROJECTILE := preload("res://scripts/ui/battle_enemy_projectile.gd")
const PHANTOM_SUMMON := preload("res://scripts/ui/battle_phantom_summon.gd")
const EXPANSION_FX := {
	"countdown_burst":"fx_countdown_burst", "trojan":"fx_hacker_trojan",
	"magic_summon":"fx_magician_summon", "isolate":"fx_infirmary_isolation_v2",
	"isolation_gain":"fx_infirmary_vitality_gain",
	"whip_bounce":"fx_phantom_whip", "shackle_lock":"fx_shackle_lock",
	"compress":"fx_claustrophobic_compress",
	"report_rebirth":"fx_report_rebirth",
}
const EXPANSION_IDS := ["gaokao_countdown", "report_card", "quiet_hacker", "magician_master", "self_destructive_pain", "infirmary_demon", "bullied_phantom", "fist_phantom", "whip_phantom", "bruised_hand", "shackle_phantom", "claustrophobic_box"]
var active_actor := -1
var phase := "idle"
var _audio_action: Dictionary = {}
var _audio_layer: Node
var _audio_actor: TextureRect
var _audio_anticipated := false

static func contact_groups(intent: Dictionary, effects: Array) -> Array:
	var groups: Array = []
	if String(intent.get("kind", "")) == "all":
		var current: Array = []
		var seen: Array = []
		for effect: Dictionary in effects:
			if seen.has(effect.target):
				groups.append(current)
				current = []
				seen = []
			current.append(effect)
			seen.append(effect.target)
		if not current.is_empty(): groups.append(current)
	else:
		for effect: Dictionary in effects: groups.append([effect])
	return groups

func _phase(value: String) -> void:
	phase = value
	if is_instance_valid(_audio_layer) and is_instance_valid(_audio_actor) and not _audio_actor.is_queued_for_deletion():
		if value == "anticipation" and not _audio_anticipated or value == "release":
			if value == "anticipation": _audio_anticipated = true
			AUDIO.emit(_audio_layer, String(_audio_action.unit.id), value, String(_audio_action.intent.get("effect", "")), int(_audio_action.unit.get("boss_phase", 1)))
	phase_changed.emit(active_actor, value)

func play(actor: TextureRect, action: Dictionary, target_rects: Dictionary, effects_layer: Control, contact: Callable, vfx: Node2D) -> void:
	if Settings.simple_battle_effects():
		await _play_simple(actor, action, target_rects, contact, vfx)
		return
	_audio_action = action
	_audio_layer = effects_layer
	_audio_actor = actor
	_audio_anticipated = false
	var signature: Node2D
	var id := String(action.unit.id)
	if is_instance_valid(actor):
		preload("res://scripts/ui/battle_generated_audio.gd").of(effects_layer).enemy_action(action.unit, action.intent)
	if is_instance_valid(actor) and id not in SIGNATURE.EXCLUDED:
		signature = SIGNATURE.new()
		signature.enemy_id = id
		signature.effect = String(action.intent.get("effect", ""))
		signature.center = actor.rest_position + actor.size * Vector2(0.5, 0.45)
		effects_layer.add_child(signature)
	var reveal := func(group: Array) -> void:
		if is_instance_valid(actor) and not actor.is_queued_for_deletion():
			var sound_effect := String(action.intent.get("effect", ""))
			if group.size() == 1 and String(group[0].get("effect", "")) == "isolation_gain": sound_effect = "isolation_gain"
			# Actual shadow portals own summon audio; resolving this snapshot can rebuild the layout first.
			if not (id == "panic_throat" and sound_effect == "summon"):
				AUDIO.emit(effects_layer, id, "contact", sound_effect, int(action.unit.get("boss_phase", 1)))
		if is_instance_valid(signature): signature.contact(group, target_rects)
		contact.call(group)
	await _play(actor, action, target_rects, effects_layer, reveal, vfx)
	if is_instance_valid(signature): signature.finish()
	_audio_action = {}
	_audio_layer = null
	_audio_actor = null

func _play_simple(actor: TextureRect, action: Dictionary, target_rects: Dictionary, contact: Callable, vfx: Node2D) -> void:
	active_actor = int(action.actor)
	_phase("anticipation")
	await Settings.battle_timer(0.10).timeout
	_phase("release")
	var groups := contact_groups(action.intent, action.effects)
	if groups.is_empty():
		if is_instance_valid(actor): vfx.play_simple_contact(actor.get_rect().get_center())
		contact.call(action.effects) # Summons, splitting and state changes may have no HP contacts.
	for group: Array in groups:
		_phase("contact")
		for effect: Dictionary in group:
			var area: Rect2 = target_rects.get("ally_%d" % int(effect.target), Rect2())
			if area.has_area(): vfx.play_simple_contact(area.get_center())
		contact.call(group)
		await Settings.battle_timer(0.22).timeout
	_phase("finished")
	active_actor = -1

func _play(actor: TextureRect, action: Dictionary, target_rects: Dictionary, effects_layer: Control, contact: Callable, vfx: Node2D) -> void:
	active_actor = int(action.actor)
	var intent: Dictionary = action.intent
	var kind := String(intent.get("kind", "single"))
	var effects: Array = action.effects
	if not is_instance_valid(actor):
		contact.call(effects)
		active_actor = -1
		return
	if String(intent.get("effect", "")) == "score_dissolve":
		_phase("release")
		actor.set_score(100)
		var title := _title(actor, intent, effects_layer, false)
		await Settings.battle_timer(0.35).timeout
		await actor.dissolve()
		contact.call(effects)
		title.queue_free()
		_phase("finished")
		active_actor = -1
		return
	if String(action.unit.id) in EXPANSION_IDS:
		await _play_expansion(actor, action, target_rects, effects_layer, contact, vfx)
		return
	if String(action.unit.id) in ["cupid", "zeus_dean", "biting_book", "nightmare", "panic_throat", "snicker_shadow", "math_exam", "perfect_score", "inverse_limit", "terminal_echo", "whisper_silhouette", "terminal_choir", "false_dawn"]:
		await _play_authored(actor, action, target_rects, effects_layer, contact, vfx)
		return
	if effects.is_empty() and kind != "split":
		active_actor = -1
		return
	var voice := String(action.unit.id) == "noise"
	var small := String(action.unit.id) in ["paper_small", "ink_wolf_echo"]
	var harmful := int(intent.get("damage", 0)) > 0 or not String(intent.get("status", "")).is_empty()
	if not harmful and kind != "split":
		contact.call(effects)
		active_actor = -1
		return
	var cast := not voice and kind in ["all", "split"]
	actor.begin_action("cast" if cast else "attack")
	actor.z_index = 35
	actor.position = actor.rest_position
	actor.rotation = 0.0
	var home: Vector2 = actor.rest_position
	var destination := home + actor.size * 0.5 + Vector2(0, 280)
	if not effects.is_empty():
		destination = (target_rects.get("ally_%d" % int(effects[0].target), Rect2(destination, Vector2.ZERO)) as Rect2).get_center()
	var toward := clampf((destination.x - home.x - actor.size.x * 0.5) / 500.0, -1.0, 1.0)
	var title := _title(actor, intent, effects_layer, voice)
	_phase("anticipation")
	# Distinct silhouettes: raised long claw, crouched minion, folded horns and closed maw.
	await _pose(actor, home, 2.0 if cast or small else 3.0, 0.20 if small else 0.40)
	if not is_instance_valid(actor):
		title.queue_free()
		return
	if kind == "split":
		_phase("release")
		await _pose(actor, home, 3.0, 0.16)
		await actor.tear_apart(0.24)
		_phase("contact")
		contact.call(effects)
	elif voice:
		_phase("release")
		# Opening the actual drawn mouth is the release. The root stays planted.
		await _pose(actor, home, 5.0, 0.16)
		var origin: Vector2 = actor.emission_point()
		for hit in effects.size():
			var effect: Dictionary = effects[hit]
			var target: Vector2 = (target_rects["ally_%d" % int(effect.target)] as Rect2).get_center()
			_phase("flight")
			var shot := _projectile(effects_layer, origin, target, "voice" if kind == "bounce" else "shout", 0.29 if hit == 0 else 0.18)
			await shot.arrived
			_phase("contact")
			contact.call([effect])
			vfx.play_enemy_contact("magic", target, origin, false, int(effect.hp_damage) > 0 or int(effect.guard_damage) > 0, String(action.unit.id) in AUDIO.EXCLUDED)
			await Settings.battle_timer(0.065).timeout
			# Reflected damage can retire the attacking body at this very contact.
			if not is_instance_valid(actor) or actor.is_queued_for_deletion(): break
			origin = target if kind == "bounce" else actor.emission_point()
	elif kind == "all":
		_phase("release")
		# Heavy beast opens both arms; minion snaps a single wrist.
		await _pose(actor, home, 3.0, 0.08 if small else 0.16)
		var origin: Vector2 = actor.emission_point()
		_phase("flight")
		var last_shot: Node2D
		for effect: Dictionary in effects:
			var target: Vector2 = (target_rects["ally_%d" % int(effect.target)] as Rect2).get_center()
			last_shot = _projectile(effects_layer, origin, target, "paper_small" if small else "paper", 0.24 if small else 0.33)
		# One cast and one shared arrival for the party, independent of party size.
		if is_instance_valid(last_shot): await last_shot.arrived
		_phase("contact")
		contact.call(effects)
		for effect: Dictionary in effects:
			vfx.play_enemy_contact("slash", (target_rects["ally_%d" % int(effect.target)] as Rect2).get_center(), origin, false, true, String(action.unit.id) in AUDIO.EXCLUDED)
		await Settings.battle_timer(0.055).timeout
	elif small:
		_phase("release")
		var reach := Vector2(toward * 115.0, 118.0)
		actor.motion_frame = 3.0
		# Full-body takeoff and landing frames follow an actual jump arc.
		await _pose(actor, home + reach * 0.45 + Vector2(0, -58), 4.0, 0.12)
		await _pose(actor, home + reach, 5.0, 0.12)
		_phase("flight")
		var slash := _projectile(effects_layer, actor.emission_point(), destination, "pounce", 0.08)
		await slash.arrived
		_phase("contact")
		contact.call(effects)
		vfx.play_enemy_contact("slash", destination, actor.emission_point(), false, true, String(action.unit.id) in AUDIO.EXCLUDED)
		if is_instance_valid(actor) and not actor.is_queued_for_deletion(): await _pose(actor, home + reach, 6.0, 0.08)
	else:
		_phase("release")
		# Weight stays behind the feet while the long claw travels overhead and down.
		await _pose(actor, home + Vector2(toward * 24.0, 22), 5.0, 0.20)
		_phase("flight")
		var slash := _projectile(effects_layer, actor.emission_point(), destination, "claw", 0.11)
		await slash.arrived
		_phase("contact")
		contact.call(effects)
		vfx.play_enemy_contact("slash", destination, actor.emission_point(), true, true, String(action.unit.id) in AUDIO.EXCLUDED)
		await Settings.battle_timer(0.085).timeout
	if is_instance_valid(actor) and not actor.is_queued_for_deletion() and kind != "split":
		_phase("recovery")
		if cast:
			await _pose(actor, home, 5.0, 0.23 if small else 0.30)
		else:
			await _pose(actor, home, 8.0, 0.28 if small else 0.38)
		if is_instance_valid(actor): actor.reset_pose()
	title.queue_free()
	_phase("finished")

func _play_expansion(actor: TextureRect, action: Dictionary, target_rects: Dictionary, layer: Control, contact: Callable, vfx: Node2D) -> void:
	var intent: Dictionary = action.intent
	var effects: Array = action.effects
	if String(intent.get("effect", "")) == "report_absent":
		_phase("release")
		_play_expansion_fx(layer, "report_rebirth", actor.rest_position + actor.size * 0.5, 360.0)
		await Settings.battle_timer(0.28).timeout
		_phase("contact")
		contact.call(effects)
		await Settings.battle_timer(0.35).timeout
		_phase("finished")
		active_actor = -1
		return
	var home: Vector2 = actor.rest_position
	var title := _title(actor, intent, layer, false)
	actor.begin_action("cast" if String(intent.get("kind", "")) == "all" else "attack")
	actor.z_index = 35
	_phase("anticipation")
	var signature: Node2D
	if String(action.unit.id) == "bullied_phantom":
		signature = preload("res://scripts/ui/battle_boss_signature_effect.gd").new()
		layer.add_child(signature)
		await signature.windup(actor, intent)
	else:
		await _pose(actor, home + Vector2(0, -24), 1.0, 0.16)
	if not is_instance_valid(actor):
		title.queue_free()
		return
	_phase("release")
	if String(action.unit.id) == "bullied_phantom" and String(intent.get("effect", "")) == "phantom_summon":
		var portal := PHANTOM_SUMMON.new()
		portal.set_meta("source", "cast")
		layer.add_child(portal)
		portal.burst(actor.rest_position + actor.size * Vector2(0.5, 0.65), 410.0)
	var countdown_burst := String(action.unit.id) == "gaokao_countdown" and String(intent.get("effect", "")) == "countdown_burst"
	if countdown_burst:
		_play_expansion_fx(layer, "countdown_burst", actor.rest_position + actor.size * 0.5, 420.0)
		Settings.battle_tween(actor).tween_property(actor, "modulate", Color("ffb4ae"), 0.12)
	var targets: Array[Vector2] = []
	for effect: Dictionary in effects:
		if String(effect.get("effect", "")) == "isolation_gain": continue
		var rect: Rect2 = target_rects.get("ally_%d" % int(effect.target), Rect2())
		if rect.size != Vector2.ZERO: targets.append(rect.get_center())
	if targets.is_empty(): targets.append(actor.rest_position + actor.size * 0.5)
	if is_instance_valid(signature): signature.impact(targets)
	var groups := contact_groups(intent, effects)
	if groups.is_empty(): groups.append([])
	var origin: Vector2 = actor.emission_point()
	var bounce := String(intent.get("kind", "")) == "bounce"
	for group: Array in groups:
		_phase("flight")
		var last_shot: Node2D
		for effect: Dictionary in group:
			var area: Rect2 = target_rects.get("ally_%d" % int(effect.target), Rect2())
			if not area.has_area() or String(effect.get("effect", "")) == "isolation_gain": continue
			last_shot = _projectile(layer, origin, area.get_center(), "signature:%s:%s" % [action.unit.id, intent.get("effect", "")], 0.22)
		if is_instance_valid(last_shot): await last_shot.arrived
		else: await Settings.battle_timer(0.20).timeout
		_phase("contact")
		contact.call(group)
		for effect: Dictionary in group:
			var area: Rect2 = target_rects.get("ally_%d" % int(effect.target), Rect2())
			if not area.has_area(): continue
			if String(effect.get("effect", "")) == "isolation_gain": continue
			if String(intent.get("effect", "")) != "isolate": _play_expansion_fx(layer, String(intent.get("effect", "")), area.get_center())
			vfx.play_enemy_contact("slash" if String(action.unit.id) == "whip_phantom" else "magic", area.get_center(), origin, false, int(effect.hp_damage) + int(effect.guard_damage) > 0, String(action.unit.id) in AUDIO.EXCLUDED)
			if bounce: origin = area.get_center()
		await Settings.battle_timer(0.70 if group.size() == 1 and String(group[0].get("effect", "")) == "isolation_gain" else 0.16).timeout
	if countdown_burst and is_instance_valid(actor):
		await Settings.battle_tween(self).tween_property(actor, "modulate:a", 0.0, 0.22).finished
	if is_instance_valid(actor) and not actor.is_queued_for_deletion() and not countdown_burst:
		_phase("recovery")
		await _pose(actor, home, 0.0, 0.20)
		if is_instance_valid(actor): actor.reset_pose()
	if is_instance_valid(signature): await signature.finish()
	title.queue_free()
	_phase("finished")
	active_actor = -1

func _play_expansion_fx(layer: Control, effect: String, center: Vector2, diameter: float = 256.0) -> void:
	if Settings.simple_battle_effects():
		var impact := preload("res://scripts/ui/battle_simple_impact.gd").new()
		impact.position = center
		layer.add_child(impact)
		preload("res://scripts/ui/battle_generated_audio.gd").of(layer).play_simple_hit()
		return
	if not EXPANSION_FX.has(effect): return
	var image := TextureRect.new()
	image.name = "EnemyFX_" + effect
	image.texture = load("res://assets/graphics/battle/new_effects/%s.webp" % EXPANSION_FX[effect])
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.position = center - Vector2.ONE * diameter * 0.5
	image.size = Vector2.ONE * diameter
	image.pivot_offset = image.size * 0.5
	image.modulate.a = 0.0
	layer.add_child(image)
	var tween := Settings.battle_tween(image).set_parallel(true)
	tween.tween_property(image, "modulate:a", 1.0, 0.12)
	match effect:
		"trojan":
			image.scale = Vector2(1.35, 0.12)
			tween.tween_property(image, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_EXPO)
			tween.tween_property(image, "rotation", 0.05, 0.08)
		"compress":
			image.scale = Vector2(1.65, 1.05)
			tween.tween_property(image, "scale", Vector2(0.70, 1.08), 0.48).set_trans(Tween.TRANS_CUBIC)
		"isolate":
			image.scale = Vector2(1.35, 0.86)
			tween.tween_property(image, "scale", Vector2(0.90, 1.1), 0.42)
		"isolation_gain":
			image.scale = Vector2(0.72, 0.68)
			tween.tween_property(image, "scale", Vector2(1.08, 1.14), 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(image, "position:y", image.position.y - 20.0, 0.48)
		"whip_bounce":
			image.rotation = -0.35
			tween.tween_property(image, "rotation", 0.20, 0.18)
			tween.tween_property(image, "scale", Vector2(1.2, 0.7), 0.22)
		"shackle_lock":
			image.scale = Vector2.ONE * 1.5
			tween.tween_property(image, "scale", Vector2.ONE * 0.85, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"magic_summon":
			image.scale = Vector2(0.8, 0.1)
			tween.tween_property(image, "scale", Vector2.ONE * 1.18, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"report_rebirth":
			image.rotation = -0.6
			tween.tween_property(image, "rotation", 0.45, 0.48)
			tween.tween_property(image, "scale", Vector2.ONE * 1.15, 0.48)
		_:
			image.scale = Vector2.ONE * 0.45
			tween.tween_property(image, "scale", Vector2.ONE * 1.35, 0.38).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(image, "modulate:a", 0.0, 0.24)
	tween.tween_callback(image.queue_free)

func _pose(actor: TextureRect, destination: Vector2, frame: float, seconds: float) -> void:
	var tween := Settings.battle_tween(self).set_parallel(true)
	tween.tween_property(actor, "position", destination, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Linear frame time retains every authored pose; easing belongs to the trajectory.
	tween.tween_property(actor, "motion_frame", frame, seconds)
	await tween.finished

static func authored_clip(id: String, intent: Dictionary) -> String:
	var effect := String(intent.get("effect", ""))
	if id in ["whisper_silhouette", "terminal_choir", "false_dawn"]: return "cast"
	if id == "terminal_echo": return "attack" if effect == "final_tired" else "cast"
	if id == "snicker_shadow": return "cast"
	if id == "perfect_score" and effect == "non_attackers": return "cast"
	if id == "zeus_dean" and String(intent.get("name", "")) != "雷霆训诫": return "cast"
	return "cast" if effect in ["love_mist", "forgetfulness", "book_power", "darkness", "fear", "silence", "weakness", "panic_guard", "summon", "island", "cage", "exam_guard", "low_state", "damp", "warmup", "injection", "downpour", "mirror"] else "attack"

func _play_authored(actor: TextureRect, action: Dictionary, target_rects: Dictionary, layer: Control, contact: Callable, vfx: Node2D) -> void:
	var id := String(action.unit.id)
	var intent: Dictionary = action.intent
	var effects: Array = action.effects
	var clip := authored_clip(id, intent)
	var cast := clip == "cast"
	var home: Vector2 = actor.rest_position
	var boss := id in ["panic_throat", "inverse_limit", "terminal_echo"]
	var title := _title(actor, intent, layer, false)
	if id == "zeus_dean":
		title.rank = 1
		title.tint = Color("c8e9ff") if String(intent.get("effect", "")) == "zeus_thunder" else Color("ffc28f") if String(intent.get("effect", "")) == "sentence" else Color("d9d5ff")
		title.caption = "三次施法 · 惩戒触发" if String(intent.get("effect", "")) == "zeus_thunder" else "违纪标记 · 裁决" if String(intent.get("effect", "")) == "sentence" else "全体训诫 · 雷威增强" if String(intent.get("effect", "")) == "discipline" else "锁定上回合最多命中者"
		title.position = Vector2(675, 92)
		title.size = Vector2(570, 135)
	actor.begin_action(clip)
	actor.z_index = 35
	_phase("anticipation")
	var drama: Node2D
	if id == "panic_throat":
		drama = preload("res://scripts/ui/battle_panic_effect.gd").new()
		layer.add_child(drama)
		var staged_intent := intent.duplicate()
		staged_intent.boss_phase = int(action.unit.get("boss_phase", 1))
		await drama.windup(actor, staged_intent)
	elif id == "inverse_limit":
		drama = preload("res://scripts/ui/battle_boss_signature_effect.gd").new()
		layer.add_child(drama)
		var staged_intent := intent.duplicate()
		staged_intent.boss_phase = int(action.unit.get("boss_phase", 1))
		await drama.windup(actor, staged_intent)
	elif id in ["terminal_echo", "whisper_silhouette", "terminal_choir", "false_dawn"]:
		title.hide()
		drama = preload("res://scripts/ui/battle_finale_effect.gd").new()
		layer.add_child(drama)
		await drama.windup(actor, intent)
	else:
		await _pose(actor, home, 2.0, 0.44 if boss else 0.30)
	# Group a simultaneous party strike, but preserve every distinct hit of a multistrike.
	var groups := contact_groups(intent, effects)
	if groups.is_empty(): groups.append([])
	var shot_kind := "judgment" if id == "zeus_dean" and String(intent.get("effect", "")) == "sentence" else String({"cupid":"heart_arrow", "zeus_dean":"thunder", "biting_book":"bite", "nightmare":"haunt", "panic_throat":"chains", "snicker_shadow":"haunt", "math_exam":"formula", "perfect_score":"red_pen", "inverse_limit":"mirror", "terminal_echo":"abyss", "terminal_choir":"choir", "false_dawn":"dawn", "whisper_silhouette":"whisper"}.get(id, "haunt"))
	if id == "snicker_shadow": shot_kind = "panic_doubt"
	if id == "inverse_limit":
		shot_kind = "inverse_rain" if int(action.unit.get("boss_phase", 1)) == 1 else "inverse_injury" if int(action.unit.get("boss_phase", 1)) == 2 else "mirror"
	if id == "panic_throat":
		shot_kind = String({"silence":"panic_silence", "pierce":"panic_pierce", "weakness":"panic_doubt", "nightmare_entry":"panic_nightmare", "cage":"panic_cage"}.get(String(intent.get("effect", "")), "chains"))
	var family := "math" if id in ["zeus_dean", "math_exam", "inverse_limit"] else "magic" if cast or id in ["cupid", "nightmare"] else "slash"
	var bounce_origin := Vector2.INF
	for n in groups.size():
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			# Rules are already resolved: still reveal any outstanding contacts.
			for remaining in groups.slice(n): contact.call(remaining)
			break
		if n > 0:
			_phase("anticipation")
			await _pose(actor, home, 2.0, 0.10)
		_phase("release")
		await _pose(actor, home, 3.0, 0.12 if not boss else 0.19)
		var origin: Vector2 = bounce_origin if bounce_origin != Vector2.INF else actor.emission_point()
		var last_shot: Node2D
		_phase("flight")
		for effect in groups[n]:
			var area: Rect2 = target_rects.get("ally_%d" % int(effect.target), Rect2())
			if area.size != Vector2.ZERO: last_shot = _projectile(layer, origin, area.get_center(), shot_kind, 0.24 if n == 0 else 0.14)
		if is_instance_valid(last_shot): await last_shot.arrived
		else:
			vfx.play_effect("barrier" if intent.get("effect", "") in ["island", "exam_guard", "warmup"] else family, origin, origin, boss, 1)
			await Settings.battle_timer(0.20).timeout
		if id == "zeus_dean" and not groups[n].is_empty():
			var strike: Node2D
			for effect: Dictionary in groups[n]:
				var strike_area: Rect2 = target_rects.get("ally_%d" % int(effect.target), Rect2())
				if strike_area.has_area(): strike = _projectile(layer, strike_area.get_center() + Vector2(0, -310), strike_area.get_center(), "judgment" if shot_kind == "judgment" else "thunder", 0.16)
			if is_instance_valid(strike): await strike.arrived
		_phase("contact")
		if is_instance_valid(drama):
			var impact_points: Array[Vector2] = []
			for effect in groups[n]:
				var impact_area: Rect2 = target_rects.get("ally_%d" % int(effect.target), Rect2())
				if impact_area.has_area(): impact_points.append(impact_area.get_center())
			drama.impact(impact_points)
		contact.call(groups[n])
		if String(intent.get("kind", "")) == "bounce" and not groups[n].is_empty():
			bounce_origin = (target_rects.get("ally_%d" % int(groups[n][-1].target), Rect2()) as Rect2).get_center()
		for effect in groups[n]:
			var area: Rect2 = target_rects.get("ally_%d" % int(effect.target), Rect2())
			if area.size != Vector2.ZERO: vfx.play_enemy_contact(family, area.get_center(), origin, boss, int(effect.hp_damage) + int(effect.guard_damage) > 0, String(action.unit.id) in AUDIO.EXCLUDED)
		await Settings.battle_timer(0.065).timeout
	if is_instance_valid(actor) and not actor.is_queued_for_deletion():
		_phase("recovery")
		Settings.battle_tween(self).tween_property(actor, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_SINE)
		await _pose(actor, home, 5.0, 0.38 if boss else 0.24)
		if is_instance_valid(actor): actor.reset_pose()
	if is_instance_valid(drama): await drama.finish()
	title.queue_free()
	_phase("finished")
	active_actor = -1

func _title(actor: TextureRect, intent: Dictionary, parent: Control, voice: bool) -> Control:
	var title := preload("res://scripts/ui/battle_enemy_title.gd").new()
	title.name = "EnemyActionTitle"
	title.skill = String(intent.get("name", "攻击"))
	var width := maxf(440,actor.size.x+100)
	title.position = Vector2(clampf(actor.rest_position.x+actor.size.x*.5-width*.5,12,1920-width-12),maxf(70,actor.rest_position.y-100))
	title.size = Vector2(width,130)
	title.tint = Color("f8a3bc") if voice else Color("e5bd87")
	parent.add_child(title)
	return title

func _projectile(parent: Control, origin: Vector2, target: Vector2, kind: String, seconds: float) -> Node2D:
	var shot := PROJECTILE.new()
	shot.name = "EnemyProjectile_" + kind
	shot.origin = origin
	shot.destination = target
	shot.kind = kind
	shot.duration = seconds
	shot.bend = clampf((target.x - origin.x) * 0.12, -80, 80)
	parent.add_child(shot)
	return shot
