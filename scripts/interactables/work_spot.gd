class_name WorkSpot
extends Interactable
## 打工工位（地图上"按 E 干一趟活"的那个交互区）。
##
## 职责边界：只负责"报到 → 干活（可能玩小游戏）→ 走时间 → 播结算"。
##   · 现在能不能干、为什么不能干 -> `Currency.work_block_reason()`
##   · 工钱多少、奖励分档         -> `WorkDb` + `Currency.wage_for()`
##   · 小游戏怎么玩               -> `PlateGame`（`scripts/minigames/`）
## 所以换一个岗位只改数据（`WorkDb.JOBS` + 场景里的工位坐标），本文件不用动。
##
## 时段规则（用户 2026-09-19 明确要求）：**每个中午 / 晚上各只能干一次**，
## 一趟消耗 1 小时游戏内时间。所以"开局中午 12 点 → 干一趟到 13 点"，
## 这一天的中午场就用掉了；晚上 17 点后还能再干一趟。
##
## ⚠️ 结算与推进时间的**次序**：先结算（此时时段还没变），再推进 1 小时。
##    反过来的话，"中午 12:30 开工 → 先推到 13:30"会把记录记成下午那一档，
##    规则会莫名其妙地松掉。

## `WorkDb.JOBS` 里的岗位 id（食堂 = canteen_shift）
@export var job_id: String = ""

## 结算记录用的键（默认 = 岗位 id）。
## 为什么允许单独指定：同一个岗位将来可能摆两处工位，那时"两处各自一次"
## 还是"共用一个名额"由数据决定，不需要改代码。
@export var record_id: String = ""

## ⚠️ `required_flag`（"没打开开关时按不动"）用的是**基类** `Interactable.required_flag` ——
##    食堂这个工位挂的是 `QuestData.FLAG_ATE`（已经吃过饭），
##    所以"没吃饭先去后厨打工"这条路径整个消失（不是弹一句"现在不行"，是根本没有这个交互点）。
##    用户 2026-09-20："在打饭吃完饭前不能先干活"。
## ⚠️ 这里**不再声明同名字段**：GDScript 会报
##    `The member "required_flag" already exists in parent class Interactable`。
##    ⚠️ 也不要在这里重写 `required_flag` 去表达"这个时段不能干" —— 它是**静态的**
##       （进场景那一刻定死），而"能不能干"是随时钟走的动态状态（见下面的 `can_interact()`）。
##       反例（踩过）：把 `required_flag` 写成"已了结就封死"，结果晚上那趟班也一起没了
##       （用户 2026-09-20 晚："晚上可以再做一次食堂打工"）。

## 这次班结束之后写下的"赚到了钱没有"（看手机那句据此选词，见 `MealSpot.FLAG_EARNED`）。
## ⚠️ 名字必须与 `MealSpot.FLAG_EARNED` 一致（同一个开关，两处读）；
##    那边是"消费方"、这里是"生产方"，所以这里也用同一串字面量。
const EARNED_FLAG := "canteen_meal_earned"


func _ready() -> void:
	if custom_prompt == "":
		custom_prompt = "干一趟活（%s）" % WorkDb.label_of(job_id)
	if record_id == "":
		record_id = job_id
	super._ready()


# ⚠️ 基类只判 `required_flag`（"吃过饭没有"），这里再叠一层**动态**判据：
#    "**这个时段**还能不能干"。两层的意义不同 ——
#      · `FLAG_ATE` 没开        → 这一趟食堂之旅还没到打工那一步（连提示都不给）；
#      · `Currency.can_work()` 为假 → 现在不是中午/晚上，或这个时段已经干过一趟了。
#    合起来的效果正是用户要的：**中午干过、晚上回食堂还能再干一趟**
#    （2026-09-20 晚："晚上可以再做一次食堂打工"），而同一个时段里怎么按都没反应。
func can_interact() -> bool:
	if not Currency.can_work(record_id):
		return false
	return super.can_interact()


## 动态排位：**现在能干时，工位排在前面**。
## 用途与开局那台手机一样（见 Interactable.interact_priority）：工位旁边往往还站着人，
## 若按距离排，"按 E 就是聊天"会一直压着"按 E 打工"，玩家得先按 Tab 才找得到挣钱的地方。
func interaction_priority() -> int:
	return 10 if Currency.can_work(record_id) else 0


func _interact() -> void:
	var job := WorkDb.job(job_id)
	if job.is_empty():
		push_warning("WorkSpot: 未登记的岗位 '%s'（节点 %s）" % [job_id, name])
		return
	await start_shift()


