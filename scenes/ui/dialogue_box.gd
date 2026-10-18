extends CanvasLayer
## 通用对话框（自动加载单例 DialogueBox）
##
## 版式参考 LingChat 的 galgame 对话框：贴底全宽的半透明框、左侧立绘位、
## 说话人名牌 + 情绪标签、逐字淡入上浮的打字机、右下"继续"指示三角；
## 另外带 **对话回顾（Backlog）**、**AUTO 自动播放**、**按住 Ctrl 快进**。
## 外观全部来自 scripts/ui/dialogue_style.gd（唯一来源），本文件只管逻辑与版式摆放。
##
## 对话数据格式（纯字典，方便以后换成外部 JSON/资源文件）：
##
##   单条： {"speaker": "周明远", "text": "肚子好饿……"}
##   可选字段：
##     "portrait" : "res://...png"（也可以直接给 Texture2D）；不给就按说话人名自动找
##     "bust"     : "res://...png"  半身立绘（框外左侧，正式立绘用；不给就不显示）
##     "emotion"  : "无语"          情绪标签，显示在名牌右边
##     "voice"    : "ch01_0012"     配音：台词 ID（表见 scripts/data/voice_bank.gd），
##                                  也可以直接写 "res://...ogg" 路径
##     "flag" / "flag_value"        走过这一行就写入剧情开关
##   序列： [ {...}, {...} ]
##   分支： {"speaker": "...", "text": "...", "choices": [
##              {"text": "选项文字", "next": [ {...后续...} ], "flag": "some_flag"},
##          ]}
##
## 用法：
##   await DialogueBox.say("周明远", "肚子好饿……")
##   await DialogueBox.say("陈默", "……", null, "无语", "ch01_0012")
##   var picked := await DialogueBox.ask("周明远", "去哪？", [{"text": "食堂"}, {"text": "回宿舍"}])
##   await DialogueBox.play_script([...])   # 播放整段（支持分支与 flag）
##   await DialogueBox.play_script([...], {"auto_only": true})  # 强制自动播放、不可手动跳过
##
## 按键：继续 = 空格 / 回车 / E / 鼠标左键；选项 = ↑↓ + 确定键；
##       回顾 = H 或鼠标滚轮上滚；自动播放 = A；快进 = 按住 Ctrl。

const HINT_ADVANCE := "空格 / 回车 / E / 鼠标左键 继续　·　H 回顾　·　A 自动　·　Ctrl 快进"
const HINT_CHOICE := "↑↓ 选择　空格 / 回车 / E 或鼠标点击 确定"

## 回顾里最多保留多少条（防止长流程把内存撑起来）
const HISTORY_MAX := 200
## 打字音效（每 N 个字响一次）；没有素材时完全静默
const TYPE_SFX_PATH := "res://assets/audio/sfx/type.ogg"
const TYPE_SFX_EVERY := 3

signal finished
signal choice_picked(index: int, choice: Dictionary)
## 每显示一行都会发（配音系统 / 存档 / 成就都可以挂在这里，不必改对话框）
signal line_shown(speaker: String, text: String, emotion: String)
signal auto_changed(enabled: bool)

## 内部信号：打字机把当前句子显示完了 / 玩家选中了某个选项
signal _typing_done
signal _choice_made(index: int)

var _box_root: Node2D
var _backdrop: ColorRect
var _shade: TextureRect
var _photo_overlay: TextureRect
var _bust: TextureRect
var _window: PanelContainer
var _portrait_frame: PanelContainer
var _portrait: TextureRect
var _name_plate: PanelContainer
var _speaker: Label
var _emotion: Label
var _mode_tag: Label
var _text: RichTextLabel
var _hint: Label
var _indicator: Label
var _choices: VBoxContainer
var _proto: Button
var _log: DialogueLog

var _char_rise: CharRiseEffect
var _type_sfx: AudioStream = null

