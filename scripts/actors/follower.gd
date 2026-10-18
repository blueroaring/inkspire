class_name Follower
extends ActorPlaceholder
## 跟宠：跟在玩家身后的角色（艾莉娜）。
##
## 用户 2026-09-19（`request/01_GOALS.md`）：
##   "在这之后，艾莉娜会作为主角旁边的跟宠跟在主角身边，
##    艾莉娜的立绘和走动图都已经生成好了。"
##
## ------------------------------------------------------------------ 它不是 NPC
##
## 这一点必须写清楚，否则以后一定有人把它改成 Npc 子类图省事：
##   · **没有** `interact()` / `get_prompt()` / 对话数组 —— 玩家按 E 不该跟跟宠说话
##     （剧情上她是"只有主角看得见听得见"的，交互由剧情脚本编排，不挂在身上）。
##   · **不进 `"npc"` 组**：走查里那几条关于 NPC 的断言（都用统一倍率、都接入专属模型、
##     "不许被街具盖住"）会随机咬住一个**会移动**的节点 —— 那几条会时红时绿，没法查。
##   · **不进 `"player"` 组**：`SceneRouter._place_player()` 会把人瞬移到出生点，
##     `CameraFollow` 也会锁住玩家组里的第一个节点。
##
## ------------------------------------------------------------------ 碰撞
##
##   `collision_layer = 0`（别人"看不见"它，不会被任何探测/碰撞匹配到）
##   `collision_mask = Layers.ENVIRONMENT`（只被墙挡住）
## 照抄 `npc.tscn` 的 `mask = 3` 会让它**把玩家顶开**（玩家 mask 里有 ACTORS）。
##
## ------------------------------------------------------------------ 跟随逻辑（2026-09-20 重写）
##
## 老版本是"朝 玩家位置+固定偏移 走直线"，用户实报"有时候会被模型卡住"：
## 玩家在障碍物另一侧时，那个落点要么在墙后、要么在障碍物**里面**，她就顶着障碍物
## 一路推，永远到不了；而兜底的瞬移阈值是 360px，这种情况一般只有一两百像素，
## **根本触发不到** → 表现就是"被卡住不动了"。
##
## 现在分三层，逐层兜底：
##
##   ① **寻路**（主路径）：`MapNavigation` 给这张图算好"哪能走"，每帧问它要一条
##      "自己 → 落点"的路（A\*，会绕开障碍物），沿路点走。玩家挪远了才重算。
##   ② **脱困**：想走却连续 N 帧几乎没位移 → 判定卡住 → 强制重算路径；
##      重算若干次还卡就"落到离落点最近的可走格上"。专治贴着墙角被碰撞箱挂住。
##   ③ **兜底**：没有寻路数据的场景退回直线跟随 + "掉太远（>360px）瞬移"，
##      行为与老版本一致，不会因为"这张图没算寻路"就变傻。
##
## ------------------------------------------------------------------ ⚠️ 三个实测坑
##
## 都是 2026-09-20 在 `tools/follower_nav_test` 里量出来的，改这段代码前先读一遍：
##
##   1. **"想要的速度"不能直接用 `to_steer.limit_length(max_speed)`**：
##      那个函数在 `|to_steer| <= max_speed` 时**原样返回向量**，于是"想要的速度"
##      等于路点距离（实测 51px/s）—— 她就在走廊里按 51px/s 蹭，玩家一走就被拉开 200px+。
##      正解：取单位方向再乘上限（见 `_move_toward`）。
##   2. **第一个路点是"脚下的格中心"，不能当路点追**：`find_path` 的第一个点固定是
##      起点吸附后的格中心，它可能在她**身后**；追它等于朝反方向加速
##      （实测 `速度=(-127, -7)`，一路往左走）。正解：按距离跳过太近的点（`_waypoint_index`）。
##   3. **落点不能用"玩家位置 + 左右摆动的偏移"**：那个偏移会随玩家横向移动**左右翻**，
##      靶子在玩家左右 40px 之间来回跳，她追左→靶子跳到右→再追右，看着像原地蹭。
##      正解：**面包屑**（玩家走过的那串点，见 `_update_trail`）——
##      它天然落在可走区域内，而且不会左右跳。
##
## ⚠️ 换场景时她**不跟着走**（每个场景由 `CollegeMap._ensure_follower()` 重新建一个），
##    所以"轨迹记不住"这件事不用担心。

