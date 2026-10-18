extends Control
const THEME := preload("res://scripts/ui/battle_theme.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const ART := preload("res://scripts/data/battle_art.gd")
var statuses: Array = []
var title := "全部状态"

func _ready() -> void:
	THEME.apply(self)
	name = "BattleStatusList"
	z_index = 112
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.01, 0.025, 0.67)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var pane := V.panel(self, Rect2(610, 210, 700, 660), THEME.INK, THEME.LINE)
	V.text(pane, title, Rect2(28, 22, 600, 46), 28, THEME.TEXT).add_theme_font_override("font", THEME.HEADING)
	V.text(pane, "共 %d 项 · 滚动查看" % statuses.size(), Rect2(28, 74, 610, 32), 18, V.MUTED)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 120)
	scroll.size = Vector2(644, 468)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pane.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	for status: Dictionary in statuses:
		var row := PanelContainer.new()
		row.name = "StatusRow_" + String(status.get("icon", "buff"))
		row.custom_minimum_size = Vector2(620, 94)
		row.add_theme_stylebox_override("panel", V.style(THEME.SURFACE, Color(THEME.LINE, 0.4)))
		rows.add_child(row)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		var margin := MarginContainer.new()
		for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 14)
		row.add_child(margin)
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 16)
		margin.add_child(content)
		var icon := TextureRect.new()
		icon.name = "StatusArt_" + String(status.get("icon", "buff"))
		icon.texture = ART.status_icon(String(status.get("icon", "")), bool(status.get("debuff", false)), String(status.get("art_key", "")))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.custom_minimum_size = Vector2(48, 48)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(box)
		var heading := Label.new()
		heading.name = "StatusHeading"
		heading.add_theme_font_override("font", THEME.HEADING)
		heading.text = String(status.get("name", "状态"))
		var stacks := int(status.get("stacks", 0))
		if String(status.get("icon", "")) == "void":
			heading.text += "  ·  %d / 5 层" % stacks
		elif stacks > 0:
			heading.text += "  ·  %d 层" % stacks
		heading.add_theme_font_size_override("font_size", 21)
		heading.add_theme_color_override("font_color", THEME.RED if status.get("debuff", false) else THEME.GREEN)
		box.add_child(heading)
		var body := Label.new()
		body.text = String(status.get("desc", ""))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 17)
		body.add_theme_color_override("font_color", THEME.TEXT)
		box.add_child(body)
	var close := Button.new()
	close.name = "CloseStatusList"
	close.text = "关闭"
	close.position = Vector2(520, 605)
	close.size = Vector2(150, 36)
	preload("res://scripts/ui/battle_theme.gd").button(close, V.GOLD)
	close.pressed.connect(queue_free)
	pane.add_child(close)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
