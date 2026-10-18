extends Node
## 流程系统（自动加载单例 GameFlow）
##
## 职责：定义"游戏怎么走"——新游戏、读档、章节/昼夜推进、游玩时长统计。
## 它调用 SceneRouter 切场景，但 SceneRouter 不知道 GameFlow 的存在（单向依赖）。
##
## 章节框架：每章包含白天段（day）与夜间段（night）。
## 大学（hometown）不属于章节，是进入高中的接口，用 phase 区分昼夜之外的状态。

signal chapter_changed(chapter: int)
signal phase_changed(phase: String)

## 游玩时长统计
var _play_clock: float = 0.0
var _counting: bool = false

## 新游戏要走的开场流程
const OPENING_SEQUENCE := [
	{"location": "intro_cg", "spawn_point": ""},
]

## 最近一次"玩家真的能操作"的地点（宿舍 / 校园 / 食堂 / 教学楼…）。
##
## 为什么需要它（用户 2026-09-20："返回标题应该自动保存当前进度"）：
##   回标题这件事**可能发生在 CG 过场里**（`cg_player` / `alyina_cg` 都有自己的
##   "回标题"出口）。而 CG 场景的 `GameState.location` 是 `cg.xxx`，把它存进槽位，
##   下次读档就会一头栽进那段过场里（还得再播一遍）。
##   所以自动存档要用这个"沉下来的锚点"，而不是当前那个可能正处于过场里的地点。
##
## ⚠️ 它**跟着存档走**（`GameState.to_dict()` 里的 `last_play_location`）：
##   读档回到"上一次真正在玩的地方"才是玩家想要的；
##   ⚠️ 旧存档没有这个键 → 兜底成空串，那时退回"用当前 location"的老行为。
var last_play_location: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if not _counting:
		return
	_play_clock += delta
	# 每 5 秒写回 GameState，避免每帧改数据
	if _play_clock >= 5.0:
		GameState.played_seconds += _play_clock
		_play_clock = 0.0


func start_play_clock() -> void:
	_counting = true
	_play_clock = 0.0


func stop_play_clock() -> void:
	if _counting and _play_clock > 0.0:
		GameState.played_seconds += _play_clock
		_play_clock = 0.0
	_counting = false


## ---------------- 入口：新游戏 / 读档 / 回标题 ----------------

## 新游戏：选择槽位 -> 重置状态 -> 走开场 CG
## 初始存档不在这里写：CG 播完进入宿舍时，宿舍门那次的自动存档会落盘。
##
## ⚠️ 新游戏必须**清掉上一局的对话回顾**（用户 2026-09-20 实报：
##    "从 A 存档退出、进入 B 存档，会保存上个存档的对话内容"）：
##    回顾挂在常驻单例上，不清的话开新档第一眼就能翻到上一档的台词。
func new_game(slot: int) -> void:
	StoryJump.end_session()
	GameState.reset_new_game(slot)
	# 新档：锚点清空（`reset_new_game` 已经清过 `GameState` 那份，这里同步运行期那份）
	last_play_location = ""
	DialogueBox.clear_history()
	start_play_clock()
	SceneRouter.fade_out_instant()
	await SceneRouter.go_to("intro_cg", "", false)


## 读取存档：恢复状态 -> 跳到存档记录的地点
func continue_game(slot: int) -> void:
	if not SaveSystem.load_from_slot(slot):
		push_warning("GameFlow: 槽位 %d 读取失败" % slot)
		return
	StoryJump.end_session()
	start_play_clock()
	# ⚠️ 把锚点从存档里**接回来**（见 `last_play_location`）：
	#    读档后如果直接回标题，自动存档要用它，不能是空的 —— 否则"刚读档就回标题"
	#    这一段进度会被判成"没什么可存"而丢掉。
	last_play_location = GameState.last_play_location
	var loc := GameState.location
	if loc == "" or loc == "main_menu" or not GameState.LOCATIONS.has(loc):
		# 存档记录的地点不合法时，退回到大学宿舍，保证不会卡死
		loc = "college.dorm"
		GameState.location = loc
	SceneRouter.fade_out_instant()
	await SceneRouter.go_to(loc, GameState.spawn_point, false)