## 追到玩家身后多远（世界像素）。取负 x = 跟在左侧偏后，不会挡住玩家前进方向。
## y 取正在玩家**下方**，这样她按 y 排序画在玩家前面一点，看起来是"飘在身侧"。
## ⚠️ 只在**没有面包屑**时用作兜底（刚进场景、玩家还没走动）。
@export var trail_offset: Vector2 = Vector2(-40.0, 22.0)
## 比玩家快一点（玩家 220），否则拐弯后永远追不上。
## ⚠️ 有了寻路之后"快一点"仍然必要：绕路走的总路程比玩家长。
##    实测（`tools/follower_nav_test`，玩家 180px/s 散步）：320 时走廊那段会落后到 240px。
@export var speed: float = 360.0
@export var accel: float = 2000.0
## 离目标点小于这个距离就停下（留出"站着不动时播 idle"的死区）
@export var stop_distance: float = 10.0
## 停下之后，落点要**离开**这么远才再动起来。
##
## ⚠️ 用户 2026-09-20 实报："很多时候尤其**在宿舍里**，停在某个地方时小精灵反复摆动。"
##    根因是**没有迟滞**：落点离障碍近时会被 `find_path` 吸附到另一格，
##    于是"走一点点"就够到死区、`move_and_slide` 又把她推回原处 ——
##    停下→动一下→被推回→再停下，来回蹭（实测折返 6 次/4 秒，位移 7px）。
##    有了迟滞，她一旦停下就必须等落点真的跑远（玩家又走了）才重新起步。
@export var resume_distance: float = 26.0
## 离玩家超过这个距离直接瞬移过去（切场景 / 彻底绕不回来时的兜底）
@export var teleport_distance: float = 360.0
## 出现条件：这个剧情开关打开时才现身并跟随。
## ⚠️ 关掉时**连移动一起停**：只藏不动的写法会让它偷偷跟着跑，
##    下次打开开关时它已经飘到地图另一头了。
@export var require_flag: String = "alyina_follows"

## 玩家挪了多远就重算一次路径（像素²）。
## 不是每帧重算：一次 A\* 要扫几百格，60fps 白跑纯属浪费；24px ≈ 玩家走两帧。
const REPATH_DISTANCE_SQ := 24.0 * 24.0
## 路点算"已经踩到"的距离（像素）：比它更近的点就跳过，去追下一个。
const WAYPOINT_SKIP := 14.0
const WAYPOINT_SKIP_SQ := WAYPOINT_SKIP * WAYPOINT_SKIP

## 卡住判定：想走却连续这么多秒几乎没有位移 → 认为被挡住了（秒）
const STUCK_SECONDS := 0.22
## 判定"几乎没位移"的阈值（像素）：多帧累计位移小于它就算没动
const STUCK_MOVE_EPSILON := 12.0
## 判定"已经脱困、真的走开了"的阈值（像素）。**必须明显大于物理引擎把她从墙里
## 挤出来的那点抖动**（实测 0.3px/帧，来回摆也能累计到十几像素）——
## 见 `_accumulate_stuck` 的注释：门槛太小会让"卡住重算"的计数永远攒不起来。
const STUCK_ESCAPE_DISTANCE := 40.0
## 认为"正在被挡住"的期望速度阈值（像素/秒）
const BLOCKED_SPEED_EPSILON := 25.0
## 连续重算路径这么多次还是卡住 → 才允许"落到可走格上"（先礼后兵）
const STUCK_REPATHS_BEFORE_SNAP := 3
## 强制重算路径的最小间隔（秒）：脱困时要重算，但也别一帧一次
const FORCE_REPATH_COOLDOWN := 0.2

## 掉到这么远之后给一脚油门（见 `_speed_boost`）
const CATCHUP_DISTANCE := 60.0
## 掉队时最多加速到几倍 / 掉到这么远时油门到底
const CATCHUP_SPEED_FACTOR := 2.0
const CATCHUP_FULL_DISTANCE := 160.0

