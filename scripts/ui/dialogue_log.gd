class_name DialogueLog
extends Control
## 对话回顾（Backlog）面板 —— 参考 galgame 的"log / 回想"。
##
## 职责很窄：把已经读过的台词按顺序铺出来，让玩家能回看。
## 它不认识剧情、不认识对话框的内部状态；`DialogueBox` 只负责
## 「打开时把历史数组交给它」和「它关掉时把 _log_open 复位」。
##
## 全部用代码构建（本项目 Node2D 根场景下锚点预设不生效，统一走 UiKit 显式摆位）。

signal closed

const PANEL_SIZE := Vector2(1440.0, 800.0)
const SCROLL_SIZE := Vector2(1360.0, 660.0)

var _dim: ColorRect
var _panel: PanelContainer
var _scroll: ScrollContainer
var _content: RichTextLabel
var _count: Label
var _open := false
var _entries := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false
	set_process_input(false)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.88)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.039, 0.055, 0.110, 0.97)
	style.set_border_width_all(3)
	style.border_color = DialogueStyle.BOX_BORDER
	style.set_corner_radius_all(8)
	style.content_margin_left = 32.0
	style.content_margin_right = 32.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_panel.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	column.add_child(header)

	var title := Label.new()
	title.text = "对话回顾"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", DialogueStyle.NAME_TEXT)
	header.add_child(title)

	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 20)
	_count.add_theme_color_override("font_color", DialogueStyle.HINT_TEXT)
	header.add_child(_count)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var hint := Label.new()
	hint.text = "滚轮翻阅　·　ESC / H 关闭"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", DialogueStyle.HINT_TEXT)
	header.add_child(hint)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = SCROLL_SIZE
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)

	_content = RichTextLabel.new()
	_content.bbcode_enabled = true
	_content.fit_content = true
	_content.scroll_active = false
	_content.custom_minimum_size = Vector2(SCROLL_SIZE.x - 30.0, 0.0)
	_content.add_theme_font_size_override("normal_font_size", 28)
	_content.add_theme_constant_override("line_separation", 8)
	_scroll.add_child(_content)


## 摆位（基准 1920x1080，按视口宽度等比缩放）
func relayout(viewport: Vector2) -> void:
	var s := viewport.x / DialogueStyle.BASE.x
	UiKit.place(_dim, Rect2(Vector2.ZERO, viewport))
	UiKit.place(_panel, Rect2(viewport * 0.5 - PANEL_SIZE * s * 0.5, PANEL_SIZE * s))
	_scroll.custom_minimum_size = SCROLL_SIZE * s
	_content.custom_minimum_size = Vector2((SCROLL_SIZE.x - 30.0) * s, 0.0)


# ---------------------------------------------------------------- 开关

func open(entries: Array) -> void:
	_render(entries)
	visible = true
	_open = true
	set_process_input(true)
	# 布局要等一帧才算完，滚到底部（最新的一句）
	await get_tree().process_frame
	if not _open:
		return
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	set_process_input(false)
	closed.emit()


func is_open() -> bool:
	return _open


func entry_count() -> int:
	return _entries


func content_text() -> String:
	return _content.text if _content != null else ""


# ---------------------------------------------------------------- 渲染

func _render(entries: Array) -> void:
	_entries = entries.size()
	_count.text = "共 %d 条" % _entries
	var parts := PackedStringArray()
	for entry_variant in entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var speaker := String(entry.get("speaker", ""))
		var emotion := String(entry.get("emotion", ""))
		var text := String(entry.get("text", ""))
		var head := ""
		if speaker != "":
			head = "[color=#f4e9b8]%s[/color]" % speaker
		if emotion != "":
			head += ("　" if head != "" else "") + "[color=#7fd4ff]「%s」[/color]" % emotion
		if head != "":
			parts.append(head)
		parts.append(text)
		parts.append("")
	_content.text = "\n".join(parts)


# ---------------------------------------------------------------- 输入

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and (k.physical_keycode == KEY_ESCAPE or k.physical_keycode == KEY_H):
			close()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll.scroll_vertical -= 80
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll.scroll_vertical += 80
			get_viewport().set_input_as_handled()
