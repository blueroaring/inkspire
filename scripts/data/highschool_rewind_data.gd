class_name HighschoolRewindData
extends RefCounted
## 回映模式的可存档状态与选项表。后续日程只需在 OPTIONS 增加节点和事件。

const FLAG_POSSESSED := "highschool.rewind.possessed"
const FLAG_TUTORIAL_SEEN := "highschool.rewind.tutorial_seen"
const FLAG_ALYINA_VIEWED := "highschool.rewind.alyina_viewed"
const FLAG_WASHED := "highschool.rewind.washed"
const FLAG_BREAKFAST_ROUTE := "highschool.rewind.breakfast_route"
const FLAG_STAGE := "highschool.rewind.stage"
const FLAG_KEY_NODE := "highschool.rewind.day_1.key_node"
const FLAG_REWIND_COUNT := "highschool.rewind.count"
const FLAG_REWIND_TUTORIAL_SHOWN_COUNT := "highschool.rewind.tutorial_shown_count"
const FLAG_DAY_1_RESOLVED := "highschool.rewind.day_1.resolved"
const FLAG_ACTIVE_DAY_INDEX := "highschool.rewind.active_day_index"
const FLAG_DAY_CHOICES := "highschool.rewind.day_choices"
const FLAG_MEAL := "highschool.rewind.meal"
const FLAG_BREAKFAST_EATEN := "highschool.rewind.breakfast_eaten"
const FLAG_ROOMMATE_CHAT := "highschool.rewind.roommate_chat"
const FLAG_CLASSROOM_SEATED := "highschool.rewind.classroom_seated"
const FLAG_ARRIVAL_MINUTE := "highschool.rewind.arrival_minute"
const FLAG_SKIP_CHAT := "highschool.rewind.skip_chat"
const FLAG_CLIMB_CHAT := "highschool.rewind.climb_chat"

const STAGE_MORNING := "morning"
const STAGE_WASHING := "washing"
const STAGE_BREAKFAST := "breakfast"
const STAGE_BREAKFAST_HELP := "breakfast_help"
const STAGE_RETURN_DORM := "return_dorm"
const STAGE_LEAVE_DORM := "leave_dorm"
const STAGE_TO_CANTEEN := "to_canteen"
const STAGE_CANTEEN_MENU := "canteen_menu"
const STAGE_EATING := "eating"
const STAGE_TO_CLASS := "to_class"
const STAGE_CLIMB := "climb"
const STAGE_CLASSROOM := "classroom"
const STAGE_SCRIPT_BOUNDARY := "script_boundary"

const TUTORIAL: Array[String] = [
	"白天状态下，意识体状态的周明远附身于过去的周明远上，无法随意控制行动。",
	"但是意识体可以向本体传达“倾向”，从而使过去的本体执行一系列相关动作。",
	"作为“观测者”，你只需要在不同时间段选择选项，即可让过去的周明远经历相应的“既定的事件”。",
	"每段“既定的事件”都会消耗当天相应的时间，选项的触发条件也受到先前选项和当前时间的影响。",
	"随着发现的信息和线索的增多，可选择的分支和可能发生的事件也会增多。",
	"当“切换到艾莉娜视角”的选项亮起时，你可以在白天观看同一时间她那边发生了什么。",
	"从艾莉娜视角切回周明远视角后，周明远视角的时间不会变化。",
	"你可以认为艾莉娜视角是“同时”发生的事件，只是你在先后体验。",
	"在白天发现的线索可能会成为夜间任务，夜间的行动也可能影响白天事件。",
	"灵活进行观测，早日找到李安雅不辞而别的秘密吧！",
]

const REWIND_TUTORIAL: Array[String] = [
	"看来观测者没有寻找到本日的“关键节点”。",
	"“关键节点”是每日必须触发完成的某件事件，若未完成会无法推进下一日的剧情。",
	"尝试在白天选择不同的选项，或是在夜间完成更多的任务，找到该日的“关键节点”吧。",
]

