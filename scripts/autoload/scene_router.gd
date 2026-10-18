extends Node
## 场景调度（自动加载单例 SceneRouter）
##
## 职责：只负责"当前显示哪个场景"这一件事——加载、卸载、淡入淡出、传递出生点。
## 它不认识章节、剧情、存档；那些属于 GameFlow。这样加新场景不用改这里。
##
## 场景接入约定（新增一个地点时照做）：
##   1. 在 GameState.LOCATIONS 里登记 "location_id": "res://.../*.tscn"
##   2. 场景根节点可选地加一个名为 "SpawnPoints" 的 Node2D，下面每个 Marker2D 是一个出生点
##   3. 玩家节点放进 "player" 组，切场景后 SceneRouter 自动把它摆到出生点

const FADE_IN_TIME := 0.28
const FADE_OUT_TIME := 0.28

## 路由加载的场景节点名（仅用于可读性，清理旧场景靠 SceneTree.current_scene，不靠名字）
const NEW_SCENE_NAME := "CurrentScene"

var current_scene: Node = null
var current_location: String = ""

var _fade: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var layer := CanvasLayer.new()
	layer.name = "TransitionLayer"
	layer.layer = 100
	add_child(layer)

	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.visible = false
	layer.add_child(_fade)


func is_busy() -> bool:
	return _busy


## 测试跳转先释放旧场景的演出协程，再构造另一套剧情状态。
func clear_current() -> void:
	var tree := get_tree()
	var previous: Array[Node] = []
	for scene in [current_scene, tree.current_scene]:
		if is_instance_valid(scene) and scene not in previous: previous.append(scene)
	current_scene = null
	tree.current_scene = null
	# 不先 remove_child：等待 process_frame 的演出仍可能在帧末销毁前恢复，
	# 此时保留树引用，避免旧演出 get_tree() 得到 null。
	for scene in previous:
		scene.process_mode = Node.PROCESS_MODE_DISABLED
		scene.queue_free()
	current_location = ""
	await tree.process_frame


## 切换地点。[param spawn_point] 为空则用场景自带的默认出生点。
##
## ⚠️ **正在切场景时不许静默丢掉这次请求**（2026-09-20 修，用户实报：
##    "如果在对话中点 esc 暂停，然后返回标题，对话还在"）。
##    老写法是 `if _busy: return` —— 而"回标题"这条路上，`SceneRouter` 很可能正在忙
##    （上一个 `go_to` 还没跑完淡入），于是这个调用**什么都没做就返回了**：
##    `GameFlow.back_to_title()` 后面的 `await` 立刻结束，标题没进去、
##    `GameState.location` 还停在原场景 —— 表现就是"按了返回标题，画面却还是游戏里"。
##    现在改成"等当前这次切完再接着做"，请求不会丢。
func go_to(location_id: String, spawn_point: String = "", fade: bool = true) -> void:
	# ⚠️ 上限只是防呆：真正的死锁（`_busy` 卡死）应该在别处修，而不是在这里无限等。
	var waited := 0
	while _busy and waited < 600:
		await get_tree().process_frame
		waited += 1
	if _busy:
		push_warning("SceneRouter: 上一次切场景超过 600 帧还没结束，已放弃这次跳转（%s）" % location_id)
		return
	if not GameState.LOCATIONS.has(location_id):
		push_warning("SceneRouter: 未登记的地点 '%s'" % location_id)
		return
	var path: String = GameState.LOCATIONS[location_id]
	if not ResourceLoader.exists(path):
		push_warning("SceneRouter: 场景文件不存在 %s" % path)
		return

	_busy = true
	var loading: Control
	var prepared: PackedScene
	if location_id == "fight" and TowerRun.active:
		loading = preload("res://scripts/ui/tower_battle_loading.gd").new()
		_fade.visible = false
		_fade.get_parent().add_child(loading)
		prepared = await loading.prepare(path)
		if prepared == null:
			TowerRun.cancel_loading_battle()
			loading.queue_free()
			_busy = false
			return
	elif fade:
		await _fade_out()

	# 动态场景会在 _ready() 读取入口（楼层、走廊分段、侧室）。
	# 必须在实例化前同步，不能只把入口传给之后的 _place_player。
	GameState.spawn_point = spawn_point
	await _swap_scene(path, location_id, spawn_point, prepared)

	GameState.location = location_id
	# 记下"最近一次真正在玩的地点"（见 `GameFlow.last_play_location` 的说明）：
	# 回标题时若正卡在 CG 过场里，自动存档要用这个锚点，而不是 `cg.xxx`。
	# ⚠️ 收在这里而不是让每个场景自己调：切场景**只有这一个入口**，
	#    散在各处必然会漏（与"回标题的收尾动作收口在一处"同一条纪律）。
	GameFlow.note_play_location(location_id)
	# 注意：fade=false 时也必须清掉遮罩。
	# 踩过的坑：之前只在 fade=true 时淡入，导致"先 fade_out_instant() 再 go_to(..., false)"
	# 的启动流程把画面永久盖成黑屏——而所有状态检查都是正常的，极难发现。
	if is_instance_valid(loading): await loading.dismiss()
	else: await _fade_in()
	_busy = false


