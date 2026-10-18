extends CanvasLayer
## 商店面板（自动加载单例 Shop）
##
## 定位：**只做"看货 + 买"这一件事**的界面。
##   · 卖什么、多少钱 -> `ShopDb`（纯数据）
##   · 钱够不够、扣钱 -> `Currency`
##   · 买到了什么     -> `Inventory`（买成功才 add，见 buy_selected 的次序注释）
## 所以这个文件只处理按钮、焦点和摆放；加一家店不需要动它。
##
## 为什么和背包面板长得像：两者都是"列表 + 详情 + 动作按钮"，
## 沿用同一套 UiKit 版式，玩家不用学第二套操作。
##
## 开关：由商店可交互物（`ShopSpot`）调 `open(shop_id)` 打开；
## ESC / 「离开」按钮关闭。面板打开期间会挡住地图交互（见 player.gd 的判断）。

const PANEL_SIZE := Vector2(1400.0, 820.0)
const LIST_SIZE := Vector2(840.0, 520.0)
const DETAIL_WIDTH := 460.0
const COLUMNS := 2

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _hint: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty: Label
var _detail_name: Label
var _detail_meta: Label
var _detail_desc: RichTextLabel
var _buy_button: Button
var _status: Label

var _open := false
var _shop_id := ""
var _selected_id := ""
var _buttons: Dictionary = {}   ## 道具 id -> Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 52
	_build()
	visible = false
	Currency.balance_changed.connect(_on_balance_changed)
	Inventory.bag_changed.connect(_on_bag_changed)
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

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)

	_title = UiKit.make_title("商店", 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(_title)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	_hint = Label.new()
	# 用户 2026-09-19：钱不做界面常驻显示，要看去背包里看 → 这里在提示里点明去哪儿看余额
	_hint.text = "方向键选择　·　回车 / 「买下」购买　·　钱数在背包（B）里看　·　ESC 离开"
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Palette.UI_DIM)
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_hint)

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

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_box.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_scroll.add_child(_grid)

	_empty = Label.new()
	_empty.text = "这家店今天没进货。"
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
	_detail_meta.add_theme_font_size_override("font_size", 22)
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

	_buy_button = _make_action_button(detail, "买下", _on_buy_pressed)
	_make_action_button(detail, "离开", _on_close_pressed)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_color", Palette.UI_DIM)
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


func current_shop() -> String:
	return _shop_id


## 开店：`shop_id` 见 `ShopDb.SHOPS`。未知 id 直接拒绝（宁可不开，也别开一个空面板）
func open(shop_id: String) -> bool:
	if not ShopDb.has_shop(shop_id):
		push_warning("Shop: 未登记的商店 '%s'" % shop_id)
		return false
	if _open and _shop_id == shop_id:
		return true
	_shop_id = shop_id
	_open = true
	visible = true
	_refresh()
	_focus_first()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false


func _focus_first() -> void:
	if not _buttons.is_empty():
		(_buttons[_buttons.keys()[0]] as Button).grab_focus()


# ---------------------------------------------------------------- 刷新

func _on_balance_changed(_scope: String, _amount: int) -> void:
	if _open:
		_refresh()


func _on_bag_changed(_scope: String) -> void:
	if _open:
		_refresh_detail()


func _refresh() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_buttons.clear()

	var stock := ShopDb.stock_of(_shop_id)
	var keep := _selected_id
	for id_variant in stock:
		var id := String(id_variant)
		var b := Button.new()
		b.text = "%s　%s" % [ItemDb.display_name(id), _price_text(id)]
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

	_empty.visible = stock.is_empty()
	_scroll.visible = not stock.is_empty()

	_title.text = ShopDb.shop_name(_shop_id)

	if keep != "" and _buttons.has(keep):
		_selected_id = keep
	elif not stock.is_empty():
		_selected_id = String(stock[0])
	else:
		_selected_id = ""
	_refresh_detail()


