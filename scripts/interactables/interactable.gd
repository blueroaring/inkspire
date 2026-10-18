class_name Interactable
extends Area2D
## 地图上"可以按 E 交互"的东西的基类。
##
## 约定：
##   - 玩家身上有一个 InteractionProbe（Area2D），检测到本类型节点后弹出提示。
##   - 子类覆写 _interact() 实现具体行为（对话、开门、看手机……）。
##   - interact_prompt 是提示文字，默认按 object_kind 生成。
##
## 新增可交互物的做法：新建场景/脚本继承本类，挂进场景即可，不需要改玩家或路由器。

@export var object_kind: String = "物件"      ## 提示里显示的名字
@export var one_shot: bool = false            ## 是否只能交互一次
@export_multiline var custom_prompt: String = ""
## 交互候选里的排位：**大的排在前面**（同级再按距离近的优先）。
## 用途：让"剧情上该先做的事"压过"离得近的东西"——
## 例如开局的手机拾取物，否则旁边那张刚爬起来的床会把它挤到第二位，
## 玩家必须先按 Tab 才找得到主线要按的东西（用户原话："很反直觉"）。
## ⚠️ 不能叫 `priority`：`Area2D` 原生就有个 `priority`（物理处理顺序），撞名会编译失败。
@export var interact_priority: int = 0

## （可选）要先满足的剧情开关 —— 没打开时这件东西**按不动**（连提示都没有）。
##
## 为什么放在**基类**（2026-09-20）：
##   · "还没看手机之前，宿舍里的家具都别去动它"这条开场门槛（`dorm.gd::OPENING_GATE`）
##     需要给一批 `ExamineObject` 挂上它，而 `dorm.gd` 里那些变量的静态类型是
##     `ExamineObject` / `StoryExamine` —— 字段只写在子类上时，
##     `area.required_flag = ...` 会在**解析期**报
##     `Could not resolve external class member "required_flag"`（实测踩到）；
##   · `SceneDoor` / `StoryExamine` 本来就各自有一份同名字段，收口到这里之后
##     全项目只有一处判据（`can_interact()`），子类的 `required_flag` 已删掉。
## ⚠️ 这也是 `MapData` 里那些 `required_flag` 写法的唯一入口。
@export var required_flag: String = ""

var _used := false
var _busy := false


func _ready() -> void:
	monitoring = true
	monitorable = true
	# 默认碰撞形状：一个圆形，子类场景里可以换成矩形
	if get_child_count() == 0:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 28.0
		shape.shape = circle
		add_child(shape)


func get_prompt() -> String:
	if custom_prompt != "":
		return custom_prompt
	return "查看 %s" % object_kind


## 交互优先级（默认取 interact_priority 字段；子类可以按剧情状态动态算）
func interaction_priority() -> int:
	return interact_priority


func can_interact() -> bool:
	if _busy:
		return false
	# 剧情开关没打开：这件东西"不存在"（连提示都不给 —— 见 `required_flag` 的说明）
	if required_flag != "" and not GameFlow.has_flag(required_flag):
		return false
	return not (one_shot and _used)


## 由玩家在按下交互键时调用
func interact() -> void:
	if not can_interact():
		return
	_busy = true
	_used = true
	await _interact()
	_busy = false


## 子类覆写这个
func _interact() -> void:
	pass


## 便利函数：当前场景里的玩家节点
func get_player() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Node2D


# ---------------------------------------------------------------- 播对话时的玩家锁
#
# 交互物播对话时都要"锁住玩家操作、播完还回去"。这两件事很容易写错，
# 所以放在基类里统一 —— 以前各处都写 `set_control_enabled(true)`，
# 那会把**剧情锁**一起解开（开场"刚醒动不了"就是这么漏掉的）。

## 锁住玩家操作，返回"对话之前玩家是否在自由移动"（交给 end_dialogue_lock 恢复）
func begin_dialogue_lock() -> bool:
	var player := get_player()
	if player == null or not player.has_method("set_control_enabled"):
		return true
	var was_moving := bool(player.get("can_move"))
	player.call("set_control_enabled", false)
	return was_moving


## 恢复成 begin_dialogue_lock() 之前的状态。
## `force_unlock = true` 表示"这次交互本身就推进了剧情，明确放开移动"
## （开场捡手机：够到手机就算人已经起来了）。
func end_dialogue_lock(was_moving: bool, force_unlock: bool = false) -> void:
	var player := get_player()
	if player == null or not player.has_method("set_control_enabled"):
		return
	player.call("set_control_enabled", true)
	if force_unlock or was_moving:
		return
	# 对话前是"只锁移动、保留交互"（例如开场），那就恢复成那个状态
	if player.has_method("set_movement_enabled"):
		player.call("set_movement_enabled", false)
