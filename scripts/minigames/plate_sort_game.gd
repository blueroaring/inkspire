extends CanvasLayer
## 「盘子分类」打工小游戏（自动加载单例 PlateGame）
##
## 玩法（用户 2026-09-19 三稿的要求）：
##   刷碗间窗口前排着一队同学，队首那位要么**拿着吃完的盘子来倒**（回收），
##   要么**空着手来取干净盘子**（出餐）。玩家按三步处理这一位：
##     ① 动作：`1` 回收 / `2` 出餐
##     ② 颜色：把盘子放进**同色**的抽屉（4 个颜色桶）
##     ③ 形状：再放进**同形状**的格子（5 个形状桶）
##   限时 60 秒，按分完的个数分档给钱。
##
##   · **三步都错不得**：错任一步 → 完成数 -1（最低 0）+ 换一位同学
##   · **桶位每次都洗牌**：每处理完一位，颜色桶与形状桶的左右顺序都随机重排
##   · **可以中途退出**：`Esc` 或「离开洗碗间」—— 不发工钱、也不占这个时段的打工名额
##
## 为什么颜色和形状都要：用户明确要求"根据盘子的颜色形状等收纳到正确的桶中"，
## 且有同学来取盘时"要什么颜色什么形状"必须能表达出来。
## 判定顺序固定为 动作 → 颜色 → 形状（先看盘子是什么颜色、再是什么形状，符合收拾东西的习惯）。
##
## 分层：本文件只管小游戏本身（排队、出题、判定、计时、计分、结算文案）。
##   · 词表与盘子贴图 -> `scripts/data/plate_types.gd`
##   · 工钱怎么算/怎么记账 -> `Currency.settle_work()` + `WorkDb`
##   · 什么时候能打工 -> `Currency.can_work()`（中午/晚上各一次）
##   · 在哪儿按 E 开始 -> `scripts/interactables/work_spot.gd`
##
## ⚠️ 它是**临时叠层**，不进任何 `.tscn`：`start()` 时才把自己搭起来，结束就收摊。

signal finished(completed: int, cents: int)

## 小游戏 id（与 `WorkDb` 里岗位的 `minigame` 字段对应）
const GAME_ID := "plate_sort"

## 一局多长（秒）——用户要求"在规定时间内"
const ROUND_SECONDS := 60.0
## 队列里始终维持几位同学（队首那位就是当前要处理的那张单子）
const QUEUE_SIZE := 5
## 出题上限：正常手速玩不完（玩不完 = 结束时按完成数结算）
const ORDER_POOL := 60
## 出题种子：固定种子 → 走查可重放（同一局永远同一串单子）
const DEFAULT_SEED := 20260919

## 动作：回收（同学拿着吃完的盘子来倒）/ 出餐（同学空手来取干净盘）
const MODE_COLLECT := "collect"
const MODE_SERVE := "serve"

const MODE_NAMES := {
	MODE_COLLECT: "回收（倒盘子）",
	MODE_SERVE: "出餐（取盘子）",
}
## 动作按钮的顺序（也决定数字键 1/2 分别是什么）
const MODES: Array[String] = [MODE_COLLECT, MODE_SERVE]

## 判定阶段：动作 → 颜色 → 形状（每一步都要对）
const STEP_MODE := "mode"
const STEP_COLOR := "color"
const STEP_SHAPE := "shape"

## 选错一次扣多少完成数（用户要求"减少正确总数"；不扣成负数）
const PENALTY := 1

var _active := false
var _job_id := ""
var _spot_id := ""
var _rng := RandomNumberGenerator.new()

var _completed := 0
var _mistakes := 0
var _time_left := 0.0
var _order_index := 0
var _orders: Array[Dictionary] = []     ## 整局的单子（可重放）
var _queue: Array[Dictionary] = []      ## 当前排队的同学（队首 = 正在处理）
var _step := STEP_MODE                  ## 当前判到哪一步
var _picked_color := ""                 ## 颜色那步选中的（选中后才允许选形状）

## 桶的顺序（每次处理完一张单子就洗牌）。存的是颜色/形状 id，UI 按它摆按钮。
var _color_order: Array[String] = []
var _shape_order: Array[String] = []
var _color_bins: Array[Button] = []
var _shape_bins: Array[Button] = []
var _mode_buttons: Array[Button] = []

