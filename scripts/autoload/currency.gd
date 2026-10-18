extends Node
## 经济系统（自动加载单例 Currency）
##
## 职责边界（与背包系统一一对应，照着它的分层写）：
##   · **钱存在哪**   -> `GameState.money`（纯字典，跟着存档走，本文件不直接碰存档代码）
##   · **钱怎么加减** -> 本文件（加/减/查/买得起吗，并统一发信号）
##   · **东西卖多少钱、哪家店卖什么** -> `ShopDb`（纯数据）
##   · **打工的规则（工时、工钱、一天一次）** -> 本文件的 work_* 系列
##   · **显示成什么样** -> `MoneyHud`（HUD）与 `ShopPanel`（商店面板）
##
## 所以本文件**不认识任何 UI、场景或建筑**：商店/工位是校园场景里的可交互物
## （`ShopSpot` / `WorkSpot`），它们只调这里的公开接口。
##
## 分册（scope）：大学与高中的钱包互相独立，口径与背包完全一致
## （`GameState.current_wallet_scope()`，由章节推出）。每个 API 都能显式传 scope，
## 方便走查与将来的跨册操作（"把剩下的钱带进高中"不需要改数据结构）。
##
## ⚠️ 所有金额都是**整数分**：浮点数进 JSON 会变成 39.999999，
##    而"买不起"的判定必须精确（见 GameState.money 的注释）。

## 一元 = 多少分。改货币精度只改这一处（千分位/显示格式都跟着走）。
const CENTS_PER_YUAN := 100

signal balance_changed(scope: String, amount_cents: int)
signal purchase(item_id: String, price_cents: int, scope: String)
signal work_done(spot_id: String, wage_cents: int, day: int)


# ---------------------------------------------------------------- 查询

## 当前该用哪一册钱包（大学 / 高中）
func scope() -> String:
	return GameState.current_wallet_scope()


func scope_name(target: String = "") -> String:
	return GameState.bag_scope_name(target if target != "" else scope())


## 余额（分）
func amount(target: String = "") -> int:
	return GameState.money_for(target if target != "" else scope())


## 余额（元，浮点 —— **只给显示用**，判定一律用 amount()）
func yuan(target: String = "") -> float:
	return float(amount(target)) / float(CENTS_PER_YUAN)


func can_afford(price_cents: int, target: String = "") -> bool:
	return price_cents >= 0 and amount(target) >= price_cents


## "¥ 12.50"（带分册前缀的那种由 HUD / 商店自己拼）
func format_amount(cents: int = -1, target: String = "") -> String:
	var value := amount(target) if cents < 0 else cents
	return format_cents(value)


## 分 -> "12.50"
static func format_cents(cents: int) -> String:
	var negative := cents < 0
	var v: int = absi(cents)
	var text := "%d.%02d" % [v / CENTS_PER_YUAN, v % CENTS_PER_YUAN]
	return ("-" + text) if negative else text


## 一句"进账多少、现在一共多少"的对话行（打工结算与商店都复用同一套说法，
## 免得三个地方各写一种口径）
func balance_line(income_cents: int, speaker: String = "周明远") -> Dictionary:
	return {
		"speaker": speaker,
		"text": "（进账 ¥ %s，钱包里一共 ¥ %s。）" % [
			format_cents(income_cents), format_amount()],
		"emotion": "踏实",
	}


# ---------------------------------------------------------------- 加减

## 加钱（打工/剧情给钱）。负数的 delta 会被拒绝 —— 扣钱必须走 spend()，
## 免得"付不起"被悄悄做成负数余额。
func earn(cents: int, reason: String = "", target: String = "") -> int:
	if cents <= 0:
		return 0
	var key := target if target != "" else scope()
	var now := GameState.money_for(key) + cents
	GameState.money[key] = now
	balance_changed.emit(key, now)
	return now


## 花钱（买东西）：钱不够时**什么都不做**并返回 false。
## 返回 true 时钱已经扣掉、`purchase` 已发出 —— 调用方（商店面板）在这之后
## 才把东西放进背包，所以不会出现"扣了钱没拿到货"。
func spend(cents: int, item_id: String = "", target: String = "") -> bool:
	if cents < 0:
		return false
	var key := target if target != "" else scope()
	var now := GameState.money_for(key)
	if now < cents:
		return false
	now -= cents
	GameState.money[key] = now
	balance_changed.emit(key, now)
	purchase.emit(item_id, cents, key)
	return true


## 直接设置余额（**只给调试/走查用**；正常玩法请走 earn/spend）
func set_amount(cents: int, target: String = "") -> void:
	var key := target if target != "" else scope()
	GameState.money[key] = maxi(0, cents)
	balance_changed.emit(key, GameState.money_for(key))


# ---------------------------------------------------------------- 游戏内"天"与"时段"
#
# 打工的口径是"**每个中午 / 晚上各只能干一次**"（用户 2026-09-19 明确要求），
# 所以记录不能只记"哪天"，要记"哪个时段"，不然中午干过之后晚上就再也干不了了。
#
# "时段"同样**不能从时钟反推成天数**：`in_game_minutes` 是 0..1439 循环的，
# 跨过 0 点后它反而变小（用"经过多少分钟"折算天数会算出负数天，实测踩到）。
# 这里只按"现在几点"分类，天由 `GameState.day` 显式存、`GameFlow.advance_time()` 在回绕时 +1。

const SLOT_NONE := ""
const SLOT_NOON := "noon"
const SLOT_EVENING := "evening"

