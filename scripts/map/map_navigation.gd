class_name MapNavigation
extends Node2D
## 一张地图的**可走格子图 + A\* 寻路**（跟宠跟随用；以后 NPC/寻路剧情也能直接用）。
##
## ------------------------------------------------------------------ 为什么需要它
##
## 用户实报（2026-09-20）："小精灵跟随有时候会被模型卡住"。
##
## 根因在老 `Follower._physics_process()`：它算的落点是「玩家位置 + 固定偏移」，
## 然后**朝那个点走直线**。玩家在桌子/建筑另一侧时，那个落点要么在墙后、要么在障碍物
## **里面**，于是她顶着障碍物一路推，永远到不了；而兜底的"掉太远就瞬移"阈值是 360px，
## 这种情况往往只有一两百像素，**根本触发不到** → 看起来就是"被卡住不动了"。
##
## 正解不是调那几个阈值，而是让她**认识路**：先把"哪能走"算成一张格子图，
## 再用 A\* 给一条**绕开障碍物**的路。
##
## ------------------------------------------------------------------ 为什么不用引擎的导航网格
##
## 先试过 `NavigationServer2D` + 运行时烘焙（`bake_from_source_geometry_data`），
## 在本项目上实测**不可用**（2026-09-20）。三条实测结论都记下来，免得以后有人再走一遍：
##
##   ① 烘焙出来的网格是**碎的**：宿舍烘出 29 个多边形、68 个顶点，其中一大半是
##      互不连通的碎块（床/桌/柜之间 10~40px 的缝隙），A\* 在里面找不到通路；
##   ② 它还会在地图**外面**生成多边形（实测有多边形落在 x∈[-20,532] 这种明显在墙外的
##      位置）—— 因为可走轮廓只能给一个矩形，墙是"在矩形里挖洞"，挖出来的边角不受约束；
##   ③ 同一个可走点在不同时机查询会得到不同结果（`get_closest_point` 时对时错）。
##
## 自己写的好处正好对上本项目的三条硬要求：
##   · **确定性**：格子是整数，路径可复现，自检能逐段断言"这条路真的没穿墙"；
##   · **零几何误差**：障碍**直接复用地图自己的数据**（`TileRoom.wall_cells()` +
##     `prop_records()` 的落地碰撞矩形），与"看到的""撞到的"同源；
##   · **小**：没有额外资源、没有烘焙时机问题，走查里能直接调。
##
## ------------------------------------------------------------------ 格子怎么算
##
##   · 格边长 `CELL = 8px`（= `Grid.CELL` 的一半，见常量注释：取整格会把过道堵死）；
##   · 障碍物外扩 `AGENT_RADIUS_CELLS = 1` 格 = 8px，所以路径天然离墙 8px；
##   · 8 方向 A\*（`AStarGrid2D`），**不允许斜穿障碍角**，最后再做一次可视拉直；
##   · 最后一步用**物理查询**按"代理身体真的放得下吗"精修一遍（见 `_measure_body_fit`）：
##     格子是 8px、她的碰撞半径也是 8px —— "格中心可走"不等于"身体放得下"，
##     不一致的地方她会**卡在墙里**（物理引擎每帧把她挤出 0.3px，她就在原地反复摆）。
##
## ------------------------------------------------------------------ 精修为什么要晚一帧
##
## 精修用的是 `PhysicsShapeQueryParameters2D` 查询**物理空间**，而墙/家具的碰撞体是
## 场景 `_ready()` 里刚建出来的 —— 物理服务器要等下一次物理步才会把新形状注册进去。
## 所以 `build()` 先做**几何部分**（先让网格可用），精修放在第 1 个物理帧之后
## （`_process` 里一次）。这中间玩家一步都走不了，不存在"用坏网格寻路"的窗口。
##
## ------------------------------------------------------------------ 对外接口
##
##   `is_ready()`             格子图建好了没（没建好时跟宠退回直线跟随）
##   `find_path(from, to)`    世界坐标 → 一串世界坐标路点（空数组 = 走不过去）
##   `snap_to_walkable(pos)`  把一个可能落在障碍/墙里的点，吸附到最近的可走格中心
##   其余 `is_walkable_*` / `is_blocked_*` / `blocked_runs()` 是走查断言用的。