func _price_text(id: String) -> String:
	# ⚠️ 带上当前商店 id：同一件东西在不同店可以不同价（售货机比超市贵，见 `ShopDb.price_of`）
	return "¥ %s" % Currency.format_cents(ShopDb.price_of(id, _shop_id))


func _refresh_detail() -> void:
	if _selected_id == "" or not _buttons.has(_selected_id):
		_detail_name.text = "—"
		_detail_meta.text = ""
		_detail_desc.text = "从左边选一件东西看看。"
		_buy_button.disabled = true
		return
	var id := _selected_id
	var price := ShopDb.price_of(id, _shop_id)
	_detail_name.text = ItemDb.display_name(id)
	_detail_meta.text = "%s　·　单价 ¥ %s　·　背包里 %d 个" % [
		ItemDb.kind_name(id), Currency.format_cents(price), Inventory.count(id)]
	_detail_desc.text = ItemDb.description(id)
	_detail_desc.scroll_to_line(0)
	_buy_button.disabled = not Currency.can_afford(price)
	_set_status(ShopDb.greeting_of(_shop_id))


# ---------------------------------------------------------------- 买卖

## 选中一件商品
func select(id: String) -> bool:
	if not _buttons.has(id):
		return false
	_selected_id = id
	_refresh_detail()
	return true


func selected_id() -> String:
	return _selected_id


func stock_size() -> int:
	return _buttons.size()


## 买下选中的东西。成功 = 扣钱 + 进背包，返回 true。
##
## ⚠️ 次序必须是"**先扣钱、再进背包**"：
##    · 先扣钱 → 钱不够时 `Currency.spend` 直接失败，背包不会被塞进白拿的东西；
##    · 反过来（先进背包再扣钱）一旦扣钱失败，就成了"白送"。
## 钱与背包都在 GameState 里、跟着存档走，所以买完不需要额外的存档代码。
func buy(id: String) -> bool:
	if id == "" or not ShopDb.is_sold(id):
		_set_status("这件东西不卖。")
		return false
	var price := ShopDb.price_of(id, _shop_id)
	if not Inventory.can_accept(id, 1, ItemDb.scope_of(id)):
		_set_status("背包放不下了。")
		return false
	if not Currency.spend(price, id):
		_set_status("钱不够。「%s」要 ¥ %s，你只有 ¥ %s。" % [
			ItemDb.display_name(id), Currency.format_cents(price), Currency.format_amount()])
		return false
	Inventory.add(id, 1, ItemDb.scope_of(id))
	_set_status("买下了「%s」，花了 ¥ %s。" % [
		ItemDb.display_name(id), Currency.format_cents(price)])
	_refresh()
	return true


func buy_selected() -> bool:
	return buy(_selected_id)


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


# ---------------------------------------------------------------- 按钮回调

func _on_buy_pressed() -> void:
	UiKit.click_sfx()
	buy_selected()


func _on_close_pressed() -> void:
	UiKit.click_sfx()
	close()


# ---------------------------------------------------------------- 对外查询 / 开发期接口

func panel_rect() -> Rect2:
	return Rect2(_panel.global_position, _panel.size) if _panel != null else Rect2()


func status_text() -> String:
	return _status.text if _status != null else ""


## 买得起吗（走查断言用）。**不返回余额文案**：钱不在界面上显示（见 MoneyHud 的删除说明），
## 界面只表达"这件买不买得起"，余额去背包里看。
func can_afford_selected() -> bool:
	if _selected_id == "":
		return false
	return Currency.can_afford(ShopDb.price_of(_selected_id, _shop_id))


func debug_select(id: String) -> bool:
	return select(id)


## 把焦点给第一件商品（商店被"按 E"打开后，方向键应当立刻能用）
func debug_focus_first() -> void:
	_focus_first()


func debug_buy(id: String) -> bool:
	return buy(id)


func debug_buy_selected() -> bool:
	return buy_selected()


# ---------------------------------------------------------------- 输入

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.physical_keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
