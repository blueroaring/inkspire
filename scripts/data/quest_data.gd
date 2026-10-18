class_name QuestData
extends RefCounted
## 任务指引（左上角那一行）。
##
## 用户 2026-09-19（`request/01_GOALS.md`）：
##   "这里需要做一个任务指引在左上角，类似先前对看手机在左上角的提示。"
##
## ------------------------------------------------------------------ 它替换了什么
##
## 原来这一行是 `scenes/ui/overworld_hud.gd::_pending_objective()` 里的**两个硬编码分支**
## （`GameFlow.has_flag("woke_up")` + `Inventory.has("phone")`）。剧情一多，那种写法会变成
## 一个越来越长的 if-else，而且"任务顺序"这件事在代码里看不出来。
##
## 现在改成一张**有序的步骤表**：从前往后找第一条"还没完成"的，就是当前指引。
## 加一步剧情 = 在 `STEPS` 里加一行数据，HUD 一个字都不用改。
##
## ------------------------------------------------------------------ 表格怎么读
##
##   `done_flag`        这一步做完时会被写上的剧情开关（写在哪由剧情脚本决定）
##   `text`             还没做完时显示在左上角的指引
##   `require_item`     （可选）背包里**有**这件道具，这一步才显示
##   `skip_unless_item` （可选）背包里**有**这件道具就跳过这一步
##
## ⚠️ `require_item` / `skip_unless_item` 是为了表达"捡手机 → 用手机"这种
##    **同一条主线里的两个状态**：它们的完成条件（`woke_up`）是同一个开关，
##    靠背包状态区分先后。硬拆成两个开关会让存档里多一个没人读的字段。
##
## ⚠️ 别把"完成条件"写成"某件道具还在背包里"：道具会被用掉/丢掉，
##    任务状态必须落成 `story_flags` 里的开关（它跟着存档走）。

## 任务开关名（**跨文件被读的那些**统一放这里）。
##
## ⚠️ 为什么要有常量：同一个开关被"剧情脚本 / 场景门 / 任务指引 / 走查断言"四处读，
##    手写字符串拼错一个字母就静默失效（那种 bug 没有任何报错）：
##      · `FLAG_ROOMMATE` 既是任务链的一步，也是食堂打饭窗口的开放条件；
##      · `FLAG_ATE` 既是任务链的一步，也是**教学楼那道门的上锁条件**
##        （08：食堂完成前不能进教学楼），还是**洗碗工位的开放条件**；
##      · `FLAG_WORK_CHOICE_DONE` 是"打完工这一趟（或者明确不去）"——
##        下一步的任务指引是"打开背包看手机"，它得等到这一步真的做完才出现；
##      · `FLAG_PHONE_AFTER_MEAL` 是"出门前看过一次手机"——
##        看过之后指引才变成"前往教学楼 301 上课"（这两步不能挤在同一个开关上，
##        否则玩家还没看手机，指引就已经跳到下一步了 —— 原来就是这么写的）。
##    ⚠️ 前两个与 `MealSpot.FLAG_ROOMMATE / FLAG_ATE` 是**同一对开关** ——
##       `MealSpot` 那边转发到这两个常量，不要在别处再写字面量。
const FLAG_ROOMMATE := "chatted_with_chenmo"
const FLAG_ATE := "ate_lunch"
## 艾莉娜登场后的晚间晚饭已经吃过。它与主线午饭开关分开，避免晚间
## 第一次来到食堂时直接落入“饭已经打过了”的旧分支。
const FLAG_ATE_ALYINA_DINNER := "ate_alyina_dinner"
const FLAG_WORK_CHOICE_DONE := "canteen_work_decided"
const FLAG_PHONE_AFTER_MEAL := "phone_checked_after_meal"
const FLAG_ABANDONED_ENTRY := "highschool_abandoned_entry_done"
const FLAG_ABANDONED_PHOTO_CHECKED := "highschool_abandoned_photo_checked"
const FLAG_ABANDONED_PHOTO_POINT := "highschool_abandoned_photo_point_done"
const FLAG_WAREHOUSE_ENTERED := "highschool.warehouse.entered"
const FLAG_WAREHOUSE_KEY_FOUND := "highschool.item.highschool_warehouse_key"
const FLAG_WAREHOUSE_DOOR_OPENED := "highschool.warehouse.door_opened"
const FLAG_ALYINA_FOUND := "highschool.alyina_found"
const FLAG_CORRIDOR_LADDER_USED := "highschool.corridor_ladder_used"

