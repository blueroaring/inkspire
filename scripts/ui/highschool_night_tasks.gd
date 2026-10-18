extends CanvasLayer
## 课间教程结束后，白天也可查看任务及所需线索。
const Data := preload("res://scripts/data/highschool_night_task_data.gd")
const PANEL_SIZE := Vector2(1540, 900)
const INK := Color("#394354")
const GOLD := Color("#bca574")
var panel: Panel
var dim: ColorRect
var entries_box: VBoxContainer
var count_label: Label
var close_button: Button
var detail_title: Label
var detail_summary: Label
var detail_reward: Label
var detail_duration: Label
var detail_clues: Label
var _selected_id := ""
var _rows: Dictionary = {}
var _open := false
var _focus_before: Control
var _location_before := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 56
	dim = ColorRect.new()
	dim.color = Color(0.035, 0.05, 0.09, 0.84)
	add_child(dim)
	panel = Panel.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color("#e9e5dc"), GOLD, 2, 6))
	add_child(panel)
	_place(_label("任务  /  夜间委托", 34, INK), panel, Rect2(42, 26, 1130, 52))
	close_button = Button.new()
	close_button.text = "关闭  J / Esc"
	UiKit.style_button(close_button)
	close_button.pressed.connect(close)
	_place(close_button, panel, Rect2(1262, 28, 232, 54))
	var catalog := Panel.new()
	catalog.add_theme_stylebox_override("panel", UiKit.panel_style(Color("#344052"), Color("#344052"), 0, 4))
	_place(catalog, panel, Rect2(28, 110, 546, 722))
	count_label = _label("", 23, Color("#e7d5ad"))
	_place(count_label, catalog, Rect2(24, 20, 498, 40))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_place(scroll, catalog, Rect2(16, 76, 514, 626))
	entries_box = VBoxContainer.new()
	entries_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_box.add_theme_constant_override("separation", 12)
	scroll.add_child(entries_box)
	var details := Panel.new()
	details.name = "TaskDetails"
	details.add_theme_stylebox_override("panel", UiKit.panel_style(Color("#f4f0e7"), Color("#d5ccb8"), 1, 4))
	_place(details, panel, Rect2(598, 110, 914, 722))
	_place(_label("夜间任务  ·  校园线索", 21, Color("#8b7752")), details, Rect2(36, 26, 838, 36))
	detail_title = _label("", 36, INK)
	_place(detail_title, details, Rect2(36, 86, 838, 100))
	_place(_label("任务简介", 24, Color("#8b7752")), details, Rect2(36, 218, 838, 40))
	detail_summary = _label("", 25, INK)
	_place(detail_summary, details, Rect2(36, 272, 838, 124))
	detail_clues = _label("", 23, INK)
	_place(detail_clues, details, Rect2(36, 402, 838, 76))
	var line := ColorRect.new()
	line.color = Color("#d5ccb8")
	_place(line, details, Rect2(36, 482, 838, 2))
	detail_reward = _label("", 24, INK)
	_place(detail_reward, details, Rect2(36, 514, 838, 42))
	detail_duration = _label("", 24, INK)
	_place(detail_duration, details, Rect2(36, 570, 838, 42))
	_place(_label("任务内容暂未开放", 22, Color("#8b7752")), details, Rect2(36, 654, 838, 36))
	_place(_label("选择任务查看所需线索  ·  白天收集线索，夜间探索委托", 21, INK), panel, Rect2(42, 850, 1400, 32))
	get_viewport().size_changed.connect(_layout)
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.state_replaced.connect(_on_state_replaced)
	GameFlow.phase_changed.connect(func(_phase: String) -> void:
		if _open and not available(): close())
	visible = false
	_layout()
	Data.sync_accepted()

func _place(control: Control, parent: Node, rect: Rect2) -> void:
	parent.add_child(control)
	control.position = rect.position
	control.size = rect.size