## 格边长（像素）。见文件头"格子怎么算"。
const CELL := 8.0
## 障碍物外扩多少格（1 格 = 8px）。
##
## ⚠️ 实测 16px 余量会把宿舍的窄过道整段抹掉（左右两半变成两个互不连通的区域，
##    她只能绕最中间那条宽过道，"跟丢"就是这么来的）。
## ⚠️ 8px 也有代价（2026-09-20 走廊实测）：走廊可走带只有 32px 高，
##    外扩一圈之后**只剩一行可走**，她的实际站位（偏下 4px）就落到"不可走"里了 ——
##    `find_path` 会把她脚下的起点吸附到那一行，路点全在头顶，她只能斜着蹭。
##    所以默认取 0：**让路径贴着障碍走，由她的碰撞体 + 卡住脱困去兜底**。
const AGENT_RADIUS_CELLS := 0
## 平滑路径时最多尝试跳多远（格）。64 格 × 8px = 512px 的直线可视距离，够拉直走廊。
const SMOOTH_MAX_SKIP := 64
## 一张图最多允许多少格（防止某个场景把世界矩形写得离谱时爆内存）
const MAX_CELLS := 400_000
## "够不到落点"时最多往外找几圈（每圈 = 1 格 = 8px）
const NEAREST_REACHABLE_RINGS := 24
## 每圈最多试几个候选（按"离她自己最近"排序后截取）
const NEAREST_REACHABLE_TRIES := 12

# ---------------------------------------------------------------- 内部状态

var _origin := Vector2i.ZERO        ## 格子图左上角对应的**世界像素**（对齐到 CELL）
var _size := Vector2i.ZERO          ## 格子图尺寸（格）
var _blocked := PackedByteArray()   ## 1 = 不可走
var _ready := false
var _astar := AStarGrid2D.new()

## 统计（自检/日志用）
var wall_cells := 0
var obstacle_cells := 0
var blocked_cells := 0
var walkable_cells := 0
var last_path_points := 0           ## 上次 `find_path` 给了几个路点
var path_requests := 0
var path_failures := 0
var build_ms := 0.0                 ## 建格子图花了多少毫秒（见 `build` 的说明）
## 跟宠/代理的身体半径与**碰撞圆心相对节点原点的偏移**（像素）。
##
## ⚠️ 两个数都必须与 `scenes/actors/follower.tscn` 一致：
##    半径 8（`Body` 的 `CircleShape2D`）、圆心 y = +4（`Body` 的 `position`）。
##    对不上的后果：精修把"她实际站的位置"当成"格中心"去查 ——
##    差 4px 就足以让某些格子被判成能站，而她站在那儿会被物理引擎每帧挤出来（原地抖）。
const AGENT_BODY_RADIUS := 8.0
const AGENT_BODY_OFFSET := Vector2(0.0, 4.0)
## 精修用到的物理空间（由 `CollegeMap.setup_navigation()` 传进来）
var _space: PhysicsDirectSpaceState2D = null
## 精修结果
var refined := false
var refine_ms := 0.0
var refine_removed := 0


