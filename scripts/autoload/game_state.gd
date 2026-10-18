extends Node
signal flag_changed(flag: String)
signal state_replaced
## 全局游戏状态（自动加载单例 GameState）
##
## 职责：保存"玩家现在在游戏的哪个进度"这一类纯数据，不碰场景、不碰 UI。
## 存档系统直接序列化本单例，所以这里只放能被 JSON 化的数据（int/float/String/bool/Array/Dictionary）。
##
## 章节框架：每章（chapter）包含白天段（day）与夜间段（night），
## 大学作为 hometown 不属于章节，用 location == "college.*" 表示。

const CHAPTER_COLLEGE := 0  ## 序章 / 大学日常（hometown）

## 背包分册：需求 `01_GOALS.md` 第 3 条——**大学与高中的背包互相独立**。
## 分册常量放在这里（而不是 ItemDb）是因为它同时属于存档格式的一部分。
const BAG_COLLEGE := "college"
const BAG_HIGHSCHOOL := "highschool"
## 高中**夜间**那本独立的钱（白天与大学共享，见 `current_wallet_scope()`）。
## ⚠️ 字面量与 `HighschoolData.WALLET_NIGHT` 必须一致；写常量会在两个脚本之间形成
##    解析期循环引用（`HighschoolData` 里又要读 `GameState.BAG_COLLEGE`），
##    所以这里写字面量，并由 `tools/story_flow_test.tscn` 的断言守住一致性。
const WALLET_NIGHT := "highschool_night"
const BAG_NAMES := {
	BAG_COLLEGE: "大学",
	BAG_HIGHSCHOOL: "高中",
	WALLET_NIGHT: "高中 · 夜间（独立）",
}

## 场景 ID -> 场景文件。SceneRouter 用这张表跳转，新增地点只改这里。
##
## ⚠️ 教学楼三层（`college.teaching_1f~3f`）的 id 是 `TeachingData.location_id()` **拼**出来的，
##    这里只能写字面量（const 里不能调函数）。所以两边的一致性靠断言守：
##    `teaching_floor.gd` 的自检会核对"本层的地点 id 在不在 LOCATIONS 里"。
##    这类字符串拼错的表现是 `SceneRouter: 未登记的地点` 警告 + 楼梯按了没反应（不会有报错）。
const LOCATIONS := {
	"tower": "res://scenes/tower/tower.tscn",
	"main_menu": "res://scenes/ui/main_menu.tscn",
	"intro_cg": "res://scenes/boot/intro_cg.tscn",
	"cg.alyina_fall": "res://scenes/boot/alyina_cg.tscn",
	"college.dorm": "res://scenes/college/dorm.tscn",
	"college.bathroom": "res://scenes/college/bathroom.tscn",
	"college.canteen": "res://scenes/college/canteen.tscn",
	"college.campus": "res://scenes/college/campus.tscn",
	"college.campus_teaching": "res://scenes/college/campus_teaching.tscn",
	"college.campus_sports": "res://scenes/college/campus_sports.tscn",
	"college.teaching_1f": "res://scenes/college/teaching_1f.tscn",
	"college.teaching_2f": "res://scenes/college/teaching_2f.tscn",
	"college.teaching_3f": "res://scenes/college/teaching_3f.tscn",
	"fight_prepare": "res://scenes/fight/preparation.tscn",
	"fight_characters": "res://scenes/fight/characters.tscn",
	"fight": "res://scenes/fight/battle.tscn",
	"spirit.list": "res://scenes/spirit/level_list.tscn",
	"spirit.realm": "res://scenes/spirit/realm.tscn",
	"highschool.gate": "res://scenes/highschool/gate.tscn",
	"highschool.abandoned": "res://scenes/highschool/abandoned.tscn",
	"cg.first_run_pv": "res://scenes/highschool/first_run_pv.tscn",
	"highschool.warehouse": "res://scenes/highschool/warehouse.tscn",
	"highschool.corridor": "res://scenes/highschool/corridor.tscn",
	"highschool.hall": "res://scenes/highschool/hall.tscn",
	"highschool.external": "res://scenes/highschool/external.tscn",
	"highschool.dorm_1f": "res://scenes/highschool/dorm_1f.tscn",
	"highschool.dorm_2f": "res://scenes/highschool/dorm_2f.tscn",
	"highschool.dorm_3f": "res://scenes/highschool/dorm_3f.tscn",
	"highschool.dorm_4f": "res://scenes/highschool/dorm_4f.tscn",
	"highschool.dorm_205": "res://scenes/highschool/dorm_205.tscn",
	"highschool.washroom": "res://scenes/highschool/washroom.tscn",
	"highschool.canteen_1f": "res://scenes/highschool/canteen_1f.tscn",
	"highschool.canteen_2f": "res://scenes/highschool/canteen_2f.tscn",
	"highschool.teaching_1f": "res://scenes/highschool/teaching_1f.tscn",
	"highschool.teaching_2f": "res://scenes/highschool/teaching_2f.tscn",
	"highschool.teaching_3f": "res://scenes/highschool/teaching_3f.tscn",
	"highschool.teaching_4f": "res://scenes/highschool/teaching_4f.tscn",
	"highschool.teaching_5f": "res://scenes/highschool/teaching_5f.tscn",
	"highschool.classroom_502": "res://scenes/highschool/classroom_502.tscn",
	"highschool.exercise": "res://scenes/highschool/exercise.tscn",
	"highschool.clinic": "res://scenes/highschool/clinic.tscn",
	"spirit.clinic_key": "res://scenes/highschool/clinic_key_bridge.tscn",
	"highschool.alyina_memory": "res://scenes/highschool/alyina_memory.tscn",
	"cg.highschool_photo": "res://scenes/highschool/photo_memory_cg.tscn",
	"highschool.teaching_room": "res://scenes/highschool/teaching_room.tscn",
}

