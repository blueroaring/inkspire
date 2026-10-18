extends Control
## Shared selector; physical card identity and selection order stay independent of art.
const THEME := preload("res://scripts/ui/battle_theme.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
var selected: Array = []
var current_options: Array = []
var signature := ""
var grid: GridContainer
var confirm: Button
var count_label: Label
var order_label: Label
var detail: Control

func _ready() -> void:
	THEME.apply(self)
	z_index = 95
	size = Vector2(1920, 1080)
	refresh()

func refresh() -> void:
	var choice: Dictionary = FightSystem.fc.choice
	if choice.is_empty():
		visible = false
		signature = ""
		if is_instance_valid(detail): detail.queue_free()
		return
	visible = true
	if choice.get("kind", "") == "painting":
		var paint_signature := "painting_" + str(choice.serial)
		if signature == paint_signature: return
		signature = paint_signature
		for child in get_children():
			remove_child(child)
			child.queue_free()
		add_child(preload("res://scripts/ui/fc_painting_panel.gd").new())
		return
	var next_signature := String(choice.title) + str((choice.options as Array).map(func(c: Dictionary) -> int: return int(c.uid)))
	if next_signature == signature: return
	signature = next_signature
	selected.clear()
	current_options = choice.options
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.045, 0.05, 0.44)
	shade.size = Vector2(1920, 1080)
	add_child(shade)
	var panel := V.panel(self, Rect2(286, 102, 1348, 876), THEME.INK, THEME.LINE, 6)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	V.panel(panel, Rect2(34, 30, 5, 102), V.GOLD, V.GOLD, 2)
	var title_parts := String(choice.title).split("：", true, 1)
	var placement: bool = not current_options.is_empty() and current_options[0].has("slot")
	var unit_choice: bool = not current_options.is_empty() and (current_options[0].has("ally") or current_options[0].has("enemy"))
	V.text(panel, "选择目标" if unit_choice else "选择位置" if placement else "安排牌序" if choice.ordered else "选择卡牌", Rect2(58, 26, 580, 32), 18, V.MUTED)
	V.text(panel, title_parts[0], Rect2(56, 61, 1120, 50), 34, THEME.TEXT).add_theme_font_override("font", THEME.HEADING)
	V.text(panel, title_parts[1] if title_parts.size() > 1 else "从下方选择目标", Rect2(56, 115, 1190, 34), 21, THEME.TEXT)
	V.text(panel, "左键选择目标" if unit_choice else "左键选择放入位置" if placement else "左键选择 · 右键详情", Rect2(930, 25, 378, 32), 18, V.MUTED)
	count_label = V.text(panel, "", Rect2(36, 156, 1240, 30), 19, THEME.BLUE)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(35, 196)
	scroll.size = Vector2(1280, 548)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = (6 if current_options.size() > 10 else 5) if placement else 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)
	for option in current_options:
		var button := V.tile(option)
		button.name = "Option_%d" % int(option.uid)
		button.pressed.connect(_toggle.bind(int(option.uid)))
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and option.has("skill_id"):
				if is_instance_valid(detail): detail.queue_free()
				detail = V.detail(self, option)
				button.accept_event()
		)
		grid.add_child(button)
	order_label = V.text(panel, "", Rect2(36, 770, 925, 66), 19, V.MUTED)
	order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm = Button.new()
	confirm.name = "ConfirmChoice"
	confirm.position = Vector2(998, 784)
	confirm.size = Vector2(314, 58)
	THEME.button(confirm, V.GOLD, true)
	confirm.add_theme_font_size_override("font_size", 24)
	confirm.add_theme_stylebox_override("normal", V.style(THEME.SELECTED, Color(V.GOLD, 0.6), 1, 5))
	confirm.add_theme_color_override("font_color", THEME.TEXT)
	confirm.pressed.connect(func() -> void: FightSystem.choose_cards(selected.duplicate()))
	panel.add_child(confirm)
	_update_selection()

func _toggle(uid: int) -> void:
	if selected.has(uid): selected.erase(uid)
	elif selected.size() < int(FightSystem.fc.choice.max): selected.append(uid)
	else: return
	AudioManager.play_card_select()
	_update_selection()

func _update_selection() -> void:
	var choice: Dictionary = FightSystem.fc.choice
	if choice.is_empty(): return
	var requirement := str(choice.min) if choice.min == choice.max else "%d–%d" % [choice.min, choice.max]
	var placement: bool = not current_options.is_empty() and current_options[0].has("slot")
	var unit_choice: bool = not current_options.is_empty() and (current_options[0].has("ally") or current_options[0].has("enemy"))
	count_label.text = "已选 %d / %s %s%s" % [selected.size(), requirement, "个目标" if unit_choice else "个位置" if placement else "张", " · 数字即结算顺序" if choice.ordered else ""]
	if not current_options.is_empty() and current_options[0].has("placement_count"):
		count_label.text += " · 首位 / 中位 / 末位按放入后的 %d 张手牌标记" % int(current_options[0].placement_count)
	confirm.text = "请先选择" if selected.size() < int(choice.min) else "确认选择" if not selected.is_empty() else "不选择，继续"
	confirm.disabled = selected.size() < int(choice.min)
	var names: Array[String] = []
	for uid in selected:
		for option in current_options:
			if int(option.uid) == int(uid): names.append(V.card_title(option) if option.has("skill_id") else String(option.get("label", "")))
	order_label.text = " → ".join(names) if choice.ordered and not names.is_empty() else "再次点击已选目标可取消选择" if unit_choice else "再次点击已选位置可取消选择" if placement else "再次点击已选卡牌可取消选择"
	for i in current_options.size():
		var option: Dictionary = current_options[i]
		V.select_tile(grid.get_child(i), option, selected.find(int(option.uid)), bool(choice.ordered))
