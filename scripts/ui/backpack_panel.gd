extends CanvasLayer
## 背包面板（自动加载单例 Backpack）
##
## 定位：**只做"看背包 + 用/丢"这一件事**的界面。
##   · 数量与归属  -> `Inventory` 单例（它才认识 GameState）
##   · 道具是什么  -> `ItemDb`（纯数据）
##   · 用了会怎样  -> `ItemActions`
## 所以这个文件只处理按钮、焦点和摆放，换 UI 风格不需要动任何游戏逻辑。
##
## 开关：`B` 键（输入映射里的 `backpack`），或 ESC 关闭。
## 大学与高中各一册背包，面板标题会写明当前是哪一册（需求 01_GOALS 第 3 条）。
##
## ⚠️ 摆放全部走 UiKit 显式摆位：本项目场景根是 Node2D，锚点预设对代码创建的
##    控件不生效（见 UiKit.fill_viewport 的注释），此前踩过"控件全堆在左上角"。

const PANEL_SIZE := Vector2(1400.0, 820.0)
const LIST_SIZE := Vector2(840.0, 520.0)
const DETAIL_WIDTH := 460.0
const COLUMNS := 2

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _scope_label: Label
var _hint: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty: Label
var _detail_name: Label
var _detail_meta: Label
var _detail_desc: RichTextLabel
var _use_button: Button
var _drop_button: Button
var _status: Label

var _open := false
var _selected_id := ""
var _buttons: Dictionary = {}   ## 道具 id -> Button
var _item_target: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_build()
	visible = false
	Inventory.bag_changed.connect(_on_bag_changed)
	Currency.balance_changed.connect(_on_balance_changed)
	get_viewport().size_changed.connect(_relayout)
	_relayout()


# ---------------------------------------------------------------- 构建

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.84)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel",
			UiKit.panel_style(Color(0.05, 0.06, 0.11, 0.98), Palette.UI_BORDER, 3, 6))
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_panel.add_child(column)

	# 标题行
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)

	_title = UiKit.make_title("背包", 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(_title)

	_scope_label = Label.new()
	_scope_label.add_theme_font_size_override("font_size", 26)
	_scope_label.add_theme_color_override("font_color", Palette.UI_BORDER)
	_scope_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_scope_label)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	_hint = Label.new()
	_hint.text = "B / ESC 关闭　·　方向键选择　·　回车使用（钱不可使用/丢弃）"
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Palette.UI_DIM)
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_hint)

	# 主体：左列表 / 右详情
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var list_box := PanelContainer.new()
	list_box.custom_minimum_size = LIST_SIZE
	list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_box.add_theme_stylebox_override("panel",
			UiKit.panel_style(Color(0.08, 0.09, 0.14, 0.9), Color(0.30, 0.30, 0.36), 2, 4))
	body.add_child(list_box)

	# 滚动列表与"空背包"提示共用同一块地方（PanelContainer 会把子节点都铺满，
	# 所以两者重叠摆放、按需显示其中一个即可 —— 和 DialogueBox 的 BoxRoot 是同一招）
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_box.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_scroll.add_child(_grid)

	_empty = Label.new()
	_empty.text = "背包里空空的。"
	_empty.add_theme_font_size_override("font_size", 26)
	_empty.add_theme_color_override("font_color", Palette.UI_DIM)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_box.add_child(_empty)

	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(DETAIL_WIDTH, 0.0)
	detail.add_theme_constant_override("separation", 10)
	body.add_child(detail)

	var detail_panel := PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel",
			UiKit.panel_style(Color(0.09, 0.10, 0.16, 0.95), Color(0.35, 0.35, 0.42), 2, 4))
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(detail_panel)

	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 10)
	detail_panel.add_child(detail_box)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 32)
	_detail_name.add_theme_color_override("font_color", Palette.UI_TEXT)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_detail_name)

	_detail_meta = Label.new()
	_detail_meta.add_theme_font_size_override("font_size", 20)
	_detail_meta.add_theme_color_override("font_color", Palette.UI_BORDER)
	detail_box.add_child(_detail_meta)

	_detail_desc = RichTextLabel.new()
	_detail_desc.bbcode_enabled = true
	_detail_desc.fit_content = false
	_detail_desc.scroll_active = true
	_detail_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_desc.add_theme_font_size_override("normal_font_size", 24)
	_detail_desc.add_theme_color_override("default_color", Palette.UI_TEXT)
	detail_box.add_child(_detail_desc)

	_use_button = _make_action_button(detail, "使用", _on_use_pressed)
	_drop_button = _make_action_button(detail, "丢弃", _on_drop_pressed)
	_make_action_button(detail, "关闭", _on_close_pressed)

	# 底部状态行
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_color", Palette.UI_DIM)
	_status.text = "大学与高中的背包各自独立。"
	column.add_child(_status)


