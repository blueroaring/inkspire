extends Node
## One scene-scoped voice lane and bounded SFX pool. Audio never consumes combat RNG.
signal cue_played(key: String, bus: String)
const DATA := preload("res://scripts/data/battle_audio_data.gd")
const ART := preload("res://scripts/data/battle_art.gd")
const ROOT := "res://assets/audio/battle_generated/"
const FRESH_SFX_ROOT := "res://assets/audio/sfx/battle_fresh/"
const POOL_SIZE := 12
const SIMPLE_HIT := preload("res://assets/audio/sfx/battle_fresh/impact_hit.wav")
var catalog: Dictionary = {}
var voice_overrides: Dictionary = {}
var _voice_variants: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _voice: AudioStreamPlayer
var _streams: Dictionary = {}
var _last: Dictionary = {}
var _actors: Dictionary = {}
var _released: Dictionary = {}
var _once: Dictionary = {}
var _serial := 0
var _simple_hit_frame := -1
var voice_priority := 0
var enemy_routes: Dictionary = {}

static func of(parent: Node) -> Node:
	# UI card flights, effect actors and cut-ins all share the battle's single mixer.
	var ancestor := parent
	while ancestor != null:
		if ancestor.has_meta("generated_battle_audio"):
			var existing: Variant = ancestor.get_meta("generated_battle_audio")
			if is_instance_valid(existing): return existing
		ancestor = ancestor.get_parent()
	var node := parent.get_node_or_null("GeneratedBattleAudio")
	if node == null:
		node = new()
		node.name = "GeneratedBattleAudio"
		parent.add_child(node)
	parent.set_meta("generated_battle_audio", node)
	return node

static func sfx(parent: Node, key: String, merge_ms: int = 90) -> bool:
	return of(parent).play_sfx("sfx_" + key, merge_ms)

static func say(parent: Node, key: String, priority: int = 0, actor: String = "") -> float:
	return of(parent).play_voice(key, priority, actor)

func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_audio_catalog.json"))
	if data is Dictionary: catalog = data.get("tracks", {})
	var routes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_enemy_voice_routes.json"))
	if routes is Dictionary: enemy_routes = routes
	var supplied: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_voice_overrides.json"))
	if supplied is Dictionary: voice_overrides = supplied.get("tracks", {})
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	_voice.volume_db = -1.0
	add_child(_voice)
	AudioManager.voice_availability_changed.connect(func(enabled: bool) -> void:
		if not enabled: _voice.stop())

func stream(key: String, variant: int = 0) -> AudioStream:
	if key == "sfx_simple_hit": return SIMPLE_HIT
	if voice_overrides.has(key):
		var variants: Array = voice_overrides[key].variants
		if variants.is_empty(): return null
		var path := String(variants[posmod(variant, variants.size())].path)
		if not _streams.has(path): _streams[path] = load(path) as AudioStream
		return _streams[path]
	if _streams.has(key): return _streams[key]
	# Player/UI effects use the noise-free pack; supplied recordings stay intact.
	if key.begins_with("sfx_") and ResourceLoader.exists(FRESH_SFX_ROOT + key + ".wav"):
		var sound := load(FRESH_SFX_ROOT + key + ".wav") as AudioStream
		if sound != null: _streams[key] = sound
		return sound
	# Prefer the delivered MP3s over the older processed battle/Anya recordings.
	if DATA.ULTIMATE_VOICES.has(key):
		var sound := load(String(DATA.ULTIMATE_VOICES[key])) as AudioStream
		if sound != null: _streams[key] = sound
		return sound
	# User-generated Anya media is optional; fixed filenames need no catalog edit.
	if key.begins_with("hero_anya_") or key.begins_with("sfx_anya_"):
		for extension in ["wav", "ogg", "mp3"]:
			var path: String = "res://assets/audio/anya/" + key + "." + extension
			if ResourceLoader.exists(path):
				var sound := load(path) as AudioStream
				if sound != null:
					_streams[key] = sound
					return sound
		return null
	if not catalog.has(key): return null
	var loaded := load(String(catalog[key].path)) as AudioStream
	if loaded != null: _streams[key] = loaded
	return loaded