## 建格子图。返回是否建出了可走的格子。
##
## ⚠️ 这是**同步**调用（在场景 `_ready()` 的末尾），所以要看一眼耗时：
##    校园三区是 1536x1088（192x136 格 = 26112 格），实测约 40~60ms —— 一次场景切换
##    里可以接受（本来就有淡入淡出）。如果以后图再大一圈，这里要改成异步或分帧。
func build(map: TileRoom, walk_rect: Rect2) -> bool:
	var started := Time.get_ticks_usec()
	if map == null:
		push_warning("MapNavigation: 没有 TileRoom，跳过可走格子图（跟宠会退回直线跟随）")
		return false

	# ---- 1) 范围：世界矩形 ∪ 地板层实际铺到的范围 ----
	#
	# ⚠️ 两者都要：校园三区的地板只铺在草地/路面上（房子底下没有地板），
	#    而墙环是画在世界边界上的。只取地板会让建筑底下那块漏判，只取世界矩形
	#    则依赖"墙环一定闭合"。取并集之后两种摆法都成立。
	var bounds := _aligned_rect(walk_rect)
	var floor_cells := map.floor_cells()
	if not floor_cells.is_empty():
		var first: Vector2i = floor_cells[0]
		var merged := Rect2i(first, Vector2i.ONE)
		for cell_variant in floor_cells:
			var cell: Vector2i = cell_variant
			merged = merged.merge(Rect2i(cell, Vector2i.ONE))
		bounds = bounds.merge(_aligned_rect(Grid.cells_to_rect(merged)))
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		push_warning("MapNavigation: 可走范围为空（世界矩形=%s 地板格=%d）"
				% [str(walk_rect), floor_cells.size()])
		return false
	if bounds.size.x * bounds.size.y > MAX_CELLS:
		push_warning("MapNavigation: 可走范围过大（%s 格 > 上限 %d），本场景不建寻路数据"
				% [str(bounds.size), MAX_CELLS])
		return false
	_origin = bounds.position
	_size = bounds.size

	# ---- 2) 障碍：墙层格子 + 家具落地碰撞矩形 ----
	_blocked.resize(_size.x * _size.y)
	_blocked.fill(0)
	for cell_variant in map.wall_cells():
		var cell: Vector2i = cell_variant
		wall_cells += 1
		for grid_cell in _tile_cell_to_grid_cells(cell):
			_set_blocked(grid_cell)
	for record_variant in map.prop_records():
		var record: Dictionary = record_variant
		var collision: Rect2 = record.get("collision", Rect2())
		if collision.size.x <= 0.0 or collision.size.y <= 0.0:
			continue
		# 家具碰撞本来就是格对齐的；向上取整到格，宁可多算一格也不能漏（漏了就是穿模）
		for grid_cell in _world_rect_to_grid_cells(collision):
			obstacle_cells += 1
			_set_blocked(grid_cell)

	# ---- 3) 外扩 AGENT_RADIUS_CELLS 格（贴墙那一圈也算不可走） ----
	_dilate(AGENT_RADIUS_CELLS)

	# ---- 4) 统计 ----
	blocked_cells = 0
	for i in _blocked.size():
		if _blocked[i] != 0:
			blocked_cells += 1
	walkable_cells = _size.x * _size.y - blocked_cells
	_ready = walkable_cells > int(float(_size.x * _size.y) * 0.05)
	if not _ready:
		push_warning("MapNavigation: 一格可走的地方都没有（障碍 %d 格 / 共 %d 格）"
				% [blocked_cells, _size.x * _size.y])
		return false

	# ---- 5) 交给 AStarGrid2D ----
	_push_to_astar()
	build_ms = float(Time.get_ticks_usec() - started) / 1000.0
	return true


## 把 `_blocked` 同步进 `AStarGrid2D`（建图与精修之后都要做一次）
func _push_to_astar() -> void:
	_astar.region = Rect2i(Vector2i.ZERO, _size)
	_astar.cell_size = Vector2(CELL, CELL)
	# 斜着走不能贴着障碍的两个角穿过去（否则拉直之后会看着像"擦着桌角穿模"）
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	for y in _size.y:
		for x in _size.x:
			_astar.set_point_solid(Vector2i(x, y), _blocked[y * _size.x + x] != 0)


