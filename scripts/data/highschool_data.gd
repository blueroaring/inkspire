class_name HighschoolData
extends RefCounted
## 高中阶段的**规则表**（用户 `request/01_GOALS.md` 第 11 段的设定）。
##
## 规则表供高中场景与战斗入口调用；高中外部、废弃校园和地下仓库的场景脚本
## 只负责演出与交互，昼夜和战斗判据仍统一从这里读取。
##
## 用户给的六条设定（原文 → 这里的落点）：
##   ① "白天主角是只能魂附在过去的本体身体上，而夜间可以以灵魂形态移动进行战斗"
##      → `player_can_move_freely()` / `player_can_fight()`
##   ② "艾莉娜在高中阶段的任意时间段都可以自由移动，但是只有在夜间才能战斗"
##      → `alyina_can_move_freely()`（恒真）/ `alyina_can_fight()`
##   ③ "白天没有怪物" → `monsters_exist()`
##   ④ "除了主角和女主李安雅，其他人都看不见艾莉娜" → `others_can_see_alyina()`
##   ⑤ "高中白天的经济系统与大学共享，但是夜间是独立的" → `wallet_scope()`
##   ⑥ "在高中里经过一天等于大学经过半天" → `COLLEGE_COOLDOWN_MINUTES`
##
## ⚠️ 判据一律收在这里：以后高中篇里任何地方要问"现在能不能打"，都调这些函数。
##    各处自己写 `if phase == "night"` 的话，改设定时要满地找。

## 两个时段（与 `GameState.phase` 同一套取值，不另造一套）
const PHASE_DAY := "day"
const PHASE_NIGHT := "night"

## 高中夜间**独立**的那本钱（白天与大学共享，见 `wallet_scope()`）
const WALLET_NIGHT := "highschool_night"

## 在高中里过完整的一天 = 大学过半天 → 回大学要等 **12 小时**（720 游戏分钟）
const COLLEGE_COOLDOWN_MINUTES := 12 * 60

## 高中一天的长度（游戏分钟）——"过完完整的一天"的判据
const HIGH_SCHOOL_DAY_MINUTES := 24 * 60

## 看得见艾莉娜的人（用户："除了主角和女主李安雅，其他人都看不见她"）
const SEERS: Array[String] = ["周明远", "李安雅"]

## 剧情开关：与艾莉娜签订天使（精灵）契约（本批剧情链的终点，也是高中篇的入口）
const STORY_CONTRACT := "angel_contract"

## 高中篇的旗标（入口与外部地图场景已接入；后续章节继续沿用这些稳定键）
const STORY_ENTERED := "entered_highschool"
const STORY_FIRST_RUN_PV_SEEN := "highschool.first_run_pv_seen"
const STORY_EXTERNAL_INTRO := "highschool.external_intro_done"
const STORY_WAREHOUSE_CLEARED := "highschool.warehouse.paper_beasts_defeated"
const WAREHOUSE_ENCOUNTER := "warehouse_paper_beasts"
const FLAG_WAREHOUSE_CLOCK_READY := "highschool.warehouse.clock_ready"
const FLAG_PHONE_TIME_CHECKED := "highschool.phone.time_checked"
const WAREHOUSE_HOUR := 5
const WAREHOUSE_LOCATIONS := ["highschool.warehouse", "highschool.corridor", "highschool.hall"]
const EXTERNAL_PHONE_LINES := [
	{"speaker":"周明远", "text":"我大学时候带的背包还在，里面还有我的手机。"},
	{"speaker":"周明远", "text":"不过没有信号就是了，只能看时间。"},
	{"speaker":"周明远", "text":"我看一下时间……已经是凌晨五点钟了。"},
]

## 高中篇的存档键：已经过去了几个高中日（冷却按它算）
const FLAG_DAY_INDEX := "highschool_day_index"