var _root: Control
var _dim: ColorRect
var _panel: PanelContainer
var _timer_label: Label
var _score_label: Label
var _rule_label: Label
var _queue_box: HBoxContainer
var _queue_slots: Array[PanelContainer] = []
var _plate_icon: TextureRect
var _plate_name: Label
var _color_box: HBoxContainer
var _shape_box: HBoxContainer
var _step_label: Label
var _status: Label
var _abandoned := false
var _last_outcome := ""     ## "settled" / "left" / ""（见 last_outcome()）


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 55          # 在 HUD（10）之上、背包（50）…暂停菜单（60）之下
	_build()
	visible = false
	set_process(false)


# ---------------------------------------------------------------- 对外接口

func is_active() -> bool:
	return _active


func game_id() -> String:
	return GAME_ID


## 开始一局。[param job_id] / [param spot_id] 只用于结算与记账，本文件不认识它们的内容。
## [param seed] 传 0 表示随机；走查传固定种子以便重放。
func start(job_id: String, spot_id: String, seed_value: int = 0) -> bool:
	if _active:
		return false
	_job_id = job_id
	_spot_id = spot_id
	_rng.seed = seed_value if seed_value != 0 else randi()
	_orders = _make_orders()
	_order_index = 0
	_completed = 0
	_mistakes = 0
	_abandoned = false
	_time_left = ROUND_SECONDS
	_reset_step()
	_queue.clear()
	for i in QUEUE_SIZE:
		_queue.append(_next_order())
	_shuffle_bins()
	_active = true
	visible = true
	_refresh_all()
	set_process(true)
	_focus_stage()
	return true


## 玩一局并等它结束（调用方只 await 这一个方法，不用自己接信号）。
## 返回 {"completed": int, "cents": int, "unlocked": bool}：
##   completed 完成个数（-1 = 没能开局，调用方应按"没有小游戏"处理）
##   cents     这趟拿到的钱（**已经记进钱包**；0 = 没结算）
##   unlocked  这一局是否是"正常玩完"（true 表示小游戏自己已经结算并给了钱）
##
## ⚠️ 为什么要把"信号"包成协程：`await signal` 只能拿到第一个参数，
##    而这里有两个（完成数、钱）。包一层是唯一能让调用方拿到完整结果的写法。
func play(job_id: String, spot_id: String, seed_value: int = 0) -> Dictionary:
	if not start(job_id, spot_id, seed_value):
		return {"completed": -1, "cents": 0, "unlocked": false, "left": false}
	var result: Array = await finished
	return {"completed": int(result[0]), "cents": int(result[1]),
			"unlocked": not _abandoned, "left": _abandoned}


## 提前收摊（切场景/被中断时用）。**不结算** —— 半途退出不该发工钱。
func cancel() -> void:
	if not _active:
		return
	_abandoned = true
	_finish(false)


## 玩家主动退出（用户要求"小游戏应该有直接中途退出的选项"）：`Esc` 或点「离开洗碗间」。
## 与 `cancel()` 的区别只在语义（那是被系统打断），行为一样：
## **不发工钱**、也不占打工名额 —— 玩家可以重来一次（时间成本由 WorkSpot 照走）。
func abandon() -> bool:
	if not _active:
		return false
	_abandoned = true
	_finish(false)
	return true


# ---------------------------------------------------------------- 出题（排队）

## 固定种子生成整局单子（走查可重放；玩家那边用随机种子）
func _make_orders() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in ORDER_POOL:
		var needs := MODE_COLLECT if _rng.randf() < 0.5 else MODE_SERVE
		out.append({
			"needs": needs,
			"plate": PlateTypes.random_plate(_rng),
			"student": _random_student(needs),
		})
	return out


## 生成一位同学（外观 + 手里的盘子）。
## "取盘"的同学手里是**空的**（他来要盘子）；"倒盘"的同学手里拿着吃完的盘子。
func _random_student(needs: String) -> Dictionary:
	return {
		"skin": ["#f0d0b0", "#e0b48c", "#c89468", "#a8703f"][_rng.randi_range(0, 3)],
		"shirt": ["#5b7fb5", "#b5635b", "#5f9e6a", "#b59a5b", "#8a6fb0",
				"#4f8f9e", "#b0764f"][_rng.randi_range(0, 6)],
		"hair": ["#3a2b22", "#5a4433", "#22242c", "#7a5f3a"][_rng.randi_range(0, 3)],
		"needs": needs,
	}


