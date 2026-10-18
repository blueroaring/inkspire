class_name FightProgression
extends RefCounted
## 永久突破与剧情许可分开保存；剧情推进只开放任务资格，不直接突破。
const BASE_LEVEL_CAP := 10
const LEVELS_PER_BREAKTHROUGH := 10
const COST_PER_BREAKTHROUGH := 4
const ENERGY_PER_BREAKTHROUGH := 1
const MAX_ENERGY := 5
const BASE_DECK_SIZE := 6
const STAGES := [
	{"id":"arrival", "name":"初入高中", "flag":"", "max_rank":0},
	{"id":"campus", "name":"校园回忆", "flag":"highschool.warehouse.paper_beasts_defeated", "max_rank":1},
	{"id":"spirit", "name":"灵境初识", "flag":"spirit_story_tutorial_complete", "max_rank":2},
]

static func stage() -> Dictionary:
	var current: Dictionary = STAGES[0]
	for entry in STAGES:
		if not String(entry.flag).is_empty() and GameState.get_flag(entry.flag, false):
			current = entry
	return current

static func rank() -> int:
	if TowerRun.active: return TowerRun.rank()
	return clampi(int(GameState.fight_progression.get("rank", 0)), 0, int(STAGES.back().max_rank))

static func level_cap() -> int:
	if TowerRun.active: return TowerRun.cap()
	return BASE_LEVEL_CAP + rank() * LEVELS_PER_BREAKTHROUGH

static func hero_level(hero_id: String) -> int:
	return clampi(int(GameState.fight_profiles.get(hero_id, {}).get("level", 1)), 1, level_cap())

static func normalize_profile(hero_id: String) -> Dictionary:
	var profile: Dictionary = GameState.fight_profiles.get(hero_id, {"level":1, "xp":0}).duplicate(true)
	var old_level := maxi(1, int(profile.get("level", 1)))
	var xp := maxi(0, int(profile.get("xp", 0)))
	# 旧档超出新上限的等级折回储存经验，成长不会丢失。
	for level in range(level_cap(), old_level): xp += level * 100
	profile["level"] = mini(old_level, level_cap())
	profile["xp"] = xp
	GameState.fight_profiles[hero_id] = profile
	return profile

static func grant_xp(hero_id: String, amount: int) -> Dictionary:
	if not FightData.HEROES.has(hero_id): return {}
	var profile := normalize_profile(hero_id)
	profile.xp += maxi(0, amount)
	if TowerRun.active:
		while int(profile.level) < level_cap() and int(profile.xp) >= TowerData.xp_needed(int(profile.level)):
			profile.xp -= TowerData.xp_needed(int(profile.level))
			profile.level += 1
		if int(profile.level) >= level_cap(): profile.xp = 0
		GameState.fight_profiles[hero_id] = profile
		return profile
	while int(profile.level) < level_cap() and int(profile.xp) >= int(profile.level) * 100:
		profile.xp -= int(profile.level) * 100
		profile.level += 1
	GameState.fight_profiles[hero_id] = profile
	return profile

static func task_flag(next_rank: int) -> String:
	return "fight.breakthrough.night_task_%d_complete" % next_rank

static func breakthrough_error() -> String:
	if TowerRun.active: return "爬塔每通关五层提高等级上限，技能在 1/10/20/30/40 级开放。"
	if rank() >= int(stage().max_rank): return "当前剧情阶段尚未开放下一次突破。"
	if GameState.phase != "night": return "突破需要在夜间完成。"
	var capped := false
	for hero_id in FightData.HEROES:
		if hero_level(hero_id) >= level_cap(): capped = true
	if not capped: return "至少一名角色达到当前等级上限后才能突破。"
	if not GameState.get_flag(task_flag(rank() + 1), false): return "需要完成夜间突破任务（暂未开放）。"
	return ""

static func complete_breakthrough() -> bool:
	if not breakthrough_error().is_empty(): return false
	GameState.fight_progression["rank"] = rank() + 1
	for hero_id in FightData.HEROES: grant_xp(hero_id, 0)
	return true

static func summary() -> String:
	if TowerRun.active: return "墨痕尖塔 · 当前等级上限 %d / 50 · 最高 %d 层" % [level_cap(), int(TowerRun.data.get("highest", 0))]
	return "%s · 突破 %d 阶 · 等级上限 %d" % [stage().name, rank(), level_cap()]
