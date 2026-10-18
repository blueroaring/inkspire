class_name StoryDoor
extends SceneDoor
## 一扇"平时正常通往别的地点、但满足剧情条件时改道去 CG"的门。
##
## 为什么需要它（真实需求，不是抽象）：
##   `request/01_GOALS.md` 里"就在主角出教学楼的那一刻，天上掉下来了一个东西砸晕了主角"——
##   也就是**同一扇门**（教学楼出口）在"翘课之前"和"翘课之后"要做两件不同的事。
##
## 为什么不做成两个门/两个场景：那要求场景在运行期增删节点，而且"哪扇门在生效"这个
##   状态会散进场景脚本；做成"门自己读剧情开关"之后，出口门永远只有一扇，
##   数据里写清楚"满足 `story_flag` 就去 `story_location`"，场景脚本一行都不用改。
##
## 用法：在门的数据字典里加四个键（见 `TeachingData.exit_door()`）：
##   story_flag      满足这个剧情开关时改道
##   story_location  改道去哪（一般是 CG 场景）
##   story_spawn     改道时的出生点（CG 场景一般不需要，留空）
##   story_done_flag 这个开关打开之后就**不再**改道（按普通门走）
##
## ⚠️ **`story_done_flag` 不是可选项，是这类门的必需品**（2026-09-19 用户实报：
##    "每次进出教学楼都会触发 cg，应该在遇到精灵后不会再触发"）。
##    只写 `story_flag` 的话，"翘课之后"这个条件一旦成立就**永远**成立 ——
##    于是玩家每次经过这扇门都会重看一遍 CG。剧情"演过一次"必须由另一个开关记住。
##
## ⚠️ 与 `SceneDoor` 一样：**不要在这里 queue_free 自己**，也不要忘了恢复玩家操作 ——
##    切换场景由 `SceneRouter` 负责，玩家控制权由目标场景/出生点重新给。

@export var story_flag: String = ""
@export var story_location: String = ""
@export var story_spawn: String = ""
## 这个开关打开之后，本门不再走剧情分支（变成普通门）
@export var story_done_flag: String = ""


func _interact() -> void:
	# 没有剧情配置 / 开关没打开 / 这段剧情**已经演过了** →
	# 完全按普通 SceneDoor 走（这是绝大多数时候）
	if story_flag == "" or story_location == "" or not GameFlow.has_flag(story_flag) \
			or (story_done_flag != "" and GameFlow.has_flag(story_done_flag)):
		await super._interact()
		return

	var player := get_player()
	if player != null and player.has_method("set_control_enabled"):
		player.call("set_control_enabled", false)

	# 进门之前先存一次：CG 之后玩家会落在别的地点，万一中途退出，
	# 存档还停在"教学楼里、已经翘课"这个真实进度上。
	if auto_save_on_enter:
		GameFlow.save_now()

	GameState.spawn_point = story_spawn
	await SceneRouter.go_to(story_location, story_spawn, true)