## 面包屑采样间距 / 她跟到"玩家身后多远"
const TRAIL_SAMPLE_DISTANCE := 10.0
const TRAIL_LENGTH := 40.0
@export var follow_distance: float = TRAIL_LENGTH
## 面包屑最多留多少个点（够 TRAIL_LENGTH 就行，留余量）
const TRAIL_MAX_POINTS := 64

## 玩家坐下时的特殊落点：座位点通常在长椅/凳子的占地中间，
## 普通面包屑会把艾莉娜带进家具贴图里。把她放到玩家正南方，
## 也就是家具前沿外侧，既不穿家具，又仍然保持在玩家附近。
const SITTING_FOLLOW_OFFSET := Vector2(0.0, 64.0)

## 调试可视化开关（走查/排查用；正常游玩不开）：
## 打开后会画"不可走格 + 当前路径"，并每 40 个物理帧打一行状态。
var debug_draw := false

var _path: PackedVector2Array = PackedVector2Array()
## 算这条路径时的落点（落点挪远了就重算）
var _path_from_target := Vector2.INF
## 上次算路径的时刻（秒）
var _last_repath_time := -999.0
## 玩家上一帧的位置（估玩家速度）与当前位置（算掉队油门）
var _player_prev := Vector2.INF
var _player_velocity := Vector2.ZERO
var _player_pos := Vector2.INF
## 面包屑：`_trail[0]` 是最新的采样点，越往后越旧；`_trail_head` 是"已经铺到哪儿了"
var _trail: Array[Vector2] = []
var _trail_head := Vector2.INF
## 上一帧玩家是否坐着。坐下/起身的瞬间要清掉旧面包屑，
## 否则目标会在"家具里的旧轨迹"与安全落点之间跳来跳去。
var _player_was_sitting := false
## 已经走到路径里的第几个点（见 `_waypoint_index`）
var _waypoint_reached := 0
## 是不是"已经停下歇着"（见 `resume_distance` 的迟滞说明）
var _at_rest := false
## 卡住检测：位移锚点 / 累计"没进展"的秒数 / 连续重算次数 / 是不是处在一次"卡住"里
var _stuck_anchor := Vector2.INF
var _stuck_time := 0.0
var _stuck_repths := 0
var _stuck_run := false

## 诊断计数（走查断言与日志用）
var stuck_events := 0
var snap_events := 0
var repath_count := 0
## 排查用：上一帧的落点 / 路点 / 想要的速度
var _last_target := Vector2.INF
var _last_waypoint := Vector2.INF
var _debug_wanted := Vector2.ZERO
var _debug_slid := Vector2.ZERO
var _debug_arrived := false

## 剧情离场：清晨对白结束后，艾莉娜要走到宿舍门口再离开。
## 走这条专用状态可以复用跟宠本身的寻路、碰撞和行走动画，避免直接
## queue_free() 造成“瞬移消失”。
var _departure_active := false
var _departure_target := Vector2.INF
var _departure_elapsed := 0.0
const DEPARTURE_TIMEOUT := 6.0
signal departure_finished


func _ready() -> void:
	_setup_physics_layers()
	# 占位视觉的颜色（真素材缺失时才会看到）：给她一个偏青的精灵色，别和同学撞色
	body_color = Color("#7fd8e8")
	head_color = Color("#dff6fb")
	super._ready()
	visible = _should_show()


## 碰撞层约定（写在一处，改的时候不会漏）
func _setup_physics_layers() -> void:
	collision_layer = 0
	collision_mask = Layers.ENVIRONMENT