# 选项后的对白与演出分开存放；每段有稳定 ID，供对话编辑器覆盖。
const MORNING_MATRON_ENTER: Array[Dictionary] = [
	{"speaker": "旁白", "text": "只见宿管阿姨用万能房卡打开了宿舍门。"},
]
const MORNING_MATRON_CALL: Array[Dictionary] = [
	{"speaker": "宿管阿姨", "text": "起床啦！太阳晒屁股了！"},
]
const MORNING_MATRON_LEAVE: Array[Dictionary] = [
	{"speaker": "旁白", "text": "宿管阿姨很快离开了，去敲下一间宿舍的门。"},
	{"speaker": "周明远", "portrait_form": "spirit", "text": "催命宿管……不好的回忆又涌现了出来。"},
]
const MORNING_WAKE: Array[Dictionary] = [
	{"speaker": "旁白", "text": "你和宿舍里的同学缓缓地起床了。"},
	{"speaker": "旁白", "text": "你们整理完床铺后，如僵尸般走出宿舍，各自前去洗漱，彼此无言。"},
	{"speaker": "周明远", "portrait_form": "spirit", "text": "你没睡够时也不想说话。"},
]
const ALYINA_VIEW: Array[Dictionary] = [
	{"speaker": "艾莉娜", "text": "……嗯，已经是早上了？"},
	{"speaker": "艾莉娜", "text": "外面好像有走路的声音。"},
	{"speaker": "艾莉娜", "text": "调查，调查……现在什么线索也没有，该怎么调查呢？"},
	{"speaker": "艾莉娜", "text": "目前有关的信息只有那张照片……"},
	{"speaker": "艾莉娜", "text": "那就先去照片的地点看看吧。"},
]
const WASHROOM_QUEUE: Array[Dictionary] = [
	{"speaker": "旁白", "text": "公共洗漱间里，水声和牙杯碰到台面的声音此起彼伏。你跟在同学后面，等着空出来的水龙头。"},
	{"speaker": "周明远", "portrait_form": "spirit", "text": "每天早上都要在这里排队……连谁习惯用哪个水龙头，我都还记得。"},
]
const WASHROOM_AT_SINK: Array[Dictionary] = [
	{"speaker": "旁白", "text": "前面的同学收好牙杯，给你让出了位置。你走到水槽前，拧开水龙头。"},
	{"speaker": "旁白", "text": "你刷完牙，用冷水洗了把脸，又把毛巾拧干。睡意终于散了一些。"},
]
const WASHROOM_FINISHED: Array[Dictionary] = [
	{"speaker": "旁白", "text": "你收好洗漱用品，和同学一起离开洗漱间。走廊里已经有人急着下楼吃早饭了。"},
]

# id、显示文案、所需时段及前置条件集中在此，场景只演出选中的事件。
const OPTIONS := {
	STAGE_MORNING: [
		{"id": "wash", "text": "起床，去卫生间排队洗漱", "minute": 390},
		{"id": "alyina", "text": "切换到艾莉娜视角", "minute": 390, "unseen_flag": FLAG_ALYINA_VIEWED},
	],
	STAGE_BREAKFAST: [
		{"id": "canteen", "text": "去食堂吃早饭", "minute": 405},
		{"id": "classroom", "text": "不去食堂，直接去教室", "minute": 405},
	],
	STAGE_BREAKFAST_HELP: [
		{"id": "roommate_brings", "text": "让舍友帮忙带早饭", "minute": 405},
		{"id": "skip_breakfast", "text": "早饭不吃了", "minute": 405},
	],
	STAGE_CANTEEN_MENU: [
		{"id": "congee", "text": "买一份皮蛋瘦肉粥"},
		{"id": "soy_combo", "text": "买一份油条鸡蛋豆浆"},
		{"id": "noodles", "text": "买一碗阳春面"},
	],
}

static func stage() -> String:
	return String(GameState.get_flag(FLAG_STAGE, ""))

static func set_stage(value: String) -> void:
	GameFlow.set_flag(FLAG_STAGE, value)

static func begin_day(index: int = -1) -> void:
	var active := index if index >= 0 else int(GameState.get_flag(HighschoolData.FLAG_DAY_INDEX, 0))
	GameFlow.set_flag(FLAG_ACTIVE_DAY_INDEX, active)
	GameFlow.set_flag(FLAG_DAY_CHOICES, [])
	GameFlow.set_flag(HighschoolBreakEvents.PENDING, {})

static func record_choice(id: String) -> void:
	var choices: Array = GameState.get_flag(FLAG_DAY_CHOICES, []).duplicate()
	if not choices.has(id):
		choices.append(id)
		GameFlow.set_flag(FLAG_DAY_CHOICES, choices)