## 穿越后随身携带手机；大学背包仍独立保存。旧仓库存档也补齐一次。
static func prepare_warehouse_inventory_and_time() -> void:
	if not Inventory.has("phone", 1, GameState.BAG_HIGHSCHOOL):
		Inventory.add("phone", 1, GameState.BAG_HIGHSCHOOL)
	if not GameFlow.has_flag(FLAG_WAREHOUSE_CLOCK_READY):
		GameState.in_game_minutes = WAREHOUSE_HOUR * 60
		# 大学里看过时间不代表知道穿越后的时间。
		GameState.time_known = GameFlow.has_flag(FLAG_PHONE_TIME_CHECKED) or GameFlow.has_flag(STORY_EXTERNAL_INTRO)
		GameFlow.set_flag(FLAG_WAREHOUSE_CLOCK_READY, true)


static func reveal_warehouse_time() -> void:
	GameFlow.set_flag(FLAG_PHONE_TIME_CHECKED, true)
	GameFlow.reveal_time(WAREHOUSE_HOUR)


static func is_warehouse_location(location: String) -> bool:
	return location in WAREHOUSE_LOCATIONS


static func warehouse_time_label() -> String:
	if not GameState.time_known:
		return "未知时间"
	return "夜间　%d:%02d" % [int(GameState.in_game_minutes / 60) % 24, GameState.in_game_minutes % 60]


## 现在是不是夜间
static func is_night(phase: String) -> bool:
	return phase == PHASE_NIGHT


## 主角能不能**自由走动**：白天只能魂附在过去的本体身上（跟着"当年的自己"走，
## 不能自己乱跑），夜间是灵魂形态，可以自由移动。
static func player_can_move_freely(phase: String) -> bool:
	return is_night(phase)


## 主角能不能战斗：只有夜间（白天是"重过一遍经历"，没有战斗）
static func player_can_fight(phase: String) -> bool:
	return is_night(phase)


## 艾莉娜能不能自由移动：**任意时段**都可以
static func alyina_can_move_freely(_phase: String) -> bool:
	return true


## 艾莉娜能不能战斗：只有夜间
static func alyina_can_fight(phase: String) -> bool:
	return is_night(phase)


## 这个时段有没有怪物：白天没有（所以白天艾莉娜"不能战斗"也无所谓）
static func monsters_exist(phase: String) -> bool:
	return is_night(phase)


## [param who] 能不能看见艾莉娜。用户设定：只有主角与李安雅。
static func others_can_see_alyina(who: String) -> bool:
	return SEERS.has(who)


## 这一时段该用哪本钱。
## ⚠️ 用户设定是"**高中白天与大学共享**，夜间独立"——不是"高中整个人一套钱"。
##    所以白天返回大学那一册（`GameState.BAG_COLLEGE`），夜间返回 `WALLET_NIGHT`。
static func wallet_scope(phase: String) -> String:
	return WALLET_NIGHT if is_night(phase) else GameState.BAG_COLLEGE


## 在高中待满 [param days] 天之后，回大学要冷却多少游戏分钟（半天/天）
static func cooldown_minutes(days: int = 1) -> int:
	return COLLEGE_COOLDOWN_MINUTES * maxi(0, days)


## 冷却够不够（[param elapsed] = 回大学之后已经过去的游戏分钟数）
static func cooldown_ready(elapsed: int, days: int = 1) -> bool:
	return elapsed >= cooldown_minutes(days)


## 规则总表（自检 / 文档 / 以后做高中篇时一眼看全）
static func rules() -> Dictionary:
	return {
		"白天主角自由移动": player_can_move_freely(PHASE_DAY),
		"夜间主角自由移动": player_can_move_freely(PHASE_NIGHT),
		"白天主角可战斗": player_can_fight(PHASE_DAY),
		"夜间主角可战斗": player_can_fight(PHASE_NIGHT),
		"白天艾莉娜可移动": alyina_can_move_freely(PHASE_DAY),
		"夜间艾莉娜可移动": alyina_can_move_freely(PHASE_NIGHT),
		"白天艾莉娜可战斗": alyina_can_fight(PHASE_DAY),
		"夜间艾莉娜可战斗": alyina_can_fight(PHASE_NIGHT),
		"白天有怪物": monsters_exist(PHASE_DAY),
		"夜间有怪物": monsters_exist(PHASE_NIGHT),
		"白天钱包": wallet_scope(PHASE_DAY),
		"夜间钱包": wallet_scope(PHASE_NIGHT),
		"高中一天等于大学分钟": cooldown_minutes(),
	}
