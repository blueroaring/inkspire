class_name StoryExamine
extends ExamineObject
## 带**剧情条件**的"查看"交互点：开关没打开时不出现；交互完写开关、发道具。
##
## 为什么需要它：`01_GOALS.md` 后半段的剧情点大多长在**本来就在场上的物件**上 ——
## 照相馆门口、宿舍书桌、宿舍床。为每一处写一个一次性 Area2D + 一坨 if 既重复又容易漏。
## 有了本脚本，场景脚本只填数据（见 `campus.gd::_build_photo_pickup` 与
## `dorm.gd::_build_photo_desk` / `_build_bed_rest`）。
##
## ⚠️ `required_flag` 关着时 `can_interact()` 返回 false —— 玩家**看不到提示、
##    Tab 也切不到它**（`player.gd` 只把 `can_interact()` 为真的收进候选）。
##    这比"看得见、按了却说'现在还不行'"干净：后者会在 HUD 上多一条噪音，
##    而且玩家会反复去按。
##
## ⚠️ 开关写在**对话播完之后**：玩家中途退出就不算完成，回来还能接着做。
##    这比"碰到就算"更符合直觉（与 `StoryData.roommate_photo_chat()` 里那句
##    "开关写在最后一行"是同一个口径）。

## ⚠️ `required_flag`（"没打开这个开关时本交互点完全不存在"）现在定义在**基类**
##    `Interactable` 里 —— 这里不再重复声明（同一个字段写两处会互相遮蔽）。
##    下面保留的是它**额外**的语义：`hide_after_flag`（做过一次就永久消失）。
## **做过一次之后就永久不再出现**（填"做完时会写上的那个开关"，通常与 `finish_flags` 同一个）。
##
## ⚠️ 一次性交互**不能只靠 `repeatable = false`**（2026-09-19 用户实报：
##    "躺在床上睡觉只应该触发一次；看那摞洗好的照片立下契约也只应该触发一次"）。
##    `repeatable = false` 只是 `ExamineObject` 里的 `_used` —— 那是**节点级**的、
##    不进存档：离开场景再回来就是一个新节点，`_used` 又是 false，剧情会**重播一遍**。
##    真正的一次性必须落在**剧情开关**上（`story_flags` 跟着存档走）。
@export var hide_after_flag: String = ""
## 交互完写入的开关（可多个）
@export var finish_flags: Array = []
## 交互完发放的道具 id（可多个）
@export var give_items: Array = []
## 交互完发道具时要不要播"获得了「X」"
@export var announce_items: bool = true
## 要不要在台词后面追加艾莉娜的插话（`AlyinaBanter`）。
## 默认开；**台词里已经写了她的反应**的那些剧情点把它关掉，免得一次交互里她说两回。
@export var allow_banter: bool = true
## 交互完把时间推到"下一个 hh:mm"（**负数 = 不动时间**）。
## 用途：宿舍床边那个"躺一会儿"要把时间推到**晚上** —— 而"晚间"正是
## `01_GOALS.md` 里后半段主线的触发条件（见 `GameFlow.wait_until` 的说明）。
@export var wait_until_hour: int = -1
@export var wait_until_minute: int = 0
## 过夜休息：淡出、黑屏跨天，再淡入；不添加额外对白。
@export var blackout_rest: bool = false
## 设为 true 时，这一整段剧情只能自动播放，玩家不能点击、按键、Ctrl 快进或打开回顾。
@export var auto_only: bool = false
## 留空则从对白第一行开始锁定；填写文本片段后，从包含该片段的台词行开始锁定。
@export var auto_only_from_text: String = ""
## 填写后，包含该片段的台词播完后解除自动播放锁。
@export var auto_only_end_text: String = ""
## 自动播放每行的停留秒数；负数表示沿用玩家设置。
@export var auto_delay: float = -1.0
## 逐字打字速度；负数表示沿用玩家设置。
@export var text_speed: float = -1.0
## true 时字符在固定位置逐个弹出，而不是裁切整行从左到右显示。
@export var text_pop: bool = false
## 交互期间临时覆盖场景 BGM；留空则沿用场景音乐。
@export var dialogue_music: String = ""


func can_interact() -> bool:
	if hide_after_flag != "" and GameFlow.has_flag(hide_after_flag):
		return false
	# `required_flag` 的判据在基类（`Interactable.can_interact()`）
	return super.can_interact()


func _interact() -> void:
	var was_moving := begin_dialogue_lock()
	if blackout_rest:
		await _rest_overnight()
		end_dialogue_lock(was_moving)
		return
	# 台词后面追加艾莉娜的插话（见 AlyinaBanter：她对大学生活好奇，主角自嘲废柴）
	var patched := DialoguePatch.apply(dialogue_id, lines)
	var output_lines := AlyinaBanter.with_banter(object_kind, patched) if allow_banter else patched
	var dialogue_options := {"auto_only": auto_only}
	if auto_only_from_text != "":
		dialogue_options["auto_only_from_text"] = auto_only_from_text
	if auto_only_end_text != "":
		dialogue_options["auto_only_end_text"] = auto_only_end_text
	if auto_delay >= 0.0:
		dialogue_options["auto_delay"] = auto_delay
	if text_speed >= 0.0:
		dialogue_options["text_speed"] = text_speed
	if text_pop:
		dialogue_options["text_pop"] = true
	if dialogue_music != "":
		dialogue_options["music_track"] = dialogue_music
	await DialogueBox.play_script(output_lines, dialogue_options)

	if wait_until_hour >= 0:
		GameFlow.wait_until(wait_until_hour, wait_until_minute)
		# 时间一变可能正好跨进"晚间"—— 立刻判一次剧情触发，别让玩家"睡醒了还得先出门再回来"
		await StoryData.maybe_play_evening_reminder(self)

	for item_variant in give_items:
		var item_id := String(item_variant)
		Inventory.add(item_id, 1, ItemDb.scope_of(item_id))
		if announce_items:
			await DialogueBox.play_script([
				{"speaker": "", "text": "获得了「%s」。" % ItemDb.display_name(item_id)},
			])

	# ⚠️ 开关最后写：前面任何一步中途退出（对话没播完）都不会算完成
	for flag_variant in finish_flags:
		GameFlow.set_flag(String(flag_variant), true)

	end_dialogue_lock(was_moving)


func _rest_overnight() -> void:
	# 遮罩随交互点一起销毁；暂停/读档/回标题不会遗留全局黑屏。
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	var fade_out := create_tween()
	fade_out.tween_property(shade, "color:a", 1.0, 0.5)
	await fade_out.finished
	# 即便调试时钟已在早上，也明确进入下一天；仍走唯一跨天入口。
	var target := wait_until_hour * 60 + wait_until_minute
	GameState.time_known = true
	GameFlow.advance_time(24 * 60 - GameState.in_game_minutes + target)
	GameState.phase = "day"
	for flag_variant in finish_flags:
		GameFlow.set_flag(String(flag_variant), true)
	# 在全黑时就开始鸟鸣；这是当前宿舍停留的临时状态，离开宿舍会清掉。
	GameState.morning_birds_active = true
	Music.play("morning_birds", 0.8)
	var reveal := create_tween()
	reveal.tween_interval(1.2)
	reveal.tween_property(shade, "color:a", 0.0, 0.8)
	await reveal.finished
	layer.queue_free()
	# 第二天早晨的对白在褪黑后立刻播放，避免玩家先走动或再次触发别的交互。
	await StoryData.maybe_play_morning_intro(self)