func play_sfx(key: String, merge_ms: int = 90) -> bool:
	# The common contact owns skill audio in simple mode; card/UI cues stay separate.
	if Settings.simple_battle_effects() and key != "sfx_simple_hit" and not key.begins_with("sfx_card_") and key != "sfx_turn_end": return false
	# The replacement ultimate recording is the complete cut-in soundtrack.
	if _voice.playing and DATA.ULTIMATE_VOICES.has(String(_voice.get_meta("cue_key", ""))): return false
	var now := Time.get_ticks_msec()
	if now - int(_last.get(key, -100000)) < merge_ms: return false
	var sound := stream(key)
	if sound == null: return false
	var chosen: AudioStreamPlayer = null
	for player in _players:
		if not player.playing:
			chosen = player
			break
	if chosen == null:
		chosen = _players[0]
		for player in _players:
			if int(player.get_meta("serial", 0)) < int(chosen.get_meta("serial", 0)): chosen = player
	_serial += 1
	var old_fade: Tween = chosen.get_meta("contact_fade") if chosen.has_meta("contact_fade") else null
	if old_fade != null and old_fade.is_valid(): old_fade.kill()
	_last[key] = now
	chosen.set_meta("serial", _serial)
	chosen.set_meta("cue_key", key)
	chosen.stream = sound
	chosen.pitch_scale = 1.0
	# Short attack contacts must not replay a substitute's long release tail.
	var duration_limit := 0.0
	if key.ends_with("_hit") or key.ends_with("_burst") or key.ends_with("_counter"): duration_limit = 0.42
	chosen.volume_db = -7.0 if key.ends_with("_charge") else -3.0
	if sound.resource_path.begins_with(FRESH_SFX_ROOT):
		chosen.volume_db = -10.0 if key.ends_with("_charge") else -6.0
		if key.ends_with("_hit") or key.ends_with("_burst") or key.ends_with("_counter"): chosen.volume_db = -3.0
		elif key.ends_with("_ultimate_release"): chosen.volume_db = -4.0
		if key.begins_with("sfx_card_"): chosen.volume_db = -9.0
	chosen.play()
	if duration_limit > 0 and sound.get_length() > duration_limit:
		_fade_contact(chosen, _serial, duration_limit)
	cue_played.emit(key, "SFX")
	return true

func play_simple_hit() -> void:
	# Merge simultaneous targets, without dropping fast successive contacts at 2x speed.
	var frame := Engine.get_process_frames()
	if frame == _simple_hit_frame: return
	if play_sfx("sfx_simple_hit", 0): _simple_hit_frame = frame

func _fade_contact(player: AudioStreamPlayer, serial: int, duration: float) -> void:
	var fade := create_tween()
	player.set_meta("contact_fade", fade)
	fade.tween_interval(duration)
	fade.tween_property(player, "volume_db", -65.0, 0.08)
	fade.tween_callback(func() -> void:
		if int(player.get_meta("serial", 0)) == serial: player.stop())

func play_voice(key: String, priority: int = 0, actor: String = "") -> float:
	if not Settings.all_voice_enabled(): return 0.0
	if DATA.ULTIMATE_VOICES.has(key) and not Settings.ultimate_presentation_enabled(): return 0.0
	if Settings.simple_battle_effects() and not DATA.ULTIMATE_VOICES.has(key): return 0.0
	# Disabled cues must not interrupt a restored ultimate or introduce a wait.
	var enabled: bool = AudioManager.ULTIMATE_SPEECH_ENABLED if DATA.ULTIMATE_VOICES.has(key) else voice_overrides.has(key) or AudioManager.SPEECH_ENABLED
	if not enabled: return 0.0
	var now := Time.get_ticks_msec()
	if priority == 0 and (_voice.playing or now - int(_actors.get(actor, -100000)) < 5500): return 0.0
	if _voice.playing and priority < voice_priority: return 0.0
	if now - int(_last.get(key, -100000)) < (1200 if priority > 0 else 8000): return 0.0
	var variant := int(_voice_variants.get(key, 0))
	var sound := stream(key, variant)
	if sound == null: return 0.0
	if voice_overrides.has(key): _voice_variants[key] = (variant + 1) % voice_overrides[key].variants.size()
	# Clear preceding skill tails before starting the authored recording alone.
	if DATA.ULTIMATE_VOICES.has(key): stop_all()
	else: _voice.stop()
	_voice.stream = sound
	_voice.set_meta("cue_key", key)
	_voice.pitch_scale = 1.0
	voice_priority = priority
	_last[key] = now
	_actors[actor] = now
	_voice.play()
	cue_played.emit(key, "Voice")
	return sound.get_length()