var _active := false
var _typing := false
var _type_progress := 0.0
var _full_text := ""
var _awaiting_advance := false
var _choice_open := false
var _log_open := false
var _auto := false
var _auto_timer := 0.0
var _skip := false
## 特殊剧情段落的自动播放锁：禁止点击、确认键、Ctrl 快进、A 切换和回顾。
var _auto_only := false
## 可选的按台词触发点；用于让一段对白的前半段仍可手动推进。
var _auto_only_trigger_text := ""
var _auto_only_end_text := ""
var _auto_previous_auto := false
var _auto_previous_skip := false
var _music_track := ""
var _music_previous_track := ""
var _music_override_started := false
var _auto_delay_override := -1.0
var _auto_delay_trigger_override := -1.0
var _text_speed_override := -1.0
var _text_speed_trigger_override := -1.0
var _text_pop_override := false
var _text_pop_active := false
var _sfx_step := 0
## "当前这一段已经被收掉了"（`hide_box()` 置真、`play_script()` 开头清掉）。
## 用途见 `show_box()`：回标题时收回来的框，不能被还按着的协程重新叫出来。
var _finished := true
var _playback_generation := 0
var _history: Array[Dictionary] = []
var _photo_tween: Tween = null
var _spirit_font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40

	_box_root = get_node("BoxRoot") as Node2D
	_backdrop = get_node("BoxRoot/Backdrop") as ColorRect
	_shade = get_node("BoxRoot/Shade") as TextureRect
	_photo_overlay = get_node("BoxRoot/PhotoOverlay") as TextureRect
	_bust = get_node("BoxRoot/Bust") as TextureRect
	_window = get_node("BoxRoot/Window") as PanelContainer
	_portrait_frame = get_node("BoxRoot/Window/HBox/PortraitFrame") as PanelContainer
	_portrait = get_node("BoxRoot/Window/HBox/PortraitFrame/Portrait") as TextureRect
	_name_plate = get_node("BoxRoot/Window/HBox/Right/Header/NamePlate") as PanelContainer
	_speaker = get_node("BoxRoot/Window/HBox/Right/Header/NamePlate/Speaker") as Label
	_emotion = get_node("BoxRoot/Window/HBox/Right/Header/EmotionTag") as Label
	_mode_tag = get_node("BoxRoot/Window/HBox/Right/Header/ModeTag") as Label
	_text = get_node("BoxRoot/Window/HBox/Right/Body/Text") as RichTextLabel
	_hint = get_node("BoxRoot/Window/HBox/Right/Footer/Hint") as Label
	_indicator = get_node("BoxRoot/Window/HBox/Right/Footer/Indicator") as Label
	_choices = get_node("BoxRoot/Choices") as VBoxContainer
	_proto = get_node("BoxRoot/Choices/ChoiceProto") as Button

	_shade.texture = DialogueStyle.make_shade_texture()
	var spirit_font := SystemFont.new()
	spirit_font.font_names = PackedStringArray(["KaiTi", "Microsoft YaHei"])
	_spirit_font = spirit_font
	_apply_styles()
	_build_char_rise()
	_build_log_panel()
	_blink_indicator()

	if ResourceLoader.exists(TYPE_SFX_PATH):
		_type_sfx = load(TYPE_SFX_PATH) as AudioStream

	_auto = bool(Settings.get_value("game", "auto_advance", false))
	_refresh_mode_tag()

	hide_box()
	set_process_input(false)
	get_viewport().size_changed.connect(_relayout)
	Settings.setting_changed.connect(_on_setting_changed)
	_relayout()


# ---------------------------------------------------------------- 版式与样式

## 显式摆放：CanvasLayer 下的控件同样不能用锚点预设（原因见 UiKit.fill_viewport）。
## 位置按基准分辨率 1920x1080 设计，其余分辨率按比例换算，保证版式一致。
func _relayout() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var view := vp.get_visible_rect().size
	UiKit.place(_backdrop, Rect2(Vector2.ZERO, view))
	UiKit.place(_shade, DialogueStyle.shade_rect(view))
	# 合照浮层放在画面上半部，给底部对话框留出完整阅读空间。
	var photo_w := minf(view.x * 0.72, 1180.0)
	var photo_h := minf(view.y * 0.52, 620.0)
	UiKit.place(_photo_overlay, Rect2((view.x - photo_w) * 0.5, view.y * 0.07, photo_w, photo_h))
	UiKit.place(_window, DialogueStyle.box_rect(view))
	UiKit.place(_choices, DialogueStyle.choices_rect(view))
	UiKit.place(_bust, DialogueStyle.bust_rect(view))
	if _log != null:
		_log.relayout(view)


## 样式只在启动与"外观设置变化"时套一次（不是每帧），改风格只动 DialogueStyle
func _apply_styles() -> void:
	_backdrop.color = DialogueStyle.BACKDROP
	_window.add_theme_stylebox_override("panel", DialogueStyle.box_style())
	_portrait_frame.add_theme_stylebox_override("panel", DialogueStyle.portrait_frame_style())
	_name_plate.add_theme_stylebox_override("panel", DialogueStyle.name_plate_style())

	_speaker.add_theme_font_size_override("font_size", DialogueStyle.FONT_NAME)
	_speaker.add_theme_color_override("font_color", DialogueStyle.NAME_TEXT)
	_emotion.add_theme_font_size_override("font_size", DialogueStyle.FONT_EMOTION)
	_emotion.add_theme_color_override("font_color", DialogueStyle.EMOTION_TEXT)
	_mode_tag.add_theme_font_size_override("font_size", DialogueStyle.FONT_MODE)
	_mode_tag.add_theme_color_override("font_color", DialogueStyle.MODE_TEXT)
	_text.add_theme_font_size_override("normal_font_size", DialogueStyle.FONT_TEXT)
	_text.add_theme_color_override("default_color", DialogueStyle.text_color())
	_hint.add_theme_font_size_override("font_size", DialogueStyle.FONT_HINT)
	_hint.add_theme_color_override("font_color", DialogueStyle.HINT_TEXT)
	_indicator.add_theme_font_size_override("font_size", DialogueStyle.FONT_HINT + 6)
	_indicator.add_theme_color_override("font_color", DialogueStyle.INDICATOR_TEXT)
	_proto.add_theme_font_size_override("font_size", DialogueStyle.FONT_CHOICE)


