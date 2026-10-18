class_name CollegeMap
extends Node2D
## 大学地图类的共同基类：把"世界尺寸"交给相机做边界限制。
##
## 每张大学地图（宿舍、校园……）在 _ready 里调用 configure_world() 声明自己多大，
## 相机就会自动被限制在地图内，不会拍到地图外的空白。

@export var world_rect: Rect2 = Rect2()

## 角色视觉倍率：本场景里"人看起来多大"（玩家与 NPC 一起，走 ActorSprite.set_visual_scale）。
##
## 为什么是**场景级参数**而不是全局常量：相机对每个场景的缩放不一样 ——
## 校园 48x34 格的整张图 1:1 铺满视口（zoom≈0.99），宿舍只有 640x448（zoom≈3.07），
## 于是同一个人"在宿舍够大、在校园偏小"。用户 2026-09-19 要求"增大校园地图里的人物大小"，
## 所以校园三区把这个值调大（1.4），室内场景保持 1.0。
## ⚠️ 只放大**视觉**：碰撞体与交互探测半径都不跟着变（见 ActorSprite.set_visual_scale）。
@export var character_scale: float = 1.0

## 跟宠（艾莉娜）的场景文件与在场景里的节点名。
##
## 为什么由**基类**统一生成，而不是每个 .tscn 里挂一个：
##   ① 用户要的是"她一直跟在主角身边"——五个大学场景各挂一次就等于五处会漏；
##   ② 她的位置每帧跟着玩家算，不需要在 .tscn 里写坐标；
##   ③ 出现与否只由剧情开关决定（`Follower.require_flag`），场景不需要知道剧情。
const FOLLOWER_SCENE := preload("res://scenes/actors/follower.tscn")
const FOLLOWER_NAME := "Follower"
## 她出现时要不要把玩家身后的位置先对齐（避免第一帧从场景原点飞过去）
const FOLLOWER_SPAWN_OFFSET := Vector2(-34.0, 20.0)

## 环境光（白天/夕阳/夜间）叠层的 CanvasLayer 层级。
##
## 为什么用 CanvasLayer 而不是场景里的 ColorRect：它要在**屏幕空间**盖住整个视口，
## 不受相机缩放/边界影响（相机在小房间里 zoom 很大，场景空间的色块盖不满屏）。
## ⚠️ 层级要卡在"世界之上、UI 之下"：CG 的画布是 5、HUD 是 10、对话框 40、
##    暂停菜单 60 —— 取 2 就正好压在世界上面、又不会把界面染黄。
const AMBIENT_LAYER := 2

## 本场景要不要"跟着天色整体压暗"。
##
## ⚠️ **只有露天场景要开**（校园三区）。用户 2026-09-19 明确：
##    "宿舍不应该是夜间是黑的，只有窗户有变化。"
##    室内有灯，天黑了屋里也亮着；而且把家具、墙面、地面一起染蓝只会让房间看起来很脏。
##    若某个室内场景确实需要天色贴片，再由该场景主动调用 `register_sky_panel()`。
@export var outdoor_ambient: bool = false

## 场景音乐配置：由宿舍、食堂、校园和教学楼子类在 `super._ready()` 前指定。
## 留在基类的好处是时间切换只需要维护一套同步逻辑；Bathroom 沿用宿舍的安静曲。
@export var music_profile: String = ""

var camera: CameraFollow
var decor: Node2D  ## 装饰/建筑统一挂到这里，方便整层替换或隐藏
var follower: Node2D = null  ## 跟宠（没登场时为 null —— 压根不建，省得走查数到它）
## 这张图的导航网格（由 `setup_navigation()` 在建图**之后**烘）。
## 跟宠靠它绕开障碍物；没烘出来的话她会退回直线跟随（见 `Follower` 的注释）。
var navigation: MapNavigation = null