## 精修：把"格中心可走、但**代理的身体放不下**"的格子标成不可走。
##
## ⚠️ 这一步不能省（用户 2026-09-20 实报"在宿舍里停在某处反复摆动"）：
##    格子是 8px，而跟宠的碰撞半径也是 8px —— 一个直径 16px 的身体塞进 8px 的格子，
##    "格中心没被障碍压住"**不等于**"身体放得下"。实测宿舍里 20 个抽样可走格中有 2 个
##    身体放不下：她走到那儿会被物理引擎每帧挤出 0.3px，看起来就是**站在原地反复摆**。
##
## 为什么用物理查询而不是几何外扩：外扩是"按格子数"算的，一刀切 ——
## 外扩一圈会把 32px 的走廊整段抹掉（实测走廊只剩一行可走，她就被挤到墙里）。
## 查询问的是"这一格她的身体真的放得下吗"，得到的网格与她的碰撞体**完全一致**。
##
## [param space] 由调用方传（场景 `_ready()` 里 `get_world_2d().direct_space_state`）。
## 不在 `build()` 里做：那时候刚建出来的碰撞体还没注册进物理空间，查了全是空的。
func refine_body_fit(space: PhysicsDirectSpaceState2D) -> void:
	if space == null or _size.x <= 0:
		return
	_space = space
	var started := Time.get_ticks_usec()
	var params := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = AGENT_BODY_RADIUS
	params.shape = shape
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = Layers.ENVIRONMENT

	# 只需要查"身体可能会压到障碍"的格子：**离任何障碍格不超过 reach 格**的那些。
	# ⚠️ 候选集合必须算准（宁可多算）：漏掉一格 = 她能站进一个"身体放不下"的地方，
	#    表现就是站在原地反复摆（用户实报的那个问题就是这么来的）。
	#    这里反过来扫 —— 每个障碍格往外扩 reach 格，标进候选位图，比"每格扫矩形"便宜得多。
	var reach := int(ceil(AGENT_BODY_RADIUS / CELL)) + 1
	var candidate_mask := PackedByteArray()
	candidate_mask.resize(_size.x * _size.y)
	candidate_mask.fill(0)
	for y in _size.y:
		for x in _size.x:
			if _blocked[y * _size.x + x] == 0:
				continue
			for dy in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= _size.x or ny >= _size.y:
						continue
					candidate_mask[ny * _size.x + nx] = 1
	var candidates: Array[Vector2i] = []
	for y in _size.y:
		for x in _size.x:
			if candidate_mask[y * _size.x + x] != 0 and _blocked[y * _size.x + x] == 0:
				candidates.append(Vector2i(x, y))

	# 查询是这里最贵的一步（一次约 50µs，校园三区近两千个候选直查要 80ms+），
	# 所以按 2x2 的块**查一格 + 保守标四格**。
	#
	# ⚠️ **查询点要"向右下各多查一格"**（见 `blocked_by_body`）：只查块左上角那一格时，
	#    如果障碍的上边缘正好切过块的中点，那一格查得到"放得下"，而块里的
	#    (1,1) 格其实放不下 —— 实测宿舍有 4 处这样的漏网，她站上去就被挤得原地抖。
	var block_blocked: Dictionary = {}
	for cell in candidates:
		var origin := Vector2i(cell.x - (cell.x & 1), cell.y - (cell.y & 1))
		if not block_blocked.has(origin):
			var blocked_block := _blocked_by_body(space, params, origin)
			block_blocked[origin] = blocked_block
			if blocked_block and _blocked_at(origin) == 0:
				_set_blocked(origin)
				refine_removed += 1
		if not bool(block_blocked[origin]) or _blocked_at(cell) != 0:
			continue
		_set_blocked(cell)
		refine_removed += 1

	blocked_cells = 0
	for i in _blocked.size():
		if _blocked[i] != 0:
			blocked_cells += 1
	walkable_cells = _size.x * _size.y - blocked_cells
	_push_to_astar()
	refined = true
	refine_ms = float(Time.get_ticks_usec() - started) / 1000.0


## 这一格的身体放得下吗？
##
## 查 2 个点：格中心，以及**向右下挪一格**的中心。
## ⚠️ 为什么不能只查格中心：块是 2x2、每格 8px，而她的碰撞圆直径 16px ——
##    障碍的上边缘只要切过块的中点，块左上角那一格就可能"放得下"，
##    而块里的 (1,1) 格放不下（实测宿舍 4 处）。
## ⚠️ **也别多查**（比如把左上/右上/左下都查一遍）：那等于把"她其实挤得过去的
##    16px 过道"整条抹掉，她会被关进一片小口袋里出不来 ——
##    实测四点是 610 格、可走 984 格时她就在 (117.8, 83.3) 原地打转（路径 0 点）。
func _blocked_by_body(space: PhysicsDirectSpaceState2D,
		params: PhysicsShapeQueryParameters2D, origin: Vector2i) -> bool:
	for offset_variant in [Vector2i.ZERO, Vector2i(1, 1)]:
		var offset: Vector2i = offset_variant
		var cell := origin + offset
		if _blocked_at(cell) != 0:
			continue        # 已经被几何挡住的格子不用查
		params.transform = Transform2D(0.0, cell_to_world(cell) + AGENT_BODY_OFFSET)
		if not space.intersect_shape(params, 1).is_empty():
			return true
	return false


