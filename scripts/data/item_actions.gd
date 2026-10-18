class_name ItemActions
extends RefCounted
## 道具"用下去会发生什么"的唯一落点。
##
## 为什么单独一个文件：`Inventory` 只该管数量与归属，不该认识对话、剧情、时间、场景；
## 而 `ItemDb` 是纯数据、放不了行为。于是道具表里的 `action` 字段是一个**字符串 ID**，
## 在这里映射到真正的行为 —— 新增可用道具 = ItemDb 加一条 + 这里加一个分支，
## 其它文件（背包面板、Inventory、存档）都不用动。
##
## 约定：每个 action 都是**协程**（可以 await 对话），返回 bool 表示"这次使用是否生效"。
## `false` 表示什么都没发生（UI 可以不做提示），而不是"出错了"。

## 第一次看手机：交代时间与处境，并把 `woke_up` 打开
##
## 照 `request/08_DIALOG.md` 的开场：醒来 → 手机就放在桌面上、屏幕还亮着 →
## "屏幕亮起，赫然显示当前的时间为 12:04" → 先去食堂吃饭。
const PHONE_FIRST_LOOK := [
	{"speaker": "", "text": "按下电源键，屏幕亮起——12:04。"},
	{"speaker": "周明远", "text": "……十二点了？", "emotion": "恍惚", "voice": "ch00_0001"},
	{"speaker": "周明远", "text": "看来真是昨天写毕业论文太用功累过头了。", "emotion": "无奈"},
	{"speaker": "周明远", "text": "算了，事已至此先去食堂吃饭吧，这个点人肯定巨多……", "emotion": "认命"},
]

## 之后再看：报时（+ 手机上的两件待办）。
##
## ⚠️ 正文里有 `%s`（当前时间）—— 对话编辑器会提醒"别把占位符删了"，
##    删掉的话 `use_phone()` 里的 `% GameState.format_time()` 会报参数不匹配。
##
## ⚠️ 08 里那两句的时间是 **13:30**（打工一小时之后）。这里的时间写成 `%s` 由时钟现取：
##    玩家可能先干别的再看手机，写死 13:30 会出现"时钟 14:10、手机说 13:30"的矛盾。
##    但**两件待办是写死的** —— 那是"今天剩下要做什么"，不是当前时间。
const PHONE_LATER := [
	{"speaker": "", "text": "手机上显示着当前时间：%s。"},
]

## 第二天早晨打开背包里的手机：只保留昨天留下的高中待办。
const PHONE_MORNING := [
	{"speaker": "", "text": "你看见你昨天写的代办:和艾莉娜去高中。"},
]

## 手机屏幕上方那**两件待办**（08 原文："14:00 教学楼301上课 ;未定时间 图书馆写毕业论文"）。
##
## ⚠️ 用户 2026-09-20："手机在和陈默对话前不应该再次使用时显示两件待办的文本" ——
##    这两件事**是陈默在那段对话里告诉主角的**（"对了，下午两点有毕业论文写作课，记得准时去"），
##    没跟他说过话就显示出来，等于手机提前知道了还没发生的事。
##    所以它挂在 `QuestData.FLAG_ROOMMATE`（跟陈默聊过）之后再出现。
const PHONE_TASKS := [
	{"speaker": "", "text": "屏幕上方还压着两件待办：\n"
		+ "　14:00　教学楼 301 上课\n"
		+ "　时间未定　图书馆写毕业论文"},
]

## 出门去上课前那句"走吧，去教学楼上课去……"（08 第 199 行，`周明远（内心）`）。
##
## ⚠️ **它不能跟 `PHONE_LATER` 一起无脑播**（用户 2026-09-20 实报：
##    "开局看一次手机后再看手机会直接显示后面看手机的对话"）：
##    08 里这句话出现在**打完饭、干完一趟活、13:30 再看手机**那一段 ——
##    紧接着就是"任务更新：前往教学楼 301 上课"。
##    所以它挂在 `QuestData.FLAG_WORK_CHOICE_DONE`（打工那一步已经了结）之后再出现。
##
## ⚠️ **它是"看手机"里的最后一句、不是"打工完立刻说"**（用户 2026-09-20：
##    "选择了先不打工应该是没有「走吧，去教学楼上课去」这句话的，打开手机后才会触发"）：
##    所以它由 `phone_later_lines()` 组装、只在**第一次看手机**时出现
##    （看过就写 `FLAG_PHONE_AFTER_MEAL`，之后再看手机只剩"报时 + 两件待办"）。
##
## ⚠️ **赚没赚到钱决定说哪一句**（用户："如果选择打工没赚到钱同理"）：
##    · 真拿到工钱 → 08 的原话（里面有"赚了点钱"）；
##    · 没拿钱（选了不干 / 干了但中途退出）→ 同一句**去掉"赚了点钱"**。
##    判据是 `canteen_meal_earned`（由 `WorkSpot` 在一次班结束时按"钱包有没有变多"写下），
##    而不是"有没有干过" —— 用户点名的是"没赚到钱"这件事本身。
const PHONE_GO_TO_CLASS_EARNED := [
	{"speaker": "周明远（内心）",
		"text": "走吧，去教学楼上课去。赚了点钱，去教学楼前顺便在自动贩卖机"
			+ "或者教育超市买点可乐什么的也行。", "emotion": "盘算"},
]

