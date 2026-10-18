class_name ItemPickup
extends Interactable
## 地图上"能捡起来的道具"：按 E 拾取 -> 进背包 -> 自己从地图上消失。
##
## 用法（数据驱动）：场景组装脚本（例如 `scripts/scenes/college/dorm.gd`）按
## `MapData.dorm_pickups()` 建出若干本节点，设好 `item_id` / `count` 即可。
## 道具的名字、描述、拾取提示、图标都从 `ItemDb` 取 —— 加一件可捡的东西
## 通常只需要在数据里加一行，不用写新脚本。
##
## 剧情锁怎么处理（这一步最容易做错）：
##   默认**恢复对话前的状态** —— 正在被剧情锁着移动时，捡东西不该顺手把锁解开。
##   但"开场刚醒"那一下需要例外：从"手机还在桌上、人动不了"到"人已经起身去够手机"
##   本身就是一次状态推进，所以开场那件拾取物把 `release_movement_lock` 打开，
##   捡完立刻能走。
##
## ⚠️ **不要**把"必须看手机"做成硬锁移动：玩家只要不知道按 B，就会以为游戏卡死
##    （实测被当成 bug 报上来过）。真正该拦的是**出口门**（`SceneDoor.required_flag = woke_up`
##    会给出明确文案），再配一条 HUD 提示就够了。

@export var item_id: String = ""
@export var count: int = 1
## 一次性拾取的**持久化标识**：一旦拿过就写进存档（`GameState.collected`），
## 重进场景不再刷出来。留空时退回用节点名（同一个场景里放多个同类道具时请显式给 id）。
@export var pickup_id: String = ""
## 拾取前的一句旁白；留空则用 ItemDb 里的 pickup_line
@export_multiline var pickup_text: String = ""
## 是否播"获得了「X」×N"
@export var announce: bool = true
## 拾取后是否从地图上消失（预留"可反复拾取"的采集点）
@export var consume_on_pickup: bool = true
## 拾取后是否**明确放开**被剧情锁住的移动（默认 false = 恢复对话前的状态）
@export var release_movement_lock: bool = false
## 占位色块尺寸（没有图标素材时用）
@export var placeholder_size := Vector2(12.0, 18.0)
@export var placeholder_color := Color(0.10, 0.11, 0.16)
@export var placeholder_glow := Color(0.35, 0.53, 0.72)

var _visual: Node2D


func _ready() -> void:
	if item_id != "":
		object_kind = ItemDb.display_name(item_id)
		if custom_prompt == "":
			custom_prompt = ItemDb.pickup_prompt(item_id)
	super._ready()
	# 已经拿过的东西不再出现在地图上。
	# ⚠️ 为什么必须查存档：拾取物是**运行期按数据生成的**，"物件自己消失了"这件事
	#    不写进存档的话，每次重进场景都会照数据再刷一个（手机被无限复制就是这么来的）。
	if is_already_collected():
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		queue_free()
		return
	_build_visual()


## 持久化标识（数据没给就用节点名兜底）
func resolved_pickup_id() -> String:
	return pickup_id if pickup_id != "" else String(name)


func is_already_collected() -> bool:
	if item_id == "" or not consume_on_pickup:
		return false
	return GameState.is_collected(resolved_pickup_id())


func can_interact() -> bool:
	if item_id == "":
		return false
	return super.can_interact()


func _interact() -> void:
	var scope := ItemDb.scope_of(item_id)
	var added := Inventory.add(item_id, count, scope)
	if added <= 0:
		# 唯一道具已经在背包里（老存档可能没记"已拾取"）：把这个多出来的直接收掉，
		# 免得它永远留在地上、还能被反复"捡"。正常新档不会走到这里。
		if ItemDb.is_unique(item_id) and Inventory.has(item_id, 1, scope):
			GameState.mark_collected(resolved_pickup_id())
			if consume_on_pickup:
				await DialogueBox.play_script([
					{"speaker": "周明远", "text": "……口袋里已经有一个了。"},
				])
				_consume()
			return
		# 背包满了（或 id 不合法）：给一句提示，东西留在地上
		await DialogueBox.play_script([
			{"speaker": "", "text": "背包已经装不下了。"},
		])
		return

	var was_moving := begin_dialogue_lock()

	var lines: Array = []
	var pre := pickup_text if pickup_text != "" else ItemDb.pickup_line(item_id)
	if pre != "":
		lines.append({"speaker": "", "text": pre})
	if announce:
		lines.append({"speaker": "", "text": "获得了「%s」×%d。" % [ItemDb.display_name(item_id), added]})
	if not lines.is_empty():
		await DialogueBox.play_script(lines)

	# 对话结束后的状态恢复（见 Interactable.end_dialogue_lock）：
	#   · 默认恢复成对话前 —— 正在被剧情锁着移动时，捡东西不该把锁一并解开；
	#   · release_movement_lock=true 时明确放开（开场捡手机：够到手机就算起来了）。
	end_dialogue_lock(was_moving, release_movement_lock)

	if consume_on_pickup:
		# 先记账再销毁：重进场景时 _ready 会看到它已被拿走，不再生成
		GameState.mark_collected(resolved_pickup_id())
		_consume()


func _build_visual() -> void:
	var icon := ItemDb.icon(item_id)
	_visual = Node2D.new()
	_visual.name = "PickupVisual"
	_visual.z_index = 50
	add_child(_visual)

	if icon != null:
		var sprite := Sprite2D.new()
		sprite.texture = icon
		_visual.add_child(sprite)
		return

	# 没图标素材时的占位：一块深色机身 + 一点亮屏，和宿舍其它占位物一个风格。
	# 换正式素材只需要在 ItemDb 里给 icon，或者按 <id>.png 放进 assets/graphics/items/。
	var body := ColorRect.new()
	body.color = placeholder_color
	body.size = placeholder_size
	body.position = -placeholder_size * 0.5
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(body)

	var glow := ColorRect.new()
	glow.color = placeholder_glow
	glow.size = placeholder_size - Vector2(4.0, 4.0)
	glow.position = -placeholder_size * 0.5 + Vector2(2.0, 2.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(glow)


## 从地图上消失。
## ⚠️ **不要**在这里直接 `queue_free()`：基类 `Interactable.interact()` 在
##    `await _interact()` 之后还要写一句 `_busy = false`，而 queue_free() 会让节点
##    赶在那句之前被释放 —— 实测报 "Trying to assign invalid previously freed instance"。
##    所以这里只做"同帧就不再被探到"（停探测 + 隐藏），销毁交给计时器。
func _consume() -> void:
	if _visual != null:
		_visual.visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var tree := get_tree()
	if tree == null:
		queue_free()
		return
	# 计时器属于 SceneTree，不依赖本节点存活；节点若先被释放，连接会被自动清理
	tree.create_timer(0.05).timeout.connect(queue_free)