## 这一格的 `radius` 格范围内有没有不可走格（只看圈，不看整块矩形）
func _has_solid_within(cell: Vector2i, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			# 只看这一圈的外框
			if absi(dx) != radius and absi(dy) != radius:
				continue
			if _blocked_at(cell + Vector2i(dx, dy)) != 0:
				return true
	return false


# ---------------------------------------------------------------- 查询


func is_ready() -> bool:
	return _ready


## 身体尺寸精修做完了没（走查要等它，见 `refine_body_fit`）
func is_refined() -> bool:
	return refined


## 格子图尺寸（格）
func grid_size() -> Vector2i:
	return _size


## 某个**世界坐标**附近那一格可不可走
func is_walkable_at(world_pos: Vector2) -> bool:
	return is_walkable_cell(world_to_cell(world_pos))


func is_walkable_cell(cell: Vector2i) -> bool:
	return _blocked_at(cell) == 0


func is_blocked_cell(cell: Vector2i) -> bool:
	return _blocked_at(cell) != 0


## 世界坐标 → 格子坐标
func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori((world_pos.x - float(_origin.x)) / CELL),
		floori((world_pos.y - float(_origin.y)) / CELL))


## 格子坐标 → 该格中心的世界坐标
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(_origin) + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


## 找离 [param world_pos] 最近的**可走格中心**。整张图没有可走格时返回 `Vector2.INF`。
##
## 为什么不是"吸附到最近的一格"：那个点可能自己在墙里（玩家贴着墙走时，
## 她身后 40px 的落点经常就在墙里），吸附过去等于把她塞进墙。
func snap_to_walkable(world_pos: Vector2) -> Vector2:
	var cell := _nearest_open_cell(world_pos)
	if cell.x < 0:
		return Vector2.INF
	return cell_to_world(cell)


# ---------------------------------------------------------------- 寻路


## 算一条 `from → to` 的路（都是**世界像素**）。
##
## 返回一串世界坐标路点（**第一个是吸附过的起点**，最后一个是实际到达点，未必等于
## [param to]：终点在障碍里时会落到最近的可走格）。返回空数组 = 走不过去。
##
## 起终点都会先吸附到最近的可走格，所以调用方**不必**先自己检查 ——
## 玩家贴着墙、站在家具边上都是常态，让调用方每次先判反而容易漏。
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	path_requests += 1
	if not _ready:
		path_failures += 1
		return PackedVector2Array()

	var start := _nearest_open_cell(from)
	var goal := _nearest_open_cell(to)
	if start.x < 0 or goal.x < 0:
		path_failures += 1
		return PackedVector2Array()

	# 终点/起点**不在可走格上**时（玩家贴着墙、站在家具边是常态）：把它挪到真正可走的格中心。
	# ⚠️ 这一步不能省。`_nearest_open_cell` 会把请求点夹到"最近的可走格"，但如果
	#    请求点本身落在不可走格里，那个格可能离它有好几格远 —— 于是
	#    "请求点 → 第一个路点"这一段本来就是穿障碍的。原来把 `from` 原样交给 `_smooth`
	#    当锚点，拉直失败时会把这条**穿墙的原始路径**原样返回（自检量到的"路径穿障碍"）。
	var anchor := cell_to_world(start)
	if not is_walkable_at(from):
		var snapped_from := snap_to_walkable(from)
		if snapped_from != Vector2.INF:
			anchor = snapped_from
			start = _nearest_open_cell(snapped_from)
	if not is_walkable_at(to):
		var snapped_goal := snap_to_walkable(to)
		if snapped_goal != Vector2.INF:
			goal = _nearest_open_cell(snapped_goal)

	var cells: PackedVector2Array = _astar.get_id_path(start, goal)
	if cells.is_empty():
		# ⚠️ 够不到落点（它在另一个连通块里，或者她**自己那一格已经是不可走**）：
		#    退而求其次，找"从她这儿真能走到的、离落点最近的一格"。
		#    没有这一步时 `find_path` 会返回空数组 → 跟宠退回"朝落点直线推" →
		#    顶着障碍原地摆（实测：卡在 (117.8, 83.3) 反复折返 4 秒、重算 42 次）。
		cells = _path_to_nearest_reachable(start, goal)
		if cells.is_empty():
			path_failures += 1
			return PackedVector2Array()

	# 第一个路点**必须是这个吸附过的锚点**：这样"调用方当前位置 → 第一个路点"这一段
	# 一定落在可走区域内（调用方的位置本来就是可走的）。跟宠那边有"离路点 14px 就算踩到"
	# 的跳过逻辑，不会因此绕小圈。
	var points := PackedVector2Array()
	points.append(anchor)
	for i in range(1, cells.size()):
		points.append(cell_to_world(cells[i]))
	points = _smooth(points, anchor)
	last_path_points = points.size()
	return points


