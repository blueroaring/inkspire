class_name SceneDoor
extends Interactable
## 通往另一个场景的门。
##
## 用法：把 target_location 设成 GameState.LOCATIONS 里的地点 ID，
## target_spawn 设成目标场景 SpawnPoints 下的节点名。
## 需要"上锁"时把 required_flag 设成剧情开关名。

@export var target_location: String = ""
@export var target_spawn: String = ""
## ⚠️ `required_flag`（"没打开这个开关时门不通"）定义在**基类** `Interactable` 里，
##    这里不再重复声明（GDScript 会直接报 `The member already exists in parent class`）。
@export var locked_message: String = "门锁着，现在还出不去。"
## 上锁提示对应的对话补丁 id。空值表示沿用原文。
@export var dialogue_id: String = ""
## 上锁时改播**一段台词**（可选，优先于 `locked_message`）。
##
## 用途：剧情上的"现在还不能去"往往需要两句带情绪的内心独白
## （例：教学楼那道门在"还没吃饭"时要演"教学楼那边……饭还没吃呢"）。
## 单行的 `locked_message` 只够说"门锁着"，而那句话由系统说、不像主角在想事情。
@export var locked_lines: Array = []
## 某些建筑夜间仍保留门口交互，但不允许进入（目前是校园第一食堂）。
## 这样玩家会得到明确的"今天已经关门"反馈，而不是直接切进室内场景。
@export var night_locked: bool = false
@export var night_locked_lines: Array = []
## 夜间提示单独使用一个 id，避免和剧情上锁提示共用覆盖段。
@export var night_dialogue_id: String = ""
## 第二天早晨仍可看见食堂门，但食堂尚未开放。
@export var morning_locked: bool = false
@export var morning_locked_lines: Array = []
@export var morning_dialogue_id: String = ""
@export var auto_save_on_enter: bool = false
## 条件门槛：当 conditional_required_flag 打开后，出口还要等
## conditional_unlock_flag 才能通过。用于契约后第二天早晨的宿舍出口，
## 这样开关在场景已生成后变化也能立即生效。
@export var conditional_required_flag: String = ""
@export var conditional_unlock_flag: String = ""


func can_interact() -> bool:
	if conditional_required_flag != "" and GameFlow.has_flag(conditional_required_flag) \
			and conditional_unlock_flag != "" \
			and not GameFlow.has_flag(conditional_unlock_flag):
		return false
	return super.can_interact()


func _interact() -> void:
	if night_locked and Daylight.period_at(GameState.in_game_minutes) == Daylight.PERIOD_NIGHT:
		await _say_locked(night_locked_lines, night_dialogue_id)
		return
	if morning_locked and GameFlow.has_flag(StoryData.FLAG_MORNING):
		await _say_locked(morning_locked_lines, morning_dialogue_id)
		return
	if required_flag != "" and not GameFlow.has_flag(required_flag):
		await _say_locked(locked_lines, dialogue_id)
		return

	var player := get_player()
	if player != null and player.has_method("set_control_enabled"):
		player.call("set_control_enabled", false)

	if auto_save_on_enter:
		GameFlow.save_now()

	GameState.spawn_point = target_spawn
	await SceneRouter.go_to(target_location, target_spawn, true)


## 播放门禁提示时统一锁住玩家，避免对话过程中又触发移动/重复交互。
func _say_locked(lines: Array, patch_id: String = "") -> void:
	var player := get_player()
	if player != null and player.has_method("set_control_enabled"):
		player.call("set_control_enabled", false)
	var output := DialoguePatch.apply(patch_id, lines)
	if not output.is_empty():
		await DialogueBox.play_script(output)
	else:
		await DialogueBox.say("", locked_message)
	if player != null and player.has_method("set_control_enabled"):
		player.call("set_control_enabled", true)