func _physics_process(delta: float) -> void:
	if _departure_active:
		_process_departure(delta)
		return
	if not _should_show():
		visible = false
		velocity = Vector2.ZERO
		_update_facing_from_velocity(velocity)
		_reset_follow_state()
		_draw_debug()
		return
	visible = true

	var player := _find_player()
	if player == null:
		velocity = Vector2.ZERO
		_update_facing_from_velocity(velocity)
		_reset_follow_state()
		_draw_debug()
		return

	var player_sitting := player.is_sitting()
	var target: Vector2
	if player_sitting:
		# 坐下后玩家的位置固定在座位点；不再追面包屑，直接追家具前沿外侧。
		# 第一次进入坐姿时清掉旧路径，避免沿着坐下前的路线穿过长椅。
		if not _player_was_sitting:
			_reset_follow_state()
		_player_prev = player.global_position
		_player_velocity = Vector2.ZERO
		_player_pos = player.global_position
		target = player.global_position + SITTING_FOLLOW_OFFSET
	else:
		# 起身后重新铺轨迹，避免把坐下期间的安全落点当成普通跟随轨迹。
		if _player_was_sitting:
			_reset_follow_state()
			_player_prev = player.global_position
		_update_trail(player, delta)
		target = _trail_target(player)
	_player_was_sitting = player_sitting
	# ⚠️ 落点被吸附到别处时（玩家贴着家具/墙站）**改用吸附后的点**：
	#    不然"到没到位"是按一个她根本到不了的点算的，她会一直想往那儿挪（抖动来源之一）。
	if _has_navigation():
		var snapped := _snapped_target(target)
		if snapped != Vector2.INF:
			target = snapped
	_last_target = target

	# ① 掉太远（刚切场景、或真的绕不回来）：直接挪过去，别让玩家等
	if global_position.distance_to(player.global_position) > teleport_distance:
		_snap_near(target, player.global_position)
		_draw_debug()
		return

	# ② 停止判定（带**迟滞**，见 `resume_distance`）：
	#    停住之后必须等落点真的跑远才重新起步，否则会在原地来回蹭。
	var gap := global_position.distance_to(target)
	var player_moving := _player_velocity.length() >= stop_distance
	if _at_rest:
		if gap <= resume_distance and not player_moving:
			_coast_to_stop(delta)
			_draw_debug()
			return
		_at_rest = false
	elif gap <= stop_distance and not player_moving:
		_at_rest = true
		_coast_to_stop(delta)
		_draw_debug()
		return

	# ③ 主路径：寻路（没有寻路数据就退回直线）
	var steering := target
	if _has_navigation():
		var waypoint := _follow_path(target)
		if waypoint != Vector2.INF:
			steering = waypoint
	_last_waypoint = steering

	_move_toward(steering, target, delta)
	_check_stuck(delta, target, player.global_position)
	_draw_debug()


## 开始一次剧情离场。目标点应放在门内侧的可走区域，走到后由调用方收掉节点。
func depart_to(target: Vector2) -> void:
	if _departure_active:
		return
	_departure_active = true
	_departure_target = target
	_departure_elapsed = 0.0
	visible = true
	velocity = Vector2.ZERO
	_reset_follow_state()
	if _has_navigation():
		var snapped_target := _snapped_target(_departure_target)
		if snapped_target != Vector2.INF:
			_departure_target = snapped_target
		repath(_departure_target)


## 沿导航路径走到门内侧；没有导航数据时退回直线移动。
func _process_departure(delta: float) -> void:
	if not is_inside_tree():
		return
	_departure_elapsed += delta
	var gap := global_position.distance_to(_departure_target)
	if gap <= stop_distance or _departure_elapsed >= DEPARTURE_TIMEOUT:
		# 正常情况会在门内侧停下；极端情况下导航数据还没准备好时，
		# 也要结束剧情锁，避免玩家被卡在宿舍里。
		if gap > stop_distance:
			global_position = _departure_target
		velocity = Vector2.ZERO
		_update_facing_from_velocity(velocity)
		_departure_active = false
		departure_finished.emit()
		return

	var steering := _departure_target
	if _has_navigation():
		var waypoint := _follow_path(_departure_target)
		if waypoint != Vector2.INF:
			steering = waypoint
	var to_steer := steering - global_position
	var wanted := Vector2.ZERO
	if to_steer.length() > 0.001:
		wanted = to_steer.normalized() * speed
	velocity = velocity.move_toward(wanted, accel * delta)
	move_and_slide()
	_update_facing_from_velocity(velocity)


## 收速度、播 idle（停在原地时的统一出口）
func _coast_to_stop(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, accel * delta)
	move_and_slide()
	_update_facing_from_velocity(velocity)
	_stuck_repths = 0
	_stuck_run = false


