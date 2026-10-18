extends Node
## Battle-scoped pool: honours SFX settings, dies with its effect layer, never uses combat RNG.
signal cue_played(cue: String, event: String)
const ROOT := "res://assets/audio/sfx/enemies/"
const POOL_SIZE := 8
const EXCLUDED := ["terminal_echo", "whisper_silhouette", "terminal_choir", "false_dawn"]
const FAMILIES := {
	"paper_large":"paper_rend", "ink_wolf":"paper_rend", "paper_small":"paper_fold", "ink_wolf_echo":"paper_fold",
	"noise":"noise_pressure", "cupid":"cupid_string", "zeus_dean":"thunder", "biting_book":"book_bite",
	"nightmare":"nightmare", "snicker_shadow":"snicker", "math_exam":"exam_grid", "perfect_score":"score_mark",
	"gaokao_countdown":"clock_tick", "report_card":"report_ash", "quiet_hacker":"hacker_data",
	"magician_master":"magic_cards", "self_destructive_pain":"pain_pulse", "infirmary_demon":"medicine",
	"bullied_phantom":"curtain", "fist_phantom":"fist", "whip_phantom":"whip", "bruised_hand":"palm",
	"shackle_phantom":"chain", "claustrophobic_box":"box_compress"
}
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _last: Dictionary = {}
var _serial := 0

static func of(parent: Node) -> Node:
	var pool := parent.get_node_or_null("EnemyAudio")
	if pool == null:
		pool = new()
		pool.name = "EnemyAudio"
		parent.add_child(pool)
	return pool

static func cue(id: String, event: String, effect: String = "", stage: int = 1) -> String:
	if id in EXCLUDED: return ""
	if event == "collapse":
		return "panic_collapse" if id == "panic_throat" else "inverse_injury_death" if id == "inverse_limit" else ""
	if event == "rebirth":
		return {"panic_throat":"panic_rebirth", "inverse_limit":"inverse_rebirth", "report_card":"report_rebirth"}.get(id, "")
	if event == "summon":
		return "shadow_summon" if id == "panic_throat" else "magic_summon" if id == "magician_master" else "phantom_summon"
	var family: String = FAMILIES.get(id, "")
	if id == "panic_throat":
		family = "panic_breath" if event == "anticipation" else String({"silence":"panic_silence", "pierce":"panic_pierce", "cage":"panic_cage", "island":"panic_cage", "panic_guard":"chain", "weakness":"snicker", "nightmare_entry":"nightmare", "summon":"shadow_summon"}.get(effect, "panic_whip"))
		if event == "death": return "panic_collapse"
	if id == "inverse_limit": family = "inverse_rain" if stage == 1 else "inverse_injury" if stage == 2 else "inverse_mirror"
	if effect == "score_dissolve": return "score_break" if event == "release" else ""
	if effect == "report_absent": return "report_rebirth" if event == "release" else ""
	if effect == "isolation_gain": return "vitality" if event == "contact" else ""
	if id == "gaokao_countdown" and effect == "countdown_burst": family = "clock_burst"
	if id == "quiet_hacker" and effect == "trojan": family = "hacker_trojan"
	if id == "magician_master" and effect == "magic_summon": family = "magic_summon"
	if id == "infirmary_demon" and effect in ["isolate", "anesthetic"]: family = "isolation"
	if family.is_empty(): return ""
	if event == "anticipation": return family + "_pre"
	if event == "death": return "score_break" if id == "perfect_score" else family + "_death"
	if event == "contact": return family
	return ""

static func emit(parent: Node, id: String, event: String, effect: String = "", stage: int = 1) -> void:
	if Settings.simple_battle_effects(): return
	var generated := preload("res://scripts/ui/battle_generated_audio.gd").of(parent)
	if id == "zeus_dean" and event in ["anticipation", "contact"]:
		var thunder := "sfx_zeus_thunder_charge" if event == "anticipation" else "sfx_zeus_thunder_impact"
		if generated.stream(thunder) != null:
			if generated.play_sfx(thunder, 100):
				of(parent).cue_played.emit(cue(id, event, effect, stage), event)
			return
	if id == "panic_throat" and event in ["collapse", "death"]:
		generated.play_sfx("enemy_panic_throat_collapse", 500)
	if id == "snicker_shadow" and event == "contact":
		generated.play_sfx("enemy_snicker_shadow_laugh", 500)
	if event == "rebirth" and id == "report_card":
		generated.play_voice("enemy_report_card_rebirth", 1, id)
	var key := cue(id, event, effect, stage)
	if not key.is_empty(): of(parent).play_cue(key, event)

func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)
	Settings.setting_changed.connect(func(section: String, key: String, value: Variant) -> void:
		if section == "battle" and key == "simple_effects" and bool(value):
			for player in _players: player.stop()
	)

func play_cue(key: String, event: String) -> void:
	if Settings.simple_battle_effects(): return
	# Only merge simultaneous summon/death arrivals; every authored attack contact remains audible.
	var now := Time.get_ticks_msec()
	if event in ["summon", "death"] and now - int(_last.get(key, -1000)) < 110: return
	_last[key] = now
	if not _streams.has(key):
		var path := ROOT + key + ".wav"
		if not ResourceLoader.exists(path):
			push_warning("Missing enemy sound: " + path)
			return
		_streams[key] = load(path)
	var chosen: AudioStreamPlayer
	for player in _players:
		if not player.playing:
			chosen = player
			break
	if chosen == null:
		chosen = _players[0]
		for player in _players:
			if int(player.get_meta("serial", 0)) < int(chosen.get_meta("serial", 0)): chosen = player
	_serial += 1
	chosen.set_meta("serial", _serial)
	chosen.stream = _streams[key]
	# A stronger default mix; user SFX volume/mute still scales every cue.
	chosen.volume_db = -15.0 if event == "anticipation" else -8.0 if event in ["rebirth", "collapse"] else -12.0 if event == "death" else -9.0
	if key == "thunder": chosen.volume_db = -6.0
	chosen.pitch_scale = 1.0
	chosen.play()
	cue_played.emit(key, event)