func player_start(skill: String, unit: Dictionary) -> void:
	var key := DATA.voice(skill)
	if not key.is_empty(): play_voice(key, 0, String(unit.get("id", "")))

func player_release(skill: String, token: int) -> void:
	if _released.has(token): return
	_released[token] = true
	if _released.size() > 256: _released.erase(_released.keys()[0])
	var key := DATA.release(skill)
	if not key.is_empty(): play_sfx("sfx_" + key)

func contact(effect: String, side: String, damaging: bool, module: String, token: int, ultimate: bool = false) -> void:
	if Settings.simple_battle_effects(): return # battle_vfx owns the single common contact cue.
	var key := DATA.contact(effect, side, damaging, module)
	if ultimate or effect.begins_with("ultimate"):
		var ids: Array = DATA.ULTIMATES.get(module, [])
		key = String(ids[0]) + "_ultimate_hit" if not ids.is_empty() else ""
	if key.is_empty(): return
	if not damaging:
		var stamp := str(token) + ":" + key
		if _once.has(stamp): return
		_once[stamp] = true
		if _once.size() > 512: _once.erase(_once.keys()[0])
	play_sfx("sfx_" + key, 65 if ultimate else 0 if damaging else 130)

func ultimate_start(module: String) -> float:
	var ids: Array = DATA.ULTIMATES.get(module, [])
	if ids.is_empty(): return 0.0
	return play_voice(String(ids[1]), 2, module)

func ultimate_release(module: String) -> void:
	# The authored MP3 owns the cut-in; the clean cue marks gameplay resolution.
	var ids: Array = DATA.ULTIMATES.get(module, [])
	if not ids.is_empty(): play_sfx("sfx_" + String(ids[0]) + "_ultimate_release")

func enemy_action(unit: Dictionary, intent: Dictionary) -> void:
	var id := String(unit.get("id", ""))
	var title := String(intent.get("name", "")).replace(" promax", "").replace(" max", "")
	var key := String(enemy_routes.get(title, ""))
	if title.begins_with("f(x)"): key = "enemy_math_exam_function"
	if String(intent.get("effect", "")) == "mirror": key = "enemy_inverse_limit_mirror"
	if String(intent.get("effect", "")) == "score_dissolve": key = "enemy_perfect_score_dissolve"
	if id == "bullied_phantom" and String(intent.get("effect", "")) == "phantom_summon":
		key = "enemy_bullied_phantom_" + String({"镣铐拖行":"shackle", "淤青之手":"hand"}.get(title, "summon"))
	if id in ["ink_wolf", "ink_wolf_echo"]: return
	if not key.begins_with("enemy_" + id + "_"): return
	var priority := 1 if String(intent.get("effect", "")) in ["zeus_thunder", "sentence", "cage", "ultimatum", "countdown_burst"] else 0
	play_voice(key, priority, id)

func rebirth(id: String, stage: int) -> void:
	var suffix := "summon" if stage == 2 else "nightmare"
	if id == "inverse_limit": suffix = "downpour" if stage == 2 else "tendon"
	play_voice("enemy_" + id + "_" + suffix, 1, id)

func stop_cues(keys: Array[String]) -> void:
	# A skipped cut-in owns only its cues, not the scene's other audio.
	for player in _players:
		if String(player.get_meta("cue_key", "")) not in keys: continue
		var fade: Tween = player.get_meta("contact_fade") if player.has_meta("contact_fade") else null
		if fade != null and fade.is_valid(): fade.kill()
		player.set_meta("serial", -1)
		player.stop()
	if String(_voice.get_meta("cue_key", "")) in keys: _voice.stop()

func stop_sfx() -> void:
	for player in _players:
		var fade: Tween = player.get_meta("contact_fade") if player.has_meta("contact_fade") else null
		if fade != null and fade.is_valid(): fade.kill()
		player.set_meta("serial", -1)
		player.stop()

func stop_all() -> void:
	stop_sfx()
	_voice.stop()

func _exit_tree() -> void:
	stop_all()
	for player in _players: player.stream = null
	_voice.stream = null
	_streams.clear()