## 取下一位（队尾补人）。单子用完了就循环复用，保证队列永远排得满。
func _next_order() -> Dictionary:
	if _orders.is_empty():
		_orders = _make_orders()
	var order: Dictionary = _orders[_order_index % _orders.size()]
	_order_index += 1
	return order


# ---------------------------------------------------------------- 判定（三步）

## 三步选对了吗：动作 + 颜色 + 形状都要对
func is_correct(mode: String, color_id: String, shape: String) -> bool:
	if _queue.is_empty():
		return false
	return String(_queue[0]["needs"]) == mode \
			and _wanted_color() == color_id and _wanted_shape() == shape


## 队首这位同学的盘子
func _current_plate() -> Dictionary:
	if _queue.is_empty():
		return {}
	return _queue[0]["plate"]


func _wanted_color() -> String:
	return String(_current_plate().get("color", ""))


func _wanted_shape() -> String:
	return String(_current_plate().get("shape", ""))


## 回到第一步（换人 / 开局时用）
func _reset_step() -> void:
	_step = STEP_MODE
	_picked_color = ""


## 第一步：动作（回收 / 出餐）。选错**立即扣分**，这位同学还得重新判一次。
func _choose_mode(mode: String) -> void:
	if not _active or _queue.is_empty():
		return
	var need := String(_queue[0]["needs"])
	if mode != need:
		_register_mistake("看错了：这位是「%s」，不是「%s」。" % [
				MODE_NAMES[need], MODE_NAMES[mode]])
		return
	_step = STEP_COLOR
	_picked_color = ""
	_set_status("对，%s。接着按**颜色**放进同色的抽屉。" % MODE_NAMES[mode])
	_refresh_all()


## 第二步：颜色。选错同样扣分 + 换人（不把玩家扣在同一个题上反复试）
func _choose_color(color_id: String) -> void:
	if not _active or _queue.is_empty():
		return
	if _step != STEP_COLOR:
		_set_status("先选「1 回收 / 2 出餐」，再挑颜色。")
		return
	if color_id != _wanted_color():
		_register_mistake("颜色错了：这只是%s盘。" % PlateTypes.color_name(_wanted_color()))
		return
	_picked_color = color_id
	_step = STEP_SHAPE
	_set_status("颜色对了。最后按**形状**放进对应的格子。")
	_refresh_all()


## 第三步：形状。三步全对才算完成一个。
func _choose_shape(shape: String) -> void:
	if not _active or _queue.is_empty():
		return
	if _step != STEP_SHAPE:
		_set_status("先把颜色挑对（同色的抽屉），再挑形状。")
		return
	if shape != _wanted_shape():
		_register_mistake("形状错了：这只是%s。" % PlateTypes.shape_name(_wanted_shape()))
		return
	_completed += 1
	UiKit.click_sfx()
	_advance_student()


## 记一次失误：完成数 -1（最低 0）+ 换一位同学 + 洗牌桶位。
##
## 为什么错了就换人（而不是"同一位继续"）：用户要求"选错了应该有惩罚，减少正确总数"，
## 并且"每次选后随机刷新顺序" —— 换人 + 洗牌同时满足这两条，也避免玩家靠位置硬记。
func _register_mistake(message: String) -> void:
	_mistakes += 1
	_completed = maxi(0, _completed - PENALTY)
	_set_status("%s（完成 -%d，换一位同学）" % [message, PENALTY])
	_advance_student()


## 服务完一位：队列前进一位，队尾补新人，回到第一步并洗牌
func _advance_student() -> void:
	_queue.remove_at(0)
	_queue.append(_next_order())
	_reset_step()
	_shuffle_bins()
	_refresh_all()


## 洗牌桶位（Fisher–Yates；用本局的 rng，走查里可重放）。
## 颜色桶与形状桶**各洗各的**：用户要求"选项位置不固定，每次选后随机刷新顺序"。
func _shuffle_bins() -> void:
	_color_order = _shuffled(PlateTypes.COLORS)
	_shape_order = _shuffled(PlateTypes.SHAPES)
	_layout_bins()


