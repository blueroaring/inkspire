extends Control
## Shared read-only catalogue for the character menu and battle archive.
const DATA := preload("res://scripts/data/enemy_bestiary.gd")
const TERMS := preload("res://scripts/data/enemy_bestiary_terms.gd")
const T := preload("res://scripts/ui/battle_theme.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
var selected_id := "paper_large"
var _rows: VBoxContainer
var _details: VBoxContainer
var _detail_scroll: ScrollContainer
var _search: LineEdit
var _count: Label
var _buttons: Dictionary = {}
var _terms: Dictionary = {}
var _term_names: Array[String] = []
var _term_overlay: Control

func _ready() -> void:
	name = "EnemyBestiary"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terms = TERMS.entries()
	for term in _terms: _term_names.append(String(term))
	_term_names.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 24)
	add_child(layout)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 350
	sidebar.add_theme_constant_override("separation", 12)
	layout.add_child(sidebar)
	_search = LineEdit.new()
	_search.name = "BestiarySearch"
	_search.placeholder_text = "搜索怪物、机制或推荐角色"
	_search.custom_minimum_size.y = 46
	_search.clear_button_enabled = true
	sidebar.add_child(_search)
	_count = _label("", 17, T.MUTED)
	sidebar.add_child(_count)
	var list_scroll := _scroll(sidebar, "BestiaryList")
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 10)
	list_scroll.add_child(_rows)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", T.frame(T.SURFACE, Color(T.LINE, 0.6), 1, 6))
	layout.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	_detail_scroll = _scroll(margin, "BestiaryDetails")
	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation", 16)
	_detail_scroll.add_child(_details)
	_search.text_changed.connect(_filter)
	_filter("")

func _scroll(parent: Node, node_name: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	return scroll

func _label(words: String, font_size: int = 20, color: Color = T.TEXT) -> Label:
	var label := Label.new()
	label.text = words
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _filter(query: String) -> void:
	_clear(_rows)
	_buttons.clear()
	var matches: Array[String] = []
	query = query.strip_edges()
	for id in DATA.ids():
		var entry := DATA.entry(id)
		var unlocked := TowerRun.enemy_defeated(id)
		var words := String(entry.name) + String(entry.kind) + String(entry.traits) + String(entry.mechanics) + str(entry.skills) + str(entry.assists) + String(entry.recommendation) + FightData.attr_name(entry.attribute) if unlocked else "???"
		if not query.is_empty() and not words.containsn(query): continue
		matches.append(id)
		var button := Button.new()
		button.name = "BestiaryEnemy_" + id
		button.custom_minimum_size = Vector2(328, 100)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = String(entry.name) if unlocked else "???"
		T.button(button, T.GOLD)
		_rows.add_child(button)
		if unlocked: V.icon(button, load(entry.portrait), Rect2(10, 12, 72, 76))
		var title := _label(String(entry.name) if unlocked else "???", 20)
		title.position = Vector2(94, 12)
		title.size = Vector2(220, 51)
		title.max_lines_visible = 2
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_child(title)
		V.text(button, "%s · %s" % [entry.kind, FightData.attr_name(entry.attribute)] if unlocked else "???", Rect2(94, 68, 220, 24), 16, T.MUTED)
		button.pressed.connect(func() -> void: select_enemy(id))
		_buttons[id] = button
	_count.text = "%d / %d 种怪物 · 点击查看" % [matches.size(), DATA.ids().size()]
	if matches.is_empty():
		_clear(_details)
		_details.add_child(_label("没有找到匹配的怪物", 28, T.GOLD))
		_details.add_child(_label("试试怪物名称、技能名称或机制关键词。清空搜索可查看全部图鉴。"))
	else:
		select_enemy(selected_id if selected_id in matches else matches[0])

func select_enemy(id: String) -> void:
	var entry := DATA.entry(id)
	if entry.is_empty(): return
	if not TowerRun.enemy_defeated(id):
		_close_term()
		_clear(_details)
		_details.add_child(_label("???", 36, T.GOLD))
		_details.add_child(_label("击败该敌人后解锁图鉴信息。", 22, T.MUTED))
		return
	_close_term()
	selected_id = String(entry.id)
	for key in _buttons: T.button(_buttons[key], T.GOLD, key == selected_id)
	_clear(_details)
	_detail_scroll.scroll_vertical = 0
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	_details.add_child(header)
	var portrait := TextureRect.new()
	portrait.name = "BestiaryPortrait"
	portrait.custom_minimum_size = Vector2(176, 176)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = load(entry.portrait)
	header.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 12)
	header.add_child(identity)
	identity.add_child(_label("%s  /  %s" % [entry.kind, FightData.attr_name(entry.attribute)], 18, T.GOLD))
	var title := _label(String(entry.name), 30)
	title.name = "BestiaryName"
	title.add_theme_font_override("font", T.HEADING)
	identity.add_child(title)
	identity.add_child(_linked_text(String(entry.traits), 19, T.MUTED))
	_section("怪物介绍", String(entry.bio))
	_section("推荐角色 / 应对方式", String(entry.recommendation))
	_details.get_child(_details.get_child_count() - 1).name = "BestiaryRecommendation"
	_section("战斗机制", String(entry.mechanics))
	if not entry.assists.is_empty():
		var assist_title := _label("我方助战技", 25, T.GOLD)
		assist_title.name = "BestiaryAssistTitle"
		_details.add_child(assist_title)
		for assist in entry.assists: _section(String(assist[0]), String(assist[1]), true)
	_details.add_child(_label("怪物技能", 25, T.GOLD))
	for skill in entry.skills:
		_section(String(skill[0]), String(skill[1]), true)

