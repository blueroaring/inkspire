class_name Npc
extends ActorPlaceholder
## 可对话 NPC 基类。
##
## 用法：在场景里放一个 Npc 节点，把它的 dialogue 设成对话数组，
## 或者在子类里覆写 build_dialogue() 动态生成。
## 它自己实现 interact()/get_prompt()，所以玩家不需要认识 Npc 类型即可交互。

@export var display_name: String = "同学"
@export var object_kind: String = "同学"
@export var idle_facing: Vector2 = Vector2.DOWN
@export var one_shot: bool = false
@export_multiline var custom_prompt: String = ""

## 对话内容（DialogueBox.play_script 的格式）
@export var dialogue: Array = []

## 这段台词在**对话补丁**里的 id（见 `scripts/data/dialogue_patch.gd`）。
## 由场景组装脚本按数据填（`campus.life.npc.gate_guard` …）；
## 子类按剧情分支自己决定时，覆写 `dialogue_block_id()`。
@export var dialogue_id: String = ""

## **多阶段对话**（可选）：一次交互播一段，播过的下标存在 `GameState.story_flags` 里。
##
## 用途：校园 NPC 的台词要"第一次说 A、之后一直说 B"（08 里好几处是这么写的：
##   与门卫大爷的完整对话、与校医院门口同学的三句）。
##   以前只能靠子类写 `if GameState.get_flag(...)`，而校园 NPC 是**数据驱动**生成
##   （见 `campus.gd::_build_npcs()`），为一个 NPC 写一个子类不划算。
##
## 约定：
##   · 非空时它**取代** `dialogue`；
##   · 播第 `n` 段时把 `dialogue_step` 记到 `story_flags["npc_step.<id>"] = n`；
##   · **最后一段永远重复**（第二次说话就走最后那一段）。
##   ⚠️ "在哪一段"必须落进 `story_flags`（跟着存档走），不能只存节点上的字段：
##      换个场景再回来就是一个新节点，台词会退回第一段（与"只发生一次"那条坑同源）。
@export var dialogue_sequence: Array = []
@export var dialogue_sequence_id: String = ""

var _busy := false
var _used := false

## 一段对话**完整播完**时发出（中途被打断不算）。
## 用途：场景脚本接"说完就走"这类脚本行为（见 `campus.gd::_wire_vanish()`）——
## 通用基类不该知道"某种 NPC 会消失"，把它挂成信号交给场景更干净。
signal finished


## 这个 NPC 聊完之后要不要让她接一句**通用**插话。
##
## ⚠️ 用户 2026-09-20 定的口径："**对于没有特殊台词的 NPC，不要加艾莉娜的台词，
##    只有体育馆门口的加**"。
##    真正的判据写在 `_talk()` 里（**`dialogue_sequence` 非空** = 数据给了多段台词，
##    也就是"体育馆门口"那几位），这里这个字段是留给**个别例外**的：
##    万一以后某个多段 NPC 也不该有她，把 `no_banter = true` 就行，不必改判据。
##    ⚠️ 默认 `false`（= 尊重 `_talk()` 的判据）—— 别把它默认成"能加"，
##       那会让"忘了开=功能静默消失"那类坑换个方向再来一次。
@export var no_banter: bool = false


func _ready() -> void:
	add_to_group("npc")
	body_color = Palette.NPC_BODY
	head_color = Palette.NPC_HEAD
	super._ready()
	face_direction(idle_facing)


func get_prompt() -> String:
	if custom_prompt != "":
		return custom_prompt
	return "和 %s 说话" % object_kind


func can_interact() -> bool:
	if _busy:
		return false
	return not (one_shot and _used)


## 玩家按 E 时被调用
func interact() -> void:
	if not can_interact():
		return
	_busy = true
	_used = true
	await _talk()
	_busy = false


func _talk() -> void:
	var lines: Array = build_dialogue()
	if lines.is_empty():
		# ⚠️ 没有台词**不等于什么都没发生**：08 里"抱着课本的同学"就是一句话都不说、
		#    急匆匆进教学楼然后消失。场景脚本接的是 `finished`（见 `campus.gd::_wire_vanish()`），
		#    所以这里也必须发一次 —— 否则那位同学永远走不掉（而且不报错）。
		finished.emit()
		return
	# 套对话补丁（`data/dialogue_patch.json`）。子类按分支给 id 时覆写 dialogue_block_id()。
	lines = DialoguePatch.apply(dialogue_block_id(), lines)
	# 艾莉娜跟着的时候，聊完人她也会插一句（见 scripts/data/alyina_banter.gd）。
	# ⚠️ 追加的是"对活人的感想"那一段，不是按物件名匹配的那套 —— 否则对着"陈默"
	#    会去匹配"床/桌"之类的关键词，驴唇不对马嘴。
	# ⚠️ 只能调一次：`npc_lines()` 带"本次已说过"的副作用，别的调用点再调一次就会把它用掉
	#    （第二个调用点拿到空数组，看起来像"这次她不说话"）。
	#    她刚加入、还没"躺床上休息"那段时间里它可以反复给（见 `AlyinaBanter.is_repeatable()`），
	#    但**调用点仍然只该有一个** —— 那是副作用语义，不是"可以随便调"。
	#
	# ⚠️⚠️ **通用插话只给"体育馆门口那几位"式的 NPC**（用户 2026-09-20 第二次澄清：
	#    "对于没有特殊台词的 npc，不要加艾莉娜的台词，只有体育馆门口的加"）。
	#    也就是说：**没有给她单独写台词的 NPC，一句都不要加** ——
	#    原来那套"闲聊时她好奇"的通用池子（"大家看起来都好忙呀…"）在这里是错的：
	#      ① 陈默那几段是情绪戏，她插一句"大家看起来都好忙"驴唇不对马嘴；
	#      ② 促销的阿姨、排队的同学这种路人，她也没必要接话；
	#      ③ 真正该有她的地方，08 已经**逐人写好了**（还书的同学 / 校医院门口的同学 /
	#         跑步的同学 / 拉伸的同学 / 沿着跑道走的同学 / 刚出图书馆的同学），
	#         那些走 `lines_after`，本来就带她 —— 本函数再加就重复了。
	#    判据 = **`dialogue_sequence` 非空**（这类 NPC 一律由数据给了多段，
	#    即"体育馆门口"那几位）；与她台词一起看，两种情况都不会重复也不会漏：
	#      · `lines_after` 型（还书的同学…）：段落非空 → 不再加通用；
	#      · `talk_order` 型（刚出图书馆的同学）：段落非空 + 台词里有她 → 不再加。
	#    ⚠️ 别改成"校园里所有 NPC 都加"——那正是用户连着报了两轮的那个毛病。
	var banter: Array = []
	if allows_banter() and not _already_has_alyina(lines) and not dialogue_sequence.is_empty():
		banter = AlyinaBanter.npc_lines()
	if not banter.is_empty():
		lines = lines.duplicate()
		lines.append_array(banter)
	# 对话期间锁住玩家移动
	var player := _find_player()
	if player != null and player.has_method("set_control_enabled"):
		player.call("set_control_enabled", false)
	await DialogueBox.play_script(lines)
	if player != null and player.has_method("set_control_enabled"):
		player.call("set_control_enabled", true)
	finished.emit()