# 选择树与可选文案共享 OPTIONS，扩充事件时只需在此补连接关系。
static func choice_tree() -> Array[Dictionary]:
	var choices: Array = GameState.get_flag(FLAG_DAY_CHOICES, [])
	var route := String(GameState.get_flag(FLAG_BREAKFAST_ROUTE, ""))
	# 从当天进度还原已遇到的选择层级，也兼容没有 day_choices 的旧存档。
	var breakfast_reached := GameFlow.has_flag(FLAG_WASHED) or route != "" \
		or stage() in [STAGE_BREAKFAST, STAGE_BREAKFAST_HELP, STAGE_SCRIPT_BOUNDARY]
	var help_reached := choices.has("classroom") or stage() == STAGE_BREAKFAST_HELP \
		or route in ["roommate_brings", "skip_breakfast"]
	var reached_stages: Array[String] = []
	if stage() != "" or not choices.is_empty() or breakfast_reached:
		reached_stages.append(STAGE_MORNING)
	if breakfast_reached:
		reached_stages.append(STAGE_BREAKFAST)
	if help_reached:
		reached_stages.append(STAGE_BREAKFAST_HELP)
	var nodes: Array[Dictionary] = [
		{"id": "start", "text": "06:30 · 起床前", "at": Vector2(20, 170), "state": "done", "parents": []},
	]
	if breakfast_reached:
		nodes.append({"id": "washed", "text": "06:45 · 洗漱完毕", "at": Vector2(530, 170),
			"state": "done", "parents": ["wash"]})
	var slots := {"wash": Vector2(275, 170), "alyina": Vector2(275, 340),
		"canteen": Vector2(785, 75), "classroom": Vector2(785, 260),
		"roommate_brings": Vector2(1040, 210), "skip_breakfast": Vector2(1040, 385)}
	var parents := {"wash": ["start"], "alyina": ["start"],
		"canteen": ["washed"], "classroom": ["washed"],
		"roommate_brings": ["classroom"], "skip_breakfast": ["classroom"]}
	for reached_stage in reached_stages:
		for entry in OPTIONS[reached_stage]:
			var id := String(entry["id"])
			var done := choices.has(id) or (id == "alyina" and GameFlow.has_flag(FLAG_ALYINA_VIEWED)) \
				or (id == "wash" and breakfast_reached) \
				or (id == "classroom" and help_reached) or route == id
			nodes.append({"id": id, "text": entry["text"], "at": slots[id],
				"state": "done" if done else ("available" if can_choose(id) else "missed"),
				"parents": parents[id]})
	var meal := String(GameState.get_flag(FLAG_MEAL, ""))
	if stage() in [STAGE_CANTEEN_MENU, STAGE_EATING] or meal != "":
		for index in OPTIONS[STAGE_CANTEEN_MENU].size():
			var entry: Dictionary = OPTIONS[STAGE_CANTEEN_MENU][index]
			nodes.append({"id": entry.id, "text": entry.text,
				"at": Vector2(1300, 30 + index * 150), "parents": ["canteen"],
				"state": "done" if meal == entry.id else ("available" if can_choose(entry.id) else "missed")})
	if GameFlow.has_flag(FLAG_CLASSROOM_SEATED):
		var parent_id := meal if meal != "" else route
		nodes.append({"id": "seated_502", "text": "%s · 502 入座" % arrival_time_label(),
			"at": Vector2(1570, 210), "parents": [parent_id], "state": "done"})
	HighschoolFirstPeriodData.append_tree(nodes)
	HighschoolMiddayData.append_tree(nodes)
	return nodes

static func arrival_time_label() -> String:
	var minute := int(GameState.get_flag(FLAG_ARRIVAL_MINUTE, GameState.in_game_minutes))
	return "%02d:%02d" % [minute / 60, minute % 60]

static func _key_flag(index: int) -> String:
	return FLAG_KEY_NODE if index == 0 else "highschool.rewind.day_%d.key_node" % (index + 1)

static func _resolved_flag(index: int) -> String:
	return FLAG_DAY_1_RESOLVED if index == 0 else "highschool.rewind.day_%d.resolved" % (index + 1)

static func available_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var minute := GameState.in_game_minutes
	for entry_variant in OPTIONS.get(stage(), []):
		var entry: Dictionary = entry_variant
		if minute != int(entry.get("minute", minute)):
			continue
		var needed := String(entry.get("required_flag", ""))
		if needed != "" and not GameFlow.has_flag(needed):
			continue
		var unseen := String(entry.get("unseen_flag", ""))
		if unseen != "" and GameFlow.has_flag(unseen):
			continue
		result.append(entry)
	return result

static func can_choose(id: String) -> bool:
	for entry in available_options():
		if String(entry["id"]) == id:
			return true
	return false