## 落点如果不可走（玩家贴着家具/墙），返回离它最近的可走格中心；否则返回 INF。
func _snapped_target(target: Vector2) -> Vector2:
	var nav := _navigation()
	if nav == null or not nav.is_ready() or nav.is_walkable_at(target):
		return Vector2.INF
	return nav.snap_to_walkable(target)


## 还没到位：朝 [param steering] 加速。
##
## ⚠️ 见文件头"实测坑 1"：**不能**写 `to_steer.limit_length(max_speed)` ——
##    路点比速度上限近时会原样返回那个向量，于是"想要的速度"= 路点距离（几十 px/s），
##    她就一路慢慢蹭。这里取单位方向再乘上限；到了落点死区才收速度。
func _move_toward(steering: Vector2, target: Vector2, delta: float) -> void:
	var to_steer := steering - global_position
	var arrived := target.distance_to(global_position) <= stop_distance
	var wanted := Vector2.ZERO
	if not arrived and to_steer.length() > 0.001:
		wanted = to_steer.normalized() * (speed * _speed_boost())
	_debug_wanted = wanted
	_debug_arrived = arrived
	velocity = velocity.move_toward(wanted, accel * delta)
	var before := global_position
	move_and_slide()
	_debug_slid = global_position - before
	_accumulate_stuck()
	_update_facing_from_velocity(velocity)


## 追人时的临时加速倍率（1 = 不加速）。
##
## 为什么需要：正常跟随是"追一个**同向移动**的靶子"，净速度只有 `speed - 玩家速度`
## —— 360 对 220 只剩 140px/s，一拐弯就追不回来（实测走廊那段稳定落后 200px+）。
## 所以掉队时给一脚油门，跟上了就收回正常速度（免得她在玩家身边窜来窜去）。
func _speed_boost() -> float:
	if _player_pos == Vector2.INF:
		return 1.0
	var far := global_position.distance_to(_player_pos)
	if far <= CATCHUP_DISTANCE:
		return 1.0
	return clampf(1.0 + (far - CATCHUP_DISTANCE)
			/ (CATCHUP_FULL_DISTANCE - CATCHUP_DISTANCE) * (CATCHUP_SPEED_FACTOR - 1.0),
			1.0, CATCHUP_SPEED_FACTOR)


# ---------------------------------------------------------------- 面包屑与落点


## 记玩家这一帧的位置，并按 [constant TRAIL_SAMPLE_DISTANCE] 往面包屑里补点。
##
## ⚠️ 采样**必须从"玩家上一帧的位置"往"这一帧的位置"补**，而且只有当玩家真的走了
##    一个采样间距才补 —— 原来写成"从 `_trail_head` 朝玩家方向推"，那个 head 是
##    **跟着她的**，玩家瞬移/她落后时整串点都会歪掉（实测落点在
##    "身后 40px"与"身前 100px"之间反复跳，她就在原地来回加速）。
func _update_trail(player: Node2D, delta: float) -> void:
	var now := player.global_position
	if _player_prev != Vector2.INF and delta > 0.0:
		_player_velocity = (now - _player_prev) / delta
	_player_prev = now
	_player_pos = now

	# 玩家瞬移（切场景 / 剧情摆位）时轨迹没意义，直接重来
	if _trail_head == Vector2.INF or now.distance_to(_trail_head) > teleport_distance * 0.5:
		_trail.clear()
		_trail_head = now
		return

	var guard := 0
	while _trail_head.distance_to(now) >= TRAIL_SAMPLE_DISTANCE and guard < 64:
		var step := _trail_head.direction_to(now) * TRAIL_SAMPLE_DISTANCE
		_trail_head += step
		_trail.push_front(_trail_head)
		guard += 1
	while _trail.size() > TRAIL_MAX_POINTS:
		_trail.pop_back()


## 跟随落点：沿着"玩家走过的面包屑"往回数 [constant TRAIL_LENGTH] 像素的那一点。
## 轨迹还没铺开（刚进场景 / 玩家还没走动）时退回"玩家位置 + trail_offset"。
##
## 这样落点**天然在可走区域内**（那是玩家自己走过的路），而且不会随玩家转向左右跳。
func _trail_target(player: Node2D) -> Vector2:
	if _trail.is_empty():
		return player.global_position + trail_offset
	var travelled := 0.0
	var previous := player.global_position
	for point in _trail:
		travelled += previous.distance_to(point)
		if travelled >= follow_distance:
			return point
		previous = point
	return _trail[_trail.size() - 1]


