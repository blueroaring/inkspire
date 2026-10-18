class_name Daylight
extends RefCounted
## 一天里的时段 —— **唯一判据来源**。
##
## 用户 2026-09-19 实报两件事，根子是同一个："时间框不会随着到了傍晚而改变，还是叫白天"，
## 以及"加上一个宿舍窗户和校园的白天/夕阳/夜间的场景变化，现在一直是白天的场景"。
##
## 原因是项目里原来只有两种"时间"概念，而且**互相不通**：
##   · `GameState.in_game_minutes`：时钟，玩家在 HUD 上看得见（12:04、18:30…）；
##   · `GameState.phase`（day/night）：**剧情状态**，谁切换谁负责，跟时钟没关系。
## HUD 显示的是 `phase`（所以永远写着"白天"），画面更是完全没管时间。
##
## 现在把"几点算什么时候"收在这里，HUD 的时间框、场景的环境光、宿舍窗户的窗外天光
## 全读同一份数据 —— 于是"时间框说夕阳、画面还是大白天"这种不一致不可能发生。
##
## ⚠️ 剧情上的"晚间"（`GameFlow.is_evening()`）用的也是 `NIGHT_FROM`：
##    "天黑了"在画面上和任务指引里必须是同一刻，不然玩家会看到"指引说等天黑、
##    时间框却还写着夕阳"。

## 时段分界（游戏内分钟，从 0:00 起）
const DAWN_FROM := 5 * 60            ## 清晨开始
const DAY_FROM := 8 * 60             ## 白天开始
## 夕阳开始。
## ⚠️ 定在 **16:00**（不是原来的 16:30）：08 里"艾莉娜登场"那一刻是**下午五点**，
##    而原文写着"（时间转为下午四点，**转为夕阳环境**）"。
##    当初为了让那一刻落在夕阳区间里，代码去迁就分界（把登场时刻改成 17:00）；
##    用户 2026-09-20 一度要回四点，随后定回 **17:00 登场**，但**夕阳仍从 16:00 开始** ——
##    于是 17:00 稳稳落在夕阳里，两件事不必再互相迁就。
const SUNSET_FROM := 16 * 60         ## 夕阳开始
## 夜间开始（= 剧情上的"晚间"）。
## ⚠️ 2026-09-20 用户要求："让晚上改为 20 点之后" —— 原来是 18:00。
##    连带效果（都是**有意的**）：
##      · 夕阳区间变长（16:00–20:00），"带艾莉娜逛校园"那一段有充足的天光；
##      · `GameFlow.EVENING_FROM_MINUTES` 转发本值，所以"该去取照片了"也从 20:00 起触发；
##      · 食堂的晚上场（17:00–20:00，见 `Currency`）整个落在夕阳里 ——
##        "在食堂干一趟活"不再一出门就撞上晚间提醒。
const NIGHT_FROM := 20 * 60          ## 夜间开始（= 剧情上的"晚间"）

const PERIOD_DAWN := "dawn"
const PERIOD_DAY := "day"
const PERIOD_SUNSET := "sunset"
const PERIOD_NIGHT := "night"

const LABELS := {
	PERIOD_DAWN: "清晨",
	PERIOD_DAY: "白天",
	PERIOD_SUNSET: "夕阳",
	PERIOD_NIGHT: "夜间",
}

## 叠在**整个画面**上的环境色（`CollegeMap` 那张全屏 ColorRect 用它）。
## alpha = 0 表示完全不叠 —— 白天就是"什么都不加"，所以白天的画面与以前完全一致。
const AMBIENT := {
	PERIOD_DAWN: Color(1.00, 0.86, 0.68, 0.14),
	PERIOD_DAY: Color(1.0, 1.0, 1.0, 0.0),
	PERIOD_SUNSET: Color(1.00, 0.55, 0.30, 0.22),
	PERIOD_NIGHT: Color(0.20, 0.28, 0.55, 0.46),
}

## 宿舍窗户"窗外那片天"的颜色。比环境光**实**得多 —— 它是"看得见的一块天"，
## 不是给人眼适应的整体压暗，所以夜间要真的发蓝发暗。
const SKY := {
	PERIOD_DAWN: Color(1.00, 0.78, 0.58, 0.55),
	PERIOD_DAY: Color(0.72, 0.86, 1.00, 0.42),
	PERIOD_SUNSET: Color(1.00, 0.48, 0.26, 0.62),
	PERIOD_NIGHT: Color(0.10, 0.16, 0.38, 0.78),
}


## 这一分钟属于哪个时段。负数/超过一天都按取模处理（时钟本身是 0..1439 循环的）。
static func period_at(minutes: int) -> String:
	var m := posmod(minutes, 24 * 60)
	if m >= NIGHT_FROM or m < DAWN_FROM:
		return PERIOD_NIGHT
	if m < DAY_FROM:
		return PERIOD_DAWN
	if m < SUNSET_FROM:
		return PERIOD_DAY
	return PERIOD_SUNSET


## 时段的中文名（HUD 的时间框用它）
static func label_at(minutes: int) -> String:
	return String(LABELS.get(period_at(minutes), LABELS[PERIOD_DAY]))


## 全屏环境色
static func ambient_at(minutes: int) -> Color:
	return AMBIENT.get(period_at(minutes), AMBIENT[PERIOD_DAY])


## 宿舍窗户的窗外天光
static func sky_at(minutes: int) -> Color:
	return SKY.get(period_at(minutes), SKY[PERIOD_DAY])


## 天是不是"暗下来了"（夕阳或夜间）。留给以后"开灯""点篝火"这类东西用。
static func is_dark(minutes: int) -> bool:
	var p := period_at(minutes)
	return p == PERIOD_SUNSET or p == PERIOD_NIGHT


## 路灯该有多亮（0 = 完全不亮，1 = 全亮）。
##
## 用户 2026-09-19："夜间路灯位置应该有部分是亮的。"
## 白天 0（多画一层纯属浪费，而且白天看得到光斑会很怪），黄昏开始亮一半、夜里全亮。
## ⚠️ 与 `AMBIENT` 是两件事：环境光是"整体压暗"，这是"灯自己发光"；
##    室内没有环境光（用户明确要求），但室内的灯（以后要做）同样读这个函数。
const LAMP_STRENGTH := {
	PERIOD_DAWN: 0.25,
	PERIOD_DAY: 0.0,
	PERIOD_SUNSET: 0.55,
	PERIOD_NIGHT: 1.0,
}


static func lamp_strength_at(minutes: int) -> float:
	return float(LAMP_STRENGTH.get(period_at(minutes), 0.0))


## 全部时段（自检与"四种天色都画得出来吗"这类遍历用它）
static func all_periods() -> Array[String]:
	return [PERIOD_DAWN, PERIOD_DAY, PERIOD_SUNSET, PERIOD_NIGHT]


## 每个时段取一个代表时刻（自检用它把四种天色都走一遍）
static func sample_minutes(period: String) -> int:
	match period:
		PERIOD_DAWN:
			return 6 * 60
		PERIOD_SUNSET:
			return 16 * 60
		PERIOD_NIGHT:
			return 21 * 60
		_:
			return 12 * 60