static func select(id: String) -> bool:
	if not can_choose(id):
		return false
	if id == "skip_breakfast" and GameFlow.has_flag(HighschoolMiddayData.FLAG_FAINTED):
		return false
	if id != "alyina":
		record_choice(id)
	match id:
		"alyina":
			pass # 片段完整播完后才标记，退出中途仍可重看。
		"wash":
			set_stage(STAGE_WASHING)
		"canteen":
			GameFlow.set_flag(FLAG_BREAKFAST_ROUTE, "canteen")
			set_stage(STAGE_RETURN_DORM)
		"classroom":
			set_stage(STAGE_BREAKFAST_HELP)
		"roommate_brings", "skip_breakfast":
			GameFlow.set_flag(FLAG_BREAKFAST_ROUTE, id)
			set_stage(STAGE_RETURN_DORM)
		"congee", "soy_combo", "noodles":
			GameFlow.set_flag(FLAG_MEAL, id)
			set_stage(STAGE_EATING)
	return true

static func complete_washing() -> void:
	if stage() != STAGE_WASHING:
		return
	GameFlow.set_flag(FLAG_WASHED, true)
	GameFlow.set_time(6, 45)
	set_stage(STAGE_BREAKFAST)

static func claim_item_once(event_id: String, item_id: String, amount: int = 1,
		scope: String = GameState.BAG_HIGHSCHOOL) -> bool:
	if event_id == "" or GameFlow.has_flag("highschool.rewind.reward." + event_id):
		return false
	if not Inventory.can_accept(item_id, amount, scope):
		return false
	if Inventory.add(item_id, amount, scope) != amount:
		return false
	GameFlow.set_flag("highschool.rewind.reward." + event_id, true)
	return true

# 供后续剧情的一白天＋一晚结束处调用。回溯只清除当天的临时选择；
# 背包、角色、技能、线索、夜间任务完成旗标及一次性奖励均保留。
static func finish_day() -> bool:
	var index := int(GameState.get_flag(FLAG_ACTIVE_DAY_INDEX,
		int(GameState.get_flag(HighschoolData.FLAG_DAY_INDEX, 0))))
	if GameFlow.has_flag(_resolved_flag(index)):
		return true
	if GameFlow.has_flag(_key_flag(index)):
		GameFlow.set_flag(_resolved_flag(index), true)
		GameFlow.set_flag(HighschoolData.FLAG_DAY_INDEX,
			maxi(int(GameState.get_flag(HighschoolData.FLAG_DAY_INDEX, 0)), index + 1))
		return true
	GameFlow.set_flag(FLAG_REWIND_COUNT, int(GameState.get_flag(FLAG_REWIND_COUNT, 0)) + 1)
	GameFlow.set_flag(FLAG_ALYINA_VIEWED, false)
	GameFlow.set_flag(FLAG_WASHED, false)
	GameFlow.set_flag(FLAG_BREAKFAST_ROUTE, "")
	GameFlow.set_flag(FLAG_DAY_CHOICES, [])
	for flag in [FLAG_BREAKFAST_EATEN, FLAG_ROOMMATE_CHAT, FLAG_CLASSROOM_SEATED, FLAG_SKIP_CHAT, FLAG_CLIMB_CHAT]:
		GameFlow.set_flag(flag, false)
	GameFlow.set_flag(FLAG_MEAL, "")
	GameFlow.set_flag(FLAG_ARRIVAL_MINUTE, 0)
	# 地图知识与背包时刻表跨回溯保留；当日路线条件重新记录。
	for flag in [HighschoolFirstPeriodData.FLAG_COPIED, HighschoolFirstPeriodData.FLAG_TEACHER]:
		GameState.story_flags.erase(flag)
	for flag in [HighschoolFirstPeriodData.FLAG_FINISHED, HighschoolFirstPeriodData.FLAG_BOARD_SEEN]:
		GameFlow.set_flag(flag, false)
	for flag in [HighschoolFirstPeriodData.FLAG_TRIP, HighschoolFirstPeriodData.FLAG_STEP, HighschoolFirstPeriodData.FLAG_ACTIVITY]:
		GameFlow.set_flag(flag, "")
	GameFlow.set_flag(HighschoolBreakEvents.PENDING, {})
	for flag in [HighschoolClassStoryData.FLAG_SEAT_DIALOGUE, HighschoolClassStoryData.FLAG_HOMEWORK,
		HighschoolClassStoryData.FLAG_MEMORY, HighschoolClassStoryData.FLAG_BRIDGE_INTRO, "spirit_story_tutorial_complete"]:
		GameFlow.set_flag(flag, false)
	GameFlow.set_flag(FLAG_POSSESSED, false)
	set_stage("")
	GameFlow.set_phase(HighschoolData.PHASE_NIGHT)
	GameFlow.set_time(5, 0)
	return false
