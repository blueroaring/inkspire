class_name ExamineObject
extends Interactable
## 通用"查看"物件：按 E 弹一段话。
##
## 用法：把 lines 设成 DialogueBox.play_script 支持的数组即可，
## 不需要为每个可查看物写一个脚本。需要特殊行为时才新建子类。

@export var lines: Array = []
@export var repeatable: bool = true
## 某些纯环境设施不应追加艾莉娜的跟宠插话（例如卫生间马桶）。
## 使用独立字段，避免与 StoryExamine 的 allow_banter 语义冲突。
@export var append_banter: bool = true

## ⚠️ `required_flag`（"没打开开关时按不动"）定义在**基类** `Interactable` 里，
##    这里不再重复声明（同一个字段写两处会互相遮蔽，而且子类声明过之后
##    `dorm.gd` 那种"静态类型是 ExamineObject"的赋值会解析失败）。
##    本类只负责"按 E 播一段话"。

## 这一段台词在**对话补丁**里的 id（见 `scripts/data/dialogue_patch.gd`）。
##
## 由场景组装脚本按数据填（`canteen.examine.red` / `map.dorm_examine.desk` /
## `teaching.classroom.301` …），对话编辑器就是按这些 id 列出全部可编辑台词的。
## 留空 = 这一段不参与补丁（照常播原文）。
@export var dialogue_id: String = ""


func _ready() -> void:
	one_shot = not repeatable
	super._ready()


func _interact() -> void:
	if lines.is_empty():
		return
	# 锁玩家 / 播对话 / 原样恢复（见 Interactable.begin_dialogue_lock 的说明：
	# 不能无脑 set_control_enabled(true)，那会把开场的剧情锁一起解开）
	var was_moving := begin_dialogue_lock()
	# ① 先套对话补丁（只覆盖"这一段原文"，不影响后面追加的插话）
	# ② 艾莉娜跟着的时候，看完东西她会插一句（她对大学生活好奇、主角自嘲废柴）。
	#    插话内容与"每类只说一次"的规矩都在 `scripts/data/alyina_banter.gd`，
	#    所以**不需要给每个物件手写台词**，这里只有一行。
	var patched := DialoguePatch.apply(dialogue_id, lines)
	var output_lines := AlyinaBanter.with_banter(object_kind, patched) if append_banter else patched
	await DialogueBox.play_script(output_lines)
	end_dialogue_lock(was_moving)