const PHONE_GO_TO_CLASS := [
	{"speaker": "周明远（内心）",
		"text": "走吧，去教学楼上课去。去教学楼前顺便在自动贩卖机"
			+ "或者教育超市买点可乐什么的也行。", "emotion": "盘算"},
]

## ⚠️ **没有"还得给陈默带饭"这一句**（用户 2026-09-20）：
##    08 改过之后，陈默让他带饭、主角是**拒绝**的（"不去。你自己去外面吃饭去得了。"，
##    见 `dorm.roommate.first`），所以手机的待办里不该再出现"带饭"这件事。
##    （原来这里有一句 `PHONE_AFTER_FAVOR`，是照着旧剧本写的，已经删掉。
##     别再照着"陈默托带饭"的旧印象加回来 —— 先去看 `request/08_DIALOG.md` 现在怎么写的。）

## 艾莉娜加入队伍之后，看完那两件待办会多出一句自嘲（用户 2026-09-20 指定）。
##
## 位置：**紧跟在「两件待办」后面**（所以她没加入队伍、手机上没那两件待办时也不会出现）。
## 为什么挂在"她已加入"上：这时玩家已经从"刚醒"推进到"有人跟着逛校园"，
## 那两件待办摆了一整天一件没动 —— 这句自嘲是那一步的情绪落点。
const PHONE_TASKS_UNDONE := [
	{"speaker": "周明远（内心）",
		"text": "你发现今天的待办你都没完成。", "emotion": "心虚"},
]

## 取到洗好的照片后，再看手机时的收束句。
## 时间仍由 `PHONE_LATER` 动态显示；这里只替换艾莉娜加入后的待办独白。
const PHONE_TASKS_AFTER_PHOTO := [
	{"speaker": "周明远（内心）", "text": "今天未完成的待办已经都被你删除了。"},
]

## 契约后在背包中使用洗好的照片时的专属旁白。
## 契约前仍走通用物品说明；这句要等照片触发契约后才出现。
const PHOTO_PRINT_LINES := [
	{"speaker": "", "text": "现在这些照片对你来说有了特别的意义。", "photo": "res://assets/graphics/cg/photo_highschool_friends.png"},
]

const PHOTO_PRINT_GENERIC_LINES := [
	{"speaker": "", "text": "你翻开了洗好的照片。", "photo": "res://assets/graphics/cg/photo_highschool_friends.png"},
]