func _build_char_rise() -> void:
	_char_rise = CharRiseEffect.new()
	_char_rise.label = _text
	# 用显式类型的数组赋值：custom_effects 是 Array[RichTextEffect]，
	# 直接塞无类型数组字面量会被拒（并且不能对它 append，属性返回的是共享副本）。
	var effects: Array[RichTextEffect] = []
	effects.append(_char_rise)
	_text.custom_effects = effects


func _build_log_panel() -> void:
	_log = DialogueLog.new()
	_log.name = "Log"
	add_child(_log)
	_log.closed.connect(_on_log_closed)


## "继续"指示三角：缓慢呼吸式闪烁，提示可以按键了
func _blink_indicator() -> void:
	_indicator.modulate.a = 0.0
	var tween := create_tween().set_loops()
	tween.tween_property(_indicator, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_indicator, "modulate:a", 0.2, 0.55).set_trans(Tween.TRANS_SINE)


func _on_setting_changed(section: String, key: String, _value: Variant) -> void:
	if section == "dialogue":
		_apply_styles()
	elif section == "game" and key == "auto_advance":
		_auto = bool(Settings.get_value("game", "auto_advance", false))
		_refresh_mode_tag()


func _rise_enabled() -> bool:
	return bool(Settings.get_value("dialogue", "char_rise", true))


func is_active() -> bool:
	return _active


func show_box() -> void:
	# 只显示对话框本体（BoxRoot），不碰 CanvasLayer.visible：
	# 回顾面板挂在同一个 CanvasLayer 下，隐藏整个 CanvasLayer 会把面板一起藏掉。
	#
	# ⚠️ **已经被收掉的那一次不算**（`_finished`）：回标题时 `hide_box()` 会把当前这一行
	#    收掉，而那个正在 `await` 的协程只是**暂时**被按住的（这里没有真正的取消机制）——
	#    一旦它在下一帧恢复（例如玩家在标题画面上按了一下继续），`play_script()` 会接着
	#    调 `_show_line()` → 这里，于是对话框**又在标题画面上冒出来**。
	#    这是用户 2026-09-20 实报的那条："在对话中点 esc 暂停、然后返回标题，对话还在"。
	if _finished:
		return
	_box_root.visible = true
	_active = true
	set_process_input(true)


func hide_box() -> void:
	_box_root.visible = false
	_active = false
	_typing = false
	_awaiting_advance = false
	# ⚠️ 标记"这一段已经被收掉了"：见 `show_box()` —— 被按住的协程恢复时不该再把框叫回来。
	_finished = true
	_choice_open = false
	_set_indicator(false)
	_set_log_open(false)
	Voice.stop()
	_clear_choices()
	set_process_input(false)


## 播放一段脚本前把它标记成"活的"（与 `hide_box()` 里那句 `_finished = true` 配对）。
## 见 `show_box()` 的说明：被 `hide_box()` 收掉之后，同一段协程不该再把框叫回来。
func _mark_live() -> void:
	_finished = false


# ---------------------------------------------------------------- 对外 API

## 显示一句话并等玩家按键继续。
## emotion / voice 是可选扩展（LingChat 的情绪标签 + 配音），老调用方式不受影响。
func say(speaker: String, text: String, portrait: Variant = null,
		emotion: String = "", voice: Variant = null) -> void:
	_show_line(speaker, text, portrait, emotion, voice, null)
	await _wait_for_advance()
	hide_box()


## 显示一句话并给选项，返回被选中的下标
func ask(speaker: String, text: String, choices: Array, portrait: Variant = null) -> int:
	_show_line(speaker, text, portrait, "", null, null)
	await _wait_for_typing_done()
	var picked := await _present_choices(choices)
	hide_box()
	return picked