## 走一趟班：报到 → 干活 → 推进时间 → 结算。
## 单独抽成公开方法，是为了让"食堂里的工位"能被脚本/走查直接驱动，不必先挪玩家。
func start_shift() -> void:
	var job := WorkDb.job(job_id)
	if job.is_empty():
		return
	var player := get_player()
	var was_moving := player != null and bool(player.get("can_move"))
	var reason := Currency.work_block_reason(record_id)
	if reason != "":
		await _play_blocked(reason, player, was_moving)
		return
	# 开工时的时段：结算文案要用它（干完 1 小时之后时段可能已经翻页，不能再现取）
	var period := Currency.current_period()

	# 报到：先把"这趟干什么"说清楚，再开始玩
	var opener: Array = []
	var line := WorkDb.line_of(job_id)
	if line != "":
		opener.append({"speaker": "", "text": line})
	opener.append({"speaker": "周明远", "text": "（%s的班，一个钟头。干吧。）" % Currency.period_label(period),
			"emotion": "认命"})
	if player != null and player.has_method("set_control_enabled"):
		player.call("set_control_enabled", false)
	await DialogueBox.play_script(opener)

	var cents := 0
	var completed := -1
	var left := false
	# ⚠️ 记下开工前的余额：这一趟到底**赚没赚到钱**要靠它算
	#    （看手机那句"赚了点钱"的有无，见 `MealSpot.FLAG_EARNED`）。
	#    用"钱包变没变多"当判据，而不是"有没有结算过" —— 中途退出、工钱为 0
	#    这两种情况在玩家看来都是"没赚到钱"。
	var balance_before := Currency.amount()
	var game := WorkDb.minigame_of(job_id)
	if game != "" and PlateGame.has_method("play"):
		var result: Dictionary = await PlateGame.play(job_id, record_id)
		completed = int(result.get("completed", -1))
		cents = int(result.get("cents", 0))
		left = bool(result.get("left", false))

	# 时间在结算**之前**推进，而且**中途退出也算**：
	# ① 记账要用**开工时的时段**，先推进时间会把记录记到下一个时段去；
	# ② 用户明确要求"一次会让时间过去 1 小时"；
	# ③ 用户 2026-09-20 补的那条："干活退出也算做了一次，时间应该调到 13:30" ——
	#    退出只是"没拿到钱"，**那一小时是真的过去了**（原来退出既不走时间也不占名额，
	#    于是玩家可以靠"进小游戏→立刻退出"无限拖时间）。
	GameFlow.advance_time(WorkDb.minutes_of(job_id))

	if left:
		# 玩家中途退出：**不发工钱**，但**占掉这个时段的名额、也走掉一小时**（见上）。
		# ⚠️ 占用名额靠 `Currency.settle_work(record_id, 0)`（工钱 0 = 只记名额）——
		#    `work_records` 是"这个时段干过了"的唯一账本，不记的话玩家能反复刷。
		Currency.settle_work(record_id, 0)
		# 没拿到钱：把"赚到了"标成 false（看手机那句据此去掉"赚了点钱"）
		GameFlow.set_flag(EARNED_FLAG, false)
		await DialogueBox.play_script(PlateGame.left_lines(completed))
		_restore_unlock(player, was_moving)
		return
	if completed < 0:
		# 没有小游戏（或小游戏没起来）：直接按底薪 + 背包加成结算
		cents = Currency.wage_for(job_id)
		Currency.settle_work(record_id, cents)

	# ⚠️ "赚没赚到钱"按**钱包实际变多没有**写（底薪兜底时也算赚到）：
	#    看手机那句"走吧，去教学楼上课去"里的"赚了点钱"读的就是它。
	GameFlow.set_flag(EARNED_FLAG, Currency.amount() > balance_before)

	var lines: Array = []
	if completed >= 0:
		# ⚠️ 把这一局的结果**显式传进去**：不要让它去读 PlateGame 的内部状态 ——
		#    收尾之后那个状态可能已经被改（走查里出现过"分完 5 只"与"成绩 0 个"对不上）。
		lines = PlateGame.result_lines(completed, cents)
	else:
		lines.append({"speaker": "", "text": WorkDb.result_of(job_id) % Currency.format_cents(cents)})
	lines.append(Currency.balance_line(cents))
	lines.append({"speaker": "周明远", "text": "（%s的活儿干完了。现在 %s，这个时段不用再来了。）" % [
			Currency.period_label(period), GameState.format_time()],
			"emotion": "疲惫"})
	await DialogueBox.play_script(lines)
	_restore_unlock(player, was_moving)


## 干不成的两种情形，各给一句明确的话 —— 用户要求的是"什么时候不能干要说明白"，
## 而不是"按了没反应"。
func _play_blocked(reason: String, player: Node, was_moving: bool) -> void:
	var lines: Array = []
	if reason == "off_hours":
		lines = [
			{"speaker": "", "text": "后厨只剩值班的师傅在收拾，洗碗的活儿只有饭点前后才有人收。"},
			{"speaker": "周明远", "text": "（现在是 %s。中午和晚上各来一趟就行，别的时候来也白来。）" % GameState.format_time(),
					"emotion": "讪讪"},
		]
	else:
		lines = [
			{"speaker": "", "text": "阿姨摆摆手：这趟的人手已经够了。"},
			{"speaker": "周明远", "text": "（%s的活儿刚干完，跑第二趟人家该嫌我烦了。）" % Currency.period_label(Currency.worked_period(record_id)),
					"emotion": "认命"},
		]
	if player != null and player.has_method("set_control_enabled"):
		player.call("set_control_enabled", false)
	await DialogueBox.play_script(lines)
	_restore_unlock(player, was_moving)


## 把玩家恢复成"交互之前"的状态（不能一律解锁，见 Interactable 的说明）
func _restore_unlock(player: Node, was_moving: bool) -> void:
	if player == null or not player.has_method("set_control_enabled"):
		return
	player.call("set_control_enabled", true)
	if not was_moving and player.has_method("set_movement_enabled"):
		player.call("set_movement_enabled", false)


## 走查断言用：工位指到岗位了吗
func is_valid_job() -> bool:
	return WorkDb.has_job(job_id)


## 现在能不能干（走查断言用）
func can_work_now() -> bool:
	return Currency.can_work(record_id)