## 各地点的中文显示名（存档槽界面用）
const LOCATION_NAMES := {
	"main_menu": "标题画面",
	"intro_cg": "序章 CG",
	"cg.alyina_fall": "艾莉娜 · 登场 CG",
	"college.dorm": "大学 · 宿舍",
	"college.bathroom": "大学 · 卫生间",
	"college.canteen": "大学 · 食堂",
	"college.campus": "大学 · 生活区",
	"college.campus_teaching": "大学 · 教学区",
	"college.campus_sports": "大学 · 运动区",
	"college.teaching_1f": "大学 · 教学楼 一层",
	"college.teaching_2f": "大学 · 教学楼 二层",
	"college.teaching_3f": "大学 · 教学楼 三层",
	"fight_prepare": "夜间 · 战斗准备",
	"fight_characters": "角色系统",
	"fight": "夜间 · 战斗试炼",
	"spirit.list": "灵境 · 关卡列表",
	"spirit.realm": "时序回溯之桥",
	"highschool.gate": "高中 · 校门",
	"highschool.abandoned": "高中 · 废弃校园",
	"cg.first_run_pv": "一周目 · 剧情 PV",
	"highschool.warehouse": "高中 · 地下仓库",
	"highschool.corridor": "高中 · 地下仓库走廊",
	"highschool.hall": "高中 · 仓库大厅",
	"highschool.external": "高中 · 校园外部",
	"highschool.dorm_1f": "高中 · 男生宿舍一层",
	"highschool.dorm_2f": "高中 · 男生宿舍二层",
	"highschool.dorm_3f": "高中 · 男生宿舍三层",
	"highschool.dorm_4f": "高中 · 男生宿舍四层",
	"highschool.dorm_205": "高中 · 男生宿舍 205",
	"highschool.washroom": "高中 · 公共洗漱间",
	"highschool.canteen_1f": "高中 · 食堂一层",
	"highschool.canteen_2f": "高中 · 食堂二层",
	"highschool.teaching_1f": "高中 · 第一教学楼一层",
	"highschool.teaching_2f": "高中 · 第一教学楼二层",
	"highschool.teaching_3f": "高中 · 第一教学楼三层",
	"highschool.teaching_4f": "高中 · 第一教学楼四层",
	"highschool.teaching_5f": "高中 · 第一教学楼五层",
	"highschool.classroom_502": "高中 · 502 教室",
	"highschool.exercise": "高中 · 阳光体育",
	"highschool.clinic": "高中 · 医务室",
	"spirit.clinic_key": "时序回溯之桥 · 过去的钥匙",
	"highschool.alyina_memory": "高中 · 艾莉娜的观测",
	"cg.highschool_photo": "高中 · 合影回忆",
	"highschool.teaching_room": "高中 · 教学楼侧室",
}