## 播放一整段对话脚本（支持 choices.next 分支与 flag 写入）
func play_script(script: Array, options: Dictionary = {}) -> void:
	_playback_generation += 1
	var generation := _playback_generation
	var force_auto := bool(options.get("auto_only", false))
	var previous_auto := _auto
	var previous_skip := _skip
	_auto_previous_auto = previous_auto
	_auto_previous_skip = previous_skip
	_auto_only = false
	_auto_only_trigger_text = String(options.get("auto_only_from_text", ""))
	_auto_only_end_text = String(options.get("auto_only_end_text", ""))
	_music_track = String(options.get("music_track", ""))
	_music_override_started = false
	_auto_delay_override = -1.0
	_auto_delay_trigger_override = float(options.get("auto_delay", -1.0))
	_text_speed_override = -1.0
	_text_speed_trigger_override = float(options.get("text_speed", -1.0))
	_text_pop_override = bool(options.get("text_pop", false))
	_text_pop_active = false
	if force_auto:
		_enter_auto_only()
		_auto_delay_override = _auto_delay_trigger_override
		_text_speed_override = _text_speed_trigger_override
		_text_pop_active = _text_pop_override
		_start_music_override()
	# 新的一段开始 = "活的"（见 `_finished` 与 `show_box()` 的说明）
	_mark_live()
	await _run_segment(script)
	if generation != _playback_generation: return
	hide_box()
	_stop_music_override()
	finished.emit()
	_auto_only = false
	# 普通对话中 AUTO 是玩家的全局播放偏好，不能在每个 play_script() 结束时
	# 恢复成进入本段前的值，否则玩家在一段对话里按 A 打开 AUTO，下一段又会被关掉。
	# 只有 auto_only 剧情段需要恢复进入前的控制状态。
	if force_auto:
		_auto = previous_auto
		_skip = previous_skip
	_auto_timer = 0.0
	_auto_only_trigger_text = ""
	_auto_only_end_text = ""
	_music_track = ""
	_auto_delay_override = -1.0
	_auto_delay_trigger_override = -1.0
	_text_speed_override = -1.0
	_text_speed_trigger_override = -1.0
	_text_pop_override = false
	_text_pop_active = false
	_refresh_mode_tag()


func _enter_auto_only() -> void:
	if _auto_only:
		return
	# 不改 Settings，避免剧情段结束后把玩家原来的 AUTO 偏好覆盖掉。
	_auto_only = true
	_auto = true
	_skip = false
	_auto_timer = 0.0
	_auto_delay_override = _auto_delay_trigger_override
	_text_speed_override = _text_speed_trigger_override
	_text_pop_active = _text_pop_override
	_refresh_mode_tag()


func _exit_auto_only() -> void:
	if not _auto_only:
		return
	_auto_only = false
	_auto = _auto_previous_auto
	_skip = _auto_previous_skip
	_auto_timer = 0.0
	_auto_delay_override = -1.0
	_text_speed_override = -1.0
	_text_pop_active = false
	if _char_rise != null:
		_char_rise.reveal_count = -1
	_refresh_mode_tag()


func _start_music_override() -> void:
	if _music_override_started or _music_track == "" or not Music.has_track(_music_track):
		return
	_music_previous_track = Music.current_track
	Music.set_override(_music_track, 0.8)
	_music_override_started = true


func _stop_music_override() -> void:
	if not _music_override_started:
		return
	Music.clear_override()
	if _music_previous_track != "" and Music.has_track(_music_previous_track):
		Music.play(_music_previous_track, 0.8)
	else:
		Music.stop(0.8)
	_music_previous_track = ""
	_music_override_started = false


## 打开 / 关闭对话回顾面板
func open_log() -> void:
	if _log == null or _auto_only:
		return
	_set_log_open(true)


func _on_log_closed() -> void:
	_log_open = false


func _set_log_open(open: bool) -> void:
	_log_open = open
	if _log == null:
		return
	if open:
		_log.open(_history)
	else:
		_log.close()


func history_entries() -> Array[Dictionary]:
	return _history


func clear_history() -> void:
	_history.clear()


## 用一份**外部历史**替换当前回顾（读档时调）。
##
## ⚠️ 为什么要有它（用户 2026-09-20 实报）：回顾面板挂在 `DialogueBox` 这个
##    **跨场景常驻**的单例上，而"存档"只存 `GameState` —— 于是
##    "从 A 槽退出、进 B 槽"之后，回顾里还是 **A 槽那一路的台词**。
##    现在回顾跟着存档走（`SaveSystem` 存/读时带上它），进出槽位各归各的。
## ⚠️ 存进 JSON 再读回来的是**无类型数组**（`Array`），里面的元素也不保证是字典
##    （手改存档、旧版本）—— 所以这里逐条过一遍，脏数据直接丢掉，
##    而不是等 `DialogueLog._render()` 里崩。
func restore_history(entries: Array) -> void:
	_history.clear()
	for entry_variant in entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var text := String(entry.get("text", ""))
		var speaker := String(entry.get("speaker", ""))
		if text == "" and speaker == "":
			continue
		_history.append({
			"speaker": speaker,
			"text": text,
			"emotion": String(entry.get("emotion", "")),
		})
		if _history.size() >= HISTORY_MAX:
			break


## **开发期/自检专用**：直接塞一条进回顾（走查要验"回顾跟着存档走"时用）。
## 正常游玩不会调用它 —— 回顾只由 `_show_line()` 往里写。
func debug_push_history(speaker: String, text: String, emotion: String = "") -> void:
	_push_history(speaker, text, emotion)


# ---------------------------------------------------------------- 内部播放

