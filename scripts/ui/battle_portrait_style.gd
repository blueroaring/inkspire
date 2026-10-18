extends Control
## Shared style choice in the character system and the in-battle character archive.
signal style_selected
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const T := preload("res://scripts/ui/battle_theme.gd")
var hero_id := ""
var _buttons: Dictionary = {}

func _ready() -> void:
	name = "BattlePortraitStyle"
	size = Vector2(490, 64)
	mouse_filter = MOUSE_FILTER_IGNORE
	var profile := FightData.hero(hero_id)
	V.text(self, "头像画风 · %s" % String(profile.get("name", hero_id)), Rect2(0, 0, 490, 23), 16, T.MUTED)
	for i in 2:
		var key := "original" if i == 0 else "retro_pixel"
		var button := Button.new()
		button.name = "PortraitStyle_" + key
		button.text = "原画" if i == 0 else "早期像素 · 测试"
		button.position = Vector2(i * 246, 28)
		button.size = Vector2(238, 34)
		button.add_theme_font_size_override("font_size", 17)
		button.tooltip_text = "仅切换当前角色的战斗头像，自动记住选择。"
		_buttons[key] = button
		button.pressed.connect(func() -> void:
			Settings.set_portrait_style(hero_id, key)
			Settings.save_settings()
			style_selected.emit()
		)
		add_child(button)
	_refresh_buttons()
	Settings.setting_changed.connect(_on_setting_changed)

func _on_setting_changed(section: String, key: String, _value: Variant) -> void:
	if section == "battle" and key == "portrait_styles": _refresh_buttons()

func _refresh_buttons() -> void:
	var selected := Settings.portrait_style(hero_id)
	for key: String in _buttons:
		T.button(_buttons[key], T.GOLD, selected == key)