func _make_action_button(parent: Node, text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(DETAIL_WIDTH, 52)
	UiKit.style_button(b)
	b.pressed.connect(handler)
	parent.add_child(b)
	return b


func _relayout() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var view := tree.root.get_visible_rect().size
	var scale := view.x / 1920.0
	UiKit.place(_dim, Rect2(Vector2.ZERO, view))
	UiKit.place(_panel, Rect2(view * 0.5 - PANEL_SIZE * scale * 0.5, PANEL_SIZE * scale))


# ---------------------------------------------------------------- 开关

func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	_get_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	_item_target = Callable()

## 临时选择用于交互物的道具；关闭面板即取消，不改变普通道具使用逻辑。
func open_for_target(target: Callable) -> void:
	_item_target = target
	open()
	_refresh_detail()


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func _get_focus() -> void:
	_refresh()
	if not _buttons.is_empty():
		(_buttons[_buttons.keys()[0]] as Button).grab_focus()


# ---------------------------------------------------------------- 刷新

func _on_bag_changed(_scope: String) -> void:
	if _open:
		_refresh()


## 钱包余额变了也要重画：钱是背包里的一个条目（用户要求），
## 所以"在商店花掉 3 块"之后，背包里的钱数必须跟着变（面板开着时不刷新就会显示旧数字）。
func _on_balance_changed(_scope: String, _amount: int) -> void:
	if _open:
		_refresh()


## 背包里要显示的全部条目 = 真实道具 + 钱包（虚拟条目，数量实时取自 Currency）。
## 顺序：钱包排在**最前**（钱是最常看的那一条），其余按 Inventory.entries() 的稳定顺序。
func _visible_entries() -> Array:
	var out: Array = []
	var wallet_scope := Inventory.scope()
	out.append({"id": ItemDb.WALLET_ID, "count": Currency.amount(wallet_scope)})
	for entry_variant in Inventory.entries():
		out.append(entry_variant)
	return out


## 某一条当前的数量（钱包是实时的，普通道具读背包）
func _count_of(id: String) -> int:
	var virtual := ItemDb.virtual_count(id)
	return virtual if virtual >= 0 else Inventory.count(id)


func _refresh() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_buttons.clear()

	var entries := _visible_entries()
	var keep := _selected_id
	for entry in entries:
		var id := String(entry["id"])
		var amount := int(entry["count"])
		var b := Button.new()
		b.text = _entry_label(id, amount)
		b.custom_minimum_size = Vector2(390.0, 72.0)
		b.focus_mode = Control.FOCUS_ALL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var icon := ItemDb.icon(id)
		if icon != null:
			b.icon = icon
			b.expand_icon = true
		UiKit.style_button(b)
		b.pressed.connect(func() -> void: select(id))
		b.focus_entered.connect(func() -> void: select(id))
		_grid.add_child(b)
		_buttons[id] = b

	_empty.visible = false        # 钱包永远在，所以列表不会空
	_scroll.visible = true

	_title.text = "背包"
	_scope_label.text = "· %s" % Inventory.scope_name()

	if keep != "" and _buttons.has(keep):
		_selected_id = keep
	elif not entries.is_empty():
		_selected_id = String((entries[0] as Dictionary)["id"])
	else:
		_selected_id = ""
	_refresh_detail()


## 列表里那一行的文字。钱显示成"¥ 12.50"（人民币口径），其余显示"名字 ×数量"。
func _entry_label(id: String, amount: int) -> String:
	if ItemDb.is_wallet(id):
		return "%s　¥ %s" % [ItemDb.display_name(id), Currency.format_cents(amount)]
	return "%s ×%d" % [ItemDb.display_name(id), amount]


func _refresh_detail() -> void:
	var has_selection := _selected_id != "" and _buttons.has(_selected_id)
	if not has_selection:
		_detail_name.text = "—"
		_detail_meta.text = ""
		_detail_desc.text = "从左边选一件东西看看。"
		_use_button.disabled = true
		_drop_button.disabled = true
		return
	var id := _selected_id
	var virtual := ItemDb.is_virtual(id)
	_detail_name.text = ItemDb.display_name(id)
	var kind := ItemDb.kind_name(id)
	var scope := Inventory.scope_name(ItemDb.scope_of(id))
	var amount := _count_of(id)
	var amount_text := ("¥ %s" % Currency.format_cents(amount)) if ItemDb.is_wallet(id) else ("%d 个" % amount)
	_detail_meta.text = "%s　·　%s　·　默认属于%s背包" % [kind, amount_text, scope]
	_detail_desc.text = ItemDb.description(id)
	_detail_desc.scroll_to_line(0)
	# 钱不可"使用"也不可丢：按钮只对真实道具开放
	_use_button.disabled = virtual or (not _item_target.is_valid() and not ItemDb.is_usable(id))
	_drop_button.disabled = virtual or not ItemDb.can_drop(id)


# ---------------------------------------------------------------- 操作

## 选中一件道具（列表点击/焦点移动都会走这里）
func select(id: String) -> bool:
	if not _buttons.has(id):
		return false
	_selected_id = id
	_refresh_detail()
	return true


func selected_id() -> String:
	return _selected_id


func entry_count() -> int:
	return _buttons.size()


## 使用某件道具：**先关面板再播剧情**，否则对话会被面板压住看不见
func use_item(id: String) -> bool:
	if ItemDb.is_virtual(id):
		_set_status("「%s」不是能用掉的东西。" % ItemDb.display_name(id))
		return false
	if not Inventory.has(id):
		return false
	if _item_target.is_valid():
		var target := _item_target
		close()
		return bool(await target.call(id))
	if not ItemDb.is_usable(id):
		_set_status("「%s」现在用不了。" % ItemDb.display_name(id))
		return false
	close()
	var ok: bool = await Inventory.use(id)
	if not ok:
		_set_status("「%s」现在用不了。" % ItemDb.display_name(id))
	return ok


func use_selected() -> bool:
	return await use_item(_selected_id)


func drop_selected() -> bool:
	var id := _selected_id
	if id == "" or ItemDb.is_virtual(id) or not Inventory.has(id):
		return false
	if not ItemDb.can_drop(id):
		_set_status("「%s」是重要东西，不能丢。" % ItemDb.display_name(id))
		return false
	Inventory.remove(id, 1)
	_set_status("丢掉了「%s」×1。" % ItemDb.display_name(id))
	_refresh()
	return true


func _set_status(text: String) -> void:
	_status.text = text


func _on_use_pressed() -> void:
	UiKit.click_sfx()
	await use_selected()


func _on_drop_pressed() -> void:
	UiKit.click_sfx()
	drop_selected()


func _on_close_pressed() -> void:
	UiKit.click_sfx()
	close()


# ---------------------------------------------------------------- 对外查询 / 开发期接口

func current_scope() -> String:
	return Inventory.scope()


## 面板在屏幕上的实际矩形（版式断言用）
func panel_rect() -> Rect2:
	return Rect2(_panel.global_position, _panel.size) if _panel != null else Rect2()


func status_text() -> String:
	return _status.text if _status != null else ""


func debug_select(id: String) -> bool:
	return select(id)


func debug_select_index(index: int) -> bool:
	var keys := _buttons.keys()
	if index < 0 or index >= keys.size():
		return false
	return select(String(keys[index]))


func debug_use_selected() -> bool:
	return await use_selected()


## 钱的显示文案（走查断言"钱在背包里"用；没开面板也返回当前值）
func wallet_text() -> String:
	return "%s　¥ %s" % [ItemDb.display_name(ItemDb.WALLET_ID),
			Currency.format_cents(Currency.amount(Inventory.scope()))]


## 当前列表里的条目 id（走查断言用）
func entry_ids() -> Array[String]:
	var out: Array[String] = []
	for key in _buttons.keys():
		out.append(String(key))
	return out


## 这一条现在能不能用 / 能不能丢（走查断言"钱不可用不可丢"用）
func can_use(id: String) -> bool:
	return not ItemDb.is_virtual(id) and ItemDb.is_usable(id)


func can_drop(id: String) -> bool:
	return not ItemDb.is_virtual(id) and ItemDb.can_drop(id)


# ---------------------------------------------------------------- 输入

## 什么时候允许开背包：没有对话、没被暂停、且当前场景里真的有玩家
## （标题画面 / CG 里没有玩家，按 B 不该弹出背包）
func _can_open() -> bool:
	if get_tree().has_group("school_document"): return false
	if DialogueBox.is_active():
		return false
	if get_tree().paused:
		return false
	return get_tree().get_first_node_in_group("player") != null or get_tree().has_group("rewind_bag_access")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("backpack"):
		get_viewport().set_input_as_handled()
		if _open:
			close()
		elif _can_open():
			open()
		return
	if not _open:
		return
	# ESC 也能关（与暂停键是同一个物理键，但背着包时应该只关包，不弹暂停菜单）
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.physical_keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