func _shuffled(source: Array[String]) -> Array[String]:
	var out: Array[String] = source.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


# ---------------------------------------------------------------- 组装界面

func _build() -> void:
	# 用 CanvasLayer 下的一个铺满视口的 Control 当舞台：
	# UiKit 的显式摆位对"代码创建的 Control"才可靠（锚点预设在 Node2D 场景根下不生效）
	_root = Control.new()
	_root.name = "Stage"
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.05, 0.86)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel",
			UiKit.panel_style(Color(0.06, 0.07, 0.12, 0.98), Palette.UI_BORDER, 3, 6))
	_root.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)

	var title := UiKit.make_title("洗碗间 · 盘子分类", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 30)
	_score_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.70))
	_score_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_score_label)

	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 34)
	_timer_label.add_theme_color_override("font_color", Color(0.98, 0.72, 0.42))
	_timer_label.custom_minimum_size = Vector2(170.0, 0.0)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_timer_label)

	_rule_label = Label.new()
	_rule_label.add_theme_font_size_override("font_size", 24)
	_rule_label.add_theme_color_override("font_color", Palette.UI_DIM)
	_rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_rule_label)

	# 排队的同学（队首 = 正在处理的那位）
	_queue_box = HBoxContainer.new()
	_queue_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_queue_box.add_theme_constant_override("separation", 10)
	column.add_child(_queue_box)
	for i in QUEUE_SIZE:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(126.0, 138.0)
		slot.add_theme_stylebox_override("panel",
				UiKit.panel_style(Color(0.09, 0.10, 0.16, 0.95), Color(0.32, 0.32, 0.38), 2, 4))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		slot.add_child(box)
		box.add_child(_make_slot_icon())
		var label := Label.new()
		label.name = "Label"
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", Palette.UI_TEXT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(112.0, 40.0)
		box.add_child(label)
		_queue_box.add_child(slot)
		_queue_slots.append(slot)

	# 窗口上的盘子
	var stage_panel := PanelContainer.new()
	stage_panel.add_theme_stylebox_override("panel",
			UiKit.panel_style(Color(0.10, 0.11, 0.17, 0.95), Color(0.35, 0.35, 0.42), 2, 4))
	column.add_child(stage_panel)

	var stage_box := VBoxContainer.new()
	stage_box.add_theme_constant_override("separation", 6)
	stage_panel.add_child(stage_box)

	_plate_icon = TextureRect.new()
	_plate_icon.custom_minimum_size = Vector2(112.0, 112.0)
	_plate_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_plate_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage_box.add_child(_plate_icon)

	_plate_name = Label.new()
	_plate_name.add_theme_font_size_override("font_size", 26)
	_plate_name.add_theme_color_override("font_color", Palette.UI_TEXT)
	_plate_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_box.add_child(_plate_name)

	# 第一步：倒 / 取
	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 18)
	column.add_child(mode_row)
	for i in MODES.size():
		var mode: String = MODES[i]
		var b := Button.new()
		b.name = "Mode_%s" % mode
		b.text = "%d　%s" % [i + 1, MODE_NAMES[mode]]
		b.custom_minimum_size = Vector2(330.0, 66.0)
		UiKit.style_button(b)
		b.pressed.connect(func() -> void: _choose_mode(mode))
		mode_row.add_child(b)
		_mode_buttons.append(b)

	# 当前该做哪一步（三步判定要有明确的路标，否则玩家不知道下一步点什么）
	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 24)
	_step_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62))
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_step_label)

	# 第二步：四个颜色抽屉（顺序每次洗牌）
	_color_box = HBoxContainer.new()
	_color_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_color_box.add_theme_constant_override("separation", 12)
	column.add_child(_color_box)

	# 第三步：五个形状格子（顺序每次洗牌）
	_shape_box = HBoxContainer.new()
	_shape_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_shape_box.add_theme_constant_override("separation", 12)
	column.add_child(_shape_box)

	# 底部：状态 + 中途退出（用户要求"小游戏应该有直接中途退出的选项"）
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", Palette.UI_DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status)

	var leave := Button.new()
	leave.name = "Leave"
	leave.text = "离开洗碗间（Esc）"
	leave.custom_minimum_size = Vector2(280.0, 56.0)
	UiKit.style_button(leave)
	leave.pressed.connect(func() -> void: abandon())
	footer.add_child(leave)

	get_viewport().size_changed.connect(_relayout)
	_relayout()


