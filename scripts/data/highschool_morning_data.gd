class_name HighschoolMorningData
extends RefCounted
## 08_DIALOG：早餐之后至 502 入座。时间为演出配置，不给未写完的剧情补结局。

const ZHOU_SHEET := "res://assets/graphics/characters/generated/rewind_zhou/processed/sheet-transparent.png"
const STUDENT_ROOT := "res://assets/graphics/characters/generated/rewind_uniform_"
const ROOMMATE_LINES: Array[Dictionary] = [
	{"speaker": "周明远", "text": "帮我带个油条，老王。"},
	{"speaker": "姓王的舍友", "text": "又不去排了？再带饭真得收你钱了。"},
	{"speaker": "周明远", "text": "我先过去教室把作业补了，你一会过来抄我的就行。"},
	{"speaker": "周明远", "portrait_form": "spirit", "text": "我想想……他应该叫王天博，高三最后那段时间卷子太多了，我们确实是各自做一部分互相交换的。"},
	{"speaker": "周明远", "portrait_form": "spirit", "text": "人家抄作业也能考上一本，我就只能留在本市的二本。"},
	{"speaker": "周明远", "portrait_form": "spirit", "text": "这就是人和人之间的差距。（笑）"},
	{"speaker": "王天博", "text": "成交。你过去记得找个靠谱的人抄。"},
]
const SKIP_LINES: Array[Dictionary] = [
	{"speaker": "周明远", "text": "算了，直接去教室去补作业吧，还有好几张数学模考卷没写完呢。"},
	{"speaker": "周明远", "text": "要是今天上课讲的时候被叫起来回答解题思路就不好了。"},
	{"speaker": "周明远", "portrait_form": "spirit", "text": "答不出来倒是无所谓，但是要站着听课就没法眯觉了。"},
	{"speaker": "周明远", "portrait_form": "spirit", "text": "但是不吃早饭有饿趴下的风险。"},
]
const CLIMB_LINES: Array[Dictionary] = [
	{"speaker": "周明远", "portrait_form": "spirit", "text": "高三的同学都在各个楼的最高层。"},
	{"speaker": "周明远", "portrait_form": "spirit", "text": "说是为了让高一高二先去吃饭时不打扰到高三学习。"},
	{"speaker": "周明远", "portrait_form": "spirit", "text": "如此煞费苦心，还帮助高三学生锻炼身体了。"},
]
const CLASSROOM_UNFED: Array[Dictionary] = [
	{"speaker": "旁白", "text": "周明远急忙赶到了教室，坐了下来，拿出了没写完的卷子。"},
	{"speaker": "周明远", "text": "这个数学卷……这个物理模拟卷……"},
	{"speaker": "周明远", "text": "坏了，丛大哥还没来，没得抄了。"},
	{"speaker": "周明远", "text": "能写点是点吧。"},
	{"speaker": "周明远", "portrait_form": "spirit", "text": "丛大哥叫丛龙业，听名字就霸气，也是打竞赛的好手。"},
	{"speaker": "周明远", "portrait_form": "spirit", "text": "丛大哥做理科作业就像小菜般简单，写完也愿意直接给我们这些菜的人“借鉴”。"},
]
const MEALS := {
	"congee": {"label": "皮蛋瘦肉粥", "window": 0, "queue": 3, "arrival": 440,
		"bought": [{"speaker": "旁白", "text": "你排了人相对中等的队伍，买了一份皮蛋瘦肉粥。"}],
		"eating": [{"speaker": "周明远", "text": "没看见瘦肉，只看见了皮蛋和粥。"}]},
	"soy_combo": {"label": "油条鸡蛋豆浆", "window": 1, "queue": 2, "arrival": 430,
		"bought": [{"speaker": "旁白", "text": "你排了排队效率最快的窗口，买了一份油条鸡蛋豆浆组合。"}],
		"eating": [{"speaker": "周明远", "portrait_form": "spirit", "text": "经典永不过时。"},
			{"speaker": "周明远", "portrait_form": "spirit", "text": "最管饱的顶级早间能量套餐。"}]},
	"noodles": {"label": "阳春面", "window": 2, "queue": 5, "arrival": 450,
		"bought": [{"speaker": "旁白", "text": "你排了队最长的队伍，花了很长时间才买到了阳春面。"}],
		"eating": [{"speaker": "周明远", "text": "吃点热的东西。"},
			{"speaker": "周明远", "text": "应该还赶得上去补作业吧。"}]},
}
const DIALOGUES := {
	"roommate_breakfast": ROOMMATE_LINES,
	"skip_breakfast": SKIP_LINES,
	"climb_teaching": CLIMB_LINES,
	"classroom_unfed": CLASSROOM_UNFED,
}