## 回标题。**必须显式换回标题曲**：`Music` 有一道"同一首不重播"的短路，
## 光靠标题场景自己的 `Music.play("menu")` 在"标题 → 游戏 → 标题"这条路上会不生效
## （用户实报："返回标题时音乐不会变"）。在这里收口，任何回标题的入口都覆盖到。
##
## ⚠️ **离开游戏前的收尾必须收口在一处**（用户 2026-09-19 要求
##    "返回标题时不会自动在相应的存档槽里保存当前进度"）：回标题的入口不止一处
##    （暂停菜单、剧情强制回标题、CG 里那两条出口…），把"存"和"跳"绑在一起，
##    才不会有某个入口漏掉。存档目标就是**当前槽**（`GameState.slot`）。
##
## [param save_now] 回标题前要不要把进度存回当前槽。
##   ⚠️ 用户 2026-09-20 第三轮："返回标题存档逻辑修改一下，加一个是否保存的选项" ——
##      所以这个决定现在由**调用方**（暂停菜单里的那个三选一）给出来：
##        · true  = 存了再走（"保存并返回标题"）；
##        · false = 直接走（"不保存，直接返回"）。
##      默认仍是 true：别的入口（剧情强制回标题之类）没有玩家可问，
##      静默存一份总比丢掉进度好。
func back_to_title(save_now: bool = true) -> void:
	stop_play_clock()
	if save_now:
		# ⚠️ 显式传"最近一次真正在玩的地点"：回标题有可能发生在 CG 过场里
		#    （`cg_player` / `alyina_cg` 都有回标题出口），而那时的 `GameState.location`
		#    是 `cg.xxx` —— 拿它去存，下次读档就会掉回同一段过场里。
		#    用户 2026-09-20："返回标题应该自动保存当前进度"。
		auto_save_before_title(last_play_location)
	# ⚠️ **回标题前必须先把对话框收掉**（用户 2026-09-20：
	#    "对话时不应该在返回标题界面时对话框还在还能点，暂停界面应该优先级最高"）。
	#    对话框是**跨场景常驻**的单例（`process_mode = ALWAYS`），
	#    切场景不会顺手关它；留着的话标题画面上会挂着一个还能用空格/E/鼠标点的对话框，
	#    压在菜单按钮上面。收尾动作与"存档""换标题曲"放同一处（见上一条注释的理由）。
	DialogueBox.hide_box()
	# ⚠️ 顺手把暂停状态清掉：暂停菜单会先 `_close()` 再调本函数，但"回标题"的入口
	#    不止一个（将来的剧情强制回标题、主菜单返回…），谁漏了谁就把整棵树冻着 ——
	#    表现是"回到标题后点什么都没反应"（`game_flow` 自己是 `PROCESS_MODE_PAUSABLE`）。
	get_tree().paused = false
	Music.play("menu", 1.2)
	await SceneRouter.go_to("main_menu", "", true)