var slot: int = -1                  ## 当前存档槽（1..5），-1 表示尚未开始新游戏
var chapter: int = CHAPTER_COLLEGE  ## 当前章节
var phase: String = "day"           ## day / night
var location: String = "main_menu"  ## 当前地点 ID
var spawn_point: String = ""        ## 进入场景时要站到的出生点名字（空 = 用场景默认）
## 最近一次"真的在玩"的地点（不含主菜单 / 开场 / CG 过场）。
##
## 用途：**在 CG 过场里回标题时的自动存档锚点** —— 用户 2026-09-20：
## "返回标题应该自动保存当前进度"。那时 `location` 是 `cg.xxx`，直接存进去
## 会让下次读档重播那段过场，所以存档写这个锚点。
## ⚠️ 旧存档没有这一项 → 读回空串（`from_dict` 的默认），那时退回"用当前 location"。
var last_play_location: String = ""
var in_game_minutes: int = 10 * 60  ## 游戏内时间（从 0:00 起的分钟数，0..1439 循环）
## 第几天（0 = 开局那天）。**必须显式存**，不能从 `in_game_minutes` 反推：
## 那个时钟是 0..1439 循环的，跨过 0 点后它反而变小了（中午开局 → 推过午夜 → 回到凌晨），
## 用"经过了多少分钟"折算天数会在跨天那一刻算出 -1 天（实测踩到）。
## 打工的"一天一次"、将来的每日刷新都读它，跟着存档走。
var day: int = 0
var played_seconds: float = 0.0     ## 本周目游玩时长
var story_flags: Dictionary = {}    ## 剧情开关，例如 {"woke_up": true}
var party: Array = []               ## 队伍成员 ID 列表（战斗系统预留）
## 高中战斗系统的持久成长数据。战斗规则保存在 FightSystem，存档只保存这些纯数据。
var fight_profiles: Dictionary = {}
var fight_progression: Dictionary = {} ## 全队永久突破阶位。
var fight_accessories: Dictionary = {} ## 已拥有饰品 id -> 当前装备者（空字符串表示仓库）。
var fight_equipment: Dictionary = {} ## 角色 id -> 两个饰品槽。
var fight_health: Dictionary = {} ## 灵境与外部共享的生命；旧档缺省为角色最大值。
var spirit_progress: Dictionary = {} ## 通关纪录、剩余神经通路与操作偏好。
var fight_loadouts: Dictionary = {}
var fight_formation: Array = ["zhoumingyuan", "alyina"]
var fight_attributes: Dictionary = {"zhoumingyuan": "none"}
var fight_unlocked_attributes: Array = ["none"]
## 背包：分册 -> {道具 id: 数量}。增删走 Inventory 单例（它会发信号、做上限检查），
## 这里只负责"能被 JSON 化地存下来"。
var inventories: Dictionary = {}
## 钱包：分册 -> 钱（**整数分**，见 `Currency` 单例）。
##
## 为什么也分册：需求 `01_GOALS.md` 第 7 条把大学当 hometown、高中当关卡，
## 两边的经济本来就该独立（大学打工挣的钱不该直接买到高中篇的东西）；
## 分册口径与背包**完全一致**（同一个 `current_wallet_scope()`），
## 将来做"带钱进高中"不需要改数据结构，只是换个 scope 读写。
##
## ⚠️ 这里存的是**分**（int），不是元：浮点数进 JSON 会得到 39.999999 这种值，
##    而"买不起"判定必须精确。换算只在 `Currency` 里做。
var money: Dictionary = {}
## 已经被拿走的**一次性场景物件**：{"<地点 id>/<物件 id>": true}。
## 为什么需要它：地图上的拾取物是**运行期按数据生成的**，如果只靠"物件自己消失了"，
## 重进场景就会照数据再刷一个出来（手机被无限复制就是这个原因）。
## 键由场景自己给（见 `MapData.dorm_pickups()` 的 `pickup_id`），跟着存档走。
var collected: Dictionary = {}
## 打工记录：{"<地点 id>/<工位 id>": 第几天打过}（天 = `Currency.current_day()`）。
## 有了它才能做"同一天不能重复领工资"，而且**跟着存档走** —— 否则读档就能刷钱。
var work_records: Dictionary = {}
var tokens: int = 0                 ## 进入高中所需的代币（流程系统预留）


## 时钟**是否已经露过面**（用户 2026-09-20："一开始开局显示的是 10:00，改为未知，
## 看了手机后改为 12:04"）。
##
## 为什么要有这个字段、而不是把 `in_game_minutes` 设成 -1：
##   ① `in_game_minutes` 是 `0..1439` 的**循环时钟**，负值会被到处当成坏数据
##      （`Daylight`/`Currency`/`format_time` 全都要特判）；
##   ② "还没看手机"本来就是**剧情状态**（跟 `woke_up` 同源），而不是时间的值 ——
##      玩家睡着了，不知道几点；看过手机才知道。
## ⚠️ 它跟着存档走：读档时时刻已经知道了（进度在那之后），
##    所以旧存档没有这个键时要按 **true** 兜底（`from_dict` 里那句），
##    否则读档后 HUD 会从"未知"开始（明明玩家早就看过手机）。
var time_known: bool = false