## 第二次及以后看手机时**到底播哪几段**。
##
## 顺序与 08 一致：报时 →（跟陈默聊过）两件待办 →（她已加入）"今天的待办你都没完成"
## →（**第一次**看手机、且打工那步已了结）"走吧，去教学楼上课去"。
##
## ------------------------------------------------------------------ ⚠️ 逐块套补丁（2026-09-20 修）
##
## 原来是"把五段拼好，整串挂 `item.phone.later` 一个补丁 id"。**那是错的**：
## 对话编辑器里这几段是**分开登记**的（`item.phone.later` / `item.phone.tasks` /
## `item.phone.go_to_class*`，见 `DialogueCatalog`），作者改 `item.phone.tasks` 存进覆盖层之后
## **游戏里一点反应都没有**（用户实报："我修改的关于手机上显示取照片的信息没生效"）——
## 因为 `use_phone()` 只问了 `item.phone.later`，那个块在补丁里根本不存在。
## 现在改成**每段问自己的 id**，与编辑器登记的粒度一一对应。
##
## ⚠️ 仍然保留"整串"那一层（`item.phone.later`）：万一有人的覆盖层里存着旧口径的整串，
##    它依旧生效（取到就以它为准）—— 迁移期的兼容，不是新写法。
##
## ⚠️ 最后那一句**只出现一次**：它的标志就是 `FLAG_PHONE_AFTER_MEAL`
##    （"出门前已经看过手机了"）——看过之后它不再重复
##    （用户 2026-09-20："……打开手机后才会触发"，而它是"出门前那一次"的内容）。
## ⚠️ "赚了点钱"的有无按 `canteen_meal_earned`（真拿到工钱没有）选句，
##    见 `PHONE_GO_TO_CLASS_EARNED` 的说明。
static func phone_later_lines() -> Array:
	if GameFlow.has_flag(StoryData.FLAG_MORNING):
		return _patched("item.phone.morning", PHONE_MORNING)
	var out: Array = _patched("item.phone.later", PHONE_LATER)
	if GameFlow.has_flag(QuestData.FLAG_ROOMMATE):
		out.append_array(_patched("item.phone.tasks", PHONE_TASKS))
	if GameFlow.has_flag(TeachingData.STORY_ALYINA_FOLLOWS):
		if GameFlow.has_flag(StoryData.FLAG_TAKEN):
			out.append_array(_patched("item.phone.tasks_after_photo", PHONE_TASKS_AFTER_PHOTO))
		else:
			out.append_array(_patched("item.phone.tasks_undone", PHONE_TASKS_UNDONE))
	if GameFlow.has_flag(QuestData.FLAG_WORK_CHOICE_DONE) \
			and not GameFlow.has_flag(QuestData.FLAG_PHONE_AFTER_MEAL):
		var go_id := "item.phone.go_to_class_earned" if GameFlow.has_flag(MealSpot.FLAG_EARNED) \
				else "item.phone.go_to_class"
		var go_src := PHONE_GO_TO_CLASS_EARNED if GameFlow.has_flag(MealSpot.FLAG_EARNED) \
				else PHONE_GO_TO_CLASS
		out.append_array(_patched(go_id, go_src))
	# 迁移期兼容：覆盖层里如果存着"整串"那一版，以它为准（见上面的说明）
	var composite := DialoguePatch.current()
	if composite.has_block("item.phone.later"):
		return composite.patched("item.phone.later", out)
	return out


## 取一段原文并套上它**自己的**补丁 id（对话编辑器按这个 id 列出这一段）。
## ⚠️ 必须 `duplicate(true)`：调用方会改 `text`（格式化时间），不能污染常量数组。
static func _patched(id: String, source: Array) -> Array:
	return DialoguePatch.apply(id, source.duplicate(true))


## 给走查用的公开入口：某一段"套了补丁之后"到底是什么。
## 为什么需要它：手机那几段的**句数**会被覆盖层改变（作者往待办里加一句是合法的），
## 所以断言不能写死"源码里有几句" —— 得问这里。
static func phone_block(id: String, source: Array) -> Array:
	return _patched(id, source)


## 这次看手机算不算"出门前那一次"（要写任务开关 `FLAG_PHONE_AFTER_MEAL`）。
##
## 判据与台词同源：**打工那一步已经了结**（干过一趟、或者明确不干）之后再看手机，
## 才是 08 里"13:30 看一眼手机 → 去教学楼"那一次。
## ⚠️ 开局 12:04 的第二次看手机**不算** —— 否则指引会跳过"去食堂打工"那一格，
##    而玩家其实还没吃上饭。
static func phone_check_counts() -> bool:
	return GameFlow.has_flag(QuestData.FLAG_WORK_CHOICE_DONE)

## 喝能量饮料：只播一段独白，**不改变任何游戏时间**。
##
## ⚠️ 用户 2026-09-19 明确要求："目前所有商品都不应该改变时间"。
##    第一版这里会把时钟往前拨到 8:30（"多撑两个小时"的玩法化表达），
##    但那违反"商品不动时间"这条规则 —— 所以效果降级成纯文本。
##    将来要接属性/状态（体力、精神），效果应该加在这里，而不是在背包面板里，
##    而且**不要再动 `in_game_minutes`**：动时间只有打工（`WorkSpot`）那一条路。
const ENERGY_DRINK_LINES := [
	{"speaker": "", "text": "拉开拉环，气泡声在安静的宿舍里格外响。"},
	{"speaker": "周明远", "text": "……苦的。", "emotion": "皱眉"},
	{"speaker": "周明远（内心）", "text": "先放着吧，真困了再喝。", "emotion": "无奈"},
]