## 回标题前的自动存档：存到**当前槽**。
## 返回 {ok, reason, slot, location, time}，供调用方播提示/记日志。
##
## [param override_location] 用哪个地点写进存档（留空 = 用当前 `GameState.location`）。
##   `back_to_title()` 会显式传 `last_play_location` —— 见下面"在 CG 里回标题"的说明。
##
## 三类情况**故意不存**（否则会污染玩家的存档）：
##   · 还没选过槽（`slot <= 0`：标题画面里就按了返回）；
##   · **一点进度都没有**（还在开场 CG，或根本没进过游戏）——
##     存下去只会把一个"会重播的中间态"写进槽里；
##   · 写盘失败（调用方要给提示）。
##
## ⚠️ 用户 2026-09-20 再次报"返回标题应该自动保存当前进度"。原来这里是
##    "只要 `location` 是 `main_menu` / `intro_cg` / `cg.*` 就一律不存"——
##    于是**在艾莉娜登场那段 CG 里回标题，整段进度就丢了**（玩家刚过完教学楼那一段）。
##    现在的口径：
##      · 只要**玩过**（`last_play_location` 有值），回标题就存 —— 存的是那个锚点地点；
##      · 只有"从没进过游戏"（锚点为空）才真的没什么可存。
func auto_save_before_title(override_location: String = "") -> Dictionary:
	var target_location := override_location if override_location != "" else GameState.location
	var result := {
		"ok": false, "reason": "", "slot": GameState.slot,
		"location": GameState.location_display_name(), "time": GameState.format_time(),
	}
	if GameState.slot <= 0:
		result["reason"] = "no_slot"
		return result
	# 还没玩过任何一处可玩场景：这时存下去等于把"开场过场"写进槽里
	if target_location == "" or target_location == "intro_cg" \
			or target_location == "main_menu" or target_location.begins_with("cg."):
		result["reason"] = "nothing_to_save"
		return result
	var data := GameState.to_dict()
	# ⚠️ 用锚点地点写盘（而不是当前那个可能正在播过场的地点）：
	#    下次读档要回到"上一次真正在玩的地方"，而不是重新掉进同一段 CG。
	data["location"] = target_location
	if override_location != "" and GameState.location.begins_with("cg."):
		data["spawn_point"] = ""
	result["ok"] = SaveSystem.save_to_slot(GameState.slot, data, true)
	result["reason"] = "" if result["ok"] else "write_failed"
	if result["ok"]:
		result["location"] = target_location
	return result


## 记下"最近一次真正在玩的地点"。
##
## 由 `SceneRouter.go_to()` 在每次切场景落地后调用（那是**唯一**的入口）。
## 只有"玩家真的能操作的地点"才算数：主菜单 / 开场 / CG 过场都不记 ——
## 它们在存档里没有意义（下次读档要回到能玩的地方，而不是重播一段过场）。
func note_play_location(location_id: String) -> void:
	if location_id == "" or location_id == "main_menu" or location_id == "intro_cg" \
			or location_id.begins_with("spirit.") \
			or location_id.begins_with("cg.") or not GameState.LOCATIONS.has(location_id):
		return
	last_play_location = location_id
	# ⚠️ 也必须写进 `GameState`：它才跟着存档走（`last_play_location` 是本单例的运行期镜像，
	#    进程重启就没了；读档之后要靠存档里那份把锚点**接回去**）。
	GameState.last_play_location = location_id


## ---------------- 章节 / 昼夜 推进 ----------------
func set_chapter(chapter: int) -> void:
	if GameState.chapter == chapter:
		return
	GameState.chapter = chapter
	chapter_changed.emit(chapter)


func set_phase(phase: String) -> void:
	if GameState.phase == phase:
		return
	GameState.phase = phase
	phase_changed.emit(phase)


## 由剧情节点调用：进入夜间（B-side）。真正的战斗场景后续接入。
func enter_night() -> void:
	set_phase("night")
	Music.play("dorm_calm", 1.2)


func enter_day() -> void:
	set_phase("day")
	Music.play("campus_day", 1.2)


## ---------------- 游戏内时间 ----------------

## 推进游戏内时间。
##
## ⚠️ 跨过 0 点时必须**同时把"第几天"+1**（`GameState.advance_day()`）：
##    时钟本身是 0..1439 循环的，跨天后它反而变小了，任何"从起始时刻折算天数"的算法
##    都会在那一刻算出负数天（实测踩到：中午开局推过午夜 → 第 -1 天）。
##    所以"天"是显式存的状态，这里是它唯一的入口。
##
## ⚠️ **看过手机之前不推进时间**（用户 2026-09-20："开局显示的是 10:00，改为未知"）：
##    那段时间玩家还睡着、也不知道几点，时钟对玩家是不可见的；
##    真让它走，会出现"未知 → 睡到 12:04 却已经过了两小时"这种算不明白的帐。
##    唯一的入口是看完手机那一下（`reveal_time`）。
##
## ⚠️ 但"程序化的时间推进"（`set_time` / 自检 / 以后的时间跳跃过场）**要把时钟点亮**：
##    它们都是"剧情已经告诉玩家几点了"的场合。判据因此放在 `set_time()` 里（见下），
##    而不是让每个调用方自己记得先 reveal ——那种约定迟早会漏。
func advance_time(minutes: int) -> void:
	if minutes <= 0 or not GameState.time_known:
		return
	var total := GameState.in_game_minutes + minutes
	GameState.in_game_minutes = total % (24 * 60)
	var crossed := int(total / (24 * 60))
	for i in crossed:
		GameState.advance_day()


