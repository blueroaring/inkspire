extends Control
signal closed
const T := preload("res://scripts/ui/battle_theme.gd")
const M := preload("res://scripts/ui/battle_management_ui.gd")
const FINISH := preload("res://scripts/ui/tower_finish.gd")
const CREDITS := preload("res://scripts/data/tower_credits.gd")
var content: RichTextLabel
var heading: Label
var tabs: Array[Button] = []
var _sections := CREDITS.sections()

func _ready() -> void:
	name = "TowerCredits"
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	T.apply(self)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.05, 0.86)
	shade.size = size
	add_child(shade)
	var panel := M.panel(Rect2(230, 90, 1460, 900), Color("e3dfcd"), T.GOLD)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	FINISH.decorate(panel)
	M.heading(self, "制作名单与许可", Rect2(285, 125, 1000, 66), 38)
	M.paragraph(self, "CREDITS & LICENSES  /  感谢每一位同行者", Rect2(288, 197, 1140, 38), 20, T.MUTED)
	for i in _sections.size():
		var tab := M.button(String(_sections[i].title), Rect2(285, 270 + i * 74, 288, 58), _select.bind(i))
		tab.name = "CreditsTab_" + String(_sections[i].id)
		tab.toggle_mode = true
		tab.add_theme_font_size_override("font_size", 21)
		add_child(tab)
		tabs.append(tab)
	heading = M.heading(self, "", Rect2(620, 258, 990, 52), 28)
	content = RichTextLabel.new()
	content.name = "CreditsText"
	content.position = Vector2(620, 328)
	content.size = Vector2(1000, 540)
	content.bbcode_enabled = false
	content.selection_enabled = true
	content.focus_mode = Control.FOCUS_ALL
	content.add_theme_font_size_override("normal_font_size", 22)
	content.add_theme_color_override("default_color", T.TEXT)
	content.add_theme_constant_override("line_separation", 7)
	add_child(content)
	M.paragraph(self, "滚动阅读 · 可选择并复制文字 · Esc 返回", Rect2(620, 903, 695, 42), 19, T.MUTED)
	var back := M.button("返回游戏", Rect2(1370, 897, 250, 58), _close, T.GOLD, true)
	back.name = "CreditsClose"
	add_child(back)
	_select(0)
	tabs[0].grab_focus()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.16)

func _select(index: int) -> void:
	for i in tabs.size(): tabs[i].set_pressed_no_signal(i == index)
	var section := _sections[index]
	heading.text = String(section.title)
	content.text = CREDITS.section_text(section)
	content.scroll_to_line(0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()