static func student_sheet(index: int, backpack: bool = true) -> String:
	return STUDENT_ROOT + ["a", "b", "c", "d", "e"][posmod(index, 5)] \
		+ ("_backpack" if backpack else "") + "/processed/sheet-transparent.png"

static func route() -> String:
	return String(GameState.get_flag(HighschoolRewindData.FLAG_BREAKFAST_ROUTE, ""))

static func meal_id() -> String:
	return String(GameState.get_flag(HighschoolRewindData.FLAG_MEAL, ""))

static func is_active() -> bool:
	return GameState.phase == HighschoolData.PHASE_DAY \
		and GameFlow.has_flag(HighschoolRewindData.FLAG_POSSESSED) and route() != ""

static func migrate_boundary() -> void:
	# 兼容之前停在“这段经历将在后续剧情中继续”的存档。
	if is_active() and HighschoolRewindData.stage() == HighschoolRewindData.STAGE_SCRIPT_BOUNDARY \
			and not GameFlow.has_flag(HighschoolRewindData.FLAG_CLASSROOM_SEATED):
		HighschoolRewindData.set_stage(HighschoolRewindData.STAGE_RETURN_DORM)

static func arrival_minute() -> int:
	if route() == "roommate_brings":
		return 420
	if route() == "skip_breakfast":
		return 415
	return int(MEALS.get(meal_id(), MEALS["congee"]).arrival)

static func redirect_if_needed(location: String) -> bool:
	if not is_active(): return false
	migrate_boundary()
	var target := ""
	var spawn := "entrance"
	var continuation := HighschoolClassStoryData.target_location(HighschoolRewindData.stage())
	if continuation != "":
		if continuation == location: return false
		if continuation == "highschool.teaching_room":
			var room_id := "5_0_4" if String(GameState.get_flag(HighschoolFirstPeriodData.FLAG_TRIP, "")) == "toilet" else "5_0_0"
			SceneRouter.go_to.call_deferred(continuation, room_id, true)
			return true
		SceneRouter.go_to.call_deferred(continuation, "", true)
		return true
	match HighschoolRewindData.stage():
		HighschoolRewindData.STAGE_RETURN_DORM:
			if location not in ["highschool.dorm_2f", "highschool.dorm_205"]: target = "highschool.dorm_205"
		HighschoolRewindData.STAGE_LEAVE_DORM:
			if location not in ["highschool.dorm_1f", "highschool.dorm_2f", "highschool.dorm_205"]: target = "highschool.dorm_2f"
		HighschoolRewindData.STAGE_TO_CLASS, HighschoolRewindData.STAGE_TO_CANTEEN:
			if location != "highschool.external":
				target = "highschool.external"
				spawn = "canteen_return" if GameFlow.has_flag(HighschoolRewindData.FLAG_BREAKFAST_EATEN) else "dorm_return"
		HighschoolRewindData.STAGE_CANTEEN_MENU, HighschoolRewindData.STAGE_EATING:
			if location not in ["highschool.canteen_1f", "highschool.canteen_2f"]: target = "highschool.canteen_1f"
		HighschoolRewindData.STAGE_CLIMB:
			if not location.begins_with("highschool.teaching_") or location.ends_with("room"): target = "highschool.teaching_1f"
		HighschoolRewindData.STAGE_CLASSROOM, HighschoolRewindData.STAGE_SCRIPT_BOUNDARY:
			if location != "highschool.classroom_502": target = "highschool.classroom_502"
	if target == "": return false
	# 切场景淡出期间存档，可能记录到旧地点与新节点；读档时自动接续目标场景。
	SceneRouter.go_to.call_deferred(target, spawn, true)
	return true

