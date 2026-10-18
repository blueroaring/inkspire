extends RefCounted
## Presentation-only shuffle bags. Never consume the combat RNG.

const ROOT := "res://assets/graphics/battle/backgrounds/"
const ARENAS := {
	"anya_phoenix": {"title":"幻羽黎明", "path":"res://assets/graphics/battle/anya/background_phoenix.webp", "shade":0.24},
	"tower": {"title":"墨痕尖塔", "path":"res://assets/graphics/tower/arena.webp", "shade":0.30},
	"finale": {"title":"天台深渊", "path":ROOT + "arenas/finale.webp", "shade":0.18},
	"rooftop": {"title":"月下天台", "path":"res://assets/graphics/battle/battle_rooftop.webp", "shade":0.42},
	"classroom": {"title":"空教室", "path":ROOT + "arenas/classroom.webp", "shade":0.36},
	"warehouse": {"title":"旧仓库", "path":ROOT + "arenas/warehouse.webp", "shade":0.24},
	"library": {"title":"书海回廊", "path":ROOT + "arenas/library.webp", "shade":0.34},
	"track": {"title":"雨后跑道", "path":ROOT + "arenas/track.webp", "shade":0.35},
	"realm": {"title":"记忆灵境", "path":ROOT + "arenas/realm.webp", "shade":0.32},
	"ranking_ashes": {"title":"焚灰排名榜", "path":ROOT + "tower/ranking_ashes.webp", "shade":0.22},
	"magic_stage": {"title":"无人鼓掌的舞台", "path":ROOT + "ultimates/wang.webp", "shade":0.22},
	"infirmary": {"title":"白帘后的医务室", "path":ROOT + "tower/infirmary.webp", "shade":0.22},
	"sealed_auditorium": {"title":"封闭礼堂", "path":ROOT + "tower/sealed_auditorium.webp", "shade":0.20},
	"perfect_score_hall": {"title":"满分执念", "path":ROOT + "tower/perfect_score_hall.webp", "shade":0.20},
	"thunder_discipline": {"title":"雷霆训诫厅", "path":ROOT + "tower/thunder_discipline.webp", "shade":0.22},
	"math_exam_hall": {"title":"无尽数学考场", "path":ROOT + "ultimates/zhou_math.webp", "shade":0.24},
	"panic_silence": {"title":"无声扼喉", "path":ROOT + "tower/panic_silence.webp", "shade":0.18},
	"panic_gazes": {"title":"百舌嘲心", "path":ROOT + "tower/panic_gazes.webp", "shade":0.18},
	"panic_island": {"title":"孤影囚笼", "path":ROOT + "tower/panic_island.webp", "shade":0.16},
	"inverse_injury": {"title":"旧伤回响", "path":ROOT + "tower/infirmary.webp", "shade":0.26},
	"inverse_mirror": {"title":"破限镜像", "path":ROOT + "tower/inverse_mirror.webp", "shade":0.18},
}
# Dedicated tower plates must never enter the story/random presentation bag.
const RANDOM_ARENAS := ["rooftop", "classroom", "warehouse", "library", "track", "realm"]
const TOWER_STAGES := {
	"panic_throat":["panic_silence", "panic_gazes", "panic_island"],
	"inverse_limit":["track", "inverse_injury", "inverse_mirror"],
}
const TOWER_ENEMIES := {
	"biting_book":"library", "report_card":"ranking_ashes", "magician_master":"magic_stage",
	"infirmary_demon":"infirmary", "claustrophobic_box":"sealed_auditorium", "perfect_score":"perfect_score_hall",
	"zeus_dean":"thunder_discipline", "math_exam":"math_exam_hall", "bullied_phantom":"infirmary",
	"paper_large":"classroom", "paper_small":"classroom", "ink_wolf":"classroom", "ink_wolf_echo":"classroom",
	"noise":"classroom", "cupid":"rooftop", "nightmare":"realm", "quiet_hacker":"classroom",
	"gaokao_countdown":"classroom", "self_destructive_pain":"infirmary",
}
const TOWER_PRIORITY := ["terminal_echo", "inverse_limit", "panic_throat", "bullied_phantom", "math_exam", "zeus_dean", "infirmary_demon", "magician_master", "claustrophobic_box", "report_card", "perfect_score", "biting_book"]
const TOWER_MUSIC := {
	"biting_book":["tower_book"], "report_card":["tower_ranking"], "magician_master":["tower_magician"],
	"infirmary_demon":["tower_infirmary"], "claustrophobic_box":["tower_claustrophobia"], "perfect_score":["tower_perfect"],
	"zeus_dean":["tower_thunder"], "math_exam":["tower_math"], "bullied_phantom":["tower_phantom"],
	"panic_throat":["tower_panic", "tower_magician", "tower_claustrophobia"],
	"inverse_limit":["tower_training", "tower_injury", "tower_mirror"],
}
const ULTIMATES := {
	"zhou_wuji":"zhou_wuji.webp", "zhou_math":"zhou_math.webp", "alyina":"alyina.webp", "wang":"wang.webp",
	"chen":"chen.webp", "xu":"xu.webp", "su":"su.webp", "liu":"liu.webp",
}
# Save-stable ordinary-floor rotation; never consumes combat RNG.
const TOWER_ORDINARY := [
	["classroom", "battle_theme_a"], ["library", "tower_book"],
	["rooftop", "battle_theme_b"], ["warehouse", "battle_pursuit"],
	["track", "battle_epic_rock"], ["realm", "tower_perfect"],
	["math_exam_hall", "tower_math"], ["sealed_auditorium", "tower_claustrophobia"],
]
const MUSIC_IDS := ["battle_theme_a", "battle_theme_b", "battle_epic_rock", "battle_pursuit", "battle"]
static var _rng := RandomNumberGenerator.new()
static var _initialized := false
static var _arena_bag: Array = []
static var _music_bag: Array = []
static var _last_arena := ""
static var _last_music := "battle"
static var _serial := -1
static var _current: Dictionary = {}