func _run_segment(segment: Array) -> void:
	var generation := _playback_generation
	for entry_variant in segment:
		if generation != _playback_generation: return
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant

		var flag := String(entry.get("flag", ""))
		if flag != "":
			GameFlow.set_flag(flag, entry.get("flag_value", true))

		var speaker := String(entry.get("speaker", ""))
		var text := String(entry.get("text", ""))
		if not _auto_only and _auto_only_trigger_text != "" \
				and text.find(_auto_only_trigger_text) >= 0:
			_enter_auto_only()
			_start_music_override()
		var end_auto_only_after_line := _auto_only and _auto_only_end_text != "" \
				and text.find(_auto_only_end_text) >= 0
		var portrait: Variant = entry.get("portrait", null)
		var emotion := String(entry.get("emotion", ""))
		if portrait == null and entry.has("portrait_form"):
			portrait = Portraits.resolve(Speakers.base_name(speaker), emotion, String(entry["portrait_form"]))
		var bust: Variant = entry.get("bust", null)
		var voice: Variant = entry.get("voice", null)
		var photo: Variant = entry.get("photo", null)
		_set_photo_overlay(photo)

		if entry.has("choices"):
			var choices: Array = entry["choices"]
			if choices.is_empty():
				continue
			_show_line(speaker, text, portrait, emotion, voice, bust,
				String(entry.get("portrait_form", "")))
			await _wait_for_typing_done()
			if generation != _playback_generation: return
			var picked := await _present_choices(choices)
			if generation != _playback_generation or picked < 0: return
			var choice: Dictionary = choices[picked]
			var choice_flag := String(choice.get("flag", ""))
			if choice_flag != "":
				GameFlow.set_flag(choice_flag, choice.get("flag_value", true))
			if choice.has("next"):
				await _run_segment(choice["next"])
			if generation != _playback_generation: return
			if end_auto_only_after_line:
				_exit_auto_only()
				_stop_music_override()
		else:
			_show_line(speaker, text, portrait, emotion, voice, bust,
				String(entry.get("portrait_form", "")))
			await _wait_for_advance()
			if generation != _playback_generation: return
			if end_auto_only_after_line:
				_exit_auto_only()
				_stop_music_override()
	_set_photo_overlay(null)


func _show_line(speaker: String, text: String, portrait: Variant,
		emotion: String = "", voice: Variant = null, bust: Variant = null,
		portrait_form: String = "") -> void:
	show_box()
	_clear_choices()
	_choice_open = false
	if _log_open:
		_set_log_open(false)
	_full_text = text
	_type_progress = 0.0
	_sfx_step = 0
	_auto_timer = 0.0
	_awaiting_advance = false
	_typing = true
	_set_indicator(false)

	var has_speaker := speaker != ""
	# 名单上写**显示名**（例如「艾莉娜（Alyina）」），但往下所有查表（头像/配音/回顾）
	# 都走规范名 —— 两件事分开的理由见 `scripts/data/speakers.gd` 的文件头。
	_speaker.text = Speakers.display(speaker)
	_speaker.visible = has_speaker
	_name_plate.visible = has_speaker
	var spirit_line := Speakers.base_name(speaker) == "周明远" and (
		portrait_form == "spirit" or (portrait_form == "" and
		GameState.location.begins_with("highschool.") and HighschoolData.is_night(GameState.phase)))
	_speaker.add_theme_color_override("font_color", Color("#9beeff") if spirit_line else DialogueStyle.NAME_TEXT)
	_text.add_theme_color_override("default_color", Color("#caf6ff") if spirit_line else DialogueStyle.text_color())
	if spirit_line:
		_speaker.add_theme_font_override("font", _spirit_font)
		_text.add_theme_font_override("normal_font", _spirit_font)
	else:
		_speaker.remove_theme_font_override("font")
		_text.remove_theme_font_override("normal_font")

	_emotion.text = "「%s」" % emotion if emotion != "" else ""
	_emotion.visible = emotion != ""

	var tex := _resolve_texture(portrait)
	# 数据里没给立绘时，按说话人名自动找头像（见 scripts/data/portraits.gd）。
	# ⚠️ 走 `Speakers.base_name()` 而不是 `canonical()`：内心独白的说话人是
	#    `周明远（内心）`（见 `Speakers`），折出"这个人本身"才查得到头像 ——
	#    用 canonical() 的话它原样返回，`Portraits.resolve()` 查不到、立绘**静默**消失。
	if tex == null:
		tex = Portraits.resolve(Speakers.base_name(speaker), emotion)
	_portrait.texture = tex
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if tex != null and tex.get_width() >= 256 else CanvasItem.TEXTURE_FILTER_NEAREST
	# 没立绘时收掉整块立绘位，避免留一个空框
	_portrait_frame.visible = tex != null

	var bust_tex := _resolve_texture(bust)
	_bust.texture = bust_tex
	_bust.visible = bust_tex != null

	_hint.text = "自动播放中…" if _auto_only else HINT_ADVANCE
	_hint.visible = true
	_refresh_mode_tag()
	# 回顾面板显示的和名牌上看到的一致（否则"刚看到艾莉娜（Alyina），回顾里却是艾莉娜"）
	_push_history(Speakers.display(speaker), text, emotion)

	# 配音：缺素材时 Voice 会静默返回 false，对话框照常往下走
	if bool(Settings.get_value("dialogue", "voice_enabled", true)):
		Voice.play(voice, speaker)

	line_shown.emit(speaker, text, emotion)

	_begin_text()
	# text_speed <= 0 表示瞬间显示
	if _current_text_speed() <= 0.01 or text == "":
		_finish_typing()


