class_name Speakers
extends RefCounted
## 说话人的**显示名**：对话数据里写"规范名"，画面上可以显示得更好认。
##
## ------------------------------------------------------------------ 为什么需要这一层
##
## 用户 2026-09-19（`request/01_GOALS.md`）明确要求：
##   "小精灵自称自己叫艾莉娜，**艾莉娜的对话框要特意写艾莉娜（Alyina）**"。
##
## 但一个角色在项目里有三个不同的"名字"，硬把它们合成一个字符串会连环出错：
##   ① **规范名**（`艾莉娜`）—— 写进对话数据的 `speaker` 字段，也用来查头像（`Portraits`）、
##      查配音（`VoiceBank`）；它们都是按这个名字建表的，改了要动三处表。
##   ② **显示名**（`艾莉娜（Alyina）`）—— 只出现在对话框的名牌上。
##   ③ 历史别名（`西莉亚` / `Celia`）—— 老剧本里写过，`Portraits` 里保留着映射。
##
## 所以做法是：**数据里始终写规范名**，只在"往名牌上写字"的那一刻换成显示名。
## 这样头像、配音、回顾面板、走查断言全都不受影响。
##
## ⚠️ 别反过来做（数据里直接写 `艾莉娜（Alyina）`）：`Portraits.resolve()` 是按
##    名字查表的，查不到就**静默**没有立绘 —— 表现是"这个人突然没头像了"，不报错。

## 规范名 -> 显示名。**只放真的需要不一样的角色**，没登记的按原名显示。
const DISPLAY := {
	"艾莉娜": "艾莉娜（Alyina）",
}


## **内心独白**的说话人写法：`"周明远（内心）"`。
##
## 用户 2026-09-20："周明远（内心）：那就一会顺便做个食堂帮工赚点外快吧。
## **这句话也是对话框的内容**，不是在任务里" —— 也就是 08 里那些标着
## `周明远（内心）` 的台词，都要真的在对话框里出现（而不是只当成任务提示的文字）。
##
## 写法上把它做成**规范名 + 后缀**，理由与上面那段"三个名字"完全一样：
##   · 数据里写 `周明远（内心）`（照剧本原样，写剧本的人一眼对得上）；
##   · 头像 / 配音 / 回顾仍按 `周明远` 查 —— 由本函数与 `canonical()` 负责折回去；
##   · 名牌上就显示 `周明远（内心）`，玩家一眼看出这句是心里想的。
##
## ⚠️ **不要**改成"用 emotion 标签表达内心"：那会与真实的情绪（迟疑 / 认命…）抢同一个位置，
##    而且 08 的写法就是括号后缀。
const INNER_SUFFIX := "（内心）"


## 取"这个人本身"的规范名（去掉内心后缀）——查头像、查配音、查回顾都用它
static func base_name(speaker: String) -> String:
	if speaker.ends_with(INNER_SUFFIX):
		return speaker.substr(0, speaker.length() - INNER_SUFFIX.length())
	return canonical(speaker)


## 这一句是不是内心独白（数据里按 `周明远（内心）` 写）
static func is_inner(speaker: String) -> bool:
	return speaker.ends_with(INNER_SUFFIX)


## 往名牌上写什么
static func display(speaker: String) -> String:
	return String(DISPLAY.get(speaker, speaker))


## 把显示名折回规范名（查头像/配音前先过一遍，防止有人把显示名写进了数据）
static func canonical(speaker: String) -> String:
	for key in DISPLAY:
		if speaker == String(DISPLAY[key]):
			return String(key)
	return speaker