static func context_arena(location: String, story: String = "") -> String:
	var context := (location + " " + story).to_lower()
	if "tower" in context: return "tower"
	if "warehouse" in context: return "warehouse"
	if "library" in context: return "library"
	if "exercise_field" in context or "track" in context or "gym" in context: return "track"
	if "spirit" in context or "realm" in context: return "realm"
	if "classroom" in context or "teaching" in context: return "classroom"
	if "rooftop" in context: return "rooftop"
	return ""

static func tower_owner(enemies: Array) -> int:
	# Bind once at entry; summons, deaths and order of ordinary mobs cannot steal the arena.
	for id in TOWER_PRIORITY:
		for i in enemies.size():
			if String(enemies[i].get("id", "")) == id: return i
	return 0 if not enemies.is_empty() else -1

static func tower_arena(enemy: Dictionary, stage: int = -1, floor_info: Dictionary = {}) -> String:
	var ambience := int(floor_info.get("ambience", -1))
	if ambience >= 0: return String(TOWER_ORDINARY[ambience % TOWER_ORDINARY.size()][0])
	var id := String(enemy.get("id", ""))
	if id == "terminal_echo": return "finale"
	if TOWER_STAGES.has(id):
		var phases: Array = TOWER_STAGES[id]
		return String(phases[clampi(int(enemy.get("boss_phase", 1)) if stage < 0 else stage, 1, phases.size()) - 1])
	return String(TOWER_ENEMIES.get(id, "tower"))

static func tower_music(enemy: Dictionary, stage: int = -1, floor_info: Dictionary = {}) -> String:
	var ambience := int(floor_info.get("ambience", -1))
	if ambience >= 0: return String(TOWER_ORDINARY[ambience % TOWER_ORDINARY.size()][1])
	var tracks: Array = TOWER_MUSIC.get(String(enemy.get("id", "")), [])
	if tracks.is_empty(): return "" # Finale controls its own three-act score.
	return String(tracks[clampi(int(enemy.get("boss_phase", 1)) if stage < 0 else stage, 1, tracks.size()) - 1])

static func _fill_bag(bag: Array, choices: Array, last: String) -> void:
	if not _initialized:
		_rng.randomize()
		_initialized = true
	if bag.is_empty():
		bag.assign(choices)
		for i in range(bag.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var swap: Variant = bag[i]
			bag[i] = bag[j]
			bag[j] = swap
	# Also handles a location-bound encounter inserted between random encounters.
	if bag.size() > 1 and String(bag.back()) == last:
		var swap: Variant = bag[0]
		bag[0] = bag.back()
		bag[bag.size() - 1] = swap

static func preview_arena(location: String = "", story: String = "") -> String:
	var bound := context_arena(location, story)
	if not bound.is_empty(): return bound
	_fill_bag(_arena_bag, RANDOM_ARENAS, _last_arena)
	return String(_arena_bag.back())

static func preview_music() -> String:
	_fill_bag(_music_bag, MUSIC_IDS, _last_music)
	return String(_music_bag.back())

static func for_encounter(serial: int, location: String = "", story: String = "") -> Dictionary:
	if serial == _serial and not _current.is_empty(): return _current.duplicate()
	var arena := preview_arena(location, story)
	if context_arena(location, story).is_empty():
		_arena_bag.pop_back()
	else:
		_arena_bag.erase(arena)
	var music := preview_music()
	_music_bag.pop_back()
	_last_arena = arena
	_last_music = music
	_serial = serial
	_current = {"arena":arena, "music":music}
	return _current.duplicate()

static func arena_path(id: String) -> String:
	return String(ARENAS.get(id, ARENAS.rooftop).path)

static func arena_shade(id: String) -> float:
	return float(ARENAS.get(id, ARENAS.rooftop).shade)

static func ultimate_path(module: String) -> String:
	if ULTIMATES.has(module): return ROOT + "ultimates/" + String(ULTIMATES[module])
	return "res://assets/graphics/battle/fc_art/refined/cg/backdrop.webp"