const STEPS: Array[Dictionary] = [
	{
		# 开场：手机还在桌上（合上 `skip_unless_item` = 还没捡到时才显示）
		"done_flag": "woke_up",
		"skip_unless_item": "phone",
		"text": "按 E 捡起桌上的手机（附近有多个目标时按 Tab 切换）",
	},
	{
		# 手机到手、还没看：明确告诉玩家下一步按什么
		"done_flag": "woke_up",
		"require_item": "phone",
		"text": "按 B 打开背包 → 选中「手机」→ 回车使用",
	},
	{
		# 醒了：先跟室友搭话（08 原文："任务更新：与还在寝室的室友对话（不对话无法去校园）"）。
		# ⚠️ 这条与出口门那道 `required_flag = "woke_up"` 的锁配套 ——
		#    任务链说的和门拦的必须是同一件事，否则玩家会在门口反复试。
		"done_flag": FLAG_ROOMMATE,
		"text": "跟还在寝室的室友说两句话（他在等你搭话）",
	},
	{
		# 室友托了带饭、也说清了下午的课（08："任务更新:去食堂吃饭"）。
		# ⚠️ 完成条件用 `ate_lunch`（吃饭那一步写上的开关），**不是**"进过食堂" ——
		#    进门转一圈出来不该算吃过，跟"看照片要看完""睡觉得睡着"是同一条口径。
		#    ⚠️ 同一个开关也是**教学楼那道门**与**洗碗工位**的开放条件。
		"done_flag": FLAG_ATE,
		"text": "去食堂吃饭（在打饭窗口按 E 打饭）",
	},
	{
		# 吃完之后、还没决定要不要打工：08 的"吃完饭后任务更新:在食堂打工赚钱"。
		# ⚠️ 用户 2026-09-20 明确了这一段的三步顺序：
		#    打饭 → 吃饭 →（可选）打工 → **打开背包看手机** → 去教学楼。
		#    所以"看手机"这一步必须排在打工那一步**之后**，不能一吃完就出现。
		"done_flag": FLAG_WORK_CHOICE_DONE,
		"text": "在食堂帮工赚点外快（不想干就直接走）",
	},
	{
		# 用户 2026-09-20："任务要求打开背包看手机时间，触发如上对话，然后任务更新成这样"
		#（"这样"= 14:00 教学楼 301 上课 / 未定时间 图书馆写毕业论文 → 前往教学楼 301 上课）
		# ⚠️ 完成条件用 `FLAG_PHONE_AFTER_MEAL`（"出门前看了一眼手机"）：
		#    原来的写法借了 `skipped_thesis_class`，于是"看手机"与"到 301 门口"两步
		#    挤在同一个开关上 —— 玩家还没看手机，指引就可能已经跳到下一步。
		"done_flag": FLAG_PHONE_AFTER_MEAL,
		"text": "按 B 打开背包 → 用手机看看现在几点（手机上还压着两件待办）",
	},
	{
		# 看过手机之后：08 的"任务更新：前往教学楼301上课（*可选:在校园里探索）"
		# ⚠️ 这一步与下一步（翘课之后出楼）**共用** `skipped_thesis_class`：
		#    它们是同一条走廊上的前后两格，玩家在 301 门口按 E 就会同时跨过两步，
		#    不需要为此多开一个只被"指引"读的开关。
		"done_flag": TeachingData.STORY_SKIPPED_CLASS,
		"text": "前往教学楼 301 上课（*可选:在校园里探索）",
	},
	{
		# 翘课了：下楼、出教学楼（出楼那一刻会触发剧情）
		"done_flag": TeachingData.STORY_ALYINA_MET,
		"text": "课不上了 —— 下楼出教学楼，去图书馆写毕业论文初稿",
	},
	{
		# 艾莉娜登场之后：08 的任务更新是"**带着艾莉娜在校园逛逛，逛累了就回宿舍躺床上休息吧**"
		# （用户 2026-09-20 特意指出：这里不该写"回宿舍躺一会儿"——那是**下一步**
		#  才该干的事，而这一步是"先带她逛"）。
		# ⚠️ 完成条件仍是 `photo_reminder`（晚间提醒）：它才是"逛够了、该去取照片"那一刻。
		"done_flag": StoryData.FLAG_REMINDER,
		"text": "带着艾莉娜在校园逛逛，逛累了就回宿舍躺床上休息吧",
	},
	{
		# 晚间想起照片还在照相馆 → 去取
		"done_flag": StoryData.FLAG_TAKEN,
		"text": "去照相馆取上周洗好的照片",
	},
	{
		# 照片到手 → 回宿舍
		"done_flag": StoryData.FLAG_ROOMMATE_CHAT,
		"text": "回宿舍，跟陈默说两句话",
	},
	{
		# 发现了"只有自己看得见她" → 在书桌上把照片看完（这一段结尾就是契约）
		"done_flag": StoryData.FLAG_CONTRACT,
		"text": "在书桌上摊开那摞照片，看完最后一张",
	},
	{
		"done_flag": StoryData.FLAG_MORNING,
		"text": "上床休息，第二天再去高中打开回溯通道吧",
	},
	{
		"done_flag": StoryData.FLAG_MORNING_WASHED,
		"text": "去卫生间洗漱",
	},
	{
		"done_flag": StoryData.FLAG_STADIUM_DEPARTED,
		"text": "去体育场大门找艾莉娜",
	},
	{
		"done_flag": FLAG_ABANDONED_ENTRY,
		"text": "与艾莉娜对话",
	},
	{
		"done_flag": FLAG_ABANDONED_PHOTO_CHECKED,
		"text": "打开背包，查看照片",
	},
	{
		"done_flag": FLAG_ABANDONED_PHOTO_POINT,
		"text": "前往第一教学楼照片点",
	},
	{
		"done_flag": FLAG_WAREHOUSE_ENTERED,
		"text": "在地下仓库中寻找出口",
	},
	{
		"done_flag": FLAG_WAREHOUSE_KEY_FOUND,
		"text": "在仓库里寻找钥匙",
	},
	{
		"done_flag": FLAG_WAREHOUSE_DOOR_OPENED,
		"text": "用钥匙打开仓库的门",
	},
	{
		"done_flag": FLAG_ALYINA_FOUND,
		"text": "打开手电筒，找到走廊里的艾莉娜",
	},
	{
		"done_flag": FLAG_CORRIDOR_LADDER_USED,
		"text": "使用绳梯离开地下仓库",
	},
]


