extends Node
## 全局设置（自动加载单例 Settings）
##
## 职责：读写 user://settings.cfg，保存音量 / 语言 / 文本速度 / 战斗表现等选项。
## 音频、对话、画面与战斗特效倍速真实生效；语言等预留项只存储。
## 新增设置项的做法：在 _defaults() 里加一行，再在 apply_all() 里加对应生效逻辑。

const CONFIG_PATH := "user://settings.cfg"

## 支持的语言（先占位，实际翻译表后续接入）
const LANGUAGES := {
	"zh_CN": "简体中文",
	"en": "English",
	"ja": "日本語",
}

signal setting_changed(section: String, key: String, value: Variant)

var _config := ConfigFile.new()


func _ready() -> void:
	load_settings()


## 全部默认值。新增设置项写这里。
func _defaults() -> Dictionary:
	return {
		"privacy": {"anonymous_tower_data": true},
		"audio": {
			"master_volume": 1.0,
			"music_volume": 0.8,
			"sfx_volume": 1.0,
			"voice_volume": 1.0,
			"mute_all_voice": false,  # 统一关闭剧情、怪物、助战与终结技配音
		},
		"game": {
			"language": "zh_CN",
			"text_speed": 40.0,       # 打字机速度：字/秒，0 表示瞬间全部显示
			"auto_advance": false,    # AUTO 自动播放（对话框里按 A 也能切）
		},
		"dialogue": {
			"box_opacity": 0.9,       # 对话框背景不透明度
			"char_rise": true,        # 打字机逐字淡入 + 上浮
			"auto_delay": 1.6,        # AUTO 模式每句停留秒数
			"voice_enabled": true,    # 播放配音
			"voice_wait": true,       # 配音没播完时，按"继续"先打断语音再推进
		},
		"battle": {
			"portrait_styles": {}, # Cosmetic portrait choice per battle character id.
			"battle_speed": 1.0,      # 特效模式：1倍速 / 2倍速
			"ultimate_presentation": true,
			"simple_effects": false,
			"show_damage_number": true,
			"confirm_commands": false, # 指令是否需要二次确认（默认关闭，可在战斗设置里开启）
		},
		"video": {
			"fullscreen": false,
			"screen_shake": 1.0,
		},
	}


func load_settings() -> void:
	var defaults := _defaults()
	for section: String in defaults:
		for key: String in defaults[section]:
			_config.set_value(section, key, defaults[section][key])

	if FileAccess.file_exists(CONFIG_PATH):
		var err := _config.load(CONFIG_PATH)
		if err != OK:
			push_warning("settings.cfg 读取失败（错误码 %d），已回退到默认设置。" % err)

	apply_all()


func save_settings() -> void:
	var err := _config.save(CONFIG_PATH)
	if err != OK:
		push_warning("settings.cfg 保存失败（错误码 %d）" % err)


func get_value(section: String, key: String, fallback: Variant = null) -> Variant:
	return _config.get_value(section, key, fallback)


func set_value(section: String, key: String, value: Variant) -> void:
	if section == "battle" and key == "battle_speed":
		value = 2.0 if float(value) >= 1.5 else 1.0
	_config.set_value(section, key, value)
	apply_section(section)
	setting_changed.emit(section, key, value)


func portrait_style(hero_id: String) -> String:
	var styles: Variant = get_value("battle", "portrait_styles", {})
	if styles is Dictionary and styles.has(hero_id):
		var selected := String(styles[hero_id])
		if selected in ["original", "retro_pixel"]: return selected
	# Existing global preferences remain the initial style until a character overrides them.
	var legacy := String(get_value("battle", "portrait_style", "original"))
	return "retro_pixel" if legacy == "retro_pixel" else "original"


func set_portrait_style(hero_id: String, style: String) -> void:
	if hero_id.is_empty(): return
	var selected := "retro_pixel" if style == "retro_pixel" else "original"
	var stored: Variant = get_value("battle", "portrait_styles", {})
	var styles: Dictionary = stored.duplicate() if stored is Dictionary else {}
	styles[hero_id] = selected
	set_value("battle", "portrait_styles", styles)


## Presentation clock only: never change Engine.time_scale or battle rules.
## Travel/contact values stay in authored seconds; convert once at the wait site.
func battle_effect_speed() -> float:
	return 2.0 if float(get_value("battle", "battle_speed", 1.0)) >= 1.5 else 1.0


func ultimate_presentation_enabled() -> bool:
	return bool(get_value("battle", "ultimate_presentation", true))


func all_voice_enabled() -> bool:
	return not bool(get_value("audio", "mute_all_voice", false))


func simple_battle_effects() -> bool:
	return bool(get_value("battle", "simple_effects", false))


func battle_tween(owner_node: Node) -> Tween:
	return owner_node.create_tween().set_speed_scale(battle_effect_speed())


func battle_timer(seconds: float) -> SceneTreeTimer:
	return get_tree().create_timer(seconds / battle_effect_speed())


func battle_msec(milliseconds: float) -> int:
	return roundi(milliseconds / battle_effect_speed())


## 重新应用全部设置（读档、切换语言后调用）
func apply_all() -> void:
	for section: String in ["audio", "game", "dialogue", "battle", "video"]:
		apply_section(section)


func apply_section(section: String) -> void:
	match section:
		"audio":
			AudioManager.apply_volumes()
		"video":
			_apply_video()
		# "dialogue" 的项由 DialogueBox 每帧/样式刷新时自行读取，这里不需要额外动作


func _apply_video() -> void:
	if (OS.has_feature("tower_release") or preload("res://scripts/ui/tower_mobile.gd").enabled()) and (OS.has_feature("android") or OS.has_feature("web")): return
	var want_fullscreen: bool = bool(_config.get_value("video", "fullscreen", false))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if want_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
