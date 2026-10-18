class_name HighschoolNightTaskData
extends RefCounted
## 夜间可选任务。只登记与展示；不传送、不扣时、不发放奖励。
const ACCEPTED := "highschool.night_tasks.accepted"
const CLUE_PREFIX := "highschool.clue."
const CLUE_NAMES := {
	"roof": "天台噩梦的传闻", "perfect_score": "满分房间的传闻", "grove": "小树林的人影传闻",
	"toilet_note": "厕所里的纸条", "dorm_ghost": "宿舍闹鬼的传闻", "masked_performer": "面具表演者的传闻",
	"clinic": "跑操晕倒后的医务室调查",
}
const TASKS := [
	{"id": "devil_clinic", "name": "恶魔医务室", "requires": ["clinic"], "summary": "白天在医务室调查，寻找进入夜间医务室的线索。", "reward": "待定", "minutes": -1},
	{"id": "roof_nightmare", "name": "天台噩梦", "requires": ["roof"], "summary": "", "reward": "待定", "minutes": -1},
	{"id": "perfect_score_room", "name": "不打满分就出不来的房间", "requires": ["perfect_score"], "summary": "", "reward": "待定", "minutes": -1},
	{"id": "grove_shadows", "name": "小树林，人影攒动", "requires": ["grove"], "summary": "", "reward": "待定", "minutes": -1},
	{"id": "claustrophobia", "name": "幽闭恐惧症", "requires": ["toilet_note"], "summary": "", "reward": "待定", "minutes": -1},
	{"id": "sleep_defense", "name": "睡眠保卫战！", "requires": ["dorm_ghost"], "summary": "", "reward": "待定", "minutes": -1},
	{"id": "performer", "name": "表演性人格", "requires": ["masked_performer"], "summary": "", "reward": "待定", "minutes": -1},
]

static func eligible(task: Dictionary) -> bool:
	for clue: String in task.requires:
		if not GameFlow.has_flag(CLUE_PREFIX + clue): return false
	return true

static func sync_accepted() -> Array[String]:
	if not GameFlow.has_flag(HighschoolRewindData.FLAG_TUTORIAL_SEEN): return []
	var accepted: Dictionary = GameState.get_flag(ACCEPTED, {}).duplicate(true)
	var added: Array[String] = []
	for task: Dictionary in TASKS:
		if accepted.has(task.id) or not eligible(task): continue
		accepted[task.id] = {"day": GameState.day, "minute": GameState.in_game_minutes}
		added.append(task.id)
	if not added.is_empty(): GameFlow.set_flag(ACCEPTED, accepted)
	return added

static func entries() -> Array[Dictionary]:
	var accepted: Dictionary = GameState.get_flag(ACCEPTED, {})
	var result: Array[Dictionary] = []
	for task: Dictionary in TASKS:
		if accepted.has(task.id): result.append(task.duplicate(true))
	return result