func _make_slot_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(112.0, 88.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon


## 桶按 `_color_order` / `_shape_order` 重新挂一遍（改顺序 = 先全摘下来再按新序 add_child）
func _layout_bins() -> void:
	if _color_box == null or _shape_box == null:
		return
	for b in _color_bins:
		if b.get_parent() != null:
			b.get_parent().remove_child(b)
	for b in _shape_bins:
		if b.get_parent() != null:
			b.get_parent().remove_child(b)
	_color_bins.clear()
	_shape_bins.clear()

	for i in _color_order.size():
		var color_id: String = _color_order[i]
		var b := Button.new()
		b.name = "Color_%s" % color_id
		b.text = "%d　%s抽屉" % [i + 1, PlateTypes.color_name(color_id)]
		b.custom_minimum_size = Vector2(216.0, 66.0)
		UiKit.style_button(b, PlateTypes.color_value(color_id))
		b.add_theme_color_override("font_color", PlateTypes.color_value(color_id).lightened(0.45))
		b.pressed.connect(func() -> void: _choose_color(color_id))
		_color_box.add_child(b)
		_color_bins.append(b)

	for i in _shape_order.size():
		var shape: String = _shape_order[i]
		var b := Button.new()
		b.name = "Shape_%s" % shape
		b.text = "%d　%s格" % [i + 1, PlateTypes.shape_name(shape)]
		b.custom_minimum_size = Vector2(174.0, 66.0)
		UiKit.style_button(b)
		b.pressed.connect(func() -> void: _choose_shape(shape))
		_shape_box.add_child(b)
		_shape_bins.append(b)


func _relayout() -> void:
	var tree := get_tree()
	if tree == null or _root == null:
		return
	var view := tree.root.get_visible_rect().size
	var panel_size := Vector2(1160.0, 900.0) * (view.x / 1920.0)
	UiKit.place(_root, Rect2(Vector2.ZERO, view))
	UiKit.place(_dim, Rect2(Vector2.ZERO, view))
	UiKit.place(_panel, Rect2(view * 0.5 - panel_size * 0.5, panel_size))


func _focus_stage() -> void:
	if not _mode_buttons.is_empty():
		_mode_buttons[0].grab_focus()


# ---------------------------------------------------------------- 刷新界面

func _refresh_all() -> void:
	if _score_label != null:
		_score_label.text = "完成 %d　·　放错 %d" % [_completed, _mistakes]
	if _timer_label != null:
		_timer_label.text = "剩余 %.1f 秒" % _time_left
	if _rule_label != null:
		_rule_label.text = "三步：1 倒盘 / 2 取盘 → 同色抽屉 → 同形状格子（每步的选项顺序都会变）"
	if _step_label != null:
		_step_label.text = "现在这一步：%s" % _step_hint()
	_refresh_queue()
	_refresh_plate()
	_refresh_steps()


## 当前该做哪一步的提示（三步判定的路标）
func _step_hint() -> String:
	match _step:
		STEP_COLOR:
			return "② 颜色 —— 这只盘子是%s" % PlateTypes.color_name(_wanted_color())
		STEP_SHAPE:
			return "③ 形状 —— 这只盘子是%s" % PlateTypes.shape_name(_wanted_shape())
		_:
			return "① 动作 —— 这位同学是来倒盘还是来取盘？"


## 高亮"当前该点的那一组"按钮，并把不该点的那一组按暗
func _refresh_steps() -> void:
	for i in _color_bins.size():
		_color_bins[i].modulate = Color.WHITE if _step == STEP_COLOR else Color(0.55, 0.55, 0.6)
	for i in _shape_bins.size():
		_shape_bins[i].modulate = Color.WHITE if _step == STEP_SHAPE else Color(0.55, 0.55, 0.6)
	for i in _mode_buttons.size():
		_mode_buttons[i].modulate = Color.WHITE if _step == STEP_MODE else Color(0.55, 0.55, 0.6)


## 队列：队首高亮 + 每位的"来意"和盘子
func _refresh_queue() -> void:
	for i in _queue_slots.size():
		var slot := _queue_slots[i]
		var icon := slot.find_child("Icon", true, false) as TextureRect
		var label := slot.find_child("Label", true, false) as Label
		if i >= _queue.size():
			if icon != null:
				icon.texture = null
			if label != null:
				label.text = "—"
			continue
		var order: Dictionary = _queue[i]
		var plate: Dictionary = order["plate"]
		var needs := String(order["needs"])
		if icon != null:
			icon.texture = _student_texture(order)
		if label != null:
			if needs == MODE_COLLECT:
				label.text = "来倒盘\n%s" % PlateTypes.plate_label(plate)
			else:
				label.text = "来取盘\n要%s" % PlateTypes.shape_name(String(plate["shape"]))
		var style := UiKit.panel_style(
				Color(0.16, 0.18, 0.26, 0.98) if i == 0 else Color(0.09, 0.10, 0.16, 0.95),
				Color(1.0, 0.86, 0.42) if i == 0 else Color(0.32, 0.32, 0.38), 3 if i == 0 else 2, 4)
		slot.add_theme_stylebox_override("panel", style)


func _refresh_plate() -> void:
	var plate := _current_plate()
	if _plate_name == null or plate.is_empty():
		return
	_plate_name.text = "窗口上：%s" % PlateTypes.plate_label(plate)
	if _plate_icon != null:
		_plate_icon.texture = PlateTypes.texture_for(
				String(plate["color"]), String(plate["shape"]))
	# 选中颜色之后把它标出来（第三步只剩形状，玩家需要看到自己已经定了颜色）
	for i in _color_bins.size():
		var color_id := String(_color_bins[i].name).trim_prefix("Color_")
		var chosen := _picked_color != "" and color_id == _picked_color
		_color_bins[i].add_theme_stylebox_override("normal", UiKit.button_style(
				Color(0.20, 0.34, 0.24, 0.98) if chosen else Color(0.13, 0.14, 0.20, 0.96),
				Color(0.55, 0.90, 0.60) if chosen else Color(0.42, 0.42, 0.40)))


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


## 画一位同学（临时叠层的小立绘：头 + 身体 + 手里的盘子）。
## "取盘"的同学手里是空的 —— 这正是玩家要判断的信息，所以必须画出来。
func _student_texture(order: Dictionary) -> Texture2D:
	var needs := String(order["needs"])
	var plate: Dictionary = order["plate"]
	# 外观存在 order["student"] 里（"来意"与"长相"分开：换外观不该影响判定）
	var student: Dictionary = order["student"]
	var key := "student_%s_%s_%s_%s" % [needs, String(student["skin"]), String(student["shirt"]),
			String(plate["color"]) if needs == MODE_COLLECT else "none"]
	var cached := PlateTypes.cached_texture(key)
	if cached != null:
		return cached
	var img := Image.create(96, 120, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin := Color(String(student["skin"]))
	var shirt := Color(String(student["shirt"]))
	var hair := Color(String(student["hair"]))
	PlateTypes.fill_rect(img, 22, 106, 52, 10, Color(0, 0, 0, 0.22))     # 影子
	PlateTypes.fill_rect(img, 26, 58, 44, 50, shirt)                     # 身体
	PlateTypes.fill_rect(img, 26, 58, 44, 14, shirt.darkened(0.25))      # 衣领阴影
	PlateTypes.fill_circle(img, 48, 36, 20, skin)                        # 头
	PlateTypes.fill_rect(img, 28, 20, 40, 14, hair)                      # 头发
	PlateTypes.fill_circle(img, 42, 38, 3, Color("#2a2620"))             # 眼睛
	PlateTypes.fill_circle(img, 56, 38, 3, Color("#2a2620"))
	if needs == MODE_COLLECT:
		# 手里端着一只吃过的盘子（脏盘：颜色压暗）
		var dirty := PlateTypes.color_value(String(plate["color"])).darkened(0.35)
		PlateTypes.fill_rect(img, 30, 78, 36, 10, dirty)
		PlateTypes.fill_rect(img, 30, 78, 36, 3, dirty.lightened(0.25))
	else:
		# 空手来取盘：把两只手画出来，强调"他手里什么都没有"
		PlateTypes.fill_circle(img, 26, 96, 6, skin)
		PlateTypes.fill_circle(img, 70, 96, 6, skin)
	var tex := ImageTexture.create_from_image(img)
	PlateTypes.cache_texture(key, tex)
	return tex


# ---------------------------------------------------------------- 计时与收尾

func _process(delta: float) -> void:
	if not _active:
		return
	_time_left = maxf(0.0, _time_left - delta)
	_refresh_all()
	if _time_left <= 0.0:
		_finish(true)


## 收尾：[param settle] = true 表示"正常玩完要结算"，false = 提前退出（不发工钱）。
func _finish(settle: bool) -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	visible = false
	_queue.clear()
	_reset_step()

	var cents := 0
	var outcome := ""
	if settle and not _abandoned and _job_id != "":
		# Currency.wage_for(job_id, 完成数) = 底薪 + 奖励档 + 背包加成（封顶）
		cents = Currency.wage_for(_job_id, _completed)
		# ⚠️ 记账要用**开工时的时段**：这里先结算、再推进时间（由 WorkSpot 负责推进）
		Currency.settle_work(_spot_id, cents)
		outcome = "settled"
	elif _abandoned:
		outcome = "left"
	finished.emit(_completed, cents)
	_last_outcome = outcome
	if settle and not _abandoned:
		_focus_stage()
	# 收尾的那句话交给调用方（WorkSpot）去播 —— 它才知道这个岗位叫什么


## 上一局是怎么结束的："settled"（正常结算）/ "left"（玩家中途退出）/ ""（还没玩过）
func last_outcome() -> String:
	return _last_outcome


## 结算文案（WorkSpot 在场景里播；放这里是因为分档规则属于小游戏）
## [param completed] / [param cents] 由调用方传**这一局的结果**。
## ⚠️ 不要在这个函数里读 `_completed`：收尾时它可能已经被下一局/调试接口改过，
##    那时总结会显示错的数字（走查里一度看到"分完 5 只"和"成绩 0 个"对不上）。
func result_lines(completed: int, cents: int) -> Array:
	return [
		{"speaker": "", "text": "一小时到。你分完 %d 只盘子，看错/放错 %d 次。" % [
			completed, _mistakes]},
		{"speaker": "", "text": "成绩：%s" % WorkDb.tier_line(completed)},
		{"speaker": "", "text": "阿姨在小票背面记了一笔，数出 %s 块钱。" % Currency.format_cents(cents)},
	]


## 玩家**中途退出**时的文案。
##
## ⚠️ 用户 2026-09-20："干活退出也算做了一次，时间应该调到 13:30" ——
##    所以这里**不再说"没拿到钱就能再来"**：那一小时已经过去了、这个时段也占掉了。
##    （占用与走时间都在 `WorkSpot.start_shift()` 里做，本函数只管文案。）
func left_lines(completed: int) -> Array:
	return [
		{"speaker": "", "text": "你把手套摘了，跟阿姨说今天先到这儿。"},
		{"speaker": "收银台后的阿姨", "text": "行。你分完 %d 只 —— 不过钱得整趟干完才结。" % completed,
				"emotion": "见怪不怪"},
		{"speaker": "周明远（内心）",
			"text": "（这一趟算白干了，钱没拿到，一个钟头倒是搭进去了。）", "emotion": "讪讪"},
	]


# ---------------------------------------------------------------- 走查 / 调试接口

## 直接"三步全对一次"或"错一步"，跳过鼠标键盘的不确定性
func debug_answer(correct: bool) -> bool:
	if not _active or _queue.is_empty():
		return false
	var need := String(_queue[0]["needs"])
	if correct:
		_choose_mode(need)
		_choose_color(_wanted_color())
		_choose_shape(_wanted_shape())
		return true
	# 错法有三种（动作错 / 颜色错 / 形状错），随机挑一种，保证三条判定都被覆盖到
	var roll := _rng.randf()
	if roll < 0.34:
		_choose_mode(MODE_SERVE if need == MODE_COLLECT else MODE_COLLECT)
	elif roll < 0.67:
		_choose_mode(need)
		_choose_color(_wrong_color())
	else:
		_choose_mode(need)
		_choose_color(_wanted_color())
		_choose_shape(_wrong_shape())
	return true


func _wrong_color() -> String:
	for color_id in PlateTypes.COLORS:
		if color_id != _wanted_color():
			return color_id
	return PlateTypes.COLORS[0]


func _wrong_shape() -> String:
	for shape in PlateTypes.SHAPES:
		if shape != _wanted_shape():
			return shape
	return PlateTypes.SHAPES[0]


## 供走查/调试：分别指定动作 / 颜色 / 形状（走查要逐条验证三步判定）
func debug_choose_mode(mode: String) -> void:
	_choose_mode(mode)


func debug_choose_color(color_id: String) -> void:
	_choose_color(color_id)


func debug_choose_shape(shape: String) -> void:
	_choose_shape(shape)


## 供走查/调试：直接把完成数设成某个值（验证"扣分不会扣成负数"用）
func debug_set_score_for_test(value: int) -> void:
	_completed = maxi(0, value)
	_refresh_all()


## 供走查/调试：把剩余时间调小（不用真的等 60 秒）
func debug_set_time_left(seconds: float) -> void:
	_time_left = maxf(0.0, seconds)
	_refresh_all()


func debug_state() -> Dictionary:
	var head: Dictionary = _queue[0] if not _queue.is_empty() else {}
	return {
		"active": _active,
		"completed": _completed,
		"mistakes": _mistakes,
		"time_left": _time_left,
		"needs": String(head.get("needs", "")),
		"shape": _wanted_shape(),
		"plate_color": _wanted_color(),
		"step": _step,
		"picked_color": _picked_color,
		"color_order": _color_order.duplicate(),
		"shape_order": _shape_order.duplicate(),
		"queue_size": _queue.size(),
		"outcome": _last_outcome,
	}


func completed_count() -> int:
	return _completed


func mistakes_count() -> int:
	return _mistakes


func time_left() -> float:
	return _time_left


## 场上有几个颜色抽屉 / 几个形状格子（走查断言"与词表一一对应"用）
func color_bin_count() -> int:
	return _color_bins.size()


func shape_bin_count() -> int:
	return _shape_bins.size()


## 抽屉/格子当前的左右顺序（走查断言"每次选后随机刷新"用）
func color_order() -> Array[String]:
	return _color_order.duplicate()


func shape_order() -> Array[String]:
	return _shape_order.duplicate()


## 当前判到第几步（走查用）
func current_step() -> String:
	return _step


## 队首这位同学是来倒盘还是取盘（走查用）
func current_need() -> String:
	return String(_queue[0]["needs"]) if not _queue.is_empty() else ""


## 队首这位同学要的盘子颜色 / 形状（走查用）
func current_color() -> String:
	return _wanted_color()


func current_shape() -> String:
	return _wanted_shape()


# ---------------------------------------------------------------- 输入

func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		# Esc = 直接退出（用户要求"小游戏应该有直接中途退出的选项"）
		if k.physical_keycode == KEY_ESCAPE:
			abandon()
			get_viewport().set_input_as_handled()
			return
		var index := _digit_index(k.physical_keycode)
		if index < 0:
			return
		# 数字键的含义**跟着当前步骤走**（选项顺序每次洗牌，所以按下标取）
		match _step:
			STEP_MODE:
				if index < MODES.size():
					_choose_mode(MODES[index])
					get_viewport().set_input_as_handled()
			STEP_COLOR:
				if index < _color_order.size():
					_choose_color(_color_order[index])
					get_viewport().set_input_as_handled()
			STEP_SHAPE:
				if index < _shape_order.size():
					_choose_shape(_shape_order[index])
					get_viewport().set_input_as_handled()


## 数字键（含小键盘）-> 0 起的序号；不是数字键返回 -1
func _digit_index(code: int) -> int:
	match code:
		KEY_1, KEY_KP_1:
			return 0
		KEY_2, KEY_KP_2:
			return 1
		KEY_3, KEY_KP_3:
			return 2
		KEY_4, KEY_KP_4:
			return 3
		KEY_5, KEY_KP_5:
			return 4
	return -1
