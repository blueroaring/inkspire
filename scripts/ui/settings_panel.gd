class_name SettingsPanel
extends Control
## 设置界面（需求 01_GOALS 第 1 条："先做可扩展的壳子"）。
##
## 现在真实生效的：主/音乐/音效/语音音量、窗口全屏、文本速度、对话框不透明度、
## 逐字上浮、AUTO 停留时间、配音开关、AUTO 自动播放、伤害数字、指令二次确认。
## 战斗特效模式：1倍速 / 2倍速，动作、弹道、粒子与命中等待同步。
## 只保存、暂未生效的：语言、震屏强度
## —— 这些字段已在 Settings 里注册，等对应系统做出来后接上即可。
##
## 扩展方式：在对应的 _build_xxx 里加一行控件，键名与 Settings._defaults() 保持一致即可。

signal closed

const T := preload("res://scripts/ui/battle_theme.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const ART := preload("res://scripts/ui/battle_archive_art.gd")
var embedded := false

var _rows: VBoxContainer
var _status: Label
var _dim: ColorRect
var _center: Control
var _scroll: ScrollContainer
var presentation_size := Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if not embedded and visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close()


func _ready() -> void:
	T.apply(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if embedded:
		_build_content(self, Vector2(1544, 600))
		return
	_dim = ColorRect.new()
	_dim.color = Color(0.035, 0.045, 0.05, 0.36)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_center = Control.new()
	_center.size = Vector2(1608, 860)
	add_child(_center)
	var frame := V.panel(_center, Rect2(0, 0, 1608, 860), T.INK, T.LINE, 6)
	frame.get_node("SurfaceArt").ornate = false
	var engraving := ART.new()
	engraving.accent = T.GOLD
	engraving.size = frame.size
	frame.add_child(engraving)
	V.glyph(frame, "retain", Rect2(32, 24, 48, 48), T.GOLD)
	var title := V.text(frame, "设置", Rect2(98, 18, 740, 48), 34)
	title.add_theme_font_override("font", T.HEADING)
	V.text(frame, "音量、特效与操作偏好", Rect2(100, 64, 1130, 24), 17, T.MUTED)
	var close := Button.new()
	close.text = "关闭  ×"
	close.position = Vector2(1414, 26)
	close.size = Vector2(154, 44)
	T.button(close, T.GOLD)
	close.pressed.connect(_on_close)
	frame.add_child(close)
	var content := Control.new()
	content.position = Vector2(32, 184)
	frame.add_child(content)
	_build_content(content, Vector2(1544, 600))
	_status = V.text(frame, "设置自动保存 · 特效模式作用于战斗动作、技能与粒子演出", Rect2(34, 815, 1230, 26), 16, T.MUTED)
	V.text(frame, "ESC / 关闭返回", Rect2(1290, 815, 280, 26), 16, T.GOLD, true)
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func _build_content(parent: Control, area: Vector2) -> void:
	parent.size = area
	for column in 2:
		var pane := V.panel(parent, Rect2(column * 784, 0, 760, area.y), T.SURFACE, Color(T.LINE, 0.5), 6)
		pane.name = "SettingsColumn_%d" % column
		_scroll = ScrollContainer.new()
		_scroll.position = Vector2(20, 14)
		_scroll.size = Vector2(720, area.y - 28)
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		pane.add_child(_scroll)
		_rows = VBoxContainer.new()
		_rows.add_theme_constant_override("separation", 12)
		_rows.custom_minimum_size = Vector2(700, 0)
		_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll.add_child(_rows)
		if column == 0:
			_build_battle()
			_build_audio()
			_build_video()
		else:
			_build_dialogue()
			_build_game()


func _relayout() -> void:
	if embedded or not is_instance_valid(_center): return
	var area := presentation_size if presentation_size != Vector2.ZERO else get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = area
	_dim.size = area
	var factor := minf(1.0, minf(area.x / 1680.0, area.y / 920.0))
	_center.scale = Vector2.ONE * factor
	_center.position = (area - Vector2(1608, 860) * factor) * 0.5


func _exit_tree() -> void:
	Settings.save_settings()


# ------------------------------------------------------------ 分组

func _section(title: String) -> void:
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", T.GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_font_override("font", T.HEADING)
	_rows.add_child(l)


func _build_audio() -> void:
	_section("音频")
	_add_check("关闭所有配音", "audio", "mute_all_voice", "立即停止所有角色、怪物、助战、终结技和剧情配音；音乐与音效仍由各自音量控制。关闭此选项后恢复配音，保留原来的语音音量。")
	_add_slider("主音量", "audio", "master_volume", 0.0, 1.0, 0.05)
	_add_slider("音乐音量", "audio", "music_volume", 0.0, 1.0, 0.05)
	_add_slider("音效音量", "audio", "sfx_volume", 0.0, 1.0, 0.05)
	_add_slider("语音音量", "audio", "voice_volume", 0.0, 1.0, 0.05)


## 对话：文字速度 / 外观 / 自动播放 / 配音开关（对应 DialogueBox 与 Voice）
func _build_dialogue() -> void:
	_section("对话")
	_add_slider("文字速度（字/秒）", "game", "text_speed", 0.0, 120.0, 5.0)
	_add_slider("对话框不透明度", "dialogue", "box_opacity", 0.3, 1.0, 0.05)
	_add_check("打字逐字上浮", "dialogue", "char_rise")
	_add_slider("自动播放停留（秒）", "dialogue", "auto_delay", 0.3, 5.0, 0.1)
	_add_check("播放对话配音", "dialogue", "voice_enabled", "控制剧情对话配音；同时受音频页的“关闭所有配音”控制。")
	_add_check("配音未播完不推进", "dialogue", "voice_wait")


func _build_game() -> void:
	_section("游戏")
	_add_language_option()
	_add_check("自动播放对话（AUTO，A 键切换）", "game", "auto_advance")


func _build_battle() -> void:
	_section("战斗")
	_add_effect_speed_option()
	_add_check("终结技演出（CG / 动画 / 语音）", "battle", "ultimate_presentation", "关闭后跳过终结技的CG、海报、动画和语音，直接结算技能；包括李安雅的变身与回归。")
	_add_check("简易特效（统一敌我攻击表现）", "battle", "simple_effects", "所有敌我攻击统一使用简短的命中特效和音效。伤害、命中次数与技能效果照常结算；终结技演出由上方开关控制。")
	_add_check("显示伤害数字", "battle", "show_damage_number", "显示敌我生命与护盾扣减的飘字。关闭后仍保留血条、状态提示和战斗记录。")
	_add_check("指令二次确认", "battle", "confirm_commands", "默认关闭。开启后，出牌、终结技、道具及结束回合前确认；需要目标的指令在选好目标后确认。确认框出现时只能选择确认或取消，取消不会消耗资源。")


func _add_effect_speed_option() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = "特效模式"
	label.custom_minimum_size = Vector2(290, 0)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", T.TEXT)
	row.add_child(label)
	var option := OptionButton.new()
	option.name = "BattleEffectSpeed"
	option.custom_minimum_size = Vector2(280, 40)
	_style_option(option)
	option.add_item("1倍速特效", 1)
	option.add_item("2倍速特效", 2)
	option.select(1 if Settings.battle_effect_speed() == 2.0 else 0)
	option.tooltip_text = "同步调整战斗动作、弹道、命中特效和粒子播放速度。"
	option.item_selected.connect(func(index: int) -> void:
		Settings.set_value("battle", "battle_speed", float(index + 1))
		Settings.save_settings()
	)
	row.add_child(option)
	_rows.add_child(row)


func _build_video() -> void:
	_section("画面")
	_add_check("全屏", "video", "fullscreen")
	_add_slider("震屏强度", "video", "screen_shake", 0.0, 2.0, 0.1)


# ------------------------------------------------------------ 控件工厂

func _add_slider(label_text: String, section: String, key: String,
		min_value: float, max_value: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(290, 0)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", T.TEXT)
	row.add_child(label)

	var slider := HSlider.new()
	slider.name = "Setting_" + section + "_" + key
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = float(Settings.get_value(section, key, min_value))
	slider.custom_minimum_size = Vector2(260, 36)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(84, 0)
	value_label.add_theme_font_size_override("font_size", 22)
	value_label.add_theme_color_override("font_color", T.MUTED)
	value_label.text = _format_value(slider.value)
	row.add_child(value_label)

	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = _format_value(v)
		Settings.set_value(section, key, v)
	)
	slider.drag_ended.connect(func(_changed: bool) -> void: Settings.save_settings())
	_style_slider(slider)

	_rows.add_child(row)


func _add_check(label_text: String, section: String, key: String, description: String = "") -> void:
	var check := CheckButton.new()
	check.name = "Setting_" + section + "_" + key
	check.custom_minimum_size.y = 38
	check.text = label_text
	check.tooltip_text = description
	check.button_pressed = bool(Settings.get_value(section, key, false))
	check.add_theme_font_size_override("font_size", 22)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		check.add_theme_color_override(state, T.TEXT)
	check.toggled.connect(func(pressed: bool) -> void:
		Settings.set_value(section, key, pressed)
		Settings.save_settings()
	)
	_rows.add_child(check)


func _add_language_option() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label := Label.new()
	label.text = "语言（预留）"
	label.custom_minimum_size = Vector2(290, 0)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", T.TEXT)
	row.add_child(label)

	var option := OptionButton.new()
	_style_option(option)
	var current := String(Settings.get_value("game", "language", "zh_CN"))
	var keys: Array = Settings.LANGUAGES.keys()
	for i in keys.size():
		option.add_item(String(Settings.LANGUAGES[keys[i]]), i)
		if String(keys[i]) == current:
			option.select(i)
	option.item_selected.connect(func(index: int) -> void:
		Settings.set_value("game", "language", String(keys[index]))
		Settings.save_settings()
	)
	row.add_child(option)
	_rows.add_child(row)


func _style_option(option: OptionButton) -> void:
	option.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "focus"]:
		option.add_theme_stylebox_override(state, T.frame(T.HOVER if state == "hover" else T.RECESSED, T.GOLD if state == "focus" else T.LINE, 1, 5))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		option.add_theme_color_override(state, T.TEXT)
	var popup := option.get_popup()
	popup.add_theme_stylebox_override("panel", T.frame(T.SURFACE, T.LINE, 1, 5))
	popup.add_theme_stylebox_override("hover", T.frame(T.SELECTED, T.GOLD, 1, 4))
	popup.add_theme_color_override("font_color", T.TEXT)
	popup.add_theme_color_override("font_hover_color", T.TEXT)
	popup.add_theme_font_override("font", T.BODY)
	popup.add_theme_font_size_override("font_size", 22)


func _style_slider(slider: HSlider) -> void:
	var track := T.frame(T.RECESSED, T.LINE, 1, 3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	slider.add_theme_stylebox_override("slider", track)
	for key in ["grabber_area", "grabber_area_highlight"]:
		var fill := T.frame(T.GOLD, Color.TRANSPARENT, 0, 3)
		fill.content_margin_top = 3
		fill.content_margin_bottom = 3
		slider.add_theme_stylebox_override(key, fill)


func _format_value(v: float) -> String:
	if absf(v - roundf(v)) < 0.001:
		return "%d" % int(roundf(v))
	return "%.2f" % v


func _on_close() -> void:
	UiKit.click_sfx()
	Settings.save_settings()
	visible = false
	closed.emit()