## 设置正文。有逐字上浮时整行包一层 [rise]（效果见 rich_text_char_rise.gd）
func _begin_text() -> void:
	if _rise_enabled() or _text_pop_active:
		_text.text = "[rise]%s[/rise]" % _full_text
	else:
		_text.text = _full_text
	_text.visible_characters = -1 if _text_pop_active else 0
	if _char_rise != null:
		_char_rise.reveal_count = 0 if _text_pop_active else -1


func _current_text_speed() -> float:
	return _text_speed_override if _text_speed_override >= 0.0 \
			else float(Settings.get_value("game", "text_speed", 40.0))


func _resolve_texture(value: Variant) -> Texture2D:
	if value == null:
		return null
	if value is Texture2D:
		return value as Texture2D
	var path := String(value)
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## 在指定台词出现时把实体照片轻轻浮到画面上方；进入下一句时淡出。
## 这是一项通用行字段，其他对话不带 `photo` 时不会改变原有版式。
func _set_photo_overlay(value: Variant) -> void:
	if _photo_overlay == null:
		return
	if _photo_tween != null and _photo_tween.is_valid():
		_photo_tween.kill()
	var tex := _resolve_texture(value)
	if tex == null:
		_photo_tween = create_tween()
		_photo_tween.tween_property(_photo_overlay, "modulate:a", 0.0, 0.18)
		_photo_tween.tween_callback(func() -> void: _photo_overlay.visible = false)
		return
	_photo_overlay.texture = tex
	_photo_overlay.visible = true
	_photo_overlay.modulate.a = 0.0
	_photo_tween = create_tween()
	_photo_tween.tween_property(_photo_overlay, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_SINE)


func _push_history(speaker: String, text: String, emotion: String) -> void:
	if text == "" and speaker == "":
		return
	_history.append({"speaker": speaker, "text": text, "emotion": emotion})
	if _history.size() > HISTORY_MAX:
		# slice() 返回无类型数组，必须 assign 回类型化数组
		var trimmed: Array[Dictionary] = []
		trimmed.assign(_history.slice(_history.size() - HISTORY_MAX))
		_history = trimmed


# ---------------------------------------------------------------- 打字机

func _process(delta: float) -> void:
	if _active:
		_update_skip_state()
	if _skip and _active and not _choice_open and not _log_open:
		if _typing:
			_finish_typing()
		if _awaiting_advance:
			_awaiting_advance = false

	if not _typing:
		_update_auto(delta)
		return

	var speed := _current_text_speed()
	if speed <= 0.01:
		_finish_typing()
		return
	_type_progress += delta * speed
	var shown := int(_type_progress)
	if shown >= _full_text.length():
		_finish_typing()
		return
	# 立约段保持整行布局，只让每个字符在自己的位置逐个弹出，避免从左到右裁切整行。
	if _text_pop_active:
		_char_rise.reveal_count = shown
		_text.visible_characters = -1
	else:
		# 普通对白用 visible_characters 控制显示进度，避免切断 BBCode
		_text.visible_characters = shown
	_maybe_type_sfx(shown)


## 按住 Ctrl = 快进（只在对话进行中生效；有选项时快进会跳过玩家选择，所以不生效）
func _update_skip_state() -> void:
	if _auto_only:
		if _skip:
			_skip = false
			_refresh_mode_tag()
		return
	var want: bool = _active and not _choice_open and not _log_open \
			and Input.is_key_pressed(KEY_CTRL)
	if want == _skip:
		return
	_skip = want
	if _skip:
		if _typing:
			_finish_typing()
		Voice.stop()
	_refresh_mode_tag()


func _maybe_type_sfx(shown: int) -> void:
	if _type_sfx == null:
		return
	var step := shown / TYPE_SFX_EVERY
	if step <= _sfx_step:
		return
	_sfx_step = step
	AudioManager.play_sfx(_type_sfx, -8.0, randf_range(0.96, 1.04))


func _finish_typing() -> void:
	if not _typing:
		return
	_typing = false
	# 结束态一定是"完全正常显示"：去掉 [rise] 包裹，避免最后一帧残留半透明
	_text.text = _full_text
	_text.visible_characters = -1
	if _char_rise != null:
		_char_rise.reveal_count = -1
	_typing_done.emit()


func _wait_for_typing_done() -> void:
	if _typing:
		await _typing_done


