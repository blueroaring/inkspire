class_name WorkDb
extends RefCounted
## 打工岗位表（**纯数据**）：每个岗位在哪儿、干什么、干多久、给多少钱。
##
## 为什么打工要单独一张表：它是**经济系统的收入端**，而收入规则（时段、工钱、奖励分档）
## 将来一定会调；把这些数字散在场景脚本里，调一次就要翻好几处。
## 这里只有数字与文案 ——
##   · "现在能不能干 / 干完怎么记账"在 `Currency`（work_* 系列）
##   · "在哪儿按 E"在场景数据（`CanteenData.works()` → `WorkSpot`）
##   · "小游戏怎么玩"在 `scripts/minigames/plate_sort_game.gd`
##
## 加一个岗位 = 这里 `JOBS` 加一条 + 在场景数据里摆一个工位。

## 岗位表：job id -> 定义
##   label      工位名（交互提示与结算文案用）
##   spot       工作地点（显示用）
##   wage       这趟的**底薪**（分）——小游戏表现差也有保底
##   minutes    这趟消耗的游戏内时间（分钟）
##   minigame   要玩的小游戏 id（空 = 直接结算，不玩小游戏）
##   line       干活前的旁白
##   result     结算时的旁白（`%s` = 这趟拿到的钱）
const JOBS := {
	"canteen_shift": {
		"label": "食堂帮工",
		"spot": "第一食堂 · 后厨洗碗间",
		"wage": 800,            # 底薪 8.00（干得再差也有）
		"minutes": 60,
		"minigame": "plate_sort",
		"line": "后厨的洗碗池边堆着一摞刚收下来的餐盘，三个回收桶敞着口。",
		"result": "阿姨照小票结了 %s 块钱，说下次还来。",
	},
	"copy_shop_shift": {
		"label": "复印店看店",
		"spot": "照相馆 · 复印店",
		"wage": 2500,           # 25.00
		"minutes": 60,
		"minigame": "",
		"line": "替老板看店，给人复印、装订，顺手把墨盒换了。",
		"result": "老板按张数结了 %s 块钱，说下次还来。",
	},
}

## 每次打工的**业绩加成上限**（分）：带上"素材/工具"类道具多一点，工钱高一点。
## 这是"经济系统与背包挂钩"的唯一一处 —— 将来接属性/技能时替换成真正的养成数值。
const BONUS_PER_ITEM := 200
const BONUS_MAX := 1000

## 小游戏的**奖励分档**：门槛（完成数）降序排，取第一个满足的档。
## 用户 2026-09-19 的要求："根据限时完成的个数给奖励，奖励按照完成数分档，有上限"。
##   bonus = 该档的加成（分），最终工钱 = 底薪 + 业绩加成 + min(背包加成, BONUS_MAX)
## ⚠️ 最后一个门槛必须是 0（兜底档），否则"一个都没完成"会取不到档。
const REWARD_TIERS: Array[Dictionary] = [
	{"min": 20, "bonus": 2200, "label": "手脚麻利"},
	{"min": 14, "bonus": 1500, "label": "还算熟练"},
	{"min": 8, "bonus": 900, "label": "勉强跟上"},
	{"min": 4, "bonus": 400, "label": "手忙脚乱"},
	{"min": 0, "bonus": 0, "label": "一团糟"},
]


static func has_job(job_id: String) -> bool:
	return JOBS.has(job_id)


static func job(job_id: String) -> Dictionary:
	return JOBS.get(job_id, {})


static func label_of(job_id: String) -> String:
	return String(job(job_id).get("label", job_id))


static func spot_of(job_id: String) -> String:
	return String(job(job_id).get("spot", ""))


static func minutes_of(job_id: String) -> int:
	return int(job(job_id).get("minutes", 0))


static func minigame_of(job_id: String) -> String:
	return String(job(job_id).get("minigame", ""))


static func line_of(job_id: String) -> String:
	return String(job(job_id).get("line", ""))


static func result_of(job_id: String) -> String:
	return String(job(job_id).get("result", "拿到了 %s 块钱。"))


static func job_ids() -> Array:
	var out: Array = JOBS.keys()
	out.sort()
	return out


# ---------------------------------------------------------------- 工钱与奖励分档


## 按完成数取奖励档；返回 {bonus, label, min}
static func tier_for(completed: int) -> Dictionary:
	for tier_variant in REWARD_TIERS:
		var tier: Dictionary = tier_variant
		if completed >= int(tier["min"]):
			return tier
	return {"bonus": 0, "label": "—", "min": 0}


## 这趟工钱（分）= 底薪 + 奖励档 + 背包加成（封顶 BONUS_MAX）。
##
## [param completed] 传 -1 表示"不看小游戏成绩"，只算底薪 + 背包加成
## （用于不玩小游戏的岗位，也用于走查里核对"上限真的存在"）。
static func wage_for(job_id: String, tools_owned: int, completed: int = -1) -> int:
	var base := int(job(job_id).get("wage", 0))
	var bonus := 0 if completed < 0 else int(tier_for(completed)["bonus"])
	var pack: int = mini(BONUS_MAX, maxi(0, tools_owned) * BONUS_PER_ITEM)
	return base + bonus + pack


## 这个岗位的理论最高工钱（奖励顶档 + 背包加成封顶）—— 走查与策划核对用
static func max_wage(job_id: String) -> int:
	return wage_for(job_id, BONUS_MAX / BONUS_PER_ITEM, 9999)


## 奖励档文案（结算界面显示"14 个 → 还算熟练 +15.00"）
static func tier_line(completed: int) -> String:
	var tier := tier_for(completed)
	return "%d 个 → %s（+¥ %s）" % [
		completed, String(tier["label"]),
		Currency.format_cents(int(tier["bonus"]))]
