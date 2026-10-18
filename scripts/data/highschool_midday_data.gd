class_name HighschoolMiddayData
extends RefCounted
const Dialogue := preload("res://scripts/data/highschool_midday_dialogue.gd")
const LESSON := "second_class"
const EXERCISE := "morning_exercise"
const COLLAPSE := "exercise_collapse"
const CLINIC := "clinic_arrival"
const EXPLORE := "clinic_explore"
const KEY_FOUND := "clinic_key_found"
const BRIDGE := "clinic_key_bridge"
const RECOVER := "clinic_recover"
const LUNCH := "midday_lunch"
const CEREMONY := "opening_ceremony_ready"
const LONG_BREAK := "morning_long_break"
const PREFIX := "highschool.midday."
const FLAG_FAINTED := PREFIX + "fainted_once"
const FLAG_RUNNING_SEEN := PREFIX + "running_seen"
const FLAG_KEY := PREFIX + "key_copied"
const KEY_ITEM := "clinic_key_copy"
const SUBJECTS := ["chinese", "math", "english", "chemistry", "biology", "physics"]
const NAMES := {"chinese": "语文", "math": "数学", "english": "英语", "chemistry": "化学", "biology": "生物", "physics": "物理"}
const MATH_TOPICS := ["conics", "geometry", "probability", "trigonometry", "derivative"]
const EXPLORE_START := 645 # 10:45，大课间中段。
const EXPLORE_END := 720
const SECONDS_PER_MINUTE := 4.0

static func day_index() -> int:
	return int(GameState.get_flag(HighschoolRewindData.FLAG_ACTIVE_DAY_INDEX, 0))

static func exercise_kind() -> String:
	return "running" if posmod(day_index(), 2) == 0 else "gymnastics"

static func lesson_plan(period: int = 2) -> Dictionary:
	var key := PREFIX + "lessons.%d" % day_index()
	var plans: Dictionary = GameState.get_flag(key, {}).duplicate(true)
	var id := str(period)
	if plans.has(id): return plans[id]
	var previous := "math" if period <= 2 else String(lesson_plan(period - 1).subject)
	# Recursion can populate prior periods; keep those entries when committing this one.
	plans = GameState.get_flag(key, {}).duplicate(true)
	var choices := SUBJECTS.duplicate()
	choices.erase(previous)
	var subject: String = choices.pick_random()
	var plan := {"subject": subject, "mode": "paper" if randi_range(0, 1) == 0 else "review", "topic": MATH_TOPICS.pick_random()}
	plans[id] = plan
	GameFlow.set_flag(key, plans)
	return plan

static func lesson_lines(plan: Dictionary) -> Array:
	if plan.subject != "math": return lines(plan.subject)
	var result := lines("math_intro")
	result.append({"speaker": "旁白", "text": "这节课是%s。" % ("讲卷子" if plan.mode == "paper" else "复习知识点")})
	result.append_array(lines("math_paper" if plan.mode == "paper" else "math_" + String(plan.topic)))
	return result

static func lines(id: String) -> Array:
	return DialoguePatch.apply("highschool.midday." + id, Dialogue.LINES[id].duplicate(true))

static func should_faint() -> bool:
	return not GameFlow.has_flag(HighschoolRewindData.FLAG_BREAKFAST_EATEN) and not GameFlow.has_flag(FLAG_FAINTED)

static func mark_fainted() -> void:
	GameFlow.set_flag(FLAG_FAINTED, true)
	GameFlow.set_flag("highschool.clue.clinic", true)
	HighschoolRewindData.record_choice("exercise_faint")
	HighschoolRewindData.set_stage(COLLAPSE)

static func target_location(stage: String) -> String:
	if stage == LESSON: return "highschool.classroom_502"
	if stage in [EXERCISE, COLLAPSE, CEREMONY, LONG_BREAK]: return "highschool.exercise"
	if stage in [CLINIC, EXPLORE, KEY_FOUND, BRIDGE, RECOVER]: return "highschool.clinic"
	if stage == LUNCH: return "highschool.canteen_1f"
	return ""

static func reset_search() -> void:
	GameFlow.set_flag(PREFIX + "search", {})
	GameFlow.set_flag(PREFIX + "position", [])
	GameFlow.set_flag(PREFIX + "search_seconds", 0.0)
	GameFlow.set_time(10, 45)
	HighschoolRewindData.set_stage(EXPLORE)

static func search_state() -> Dictionary:
	return GameState.get_flag(PREFIX + "search", {}).duplicate(true)

static func discover(id: String) -> void:
	var state := search_state()
	state[id] = true
	GameFlow.set_flag(PREFIX + "search", state)

static func objective() -> String:
	match HighschoolRewindData.stage():
		LESSON: return "09:00—09:50 · 第二节课"
		EXERCISE, COLLAPSE: return "10:00—10:30 · 阳光体育"
		CLINIC, RECOVER: return "医务室 · 留观"
		EXPLORE: return "艾莉娜 · 12:00 前寻找医务室钥匙"
		KEY_FOUND, BRIDGE: return "时序回溯之桥 · 复制医务室钥匙"
		LUNCH: return "12:00 · 午餐时间"
		CEREMONY: return "10:30 · 前往中央广场参加开学典礼"
		LONG_BREAK: return "10:30—11:00 · 大课间"
	return ""

static func append_tree(nodes: Array[Dictionary]) -> void:
	var choices: Array = GameState.get_flag(HighschoolRewindData.FLAG_DAY_CHOICES, [])
	if not choices.has("second_lesson"): return
	nodes.append({"id": "second_lesson", "text": "09:00 · " + String(NAMES[lesson_plan().subject]), "at": Vector2(2670, 210), "parents": ["first_break"], "state": "done"})
	if not choices.has("exercise"): return
	nodes.append({"id": "exercise", "text": "10:00 · 阳光体育", "at": Vector2(2940, 210), "parents": ["second_lesson"], "state": "done"})
	if choices.has("exercise_faint"):
		nodes.append({"id": "exercise_faint", "text": "空腹晕倒 · 医务室", "at": Vector2(3210, 330), "parents": ["exercise"], "state": "done"})
		if choices.has("clinic_key"):
			nodes.append({"id": "clinic_key", "text": "双人回溯 · 钥匙复制品", "at": Vector2(3480, 330), "parents": ["exercise_faint"], "state": "done"})