static func classroom_population(minute: int) -> int:
	if minute < 425: return 9
	if minute < 440: return 15
	if minute < 470: return 23
	return 31

static func teacher_present(minute: int) -> bool:
	# 08_DIALOG：只有最晚的阳春面路线入座时有班主任；7:30 起统一监看早自习。
	return minute >= 450

static func menu(minute: int) -> Array[String]:
	if minute < 10 * 60:
		return ["皮蛋瘦肉粥", "油条 · 鸡蛋 · 豆浆", "阳春面"]
	if minute < 16 * 60:
		return ["荤素套餐", "盖浇饭", "面食"]
	return ["晚间套餐", "馄饨 · 饺子", "粥 · 包子"]

static func queues(minute: int) -> Array[int]:
	if minute < 10 * 60: return [3, 2, 5]
	if minute < 16 * 60: return [5, 4, 2]
	return [3, 5, 2]

static func objective() -> String:
	var midday := HighschoolMiddayData.objective()
	if midday != "": return midday
	if HighschoolRewindData.stage() in [HighschoolFirstPeriodData.BREAK, HighschoolFirstPeriodData.OUTING, HighschoolFirstPeriodData.RETURN]:
		return "8:50—9:00 · 第一节课课间"
	if HighschoolRewindData.stage() == HighschoolFirstPeriodData.BOARD: return "艾莉娜 · 仓库旁的公示栏"
	if HighschoolRewindData.stage() == HighschoolFirstPeriodData.END: return "9:00 · 第二节课即将开始"
	match HighschoolRewindData.stage():
		HighschoolClassStoryData.STUDY, HighschoolClassStoryData.STUDY_END: return "7:30—8:00 · 早自习"
		HighschoolClassStoryData.LOST: return "艾莉娜 · 寻找照片中的地点"
		HighschoolClassStoryData.PHOTO, HighschoolClassStoryData.BRIDGE: return "艾莉娜 · 时序回溯之桥"
		HighschoolClassStoryData.ECHO: return "靠近合影虚影，按 E 回溯记忆"
		HighschoolClassStoryData.MEMORY, HighschoolClassStoryData.AFTER: return "6 月 30 日 · 合影回忆"
		HighschoolClassStoryData.MATH, HighschoolClassStoryData.FIRST_CLASS: return "8:00—8:50 · 第一节数学课"
	match HighschoolRewindData.stage():
		HighschoolRewindData.STAGE_RETURN_DORM:
			return "回 205 找王天博带早饭" if route() == "roommate_brings" else "回宿舍取书包，准备出发"
		HighschoolRewindData.STAGE_LEAVE_DORM: return "离开宿舍楼"
		HighschoolRewindData.STAGE_TO_CANTEEN: return "前往食堂吃早饭"
		HighschoolRewindData.STAGE_CANTEEN_MENU: return "选择今天的早餐"
		HighschoolRewindData.STAGE_EATING: return "排队买饭，找座位吃早饭"
		HighschoolRewindData.STAGE_TO_CLASS: return "前往第一教学楼"
		HighschoolRewindData.STAGE_CLIMB: return "上五楼，前往靠国旗一侧的 502 教室"
		HighschoolRewindData.STAGE_CLASSROOM: return "找到自己的座位，坐下补卷子"
		HighschoolRewindData.STAGE_SCRIPT_BOUNDARY: return "502 · 早自习"
	return ""
