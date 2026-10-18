class_name BattleTutorialDialog
extends CanvasLayer
## 战斗专用的独立对话框；选择与逐步说明都在这里显示。

signal choice_made(skip: bool)
signal acknowledged
const T := preload("res://scripts/ui/battle_theme.gd")

var _title: Label
var _body: Label
var _buttons: HBoxContainer
var _overlay: Control
var _highlight_panel: Panel
var _highlight_rect := Rect2()

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = Control.new()
	T.apply(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.06, 0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(shade)
	_highlight_panel = Panel.new()
	var border := UiKit.panel_style(Color.TRANSPARENT, Color("#ffe08b"), 5, 8)
	border.draw_center = false
	_highlight_panel.add_theme_stylebox_override("panel", border)
	_highlight_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_highlight_panel)
	get_viewport().size_changed.connect(_layout_highlight)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(740, 260)
	panel.add_theme_stylebox_override("panel", T.frame(T.SURFACE, T.GOLD, 2, 8))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 31)
	_title.add_theme_font_override("font", T.HEADING)
	_title.add_theme_color_override("font_color", T.GOLD)
	column.add_child(_title)
	_body = Label.new()
	_body.custom_minimum_size = Vector2(670, 86)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 23)
	_body.add_theme_color_override("font_color", T.TEXT)
	column.add_child(_body)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 16)
	column.add_child(_buttons)
	_layout_highlight()

func highlight(rect: Rect2) -> void:
	_highlight_rect = rect
	if is_inside_tree():
		_layout_highlight()

func _layout_highlight() -> void:
	if not is_instance_valid(_highlight_panel):
		return
	_highlight_panel.visible = _highlight_rect.size.x > 0 and _highlight_rect.size.y > 0
	if not _highlight_panel.visible:
		return
	var viewport := get_viewport().get_visible_rect().size
	var scale: float = minf(viewport.x / 1920.0, viewport.y / 1080.0)
	var origin := (viewport - Vector2(1920, 1080) * scale) * 0.5
	_highlight_panel.position = origin + _highlight_rect.position * scale
	_highlight_panel.size = _highlight_rect.size * scale

func ask_skip() -> bool:
	_title.text = "战斗新手教程"
	_body.text = "是否跳过新手教程？\n继续后会按步骤练习战斗操作。"
	_clear_buttons()
	_add_button("继续教程", false, false)
	_add_button("跳过教程", true, true)
	return await choice_made

func show_step(title: String, body: String) -> void:
	_title.text = title
	_body.text = body
	_clear_buttons()
	_add_button("继续", false, false)
	await acknowledged

func _clear_buttons() -> void:
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()

func _add_button(caption: String, skip: bool, is_choice: bool) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(170, 52)
	T.button(button, T.GOLD, not skip)
	_buttons.add_child(button)
	button.pressed.connect(func() -> void:
		if is_choice or _buttons.get_child_count() > 1:
			choice_made.emit(skip)
		else:
			acknowledged.emit()
	)
	if _buttons.get_child_count() == 1:
		button.grab_focus()