## "刚从艾莉娜登场 CG 出来、那三句落地台词还没说"——**会话级，不存档**。
##
## 用途：`CgData.alyina_landing_lines()` 那三句按用户要求从 CG 里挪到"CG 播完后"
## （`StoryData.maybe_play_alyina_tour()`）。为什么不复用持久开关
## `TeachingData.STORY_ALYINA_FOLLOWS` 当判据：那个开关跟着存档走，
## 读一个中期的存档时它照样成立 → 玩家一进校园就被"刚认识她"的寒暄拦一次。
## ⚠️ 同理**不要**把它写进存档：它是"两个场景之间的一次交接"，跨进程没有意义
##    （真在那一瞬间退出游戏，代价只是这段寒暄丢掉一次，不影响任何进度）。
var alyina_landing_pending: bool = false
## 契约后醒来时的宿舍鸟鸣，仅在这次宿舍场景停留期间有效；不写入存档。
var morning_birds_active: bool = false


func reset_new_game(new_slot: int) -> void:
	slot = new_slot
	chapter = CHAPTER_COLLEGE
	phase = "day"
	location = "intro_cg"
	spawn_point = ""
	# 新档还没有"玩过的地方"（见 `last_play_location`）
	last_play_location = ""
	in_game_minutes = 10 * 60
	# 新游戏：**时刻是未知的**，等玩家看过手机（`GameFlow.reveal_time()`）才显示
	time_known = false
	# 会话级标记也一并清掉（新游戏当然没有"刚从登场 CG 出来"这回事）
	alyina_landing_pending = false
	morning_birds_active = false
	day = 0
	played_seconds = 0.0
	story_flags = {}
	party = ["zhoumingyuan"]
	fight_profiles = {}
	fight_progression = {}
	fight_accessories = {}
	fight_equipment = {}
	fight_health = {}
	spirit_progress = {}
	fight_loadouts = {}
	fight_formation = ["zhoumingyuan", "alyina"]
	fight_attributes = {"zhoumingyuan": "none"}
	fight_unlocked_attributes = ["none"]
	inventories = {}
	money = {}
	collected = {}
	work_records = {}
	tokens = 0
	state_replaced.emit()


## 跨天：第几天 +1。**唯一入口**是 `GameFlow.advance_time()` 在时间回绕的那一刻 ——
## 所以"日结"（打工一天一次、将来的每日刷新）只有一条路会触发，不会漏也不会重复。
func advance_day() -> void:
	day += 1


## 当前该看哪一册背包：由章节推出来（高中篇 chapter >= 1，大学是序章 0）
func current_bag_scope() -> String:
	if chapter >= 1:
		return BAG_HIGHSCHOOL
	return BAG_COLLEGE


## 当前该用哪个钱包。
##
## ⚠️ 与背包**不同源**（2026-09-19 按用户设定改）：用户 `01_GOALS.md` 写的是
##    "高中**白天**的经济系统与大学共享，但是**夜间**是独立的系统"——
##    也就是"钱"这件事在高中是**白天共享、夜间独立**，而不是"高中整个人一套钱"。
##    判据收在 `HighschoolData.wallet_scope()` 一处，这里只做转发。
func current_wallet_scope() -> String:
	if chapter >= 1:
		return HighschoolData.wallet_scope(phase)
	return BAG_COLLEGE


## 某一册钱包里有多少钱（**分**）。分册不存在 = 0，不写坏数据。
func money_for(scope: String) -> int:
	return int(money.get(scope, 0))


func bag_scope_name(scope: String) -> String:
	return String(BAG_NAMES.get(scope, scope))


## 这件一次性场景物件是否已经被拿走了（重进场景时据此不再生成）
func is_collected(key: String) -> bool:
	if key == "":
		return false
	return bool(collected.get(key, false))


func mark_collected(key: String) -> void:
	if key == "":
		return
	collected[key] = true


## 撤销（调试/剧情回溯用；正常玩法不需要）
func clear_collected(key: String) -> void:
	collected.erase(key)


func get_flag(flag: String, fallback: Variant = false) -> Variant:
	return story_flags.get(flag, fallback)


func set_flag(flag: String, value: Variant = true) -> void:
	if story_flags.has(flag) and story_flags[flag] == value: return
	story_flags[flag] = value
	flag_changed.emit(flag)