## 环境光与可选的"窗外天光"贴片（见 `_build_ambient` / `register_sky_panel`）
var _ambient: ColorRect = null
var _sky_panels: Array[ColorRect] = []
var _last_period := ""
var _last_music_track := ""


func _ready() -> void:
	decor = Node2D.new()
	decor.name = "Decor"
	add_child(decor)
	_build_ambient()
	_ensure_follower()
	call_deferred("_apply_character_scale")
	call_deferred("_check_story_triggers")


## 环境光：一张**全屏**色块，颜色随时段变（白天=完全不叠，所以老画面零变化）。
##
## ⚠️ **只有 `outdoor_ambient = true` 的露天场景才建这张色块**（校园三区）。
##    室内（宿舍/食堂/卫生间/教学楼）**不压暗** —— 用户 2026-09-19：
##    "宿舍不应该是夜间是黑的，只有窗户有变化。"
##    天光贴片是可选的；没有场景登记时，室内不会额外叠加窗外颜色。
func _build_ambient() -> void:
	if outdoor_ambient:
		var canvas := CanvasLayer.new()
		canvas.name = "AmbientLayer"
		canvas.layer = AMBIENT_LAYER
		add_child(canvas)
		_ambient = ColorRect.new()
		_ambient.name = "Ambient"
		_ambient.color = Color(1, 1, 1, 0)
		_ambient.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ambient.set_anchors_preset(Control.PRESET_FULL_RECT)
		canvas.add_child(_ambient)
	_apply_ambient(true)


## 登记一块"跟着天色变的贴片"（宿舍窗户的窗外天光用它）。
##
## 为什么让场景自己登记、基类统一刷新：这种贴片只有场景知道该放哪（窗户在哪一格），
## 而"现在是什么时段"只有基类在算。分开之后两边都不用知道对方的细节。
## 返回建好的控件，方便调用方再调（例如改 z_index）。
func register_sky_panel(rect: Rect2, z: int) -> ColorRect:
	var panel := ColorRect.new()
	panel.color = Daylight.sky_at(GameState.in_game_minutes)
	panel.position = rect.position
	panel.size = rect.size
	panel.z_index = z
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	decor.add_child(panel)
	_sky_panels.append(panel)
	return panel


## 每帧对一次时段。**只在时段真的变了才重设颜色**（一帧四次属性写入没必要）。
func _process(_delta: float) -> void:
	_apply_ambient(false)
	_sync_music()


## 场景音乐跟随地点与天色切换。
##
## 只有校园需要按白天/夕阳/夜间分曲；室内地点固定自己的主题曲。
## `Music.play()` 自带同曲短路和交叉淡入，这里只在目标曲目变化时请求切换。
func _sync_music() -> void:
	if Music.has_override():
		return
	var target := ""
	match music_profile:
		"dorm":
			target = "dorm_calm"
			if GameState.morning_birds_active:
				target = "morning_birds"
		"canteen":
			target = "canteen_upbeat"
		"teaching":
			target = "teaching_bright"
		"campus":
			match Daylight.period_at(GameState.in_game_minutes):
				Daylight.PERIOD_SUNSET:
					target = "campus_sunset"
				Daylight.PERIOD_NIGHT:
					target = "campus_night"
				_:
					target = "campus_day"
	if target == "" or (target == _last_music_track and Music.is_playing and Music.current_track == target):
		return
	_last_music_track = target
	Music.play(target, 1.0)


func _apply_ambient(force: bool) -> void:
	var minutes := GameState.in_game_minutes
	var period := Daylight.period_at(minutes)
	if not force and period == _last_period:
		return
	_last_period = period
	if _ambient != null:
		_ambient.color = Daylight.ambient_at(minutes)
	var sky := Daylight.sky_at(minutes)
	for panel in _sky_panels:
		if is_instance_valid(panel):
			panel.color = sky


## 当前环境色（走查断言"天色真的变了"用；白天 / 室内都应该是 alpha 0）
func ambient_color() -> Color:
	return _ambient.color if _ambient != null else Color(0, 0, 0, 0)