func _wait_for_advance() -> void:
	var generation := _playback_generation
	_awaiting_advance = true
	_set_indicator(true)
	while _awaiting_advance and _active and generation == _playback_generation:
		await get_tree().process_frame
	if generation != _playback_generation: return
	_set_indicator(false)


## 取消整段对白（包括等待选项的分支），不执行尚未到达的剧情标记。
func cancel_playback() -> void:
	_playback_generation += 1
	hide_box()
	_stop_music_override()
	_exit_auto_only()
	_typing_done.emit()
	_choice_made.emit(-1)
	_set_photo_overlay(null)


func _set_indicator(enabled: bool) -> void:
	if _indicator != null:
		_indicator.visible = enabled


# ---------------------------------------------------------------- 自动播放 / 快进

func _update_auto(delta: float) -> void:
	if not _auto or not _awaiting_advance or _choice_open or _log_open:
		return
	# 配音还没播完就不推进（AUTO 是为了"边听边看"，不是抢拍）
	if Voice.is_playing() and _wait_voice():
		_auto_timer = 0.0
		return
	_auto_timer += delta
	var auto_delay := _auto_delay_override if _auto_delay_override >= 0.0 \
			else float(Settings.get_value("dialogue", "auto_delay", 1.6))
	if _auto_timer >= auto_delay:
		_auto_timer = 0.0
		_awaiting_advance = false


func _toggle_auto() -> void:
	if _auto_only:
		return
	_auto = not _auto
	_auto_timer = 0.0
	if _auto:
		_skip = false
	Settings.set_value("game", "auto_advance", _auto)
	_refresh_mode_tag()
	auto_changed.emit(_auto)


func _refresh_mode_tag() -> void:
	var parts := PackedStringArray()
	if _skip:
		parts.append("SKIP")
	if _auto:
		parts.append("AUTO")
	if _auto_only:
		parts.append("LOCK")
	_mode_tag.text = "　".join(parts)
	_mode_tag.visible = not parts.is_empty()


## 配音未播完时，按"继续"先打断语音而不是跳台词（galgame 惯例）
func _wait_voice() -> bool:
	return bool(Settings.get_value("dialogue", "voice_wait", true))


# ---------------------------------------------------------------- 选项

func _present_choices(choices: Array) -> int:
	_clear_choices()
	_choice_open = true
	_hint.text = HINT_CHOICE

	var buttons: Array[Button] = []
	for i in choices.size():
		var cfg: Dictionary = choices[i]
		var b := Button.new()
		b.text = String(cfg.get("text", "…"))
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_size_override("font_size", DialogueStyle.FONT_CHOICE)
		for state: String in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, DialogueStyle.choice_style(state))
		b.add_theme_color_override("font_color", DialogueStyle.DEFAULT_TEXT_COLOR)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_focus_color", Color.WHITE)
		_choices.add_child(b)
		var idx := i
		b.pressed.connect(func() -> void: _choose(idx))
		b.mouse_entered.connect(func() -> void: b.grab_focus())
		buttons.append(b)

	if not buttons.is_empty():
		buttons[0].grab_focus()

	var picked: int = await _choice_made
	_choice_open = false
	_clear_choices()
	return picked


func _choose(index: int) -> void:
	if not _choice_open:
		return
	choice_picked.emit(index, {})
	_choice_made.emit(index)


# ---------------------------------------------------------------- 开发期驱动接口
# 供 DevActions / DevAutotest 在无人操作的环境里推进对话（详见 scripts/debug/dev_actions.gd）。

## 当前是否正在等待玩家做选择
func has_choices() -> bool:
	return _choice_open


## 当前给出的选项数量
func choice_count() -> int:
	if not _choice_open:
		return 0
	var count := 0
	for child in _choices.get_children():
		if child is Button and child != _proto:
			count += 1
	return count


## 当前显示的说话人头像（供自检/测试核对；没头像时为 null）
func current_portrait() -> Texture2D:
	return _portrait.texture if _portrait != null else null


## 当前行的说话人名（调试用）
func current_speaker() -> String:
	return _speaker.text if _speaker != null else ""


## 当前行的情绪标签（没写 emotion 时为空串）
func current_emotion() -> String:
	if _emotion == null or not _emotion.visible:
		return ""
	return _emotion.text.trim_prefix("「").trim_suffix("」")


## 当前正文（去掉了打字机的 [rise] 包裹）
func current_text() -> String:
	return _full_text


## 回顾面板是否开着
func is_log_open() -> bool:
	return _log_open


## 已读台词条数（回顾面板的数据源）
func history_size() -> int:
	return _history.size()


## AUTO 自动播放是否开着
func is_auto() -> bool:
	return _auto


## 对话是否处于"按住 Ctrl 快进"状态
func is_skipping() -> bool:
	return _skip


## 对话框在屏幕上的实际矩形（版式断言用：必须是贴底全宽）
func box_rect() -> Rect2:
	return Rect2(_window.global_position, _window.size) if _window != null else Rect2()