## 时钟文字。**还没看过手机时显示"未知"**（用户 2026-09-20 的要求）。
##
## ⚠️ 显示用的"未知"与"内部时钟的值"是两件事：内部那个 10:00 只是为了有个合法初值，
##    玩家看不到它 —— 看到手机之前，现实里是"睡到中午、不知道几点"。
func format_time() -> String:
	if not time_known:
		return TIME_UNKNOWN_TEXT
	var h := int(in_game_minutes / 60) % 24
	var m := in_game_minutes % 60
	return "%02d:%02d" % [h, m]


## 时钟显示不出来的那段时间用什么字（HUD 与手机共用同一处，免得两处写得不一样）
const TIME_UNKNOWN_TEXT := "未知"


func location_display_name() -> String:
	return LOCATION_NAMES.get(location, location)


## 序列化为可 JSON 化的字典（存进存档文件）
func to_dict() -> Dictionary:
	return {
		"slot": slot,
		"chapter": chapter,
		"phase": phase,
		"location": location,
		"spawn_point": spawn_point,
		# 最近一次"真的在玩"的地点（见 `GameFlow.last_play_location`）：
		# 回标题时若正卡在 CG 过场里，自动存档用它当锚点，读档也就回到这里。
		"last_play_location": last_play_location,
		"in_game_minutes": in_game_minutes,
		"time_known": time_known,
		"day": day,
		"played_seconds": played_seconds,
		"story_flags": story_flags,
		"party": party,
		"fight_profiles": fight_profiles,
		"fight_progression": fight_progression,
		"fight_accessories": fight_accessories,
		"fight_equipment": fight_equipment,
		"fight_health": fight_health,
		"spirit_progress": spirit_progress,
		"fight_loadouts": fight_loadouts,
		"fight_formation": fight_formation,
		"fight_attributes": fight_attributes,
		"fight_unlocked_attributes": fight_unlocked_attributes,
		"inventories": inventories,
		"money": money,
		"collected": collected,
		"work_records": work_records,
		"tokens": tokens,
	}


## 从存档字典恢复
func from_dict(data: Dictionary) -> void:
	slot = int(data.get("slot", slot))
	chapter = int(data.get("chapter", chapter))
	phase = String(data.get("phase", phase))
	location = String(data.get("location", location))
	spawn_point = String(data.get("spawn_point", ""))
	# 旧存档没有 `last_play_location`：兜底成空串（= 退回"用当前 location"的老行为）
	last_play_location = String(data.get("last_play_location", ""))
	in_game_minutes = int(data.get("in_game_minutes", in_game_minutes))
	# ⚠️ 旧存档没有 `time_known` 键：**兜底成 true**（那时玩家早就看过手机了，
	#    有明确时刻）—— 兜底成 false 的话，读档后 HUD 会莫名其妙地回到"未知"。
	time_known = bool(data.get("time_known", true))
	# 经济系统之前的老存档没有 day 键：读成 0（= 开局那天），不会因为缺字段而崩
	day = int(data.get("day", 0))
	played_seconds = float(data.get("played_seconds", 0.0))
	story_flags = data.get("story_flags", {})
	party = data.get("party", [])
	fight_profiles = data.get("fight_profiles", {})
	fight_progression = data.get("fight_progression", {})
	fight_accessories = data.get("fight_accessories", {})
	fight_equipment = data.get("fight_equipment", {})
	fight_health = data.get("fight_health", {})
	spirit_progress = data.get("spirit_progress", {})
	fight_loadouts = data.get("fight_loadouts", {})
	fight_formation = data.get("fight_formation", ["zhoumingyuan", "alyina"])
	fight_attributes = data.get("fight_attributes", {"zhoumingyuan": "none"})
	fight_unlocked_attributes = data.get("fight_unlocked_attributes", ["none"])
	inventories = data.get("inventories", {})
	collected = data.get("collected", {})
	# 旧存档（背包分册之前）只有一个 inventory 字典：整个搬进"大学"那一册
	if inventories.is_empty() and data.has("inventory"):
		var legacy: Dictionary = data.get("inventory", {})
		if not legacy.is_empty():
			inventories[BAG_COLLEGE] = legacy
	# 经济系统之前的老存档没有 money / work_records 这两个键：读成空字典（= 一分钱没有）
	money = data.get("money", {})
	work_records = data.get("work_records", {})
	tokens = int(data.get("tokens", 0))
	FightEquipmentData.normalize(not data.has("fight_equipment"))
	state_replaced.emit()