## 当前该显示哪一步；全部做完时返回空字典。
static func current() -> Dictionary:
	var room_step := _warehouse_step()
	if not room_step.is_empty():
		return room_step
	for step_variant in STEPS:
		var step: Dictionary = step_variant
		if bool(GameState.get_flag(String(step["done_flag"]), false)):
			continue
		var require := String(step.get("require_item", ""))
		if require != "" and not Inventory.has(require):
			continue
		var skip_unless := String(step.get("skip_unless_item", ""))
		if skip_unless != "" and Inventory.has(skip_unless):
			continue
		return step
	return {}


## 当前指引文字；没有待办时返回空串（HUD 会退回按键说明）。
static func _warehouse_step() -> Dictionary:
	if GameState.location.begins_with("highschool.") and HighschoolMorningData.is_active():
		var objective := HighschoolMorningData.objective()
		if objective != "":
			return {"done_flag": "", "text": objective}
	match GameState.location:
		"highschool.external":
			if GameFlow.has_flag(HighschoolRewindData.FLAG_POSSESSED):
				return {"done_flag": HighschoolRewindData.FLAG_KEY_NODE, "text": "继续观测第一天的经历"}
			if not GameFlow.has_flag(HighschoolData.STORY_EXTERNAL_INTRO):
				return {"done_flag": HighschoolData.STORY_EXTERNAL_INTRO, "text": "听艾莉娜说明白天的行动安排"}
			if not GameFlow.has_flag("highschool.dorm.entered"):
				return {"done_flag": "highschool.dorm.entered", "text": "找到宿舍，进入宿舍楼"}
			if not GameFlow.has_flag("highschool.dorm.205.entered"):
				return {"done_flag": "highschool.dorm.205.entered", "text": "前往二楼 205 宿舍"}
			return {"done_flag": "", "text": "继续探索高中校园"}
		"highschool.dorm_1f", "highschool.dorm_2f", "highschool.dorm_3f", "highschool.dorm_4f":
			if HighschoolRewindData.stage() == HighschoolRewindData.STAGE_WASHING:
				return {"done_flag": HighschoolRewindData.FLAG_WASHED, "text": "去公共卫生间洗漱"}
			if HighschoolRewindData.stage() in [HighschoolRewindData.STAGE_BREAKFAST,
					HighschoolRewindData.STAGE_BREAKFAST_HELP]:
				return {"done_flag": HighschoolRewindData.FLAG_BREAKFAST_ROUTE, "text": "选择早饭安排"}
			if HighschoolRewindData.stage() == HighschoolRewindData.STAGE_SCRIPT_BOUNDARY:
				return {"done_flag": HighschoolRewindData.FLAG_KEY_NODE, "text": "继续观测第一天的经历"}
			if not GameFlow.has_flag("highschool.dorm.205.entered"):
				return {"done_flag": "highschool.dorm.205.entered", "text": "前往二楼 205 宿舍"}
			return {"done_flag": "", "text": "继续调查男生宿舍"}
		"highschool.dorm_205":
			if not GameFlow.has_flag(HighschoolRewindData.FLAG_POSSESSED):
				return {"done_flag": HighschoolRewindData.FLAG_POSSESSED, "text": "附身周明远"}
			return {"done_flag": HighschoolRewindData.FLAG_WASHED, "text": "在回映模式中选择早晨的行动"}
		"highschool.warehouse":
			if GameFlow.has_flag("highschool.corridor.intro_done") and not GameFlow.has_flag(FLAG_ALYINA_FOUND) and not Inventory.has("flashlight", 1, GameState.BAG_HIGHSCHOOL):
				return {"done_flag": "highschool.item.flashlight", "text": "回仓库找手电筒"}
			if GameFlow.has_flag(FLAG_WAREHOUSE_DOOR_OPENED):
				return {"done_flag": FLAG_ALYINA_FOUND, "text": "从仓库门离开"}
			if not GameFlow.has_flag("highschool.warehouse.door_checked"):
				return {"done_flag": "highschool.warehouse.door_checked", "text": "从仓库门离开"}
			if not GameFlow.has_flag(FLAG_WAREHOUSE_KEY_FOUND):
				return {"done_flag": FLAG_WAREHOUSE_KEY_FOUND, "text": "在仓库里寻找钥匙"}
			return {"done_flag": FLAG_WAREHOUSE_DOOR_OPENED, "text": "用钥匙打开仓库的门"}
		"highschool.corridor":
			if GameFlow.has_flag(FLAG_ALYINA_FOUND):
				return {"done_flag": FLAG_CORRIDOR_LADDER_USED, "text": "通过绳梯前往地上"}
			if not Inventory.has("flashlight", 1, GameState.BAG_HIGHSCHOOL):
				return {"done_flag": "highschool.item.flashlight", "text": "回仓库找手电筒"}
			return {"done_flag": FLAG_ALYINA_FOUND, "text": "按 Z 打开手电筒，前往走廊尽头"}
		"highschool.hall":
			if GameFlow.has_flag(HighschoolData.STORY_WAREHOUSE_CLEARED):
				return {"done_flag": HighschoolData.STORY_EXTERNAL_INTRO, "text": "从仓库大门离开"}
			return {"done_flag": HighschoolData.STORY_WAREHOUSE_CLEARED, "text": "击败试卷兽"}
	return {}


static func text() -> String:
	return String(current().get("text", ""))


## 当前步骤要等的剧情开关（自检/走查用：断言"任务链没有断在某个没人写的开关上"）
static func pending_flag() -> String:
	return String(current().get("done_flag", ""))


## 所有被引用到的开关名（走查用：核对它们都在 `TeachingData` 里声明过）
static func referenced_flags() -> Array[String]:
	var out: Array[String] = []
	for step_variant in STEPS:
		var flag := String((step_variant as Dictionary)["done_flag"])
		if not out.has(flag):
			out.append(flag)
	return out