## 逐字上浮效果是否已挂上（素材无关的行为断言）
func has_char_rise() -> bool:
	return _char_rise != null and _text != null and _text.custom_effects.has(_char_rise)


## 逐字上浮累计改动过的字符数（配 reset_char_rise_counter 用来断言"效果真的在跑"）
func char_rise_applied_chars() -> int:
	return _char_rise.applied_chars if _char_rise != null else 0


func reset_char_rise_counter() -> void:
	if _char_rise != null:
		_char_rise.applied_chars = 0


## 逐字上浮的诊断串：区分"根本没被引擎调用"和"调用了但没到该动的位置"
func char_rise_diag() -> String:
	if _char_rise == null:
		return "效果未创建"
	return "调用=%d 改动=%d 最近visible=%d 已注册=%s" % [
		_char_rise.calls, _char_rise.applied_chars, _char_rise.last_visible,
		str(has_char_rise())]


## "继续"指示三角当前是否可见
func indicator_visible() -> bool:
	return _indicator != null and _indicator.visible


## 调试状态串：一眼看清对话框内部处于哪个阶段
func debug_state() -> String:
	return "speaker=%s emotion=%s typing=%s 等推进=%s 立绘框可见=%s 头像=%s auto=%s skip=%s 回顾=%s 历史=%d" % [
		current_speaker(), current_emotion(), str(_typing), str(_awaiting_advance),
		str(_portrait_frame.visible if _portrait_frame != null else false),
		str(current_portrait()), str(_auto), str(_skip), str(_log_open), _history.size()]


## 等价于玩家按了一次"继续"：打字中则补全，等待中则推进
func debug_advance() -> void:
	if not _active or _auto_only:
		return
	if _typing:
		_finish_typing()
		return
	if _awaiting_advance:
		_awaiting_advance = false


## 直接选中第 index 个选项（选项未展开时忽略）
func debug_choose(index: int) -> void:
	if not _choice_open:
		return
	var buttons: Array[Button] = []
	for child in _choices.get_children():
		if child is Button and child != _proto:
			buttons.append(child as Button)
	if index < 0 or index >= buttons.size():
		push_warning("DialogueBox: 选项下标越界 %d（共 %d 项）" % [index, buttons.size()])
		return
	_choose(index)


## 切换 AUTO（等价于玩家按 A）
func debug_toggle_auto() -> void:
	_toggle_auto()


func debug_open_log() -> void:
	open_log()


func debug_close_log() -> void:
	_set_log_open(false)


func _clear_choices() -> void:
	if _choices == null:
		return
	for child in _choices.get_children():
		if child != _proto:
			child.queue_free()
	if _proto != null:
		_proto.visible = false


# ---------------------------------------------------------------- 输入

## 一次"继续"：打字中则立即补全整句（第一次点击），已在等待则推进（第二次点击）。
## 键盘与鼠标共用这一条逻辑，保证手感一致。
func _try_advance() -> void:
	if _typing:
		_finish_typing()
		get_viewport().set_input_as_handled()
		return
	# 语音还没播完：这一次"继续"只打断语音，不跳台词
	if _wait_voice() and Voice.is_playing():
		Voice.stop()
		get_viewport().set_input_as_handled()
		return
	if _awaiting_advance:
		_awaiting_advance = false
		_auto_timer = 0.0
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	# ⚠️ **暂停时一律不响应**（用户 2026-09-20："暂停界面应该优先级最高"）。
	#    对话框是常驻单例、`process_mode = ALWAYS`（暂停菜单里也能翻回顾），
	#    于是它比暂停菜单（`layer = 60`）**更早**拿到输入 —— 菜单开着的时候
	#    按空格/E/鼠标点，还会把底下的对话推掉。
	#    ⚠️ 回顾面板例外：它是对话框自己的功能，暂停里也允许看（面板自己处理按键）。
	if get_tree().paused and not _log_open:
		return
	if _log_open:
		return  # 回顾面板自己处理按键与滚轮
	if _auto_only:
		# 立约段落只能由 _update_auto 推进；所有手动跳过入口都屏蔽。
		return

	# 鼠标左键单击 = 继续；滚轮上滚 = 打开回顾（用户要求鼠标可操作）
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			open_log()
			get_viewport().set_input_as_handled()
			return
		if _choice_open:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_try_advance()
		return

	# 键盘：H 回顾 / A 自动（有选项时也能按 A，不影响选择）
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.physical_keycode == KEY_H:
			open_log()
			get_viewport().set_input_as_handled()
			return
		if k.physical_keycode == KEY_A:
			_toggle_auto()
			get_viewport().set_input_as_handled()
			return

	if _choice_open:
		return  # 有选项时方向键/回车交给按钮的焦点系统处理

	if not (event.is_action_pressed("ui_accept") or event.is_action_pressed("dialogue_advance")):
		return
	_try_advance()