func _label(text: String, font_size: int, color: Color = Color("#e5eaf0")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	dim.size = screen
	var factor := minf(1.0, minf((screen.x - 48) / PANEL_SIZE.x, (screen.y - 48) / PANEL_SIZE.y))
	panel.size = PANEL_SIZE
	panel.scale = Vector2.ONE * factor
	panel.position = (screen - PANEL_SIZE * factor) * 0.5

func available() -> bool:
	return GameFlow.has_flag(HighschoolRewindData.FLAG_TUTORIAL_SEEN) \
		and (GameState.phase == HighschoolData.PHASE_NIGHT or GameFlow.has_flag(HighschoolFirstPeriodData.FLAG_BREAK_TUTORIAL)) \
		and GameState.chapter >= 1 and GameState.location.begins_with("highschool.") \
		and GameState.location not in ["highschool.abandoned", "highschool.gate"]

func can_open() -> bool:
	if not available() or get_tree().paused or SceneRouter.is_busy(): return false
	if DialogueBox.is_active() or Backpack.is_open() or Shop.is_open() or PlateGame.is_active(): return false
	if get_tree().has_group("school_document"): return false
	var player := get_tree().get_first_node_in_group("player")
	return (player != null and player.can_move) or get_tree().has_group("rewind_bag_access") or get_tree().has_group("night_task_access")

func _catalog() -> Array[Dictionary]:
	if not GameFlow.has_flag(HighschoolFirstPeriodData.FLAG_BREAK_TUTORIAL): return Data.entries()
	var result: Array[Dictionary] = []
	for task: Dictionary in Data.TASKS: result.append(task.duplicate(true))
	return result

func is_open() -> bool:
	return _open

func open() -> void:
	if _open or not can_open(): return
	Data.sync_accepted()
	_refresh()
	_focus_before = get_viewport().gui_get_focus_owner()
	_location_before = GameState.location
	_open = true
	visible = true
	get_tree().paused = true
	_layout()
	if _rows.has(_selected_id): _rows[_selected_id].grab_focus()
	else: close_button.grab_focus()

func close() -> void:
	if not _open: return
	_open = false
	visible = false
	get_tree().paused = false
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree(): _focus_before.grab_focus()

func _refresh() -> void:
	for child in entries_box.get_children():
		entries_box.remove_child(child)
		child.queue_free()
	_rows.clear()
	var tasks := _catalog()
	count_label.text = "任务目录  /  %02d    已接取 %02d" % [tasks.size(), Data.entries().size()]
	if tasks.is_empty():
		_selected_id = ""
		var empty := _label("暂无夜间任务\n\n白天留意校园线索", 25, Color("#c4cedc"))
		empty.custom_minimum_size.y = 220
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		entries_box.add_child(empty)
		detail_title.text = "等待新的线索"
		detail_summary.text = "白天与同学交谈、探索校园，发现的线索会记录在这里。"
		detail_reward.text = "任务奖励：—"
		detail_duration.text = "任务耗时：—"
		detail_clues.text = "所需线索：尚未发现"
		return
	for task: Dictionary in tasks:
		var row := Button.new()
		row.name = task.id
		row.text = "◇  " + task.name + ("\n已接取" if Data.eligible(task) else "\n待收集线索")
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(0, 88)
		row.add_theme_font_size_override("font_size", 25)
		row.pressed.connect(_select_task.bind(String(task.id)))
		row.focus_entered.connect(_select_task.bind(String(task.id)))
		entries_box.add_child(row)
		_rows[task.id] = row
	if not _rows.has(_selected_id): _selected_id = tasks[0].id
	_select_task(_selected_id)

func _select_task(id: String) -> void:
	_selected_id = id
	for row_id: String in _rows:
		var row: Button = _rows[row_id]
		var selected := row_id == id
		row.add_theme_stylebox_override("normal", UiKit.panel_style(Color("#e8dfcd") if selected else Color("#414e62"), GOLD if selected else Color("#596579"), 2 if selected else 1, 3))
		row.add_theme_stylebox_override("hover", UiKit.panel_style(Color("#dcd3bf"), GOLD, 2, 3))
		row.add_theme_stylebox_override("focus", UiKit.panel_style(Color.TRANSPARENT, Color("#f4dea4"), 2, 3))
		row.add_theme_color_override("font_color", INK if selected else Color("#eee9df"))
		row.add_theme_color_override("font_hover_color", INK)
	for task: Dictionary in _catalog():
		if task.id != id: continue
		detail_title.text = task.name
		detail_summary.text = task.summary if task.summary != "" else ("已获得所需线索，任务已记录。后续内容待开放。" if Data.eligible(task) else "收集下列线索后可接取这个夜间任务。")
		var requirements: PackedStringArray = []
		for clue: String in task.requires:
			requirements.append(("已获得 · " if GameFlow.has_flag(Data.CLUE_PREFIX + clue) else "未获得 · ") + String(Data.CLUE_NAMES.get(clue, clue)))
		detail_clues.text = "所需线索：\n" + "\n".join(requirements)
		detail_reward.text = "任务奖励：" + task.reward
		detail_duration.text = "任务耗时：" + ("%d 分钟" % int(task.minutes) if int(task.minutes) >= 0 else "待定")
		break

func _on_flag_changed(flag: String) -> void:
	if flag.begins_with(Data.CLUE_PREFIX) or flag == HighschoolRewindData.FLAG_TUTORIAL_SEEN:
		var added := Data.sync_accepted()
		if not added.is_empty() and available():
			for hud in get_tree().get_nodes_in_group("overworld_hud"):
				hud.show_toast("已接取夜间任务 · J 查看", 4.0)
	if flag == Data.ACCEPTED and _open: _refresh()

func _on_state_replaced() -> void:
	close()
	_selected_id = ""
	Data.sync_accepted()

func _process(_delta: float) -> void:
	if _open and (GameState.location != _location_before or not available()): close()

func _input(event: InputEvent) -> void:
	if event.is_echo(): return
	if event.is_action_pressed("night_tasks") and (_open or can_open()):
		if _open: close()
		else: open()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