## 热重开当前场景（读档失败/调试用）
func reload_current() -> void:
	if current_location == "":
		return
	await go_to(current_location, GameState.spawn_point, false)


func _swap_scene(path: String, location_id: String, spawn_point: String, prepared: PackedScene = null) -> void:
	_free_previous_scenes()

	var packed: PackedScene = prepared if prepared != null else load(path)
	current_scene = packed.instantiate()
	current_scene.name = NEW_SCENE_NAME
	get_tree().root.add_child(current_scene)
	current_scene.owner = null
	# 让引擎的"当前场景"指针指向新场景（旧指针在 _free_previous_scenes 里已随节点释放）
	get_tree().current_scene = current_scene
	current_location = location_id

	# 场景切换后把玩家摆到出生点
	_place_player(spawn_point)


## 彻底清掉上一个场景。
##
## 踩过的坑（都记在这里，避免重犯）：
## 1) 首次切换时 current_scene 还是 null（启动场景由 main_scene 直接加载，绕过了路由）。
##    当时我按"根节点下叫 CurrentScene 的节点"去兜底，但启动场景的节点名是它自己的
##    根节点名（Boot），名字对不上 → 启动画面（LOGO 与纯色底）永久留在根节点上，
##    盖在后续所有场景之上。正确做法是用 SceneTree.current_scene：
##    它在启动时确实指向启动场景，是引擎给的权威引用。
## 2) 不能对"当前正在执行的场景"调用 free()：那会在引擎还持有指针时直接把节点销毁，
##    实测直接段错误（signal 11）。所以这里用 remove_child（立刻从树上摘掉，
##    此后不再渲染）+ queue_free（让引擎在安全时机销毁）。
func _free_previous_scenes() -> void:
	var tree := get_tree()
	var to_free: Array[Node] = []

	for candidate in [current_scene, tree.current_scene]:
		if candidate != null and is_instance_valid(candidate) and not to_free.has(candidate):
			to_free.append(candidate)

	current_scene = null
	for node in to_free:
		var parent := node.get_parent()
		if parent != null:
			parent.remove_child(node)
		node.queue_free()


## 把 "player" 组里的节点移动到出生点；没找到出生点就保留场景原有位置
func _place_player(spawn_point: String) -> void:
	if current_scene == null:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node2D
	if player == null:
		return

	var target := _find_spawn_point(spawn_point)
	if target == null:
		return
	player.global_position = target.global_position
	if player.has_method("face_direction"):
		player.call("face_direction", _spawn_facing(target))
	# 出生点可以声明"落地时锁住移动"（例如开场从床上醒来）。
	# 注意用 set_movement_enabled 而不是 set_control_enabled：
	# 开场必须保留交互，否则玩家看不了手机、也就永远解锁不了（真踩过这个死锁）。
	if player.has_method("set_movement_enabled"):
		player.call("set_movement_enabled", not bool(target.get_meta("start_locked", false)))
	elif player.has_method("set_control_enabled"):
		player.call("set_control_enabled", not bool(target.get_meta("start_locked", false)))


## 出生点朝向：用两个标量 meta 记录（比在 .tscn 里写 Vector2 更稳，也更好手写）
func _spawn_facing(target: Marker2D) -> Vector2:
	var dir := Vector2(float(target.get_meta("face_x", 0.0)), float(target.get_meta("face_y", 1.0)))
	if dir == Vector2.ZERO:
		return Vector2.DOWN
	return dir.normalized()


func _find_spawn_point(spawn_point: String) -> Marker2D:
	if current_scene == null:
		return null
	var holder := current_scene.get_node_or_null("SpawnPoints")
	if spawn_point == "":
		# 场景默认出生点：优先 "default"，否则第一个 Marker2D
		if holder != null:
			var d := holder.get_node_or_null("default") as Marker2D
			if d != null:
				return d
			for child in holder.get_children():
				if child is Marker2D:
					return child
		return null
	if holder == null:
		push_warning("SceneRouter: 场景 %s 没有 SpawnPoints，找不到出生点 '%s'" % [current_location, spawn_point])
		return null
	var marker := holder.get_node_or_null(spawn_point) as Marker2D
	if marker == null:
		push_warning("SceneRouter: 场景 %s 没有出生点 '%s'" % [current_location, spawn_point])
	return marker


## 立即变黑（新游戏/读档时避免看到上一帧画面）
func fade_out_instant() -> void:
	_fade.visible = true
	_fade.color.a = 1.0


func _fade_out() -> void:
	_fade.visible = true
	_fade.color.a = 0.0
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_OUT_TIME)
	await tween.finished


func _fade_in() -> void:
	_fade.visible = true
	_fade.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, FADE_IN_TIME)
	await tween.finished
	_fade.visible = false