## 本场景会不会整体压暗（走查断言"室内不该变黑"用）
func has_ambient_overlay() -> bool:
	return _ambient != null


## 当前窗外天光色（同上）
func sky_color() -> Color:
	for panel in _sky_panels:
		if is_instance_valid(panel):
			return panel.color
	return Color(0, 0, 0, 0)


func sky_panel_count() -> int:
	return _sky_panels.size()


## 每个大学场景进来时判一次"有没有该自动播的剧情"。
##
## 目前有两条：
##   ① **刚出艾莉娜登场 CG** → 那三句"带你逛逛校园吧"（`CgData.alyina_landing_lines()`）。
##      用户 2026-09-20 要求它从 CG 里挪到"CG 播完之后"——判据是会话级标记
##      `GameState.alyina_landing_pending`，只有"这一趟真的刚从那个 CG 出来"才为真。
##   ② **晚间想起去取照片**（`01_GOALS.md` 后半段的触发点）。
## 放在基类是因为触发条件是"现在是不是晚间"这个**全局状态** —— 玩家可能在校园、
## 教学楼、食堂任何地方把时间耗到晚上，挂在某一个场景里就会漏掉别的场景。
func _check_story_triggers() -> void:
	await StoryData.maybe_play_morning_intro(self)
	await StoryData.maybe_play_alyina_tour(self)
	await StoryData.maybe_play_evening_reminder(self)


## 按剧情开关决定要不要把跟宠建出来。
##
## ⚠️ 必须在 `_ready()` 里**同步**建（不能 `call_deferred`）：
##    `SceneRouter._swap_scene()` 的顺序是「`add_child`（跑 `_ready`）→ `_place_player()`」，
##    延后一帧的话她会先出现在 .tscn 里写的位置、下一帧再瞬移过来（肉眼能看到闪一下）。
##
## ⚠️ 没登场（开关关着）时**不建节点**，而不是建了再 `visible = false`：
##    走查/调试会遍历场上节点，一个永远隐藏的跟宠是纯粹的噪音。
##    代价是"她登场的瞬间"需要在场景里补建一次 —— 见 `_ensure_follower()` 的调用点
##    （每个场景 `_ready` 时判一次就够：登场发生在 CG 场景里，之后每次进场景都会重新判）。
func _ensure_follower() -> void:
	if follower != null and is_instance_valid(follower):
		return
	if not GameFlow.has_flag(TeachingData.STORY_ALYINA_FOLLOWS) \
			or GameFlow.has_flag(StoryData.FLAG_ALYINA_LEFT_DORM) \
			or GameFlow.has_flag(StoryData.FLAG_MORNING):
		return
	follower = FOLLOWER_SCENE.instantiate() as Node2D
	follower.name = FOLLOWER_NAME
	# 先摆在玩家身后（这时玩家还在 .tscn 写的位置；`_place_player` 之后
	# Follower 自己的"掉太远就瞬移"会把它带到正确位置）
	var player := get_tree().get_first_node_in_group("player") as Node2D
	follower.position = (player.global_position if player != null else Vector2.ZERO) \
			+ FOLLOWER_SPAWN_OFFSET
	add_child(follower)


## 把角色倍率应用到场上的**所有**角色（玩家 + NPC + 跟宠）。
## 延后一帧执行：NPC 是校园脚本在 _ready 里动态建的，`get_nodes_in_group("npc")`
## 要等它们都进了场景树才数得全 —— 少应用一个就是"全场只有一个人特别小"。
##
## ⚠️ `"follower"` 也在这张表里：跟宠同样要跟着场景的倍率走，
##    漏掉它的表现是"校园里 NPC 都变大了，只有艾莉娜还是宿舍那么大"。
func _apply_character_scale() -> void:
	apply_character_scale()