## 按 action ID 执行；未实现的 action 只警告并返回 false（不会崩）
static func run(action: String, item_id: String) -> bool:
	match action:
		"read_timetable":
			await load("res://scripts/ui/highschool_document.gd").show_document(
				SceneRouter.current_scene, HighschoolFirstPeriodData.TIMETABLE_IMAGE, "校园时刻表")
			return true
		"use_phone":
			return await use_phone(item_id)
		"read_item":
			return await read_item(item_id)
		"use_flashlight":
			return await use_flashlight(item_id)
		"use_energy_drink":
			return await use_energy_drink(item_id)
	if action != "":
		push_warning("ItemActions: 道具 '%s' 声明的效果 '%s' 还没实现" % [item_id, action])
	return false


## 看手机。
## 第一次：播独白 + 打开 `woke_up` + 把时间**露出来**（"未知" → 12:04）+ 放开开场被锁住的移动
##        （"看完手机才算真的醒了"，这是开场唯一的解锁点，别删）。
## 之后：只报时（外加"两件待办 / 去教学楼 / 给陈默带饭"那几句，见 `phone_later_lines()`），
##       并把玩家恢复成"使用前"的状态。
const PHONE_WAREHOUSE := [
	{"speaker": "旁白", "text": "手机没有信号，屏幕上显示着当前时间：5:00。"},
]

static func use_phone(_item_id: String) -> bool:
	var player := _find_player()
	# ⚠️ 记下"用之前"的**全部**状态，而不是只记 can_move：
	#    开场是"锁移动、但允许交互"（`set_movement_enabled(false)`），
	#    如果只记 `can_move`，播完就没法把那个状态原样还回去（见 `restore_player()`）。
	var was_moving := player != null and bool(player.get("can_move"))
	var was_locked := player != null and bool(player.get("_interaction_locked"))
	_lock_player(player, true)

	if HighschoolData.is_warehouse_location(GameState.location) or GameState.location == "highschool.external":
		# 自由查看只揭示时间，外部地图的手机剧情由它自己的进度旗标控制。
		if not GameState.time_known:
			HighschoolData.reveal_warehouse_time()
		var phone_lines := PHONE_WAREHOUSE.duplicate(true)
		phone_lines[0]["text"] = "手机没有信号，屏幕上显示着当前时间：%d:%02d。" % [int(GameState.in_game_minutes / 60) % 24, GameState.in_game_minutes % 60]
		await DialogueBox.play_script(DialoguePatch.apply("item.phone.warehouse", phone_lines))
		restore_player(player, was_moving, was_locked)
		return true

	var first_time := not GameFlow.has_flag("woke_up")
	if first_time:
		await DialogueBox.play_script(
				DialoguePatch.apply("item.phone.first", PHONE_FIRST_LOOK))
		GameFlow.set_flag("woke_up", true)
		# ⚠️ 用 `reveal_time()` 而不是 `set_time()` + `advance_time()`：
		#    它是"未知 → 12:04"的唯一入口（开局 HUD 上写的是"未知"，
		#    见 `GameState.time_known` 的说明）。
		GameFlow.reveal_time(12, 4)
		# 开场是被剧情锁着移动的，"看完手机才算真的醒了" —— 这里必须彻底放开
		_lock_player(player, false)
	else:
		# ⚠️ 先套补丁**再**做时间格式化：补丁里的正文同样带 `%s` 占位符
		#    （对话编辑器会提醒别把它删掉，但删了也不该崩 —— 所以下面按参数个数安全格式化）
		# ⚠️ 播哪几段由 `phone_later_lines()` 一处决定（什么时候出现"去教学楼上课去"
		#    与"还得给陈默带饭"都在那里判，别在这里再写一遍 if）。
		var lines: Array = []
		for entry_variant in DialoguePatch.apply("item.phone.later", phone_later_lines()):
			var copy: Dictionary = (entry_variant as Dictionary).duplicate()
			copy["text"] = _format_time_text(String(copy["text"]))
			lines.append(copy)
		await DialogueBox.play_script(lines)
		# "出门前看了手机"这一步落在这里（指引随之变成"前往教学楼 301 上课"）。
		# ⚠️ 只有"打工那一步已经了结"之后看手机才算（见 `phone_check_counts()`）——
		#    否则开局随便看一眼就会把"去食堂帮工"那一格任务跳过去。
		if phone_check_counts():
			GameFlow.set_flag(QuestData.FLAG_PHONE_AFTER_MEAL, true)
		restore_player(player, was_moving, was_locked)
	return true


## 把正文里的 `%s` 换成当前时间；**一个占位符都没有就原样返回**。
## 为什么不能直接 `% time`：`"abc" % x` 在 GDScript 里会报
## "not all arguments converted"，玩家自己改文案（删掉 %s）就会在使用道具时崩。
static func _format_time_text(text: String) -> String:
	if not text.contains("%"):
		return text
	return text % GameState.format_time()