func _section(title: String, words: String, skill: bool = false) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 8)
	_details.add_child(block)
	block.add_child(_linked_text(title, 21 if skill else 25, T.TEXT if skill else T.GOLD))
	block.add_child(_linked_text(words))

func _linked_text(words: String, font_size: int = 20, color: Color = T.TEXT) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size.x = 1
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("normal_font", T.BODY)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", color)
	label.add_theme_constant_override("line_separation", 5)
	label.meta_clicked.connect(_show_term)
	var cursor := 0
	var linked: Array[String] = []
	while cursor < words.length():
		var next_at := words.length()
		var next_term := ""
		for term in _term_names:
			var at := words.find(term, cursor)
			if at >= 0 and at < next_at:
				next_at = at
				next_term = term
		label.add_text(words.substr(cursor, next_at - cursor))
		if next_term.is_empty(): break
		label.push_meta(next_term)
		label.push_color(T.BLUE)
		label.push_underline()
		label.add_text(next_term)
		label.pop_all()
		linked.append(next_term)
		cursor = next_at + next_term.length()
	label.set_meta("linked_terms", linked)
	return label

func _show_term(term_value: Variant) -> void:
	var term := String(term_value)
	if not _terms.has(term): return
	_close_term()
	var detail: Dictionary = _terms[term]
	var overlay := ColorRect.new()
	overlay.name = "BestiaryTermOverlay"
	overlay.color = Color(0.06, 0.12, 0.16, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: _close_term())
	add_child(overlay)
	_term_overlay = overlay
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "BestiaryTermPanel"
	panel.custom_minimum_size.x = minf(620.0, size.x - 40.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", T.frame(T.ON_STAGE, T.GOLD, 2, 6))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	heading.add_child(_label(String(detail.kind), 17, T.GOLD))
	var title := _label(term, 28)
	title.name = "BestiaryTermTitle"
	heading.add_child(title)
	var close := Button.new()
	close.name = "BestiaryTermClose"
	close.text = "×"
	close.tooltip_text = "关闭说明"
	close.custom_minimum_size = Vector2(40, 40)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	T.button(close, T.GOLD)
	close.pressed.connect(_close_term)
	header.add_child(close)
	var body := _linked_text(String(detail.desc))
	body.name = "BestiaryTermDescription"
	column.add_child(body)
	close.grab_focus()

func _close_term() -> void:
	if is_instance_valid(_term_overlay):
		_term_overlay.queue_free()
		_term_overlay = null

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(_term_overlay) and event.is_action_pressed("ui_cancel"):
		_close_term()
		get_viewport().set_input_as_handled()