func apply_character_scale() -> int:
	if is_equal_approx(character_scale, 1.0):
		return 0
	var applied := 0
	for group in ["player", "npc", "follower"]:
		for node in get_tree().get_nodes_in_group(group):
			if not is_ancestor_of(node):
				continue
			var sprite := node.get_node_or_null("AnimatedSprite2D")
			if sprite != null and sprite.has_method("set_visual_scale"):
				sprite.call("set_visual_scale", ActorSprite.BASE_SCALE * character_scale)
				applied += 1
	return applied


## 场上角色当前的视觉倍率（走查断言用；没有角色时返回 -1）
func character_visual_scale() -> float:
	for node in get_tree().get_nodes_in_group("player"):
		if not is_ancestor_of(node):
			continue
		var sprite := node.get_node_or_null("AnimatedSprite2D")
		if sprite != null and sprite.has_method("current_visual_scale"):
			return float(sprite.call("current_visual_scale"))
	return -1.0


## 设定世界范围并驱动相机（缩放与边界都由相机自己按世界尺寸算）
func configure_world(rect: Rect2) -> void:
	world_rect = rect
	if camera == null:
		camera = get_node_or_null("Camera") as CameraFollow
	if camera == null:
		return
	camera.configure_world(rect)


# ---------------------------------------------------------------- 导航网格


## 烘一张本场景的导航网格（跟宠寻路用）。
##
## ⚠️ **必须在 `_ready()` 的最后一个动作**（所有地图几何都摆完之后）调用：
##    导航网格是照着"墙层格子 + 家具落地碰撞"算出来的，早一步调用就会漏掉
##    后面才摆的家具 —— 表现是"她绕着桌椅走得好好的，唯独穿某几张桌子"。
##
## 为什么由各场景脚本显式调用、而不是基类自动做：
##    基类不知道"这个场景什么时候算建完"（`_ready()` 是同步的，没有构建完成回调）。
##    显式一行调用 + 每张图都要，比在基类里猜一个时机可靠 —— 漏了的那张图
##    会在自检的"导航"那一行显示 多边形=0，一眼可见。
##
## 顺带把概况打进日志：排查"她为什么突然开始绕远路"时，
## 第一件事就是确认这张图的导航网格到底有没有、有多大。
func setup_navigation() -> void:
	if navigation != null and is_instance_valid(navigation):
		return
	var map := get_node_or_null("Builder/Map") as TileRoom
	if map == null:
		map = get_node_or_null("Builder") as TileRoom
	if map == null:
		push_warning("CollegeMap: 找不到 TileRoom，本场景不烘导航网格（跟宠走直线）")
		return
	var built := MapNavigation.new()
	built.name = "Navigation"
	add_child(built)
	built.build(map, world_rect if world_rect.size.x > 0.0
			else Rect2(Vector2.ZERO, Grid.size_to_px(Grid.CAMPUS_SIZE)))
	navigation = built
	# ⚠️ 精修必须**等一个物理帧**：墙/家具的碰撞体是本帧刚建出来的，
	#    物理服务器要等下一次物理步才把它们注册进空间 —— 立刻查会全是空的。
	#    这一帧里玩家一步都走不了，所以不存在"用未精修的网格寻路"的窗口。
	_refine_navigation.call_deferred()
	print("[导航] %s" % built.describe())


## 用一个物理帧之后的空间状态精修导航网格（见 `MapNavigation.refine_body_fit`）
func _refine_navigation() -> void:
	if navigation == null or not is_instance_valid(navigation):
		return
	await get_tree().physics_frame
	if navigation == null or not is_instance_valid(navigation):
		return
	navigation.refine_body_fit(get_world_2d().direct_space_state)
	print("[导航·精修] %s" % navigation.describe())


## 把自己限制在相机边界里（Godot 4 用 limit_* 即可，这里留个钩子方便以后加自定义逻辑）
func clamp_camera_to_world() -> void:
	configure_world(world_rect)