## 通用"看东西"：把道具描述当一段独白播出来。
##
## 为什么给它一个通用 action：背包里绝大多数东西（笔记本、笔、抽纸、明信片…）不该
## "用不了"—— 玩家点「使用」却弹"现在用不了"是最劝退的反馈。
## 于是凡是在 ItemDb 里标了 `action = "read_item"` 的，都能看一段描述，
## **加一件可读的道具不需要再写代码**（只改 ItemDb 一条数据）。
static func read_item(item_id: String) -> bool:
	if item_id == "highschool_boxing_note":
		await load("res://scripts/ui/highschool_document.gd").show_document(
			SceneRouter.current_scene, HighschoolBreakEvents.NOTE_FRONT, "厕所角落的纸条", HighschoolBreakEvents.NOTE_BACK)
		return true
	if item_id == "highschool_anya_photo":
		await DialogueBox.play_script([{"speaker": "旁白", "text": ItemDb.description(item_id), "photo": "res://assets/graphics/cg/photo_highschool_friends.png"}])
		return true
	if item_id == "photo_print":
		var lines := PHOTO_PRINT_LINES if GameFlow.has_flag(StoryData.FLAG_CONTRACT) else PHOTO_PRINT_GENERIC_LINES
		await DialogueBox.play_script(DialoguePatch.apply("item.photo_print", lines))
		return true
	var desc := ItemDb.description(item_id)
	if desc == "":
		return false
	var name := ItemDb.display_name(item_id)
	await DialogueBox.play_script([
		{"speaker": "", "text": "（%s）" % name},
		{"speaker": "周明远", "text": desc, "emotion": "自语"},
	])
	return true

static func use_flashlight(_item_id: String) -> bool:
	var enabled := toggle_flashlight()
	await DialogueBox.play_script([{"speaker":"", "text":"手电筒已%s。" % ("打开" if enabled else "关闭")}])
	return true

static func toggle_flashlight() -> bool:
	var enabled := GameFlow.has_flag("highschool.flashlight_on")
	# 黑暗走廊首次相遇前，开启后保持照明；背包和快捷键共用判据。
	if enabled and GameState.location == "highschool.corridor" and not GameFlow.has_flag("highschool.alyina_found"):
		return true
	GameFlow.set_flag("highschool.flashlight_on", not enabled)
	return not enabled


## 喝能量饮料：只播一段独白，**不改变任何游戏内时间**。
## （正文在 `ENERGY_DRINK_LINES`，见上面的说明 —— 段落常量是为了让对话编辑器能取到原文。）
static func use_energy_drink(_item_id: String) -> bool:
	await DialogueBox.play_script(
			DialoguePatch.apply("item.energy_drink", ENERGY_DRINK_LINES))
	return true


# ---------------------------------------------------------------- 内部

## 锁住 / 放开玩家的操作。
## 用 set_control_enabled：它同时管"移动"与"交互"，播放剧情时必须两个都锁。
static func _lock_player(player: Node, locked: bool) -> void:
	if not is_instance_valid(player):
		return
	if player.has_method("set_control_enabled"):
		player.call("set_control_enabled", not locked)


## 把玩家恢复成"使用道具之前"的状态。
## 为什么不能一律 `set_control_enabled(true)`：开场是 `set_movement_enabled(false)`
## （只锁移动、保留交互），无条件放开会把剧情锁一起解开。
##
## ⚠️ 这里把**两个开关分别照原样还回去**（用户 2026-09-20 报"卡死无法移动"时顺带查到的坑）：
##    旧写法是"`can_move` 为真就 `set_control_enabled(true)`，否则
##    `set_control_enabled(true)` + `set_movement_enabled(false)`" ——
##    第二条路**无条件**把移动锁上了：如果玩家用道具前正好是"移动锁着、但交互可用"
##    （开场那种状态，或者剧情锁着的时候点开背包用了一件东西），
##    用完就变成"永久动不了"，而且 `can_move=false` 是**看起来完全正常**的状态。
static func restore_player(player: Node, was_moving: bool, was_locked: bool = false) -> void:
	if not is_instance_valid(player):
		return
	if was_moving:
		_lock_player(player, false)
		return
	# 使用前不能动：恢复成"不能动"，但**交互开关按原样**
	if player.has_method("set_control_enabled"):
		player.call("set_control_enabled", not was_locked)
	if player.has_method("set_movement_enabled"):
		player.call("set_movement_enabled", false)


static func _find_player() -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Node2D