## 这一段台词里**已经有艾莉娜的专属台词**吗（见 `_talk()` 里那段说明）。
##
## ⚠️ 判据用 `speaker` 字段而不是显示名：那是 `Speakers.display()` 之前的**规范名**
##    （"艾莉娜"），作者在对话编辑器里改显示名不会影响它。
func _already_has_alyina(lines: Array) -> bool:
	for line_variant in lines:
		if not (line_variant is Dictionary):
			continue
		if String((line_variant as Dictionary).get("speaker", "")).contains("艾莉娜"):
			return true
	return false


## 返回对话数组；子类可覆写以根据剧情分支
##
## ⚠️ **多阶段对话在这里收口**（见 `dialogue_sequence`）：一个 NPC 要"第一次说 A、
##    之后说 B"时，数据侧只给两段，由这里按 `story_flags` 里的进度挑一段 ——
##    校园 NPC 是数据驱动生成的，为这种事写一个子类不划算。
##    进度**在本函数里推进**（而不是在 `_talk()` 里）：它只在真的播出来时被调用一次。
func build_dialogue() -> Array:
	if dialogue_sequence.is_empty():
		return dialogue
	var step := _sequence_step()
	var entry: Variant = dialogue_sequence[step]
	var block: Array = entry if entry is Array else [entry]
	# 推进进度：最后一段不再前进（第二次说话就走最后那一段）
	var next_step := mini(step + 1, dialogue_sequence.size() - 1)
	var previous := int(GameState.get_flag(_sequence_step_flag(), 0))
	if next_step > previous:
		GameState.set_flag(_sequence_step_flag(), next_step)
	return block


## 这一段多阶段对话当前该播第几段（存在 `story_flags` 里，跟着存档走）
func _sequence_step() -> int:
	if dialogue_sequence_id == "" or dialogue_sequence.is_empty():
		return 0
	return clampi(int(GameState.get_flag(_sequence_step_flag(), 0)), 0,
			dialogue_sequence.size() - 1)


## 进度开关名：按 NPC 的补丁 id 派生（同一处算，免得两处拼字符串）
func _sequence_step_flag() -> String:
	return "npc_step.%s" % dialogue_sequence_id


## 给场景脚本用：这个 NPC 的对话是不是已经走到最后一段了（"食堂做完之前"这类门槛用它）
func sequence_finished() -> bool:
	return dialogue_sequence.is_empty() or _sequence_step() >= dialogue_sequence.size() - 1


## 这一段台词在对话补丁里的 id。默认取 `dialogue_id`；
## **按剧情分支换台词的子类**覆写它（例：`dorm_roommate` 返回 `dorm.roommate.<branch>`）。
##
## ⚠️ 多阶段对话时，**每一段有各自的 id**（第一段 `…npc.<id>`，后面的 `…_after1`…）——
##    都挤在同一个 id 上的话，补丁里改的是第一段，而游戏里播的是第二段，
##    "改了没反应"而且不报错（对话编辑器也只会列出一条）。
func dialogue_block_id() -> String:
	if dialogue_sequence.is_empty():
		return dialogue_id
	var step := _sequence_step()
	return dialogue_id if step == 0 else "%s_after%d" % [dialogue_id, step]


## 这次对话要不要在末尾追加艾莉娜的插话（见 `AlyinaBanter`）。
## 子类覆写成 false 就能让某一段"情绪戏"不被打断
## （例：`dorm_roommate.gd` 里"发现只有自己看得见她"那一段）。
##
## ⚠️ 现在还要看 `no_banter`（数据/场景给的"这个 NPC 不该有她"）。
##    ⚠️ 真正的"该不该加通用插话"判据在 `_talk()` 里（`dialogue_sequence` 非空），
##       那个是**通用/专属二选一**；本函数是子类用来整体关掉的开关
##       （`dorm_roommate.gd` 的 photo_chat 情绪戏就是这么关的）。
func allows_banter() -> bool:
	return not no_banter


func _find_player() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Node2D