## 找"从 [param start] 真能走到、且离 [param goal] 最近"的那一格，返回路径（含起点）。
##
## 用一圈圈往外试的办法（每圈取"离她自己最近"的几个候选试 A\*），
## 上限 `NEAREST_REACHABLE_RINGS` 圈；一个都试不出来就返回空数组。
## 只在"直接寻路失败"时才跑，所以平时不花代价。
##
## ⚠️ `AStarGrid2D.get_id_path()` 返回的是 `PackedVector2Array`（元素是格坐标的 float 形式），
##    不是 `Array[Vector2i]` —— 直接赋给后者会报"类型不匹配"（踩过）。
func _path_to_nearest_reachable(start: Vector2i, goal: Vector2i) -> PackedVector2Array:
	var rings := mini(maxi(_size.x, _size.y), NEAREST_REACHABLE_RINGS)
	for radius in range(0, rings):
		var probes: Array[Vector2i] = []
		if radius == 0:
			probes.append(goal)
		else:
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if absi(dx) != radius and absi(dy) != radius:
						continue
					probes.append(goal + Vector2i(dx, dy))
			# 先试"离她自己最近"的那几个：那是她最可能真的走得到的
			probes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return start.distance_squared_to(a) < start.distance_squared_to(b))
		var limit := mini(probes.size(), NEAREST_REACHABLE_TRIES)
		for i in limit:
			var probe: Vector2i = probes[i]
			if not _astar.is_in_boundsv(probe) or _astar.is_point_solid(probe):
				continue
			var path := _astar.get_id_path(start, probe)
			if not path.is_empty():
				return path
	return PackedVector2Array()


# ---------------------------------------------------------------- 内部：坐标换算


## 把世界矩形对齐到格（起点向下取整、终点向上取整），返回**格矩形**
func _aligned_rect(rect: Rect2) -> Rect2i:
	var x0 := floori(rect.position.x / CELL)
	var y0 := floori(rect.position.y / CELL)
	var x1 := ceili(rect.end.x / CELL)
	var y1 := ceili(rect.end.y / CELL)
	return Rect2i(x0, y0, maxi(0, x1 - x0), maxi(0, y1 - y0))


## 一个**图块格**（16px）覆盖到的所有格子（8px）→ 4 个
func _tile_cell_to_grid_cells(cell: Vector2i) -> Array[Vector2i]:
	var factor := int(Grid.CELL / CELL)
	var out: Array[Vector2i] = []
	for dy in factor:
		for dx in factor:
			out.append(Vector2i(
				(cell.x - _origin.x) * factor + dx,
				(cell.y - _origin.y) * factor + dy))
	return out


## 一个世界矩形（家具落地碰撞）覆盖到的所有格子
func _world_rect_to_grid_cells(rect: Rect2) -> Array[Vector2i]:
	var aligned := _aligned_rect(rect)
	var out: Array[Vector2i] = []
	for y in range(aligned.position.y, aligned.end.y):
		for x in range(aligned.position.x, aligned.end.x):
			out.append(Vector2i(x - _origin.x, y - _origin.y))
	return out


# ---------------------------------------------------------------- 内部：格子读写


func _blocked_at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= _size.x or cell.y >= _size.y:
		return 1
	return _blocked[cell.y * _size.x + cell.x]