# ---------------------------------------------------------------- 寻路


## 这张图有没有可用的寻路数据（没算好之前一律退回直线，行为不退化）
func _has_navigation() -> bool:
	var nav := _navigation()
	return nav != null and nav.is_ready()


## 寻路节点住在场景根下（`CollegeMap.setup_navigation()` 建的，名字固定 "Navigation"）
func _navigation() -> MapNavigation:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("Navigation") as MapNavigation


## 拿下一个要走向的路点（没有寻路时返回 INF）。玩家挪远了才重算。
func _follow_path(target: Vector2) -> Vector2:
	if _navigation() == null:
		return Vector2.INF
	var now := float(Time.get_ticks_msec()) / 1000.0
	var stale := _path.is_empty() \
			or _path_from_target == Vector2.INF \
			or _path_from_target.distance_squared_to(target) > REPATH_DISTANCE_SQ
	if stale and now - _last_repath_time >= FORCE_REPATH_COOLDOWN:
		repath(target)
	var index := _waypoint_index()
	if index >= _path.size():
		return Vector2.INF
	return _path[index]


## 就地重算路径（正常重算与脱困共用这一个入口，避免两条路各写一份）
func repath(target: Vector2) -> void:
	var nav := _navigation()
	if nav == null:
		return
	_last_repath_time = float(Time.get_ticks_msec()) / 1000.0
	_path = nav.find_path(global_position, target)
	_path_from_target = target
	_waypoint_reached = 0
	repath_count += 1


## 下一个路点：**按距离**跳过"离自己太近"的点。
##
## ⚠️ 见文件头"实测坑 2"：第一个路点固定是"起点吸附后的格中心"（可能在她身后），
##    必须靠距离把它筛掉；另外**不要**再额外记"走到第几个了"，
##    两套规则叠在一起会把有用的中间点也跳过去。
func _waypoint_index() -> int:
	if _path.is_empty():
		return 0
	var last := _path.size() - 1
	for i in range(_waypoint_reached, _path.size()):
		if global_position.distance_squared_to(_path[i]) > WAYPOINT_SKIP_SQ:
			return i
	return last


# ---------------------------------------------------------------- 脱困


## 每帧把"当前位置"记到锚点上；一旦**真的走开了**就说明脱困了，记账清零。
##
## ⚠️ 门槛必须比"摆动幅度"大：她卡在墙里时物理引擎每帧推她 0.3px 左右，
##    门槛太小（原来是 12px）时那种**来回摆**也会累计到 12px 而把计数清零 ——
##    于是"卡住 → 重算 → 计数归零 → 永远等不到脱困"（实测重算 42 次仍在原地摆）。
func _accumulate_stuck() -> void:
	if _stuck_anchor == Vector2.INF:
		_stuck_anchor = global_position
		return
	if global_position.distance_to(_stuck_anchor) >= STUCK_ESCAPE_DISTANCE:
		_stuck_anchor = global_position
		_stuck_time = 0.0
		_stuck_repths = 0
		_stuck_run = false


## 卡住检测与两级脱困。
##
## ⚠️ **停下来的那一瞬间不要清计数**（这一条是实测逼出来的）：
##    她卡在墙里时速度会忽高忽低（0 / 12 / 32 / 96 px/s 之间跳），
##    老写法"速度低于阈值就清零"会让计数永远攒不到 3，于是**永远等不到脱困**，
##    只能一直在原地重算路径（实测重算 42 次、原地摆 4 秒）。
##    现在只有"真的走开了一段"（`_accumulate_stuck`）才清计数。
func _check_stuck(delta: float, target: Vector2, player_pos: Vector2) -> void:
	var blocked := _stuck_run or velocity.length() <= BLOCKED_SPEED_EPSILON
	if not blocked:
		return
	_stuck_run = true
	_stuck_time += delta
	if _stuck_time < STUCK_SECONDS:
		return
	_stuck_time = 0.0
	# ① 先强制重算路径（也许玩家刚才拐了个弯，旧路已经过期）
	_stuck_repths += 1
	stuck_events += 1
	repath(target)
	if _stuck_repths < STUCK_REPATHS_BEFORE_SNAP:
		return
	# ② 重算也救不回来：落到"离落点最近的可走格"上。
	#    ⚠️ 落点常在墙里/家具里（玩家贴着墙走），所以要用**吸附后**的点，
	#       否则她会被瞬移进墙里，下一次卡住更难出来。
	#    ⚠️ 但已经站到落点跟前就别折腾：那点距离不值得瞬移，不然玩家站在
	#       "她挤不进去的缝"里时会不停瞬移。
	if target.distance_to(global_position) > stop_distance:
		_snap_near(target, player_pos)
		_stuck_repths = 0