## 中午场：11:00 起（含）到 14:00 前（不含）—— 开局 12:00 干一趟到 13:00，正好还在这个场次里
const NOON_FROM := 11 * 60
const NOON_TO := 14 * 60
## 晚上场：17:00 起（含）到 20:00 前（不含）
const EVENING_FROM := 17 * 60
const EVENING_TO := 20 * 60


## 当前是第几天（0 = 开局那天）。跨天 +1 的唯一入口是 `GameFlow.advance_time()`。
func current_day() -> int:
	return GameState.day


## 现在属于哪个打工时段（中午 / 晚上 / 空 = 这会儿食堂不收人）
func current_period() -> String:
	var now := GameState.in_game_minutes
	if now >= NOON_FROM and now < NOON_TO:
		return SLOT_NOON
	if now >= EVENING_FROM and now < EVENING_TO:
		return SLOT_EVENING
	return SLOT_NONE


func period_label(period: String) -> String:
	match period:
		SLOT_NOON:
			return "中午"
		SLOT_EVENING:
			return "晚上"
	return "现在"


## 上一趟干活记在哪一天（没干过返回 -1）
func worked_day(spot_id: String) -> int:
	var rec: Dictionary = GameState.work_records.get(spot_id, {})
	return int(rec.get("day", -1))


## 上一趟干活记在哪个时段（没干过返回空串）
func worked_period(spot_id: String) -> String:
	var rec: Dictionary = GameState.work_records.get(spot_id, {})
	return String(rec.get("period", ""))


# ---------------------------------------------------------------- 打工

## 这个工位**现在**能不能干：必须是中午/晚上时段，且这个时段还没干过。
func can_work(spot_id: String) -> bool:
	if spot_id == "":
		return false
	var period := current_period()
	if period == SLOT_NONE:
		return false
	return not (worked_day(spot_id) == current_day() and worked_period(spot_id) == period)


## 这次干不成的原因（给玩家一句明确的话，而不是"按了没反应"）：
##   ""               = 可以干
##   "off_hours"      = 现在不是中午/晚上，食堂不收人
##   "already_worked" = 这个时段已经干过一趟了
func work_block_reason(spot_id: String) -> String:
	if current_period() == SLOT_NONE:
		return "off_hours"
	if not can_work(spot_id):
		return "already_worked"
	return ""


## 现在干这一趟能拿多少钱（分）= 底薪 + 奖励档 + 背包加成，见 `WorkDb.wage_for`。
##
## [param completed] 传 -1 = "没有小游戏成绩"（只算底薪 + 背包加成）；
## 传 >= 0 = 小游戏完成了几个，按档位加钱（用户要求"根据限时完成的个数给奖励，按完成数分档"）。
##
## 为什么"数背包"这件事放在经济系统里而不是工位场景里：工钱公式属于收入规则，
## 而工位（`WorkSpot`）只该知道"我干哪个岗位"和"播什么文案"。
func wage_for(job_id: String, completed: int = -1, target: String = "") -> int:
	return WorkDb.wage_for(job_id, _tool_count(target), completed)


## 背包里"工具 / 素材"类道具的件数（打工加成的依据）
func _tool_count(target: String = "") -> int:
	var count := 0
	for entry_variant in Inventory.entries(target):
		var entry: Dictionary = entry_variant
		var kind := String(ItemDb.get_item(String(entry["id"])).get("kind", ""))
		if kind == "tool" or kind == "material":
			count += int(entry["count"])
	return count


## 记一次打工并结算工钱。
##
## 参数里的 `wage_cents` 由调用方（工位 / 小游戏）算好 —— 本文件不认识建筑，
## 也不该知道"食堂一小时多少钱"。返回实际拿到的钱（分）；这会儿干不了 = 0（不发钱）。
##
## ⚠️ 次序是"先记账、再发钱"：万一发钱那步出问题，也不会出现"重复打工叠加发钱"。
func settle_work(spot_id: String, wage_cents: int, target: String = "") -> int:
	if not can_work(spot_id):
		return 0
	var period := current_period()
	GameState.work_records[spot_id] = {"day": current_day(), "period": period}
	_prune_work_records()
	var paid := maxi(0, wage_cents)
	if paid > 0:
		earn(paid, "work", target)
	work_done.emit(spot_id, paid, current_day())
	return paid


## 清掉"既不是今天、也不是这个时段"的打工记录。
## 为什么需要：`work_records` 跟着存档走，不清的话它会随游戏天数无限长大
## （每天每时段一条），而旧记录也没有语义（只判断"是不是今天的这个时段"）。
func _prune_work_records() -> void:
	var today := current_day()
	var period := current_period()
	for key: String in GameState.work_records.keys():
		if worked_day(key) != today or worked_period(key) != period:
			GameState.work_records.erase(key)


# ---------------------------------------------------------------- 开发期驱动接口

## 直接塞钱（走查/调试用，等价于"打工挣到了"）
func debug_give(cents: int, target: String = "") -> int:
	return earn(cents, "debug", target)


## 把余额设成某个值（走查用：验证"钱不够"时不该成交）
func debug_set(cents: int, target: String = "") -> void:
	set_amount(cents, target)


## 把某个工位标记成"某天某时段已经打过了"（走查里验证"换时段会重置"用）
func debug_mark_worked(spot_id: String, day: int, period: String) -> void:
	GameState.work_records[spot_id] = {"day": day, "period": period}