## 直接把时钟拨到 hh:mm。
## ⚠️ 它同时把 `time_known` 置真：能"拨时间"的场合（剧情跳过、自检摆状态）
##    都意味着时刻是明确的；不置真的话，`advance_time()` 会在后面静默不生效
##    （实测：story_flow_test 里所有"推时间"的断言全红，而时间一直是"未知"）。
func set_time(hour: int, minute: int = 0) -> void:
	GameState.in_game_minutes = (hour * 60 + minute) % (24 * 60)
	GameState.time_known = true


## **让时钟露面**：把时间拨到 hh:mm 并标记"玩家已经知道几点了"。
##
## 只在"第一次看手机"那一下调用（08：旁白"屏幕亮起，赫然显示当前的时间为 12:04"）。
## ⚠️ 它是"未知 → 已知"的唯一入口：写在别处的话，会有第二条路悄悄把时钟点亮，
##    HUD 上"什么时候该显示时间"就没人说得清了。
func reveal_time(hour: int, minute: int = 0) -> void:
	GameState.in_game_minutes = (hour * 60 + minute) % (24 * 60)
	GameState.time_known = true


## ---------------- "晚间"与主动等待 ----------------

## 从这里开始算晚间（用户 `01_GOALS.md`："剧情的推进触发点为**晚间**主角想起来要去拿照片"）。
##
## ⚠️ 为什么按**时钟**判而不是按 `phase`：`phase` 是剧情状态（谁切换谁负责），
##    而玩家看得见的是时钟（HUD 上写着几点）。"天黑了"这件事该以时钟为准 ——
##    否则会出现"时钟显示 20:00，但 phase 还是 day，剧情不触发"的怪事。
##
## ⚠️ 值与 `Daylight.NIGHT_FROM` 是**同一个时刻**，而且是**有意的**：
##    HUD 上的时段名（白天/夕阳/夜间）与画面环境光都由 `Daylight` 算，
##    "晚间"如果和"夜间"差一截，玩家就会看到"指引说等天黑、时间框却还写着夕阳"。
##    所以这里只是转发，不再自己写数字。
const EVENING_FROM_MINUTES := Daylight.NIGHT_FROM


func is_evening() -> bool:
	return GameState.in_game_minutes >= EVENING_FROM_MINUTES


## 玩家**主动等待**：把时间推进到"下一个 hh:mm"（睡觉 / 发呆 / 等人）。
## 返回推进了多少分钟，供调用方判断。
##
## 为什么要有它（不是可有可无的便利函数）：
##   `01_GOALS.md` 后半段的触发点是"**晚间**"，而在这之前时钟只会被两件事动过 ——
##   看手机（拨到 12:04）和打工（一小时一档）。**玩家没有任何办法把时间推到晚上**，
##   剧情就永远触发不了。宿舍床边那个"躺一会儿"用的就是它。
##
## ⚠️ 与"商品不许改时间"那条规矩不冲突：那不是商品效果，是玩家自己的选择。
## ⚠️ 仍然走 `advance_time()`（**唯一的跨天入口**），所以跨过 0 点时"第几天"照样 +1。
func wait_until(hour: int, minute: int = 0) -> int:
	var target := (hour * 60 + minute) % (24 * 60)
	var delta := target - GameState.in_game_minutes
	if delta <= 0:
		delta += 24 * 60
	advance_time(delta)
	return delta


## ---------------- 剧情开关 ----------------

func has_flag(flag: String) -> bool:
	return bool(GameState.get_flag(flag, false))


func set_flag(flag: String, value: Variant = true) -> void:
	GameState.set_flag(flag, value)


## 手动存档（存档点调用）
func save_now() -> bool:
	if GameState.slot <= 0:
		push_warning("GameFlow: 尚未选择存档槽，无法存档")
		return false
	SaveSystem.save_to_slot(GameState.slot, GameState.to_dict(), true)
	return true