## 把自己挪到"离 [param probe] 最近的可走格"（没有寻路数据时按原样挪过去）
func _snap_near(probe: Vector2, player_pos: Vector2) -> bool:
	var nav := _navigation()
	var destination := probe
	if nav != null and nav.is_ready():
		var snapped := nav.snap_to_walkable(probe)
		if snapped != Vector2.INF and snapped.distance_to(player_pos) <= teleport_distance:
			destination = snapped
	global_position = destination
	velocity = Vector2.ZERO
	_reset_follow_state()
	snap_events += 1
	return true


func _reset_follow_state() -> void:
	_path = PackedVector2Array()
	_path_from_target = Vector2.INF
	_waypoint_reached = 0
	_at_rest = false
	_stuck_anchor = global_position
	_stuck_time = 0.0
	_stuck_repths = 0
	_stuck_run = false
	_last_target = Vector2.INF
	_last_waypoint = Vector2.INF
	# 面包屑也要清：切场景/瞬移之后"她刚才追的那串点"已经不在当前这张图上了
	_trail.clear()
	_trail_head = Vector2.INF


# ---------------------------------------------------------------- 查询接口


## 现在该不该现身（剧情开关）
func _should_show() -> bool:
	if require_flag == "":
		return true
	return GameFlow.has_flag(require_flag)


## 当前是否在跟着玩家（走查断言用）
func is_following() -> bool:
	return _should_show() and _find_player() != null


func _find_player() -> Player:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Player


# ---------------------------------------------------------------- 调试


## 当前是不是在走寻路（走查断言用：证明"她是照着路走的"，不是碰巧直线能到）
func is_navigating() -> bool:
	return _has_navigation()


## 当前算出来的路径点数（0 = 没路。走查断言用）
func path_point_count() -> int:
	return _path.size()


## 步行速度（走查断言用）
func debug_speed() -> float:
	return velocity.length()


## 面包屑长度（走查断言用）
func debug_trail_size() -> int:
	return _trail.size()


## 当前落点（走查诊断用）
func debug_target() -> Vector2:
	return _last_target


## 一行状态（排查"她为什么站着不动 / 往反方向走"用）
func debug_state() -> String:
	return "pos=%s 落点=%s 路点=%s idx=%d/%d 速度=%.0f 想要=%s 歇=%s 卡=%d 瞬移=%d 重算=%d" % [
		str(global_position), str(_last_target), str(_last_waypoint),
		_waypoint_reached, _path.size(), velocity.length(),
		str(_debug_wanted), str(_at_rest),
		stuck_events, snap_events, repath_count]


## 调试可视化：画"不可走格"（淡红）与当前路径（黄点）。
## 开关是 `debug_draw`，正常游玩永远关着 —— 这里一个像素都不会画。
func _draw_debug() -> void:
	if not debug_draw:
		return
	queue_redraw()
	var nav := _navigation()
	if nav != null:
		var cell := MapNavigation.CELL
		var tint := Color(1.0, 0.35, 0.3, 0.16)
		for center in nav.debug_blocked_centers():
			draw_rect(Rect2(center - Vector2(cell, cell) * 0.5, Vector2(cell, cell)), tint)
	var prev := global_position
	for point in _path:
		draw_line(prev, point, Color(1.0, 0.85, 0.2, 0.7), 1.0)
		draw_circle(point, 2.0, Color(1.0, 0.85, 0.2))
		prev = point
