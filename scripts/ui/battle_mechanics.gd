extends Control
## Shared by character references and the in-battle archive.
const DATA := preload("res://scripts/data/battle_mechanics.gd")
const T := preload("res://scripts/ui/battle_theme.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
var category := "all"
var entries: Array[Dictionary] = []
var _search: LineEdit
var _count: Label
var _categories: HFlowContainer
var _scroll: ScrollContainer
var _rows: GridContainer
var _empty: Label
var _buttons: Dictionary = {}

func _ready() -> void:
	name = "MechanicsGuide"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size == Vector2.ZERO: size = Vector2(1744, 696)
	entries = DATA.entries()
	var title := V.text(self, "战斗机制索引", Rect2(0, 0, 540, 42), 29, T.TEXT)
	title.add_theme_font_override("font", T.HEADING)
	_count = V.text(self, "", Rect2(0, 44, 900, 30), 18, T.MUTED)
	_search = LineEdit.new()
	_search.name = "MechanicsSearch"
	_search.placeholder_text = "搜索机制、角色或效果，如：毒 / 净化 / 涅槃"
	_search.clear_button_enabled = true
	_search.add_theme_font_size_override("font_size", 18)
	add_child(_search)
	_search.text_changed.connect(func(_text: String): _filter())
	_categories = HFlowContainer.new()
	_categories.name = "MechanicsCategories"
	_categories.add_theme_constant_override("h_separation", 10)
	_categories.add_theme_constant_override("v_separation", 8)
	add_child(_categories)
	for key in DATA.CATEGORIES:
		var count := entries.size() if key == "all" else entries.filter(func(entry: Dictionary): return entry.category == key).size()
		var button := Button.new()
		button.name = "MechanicsCategory_" + key
		button.text = "%s  %d" % [DATA.CATEGORIES[key], count]
		button.custom_minimum_size = Vector2(144, 42)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(select_category.bind(key))
		_categories.add_child(button)
		_buttons[key] = button
	_scroll = ScrollContainer.new()
	_scroll.name = "ReferenceTerms"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_rows = GridContainer.new()
	_rows.name = "MechanicsRows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("h_separation", 16)
	_rows.add_theme_constant_override("v_separation", 14)
	_scroll.add_child(_rows)
	for entry in entries: _entry(entry)
	_empty = V.text(self, "没有找到匹配的机制，试试其他关键词或切换到「全部」。", Rect2(), 21, T.MUTED, true)
	_empty.name = "MechanicsEmpty"
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resized.connect(_layout)
	_categories.resized.connect(_layout_scroll)
	_layout()
	_filter()

func _layout() -> void:
	if not is_instance_valid(_search): return
	var narrow := size.x < 1100
	_search.position = Vector2(0, 84) if narrow else Vector2(size.x - 540, 5)
	_search.size = Vector2(size.x if narrow else 540, 44)
	_categories.position = Vector2(0, 142 if narrow else 90)
	_categories.size.x = size.x
	_rows.columns = 1 if narrow else 2
	_count.size.x = size.x
	_layout_scroll()

func _layout_scroll() -> void:
	if not is_instance_valid(_scroll): return
	var top := _categories.position.y + maxf(42, _categories.size.y) + 18
	_scroll.position = Vector2(0, top)
	_scroll.size = Vector2(size.x, maxf(80, size.y - top))
	_empty.position = _scroll.position + Vector2(10, 24)
	_empty.size = Vector2(size.x - 20, 80)

func select_category(key: String) -> void:
	if not DATA.CATEGORIES.has(key): return
	category = key
	_filter()

func _filter() -> void:
	var count := 0
	for row in _rows.get_children():
		row.visible = DATA.matches(row.get_meta("entry"), _search.text, category)
		if row.visible: count += 1
	_count.text = "显示 %d / %d 项 · 图标与战斗一致 · 滚动查看完整规则" % [count, entries.size()]
	_empty.visible = count == 0
	_scroll.scroll_vertical = 0
	for key in _buttons: T.button(_buttons[key], T.GOLD, key == category)

func _entry(entry: Dictionary) -> void:
	var pane := PanelContainer.new()
	pane.name = "Mechanic_" + String(entry.id)
	pane.set_meta("entry", entry)
	pane.custom_minimum_size.y = 174
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.add_theme_stylebox_override("panel", T.frame(T.SURFACE, Color(T.LINE, 0.55), 1, 6))
	_rows.add_child(pane)
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 20)
	pane.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	var icon := Control.new()
	icon.name = "MechanicIcon"
	icon.custom_minimum_size = Vector2(58, 64)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var texture := DATA.texture(entry)
	if texture != null:
		V.icon(icon, texture, Rect2(0, 4, 58, 58)).name = "MechanicArt"
	else:
		V.glyph(icon, String(entry.icon_id) if entry.icon_kind == "glyph" else "innate", Rect2(2, 6, 54, 54), T.GOLD).name = "MechanicGlyph"
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 8)
	row.add_child(words)
	var heading := Label.new()
	heading.name = "MechanicTitle"
	heading.text = String(entry.name)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_override("font", T.HEADING)
	heading.add_theme_font_size_override("font_size", 24)
	words.add_child(heading)
	var group := Label.new()
	group.text = String(DATA.CATEGORIES[entry.category])
	group.add_theme_font_size_override("font_size", 15)
	group.add_theme_color_override("font_color", T.MUTED)
	words.add_child(group)
	var body := Label.new()
	body.name = "MechanicDescription"
	body.text = String(entry.desc)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 19)
	body.add_theme_color_override("font_color", T.TEXT)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(body)