func _set_blocked(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= _size.x or cell.y >= _size.y:
		return      # 范围外的墙不用记（本来就在图外，`_blocked_at` 会当成不可走）
	_blocked[cell.y * _size.x + cell.x] = 1


## 把不可走的格子往外扩 [param radius] 格（八邻域方形膨胀）
func _dilate(radius: int) -> void:
	if radius <= 0:
		return
	var source := _blocked.duplicate()
	for y in _size.y:
		for x in _size.x:
			if source[y * _size.x + x] == 0:
				continue
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= _size.x or ny >= _size.y:
						continue
					_blocked[ny * _size.x + nx] = 1


## 找离某个世界坐标最近的可走格（返回格坐标；找不到返回 (-1,-1)）
func _nearest_open_cell(world_pos: Vector2) -> Vector2i:
	var cell := world_to_cell(world_pos)
	cell = Vector2i(
		clampi(cell.x, 0, maxi(0, _size.x - 1)),
		clampi(cell.y, 0, maxi(0, _size.y - 1)))
	if _blocked_at(cell) == 0:
		return cell
	var limit := maxi(_size.x, _size.y)
	for radius in range(1, limit):
		var best := Vector2i(-1, -1)
		var best_dist := INF
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				# 只看这一圈的外框（里圈上一轮已经找过）
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var probe := cell + Vector2i(dx, dy)
				if _blocked_at(probe) != 0:
					continue
				var dist := Vector2(dx, dy).length_squared()
				if dist < best_dist:
					best_dist = dist
					best = probe
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## 把一串"格中心"路点做**可视拉直**：能直着走到后面某个点，就把中间的点删掉。
##
## 为什么需要：格中心路径天生是"楼梯状"的，她照着走会一顿一顿。
##
## ⚠️ **不能"实在拉不直就硬接下一个点"**（这一条是走查抓出来的）：
##    起点常常被吸附过（玩家站在外扩圈里），于是"起点 → 第二个路点"这一段可能本来就
##    穿障碍。原来的写法在这种情况下会把一个**穿墙的路点**直接塞进结果里，
##    自检一量就是"路径穿过障碍块"。
##    现在的写法保证：**要么能直着走到，要么就退回原始格中心路径**（逐格相邻，天然安全）。
func _smooth(points: PackedVector2Array, from: Vector2) -> PackedVector2Array:
	if points.size() <= 1:
		return points
	var out := PackedVector2Array()
	var anchor := from
	var index := 0
	while index < points.size():
		var jumped := -1
		var probe := mini(points.size() - 1, index + SMOOTH_MAX_SKIP)
		while probe > index:
			if _segment_clear(anchor, points[probe]):
				jumped = probe
				break
			probe -= 1
		if jumped < 0:
			if not _segment_clear(anchor, points[index]):
				# 连下一个点都走不过去：说明起点被吸附过，**放弃拉直**，把原始路径原样交出去
				return points
			jumped = index
		out.append(points[jumped])
		anchor = points[jumped]
		index = jumped + 1
	return out


## 两个世界坐标之间能不能直着走过去。
##
## ⚠️ **不能用"沿线段密集采样"**（这一条是走查量出来的）：采样点可能**跳过一个格子**，
##    于是斜着穿过障碍**转角**的那一小块永远不会被采到 —— 拉直之后的路径看着直，
##    实际会从桌角/墙角"擦"过去（自检量到 24 条这样的路径）。
##    这里用的是**超覆盖格遍历**（Amanatides & Woo 的 DDA）：线段经过的**每一个**格子
##    都会被访问到，不可能漏。
func _segment_clear(from: Vector2, to: Vector2) -> bool:
	var x0 := floori(from.x / CELL)
	var y0 := floori(from.y / CELL)
	var x1 := floori(to.x / CELL)
	var y1 := floori(to.y / CELL)
	# 起点格自己可能是不可走的（被吸附过的请求点），那一格不算在"路上"
	var cell := Vector2i(x0, y0)
	var dx := to.x - from.x
	var dy := to.y - from.y
	var step_x := signi(x1 - x0)
	var step_y := signi(y1 - y0)
	# 沿 x / y 方向走到"下一列/下一行"的参数增量
	var t_delta_x := INF if step_x == 0 else CELL / absf(dx)
	var t_delta_y := INF if step_y == 0 else CELL / absf(dy)
	var next_x := float(x0 + (1 if step_x > 0 else 0)) * CELL
	var next_y := float(y0 + (1 if step_y > 0 else 0)) * CELL
	var t_max_x := INF if step_x == 0 else (next_x - from.x) / dx
	var t_max_y := INF if step_y == 0 else (next_y - from.y) / dy
	# 最多走"格数之和 + 2"步就一定到终点了（防御性上界，避免浮点误差导致死循环）
	var limit := absi(x1 - x0) + absi(y1 - y0) + 2
	for i in limit:
		if cell.x == x1 and cell.y == y1:
			return true
		# 取更早发生的那个轴穿越；相等时两个一起跨（正好穿角）
		if t_max_x < t_max_y:
			cell.x += step_x
			t_max_x += t_delta_x
		elif t_max_y < t_max_x:
			cell.y += step_y
			t_max_y += t_delta_y
		else:
			cell.x += step_x
			cell.y += step_y
			t_max_x += t_delta_x
			t_max_y += t_delta_y
		if not _can_traverse(cell):
			return false
	return true


## 线段能不能踩这一格（越界按不可走算）
func _can_traverse(cell: Vector2i) -> bool:
	return _blocked_at(cell) == 0


# ---------------------------------------------------------------- 自检 / 调试


## 一行概况（各场景自检里打印，方便"这图有没有寻路数据"一眼可见）
func describe() -> String:
	return ("寻路：格子=%s（%d 格，每格 %.0fpx）原点=%s 墙=%d 家具格=%d 不可走=%d 可走=%d "
			+ "就绪=%s 建图=%.0fms 精修=%s（剔 %d 格 %.0fms）") % [
		str(_size), _size.x * _size.y, CELL, str(_origin),
		wall_cells, obstacle_cells, blocked_cells, walkable_cells, str(_ready),
		build_ms, str(refined), refine_removed, refine_ms]


## 单个格子的原始状态（排查"为什么这格算可走"用）
func debug_cell_state(cell: Vector2i) -> String:
	return "格%s：local=%s blocked=%d 世界=%s size=%s origin=%s" % [
		str(cell), str(cell), _blocked_at(cell), str(cell_to_world(cell)),
		str(_size), str(_origin)]


## 公开版：两个世界坐标之间能不能直着走过去（走查拿它量"路径有没有穿障碍"，
## 与内部拉直用的是**同一个**判定，避免"自检用的尺子和实现不是同一把"）。
func segment_clear(from: Vector2, to: Vector2) -> bool:
	return _segment_clear(from, to)


## 某个世界坐标离最近的**不可走格**有多远（像素）。走查用它量"路径有没有贴着墙走"。
## 超出 [param radius] 格范围就算够远，直接返回 `radius * CELL`（不为了量一个数扫全图）。
func distance_to_blocked(world_pos: Vector2, radius: int = 6) -> float:
	var center := world_to_cell(world_pos)
	var best := INF
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cell := center + Vector2i(dx, dy)
			if _blocked_at(cell) == 0:
				continue
			# "格中心距查询点"减半格 = 到那一格边缘的距离（格子是有面积的）
			var distance := Vector2(cell - center).length() * CELL - CELL * 0.5
			best = minf(best, distance)
	if best == INF:
		return float(radius) * CELL
	return maxf(0.0, best)


## 所有不可走格的中心（调试可视化用；量大，只在 `debug_draw` 打开时调）
func debug_blocked_centers() -> PackedVector2Array:
	var out := PackedVector2Array()
	for y in _size.y:
		for x in _size.x:
			if _blocked[y * _size.x + x] != 0:
				out.append(cell_to_world(Vector2i(x, y)))
	return out


## 把格子图打成 ASCII（排查"哪一段过道被堵死了"用）。
## [param step] 是采样步长（格）：1 = 每一格都画（很长），8 = 每 64px 画一个点。
func debug_ascii(step: int = 4) -> String:
	var text := ""
	for y in range(0, _size.y, step):
		for x in range(0, _size.x, step):
			text += "#" if _blocked[y * _size.x + x] != 0 else "."
		text += "\n"
	return text


## 把同一行相邻的不可走格并成矩形（走查断言"路径有没有穿障碍"用）
func blocked_runs() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for y in _size.y:
		var run_start := -1
		for x in range(0, _size.x + 1):
			var solid := x < _size.x and _blocked[y * _size.x + x] != 0
			if solid and run_start < 0:
				run_start = x
			elif not solid and run_start >= 0:
				out.append(Rect2(
					cell_to_world(Vector2i(run_start, y)) - Vector2(CELL, CELL) * 0.5,
					Vector2(float(x - run_start) * CELL, CELL)))
				run_start = -1
	return out
