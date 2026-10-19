extends Control
signal dismissed
var heading := "说明"
var description := ""
var action_text := ""
var action: Callable
var cancel_action: Callable
var input_text := ""
var prompt_input := false
var choices: Array[Dictionary] = []
var field: LineEdit
const M := preload("res://scripts/ui/tower_mobile.gd")
const T := preload("res://scripts/ui/battle_theme.gd")

func _ready() -> void:
	name = "MobileHelp"
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	T.apply(self)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.035, 0.05, 0.85)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var title := Label.new()
	title.position = Vector2(100, 70)
	title.size = Vector2(1680, 90)
	title.text = heading
	title.add_theme_color_override("font_color", T.GOLD)
	title.add_theme_font_size_override("font_size", 48)
	add_child(title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(100, 190)
	scroll.size = Vector2(1720, 650)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 24)
	scroll.add_child(rows)
	var body := Label.new()
	body.text = description
	body.add_theme_color_override("font_color", Color("e9edf2"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 40)
	body.add_theme_constant_override("line_spacing", 12)
	rows.add_child(body)
	if prompt_input:
		field = LineEdit.new()
		field.name = "MobileTextInput"
		field.text = input_text
		field.placeholder_text = "无名攀登者"
		field.max_length = 24
		field.custom_minimum_size.y = 144
		field.add_theme_font_size_override("font_size", 38)
		field.text_submitted.connect(func(_text: String): field.release_focus(); DisplayServer.virtual_keyboard_hide())
		rows.add_child(field)
	for choice in choices:
		var option := Button.new()
		option.text = choice.text
		option.custom_minimum_size.y = 144
		option.disabled = choice.get("disabled", false)
		option.add_theme_font_size_override("font_size", 40)
		option.pressed.connect(func(): dismiss(); choice.action.call())
		rows.add_child(option)
	var close := Button.new()
	close.name = "CloseMobileHelp"
	close.text = "关闭说明"
	close.position = Vector2(1320, 900)
	close.size = Vector2(500, 144)
	close.add_theme_font_size_override("font_size", 34)
	T.button(close, T.GOLD)
	close.pressed.connect(func():
		if cancel_action.is_valid(): cancel_action.call()
		else: dismiss())
	add_child(close)
	if not action_text.is_empty():
		close.text = "取消"
		var confirm := Button.new()
		confirm.name = "MobileConfirm"
		confirm.text = action_text
		confirm.position = Vector2(100, 900)
		confirm.size = Vector2(650, 144)
		confirm.add_theme_font_size_override("font_size", 34)
		T.button(confirm, T.GOLD)
		confirm.pressed.connect(func():
			var result := field.text if is_instance_valid(field) else ""
			dismiss()
			if action.is_valid():
				if prompt_input: action.call(result)
				else: action.call())
		add_child(confirm)
	get_viewport().size_changed.connect(_resize)
	_resize()

func _resize() -> void:
	M.fit(self, get_viewport())

func dismiss() -> void:
	if is_instance_valid(field):
		field.release_focus()
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
	hide()
	dismissed.emit()
