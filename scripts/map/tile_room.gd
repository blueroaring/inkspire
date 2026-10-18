class_name TileRoom
extends Node2D
## 用 TileSet + TileMapLayer 搭地图的工具节点。
##
## ------------------------------------------------------------------ 三层怎么分
##
##   FloorLayer  地板层  terrain 集 `floor`，四邻全通配（-1）→ 铺到房间边界也不丢格
##   WallLayer   墙层    terrain 集 `wall`，MATCH_SIDES 自动拼接，含转角与厚度
##   PropLayer   物件层  家具/门/窗/装饰，取自 Interiors 图集（按需建格）
##
## ------------------------------------------------------------------ 碰撞为什么搬到 TileSet
##
## 以前是 MapBuilder.add_wall()：脚本算一个矩形 → new StaticBody2D + ColorRect。
## 那样"看到的墙"和"撞到的墙"是两份数据，改了一处忘了另一处就会出现
## 「画了墙但能穿过去」或者「空气墙」。现在墙的碰撞写在 TileSet 的物理层里，
## 跟贴图是同一格数据：**有这一格墙就一定有这一格的碰撞**，从结构上不可能不一致。
##
## ------------------------------------------------------------------ 逻辑坐标 vs 图块坐标
##
## 项目里有两套格子，别混（混了就会整张图错位一半）：
##   · **逻辑格** Grid.TILE = 32px —— MapData / 相机 / 出生点 / 房间尺寸用它
##   · **图块格** 16px（本文件的单位）—— TileMapLayer 用的一律是这个
## 换算只走 Grid.tile_to_cell() / Grid.rect_to_cells()，不要在场景里写 *2 / /2。

const TILESET_PATH := "res://assets/tilesets/school.tres"

## 图集来源 id（与 tools/build_tileset.gd 里 add_source 的顺序一致）
const SOURCE_ATLAS := 0      ## school_16.png：墙 + 地板
const SOURCE_PROPS := 1      ## Interiors_free_16x16.png：家具/门窗

## terrain 集 id
const TERRAIN_SET_WALL := 0
const TERRAIN_SET_FLOOR := 1

## 墙厚（图块数）。2 图块 = 32px = 一个逻辑格，正好和"墙占一格"的布局直觉对上。
const WALL_TILES := 2

## 各层的 z_index（沿用 MapBuilder 的层次约定：地板必须沉到最底，否则会盖住家具）
const FLOOR_Z := -1000
## 贴地装饰层夹在地板与墙之间
const DECAL_Z := -900
const WALL_Z := -100

@export var tileset: TileSet

var floor_layer: TileMapLayer
## 贴地装饰层（地毯/地垫/地面阴影）：**盖在地板之上**的一层独立 TileMapLayer。
## 为什么不直接铺进地板层：图块一格只能有一个 tile，铺进地板层等于把那格地板删了，
## 而这类贴图四周都有透明边距 → 边距处会露出场景背景色（地毯被挖了一圈洞）。踩过两次。
var decal_layer: TileMapLayer
var wall_layer: TileMapLayer
var prop_layer: TileMapLayer

## 宿舍这类 3/4 俯视场景不能把一件家具拆成多个 y-sort 图块：
## 那样角色经过时会在同一张床的上下两半之间穿层。整件精灵单独放在这里。
var prop_visuals: Node2D
var _prop_coverage: Dictionary = {}
## 贴地装饰格（地毯等）。它们在自己那一层，不参与 y 排序，也永远不挡人。
var _floor_decals: Dictionary = {}
var _prop_collision_count := 0
## 每件「整件精灵」家具的实际几何：{ kind, cells, visual(世界矩形), collision(世界矩形) }
## 走查靠它断言"看得见的"和"撞得到的"是同一个范围（这类不一致肉眼很难发现，必须量）。
var _prop_records: Array[Dictionary] = []
## 裁过透明边距的贴图缓存（按路径）
var _trim_cache: Dictionary = {}

## 建过的物件图块（避免重复 create_tile）
var _prop_tiles: Dictionary = {}


func _ready() -> void:
	ensure_layers()


## 三层只建一次（场景里的 _ready 与脚本里的调用都会走这里，幂等）
func ensure_layers() -> void:
	if floor_layer != null and is_instance_valid(floor_layer):
		return
	var ts := tileset
	if ts == null:
		ts = load(TILESET_PATH) as TileSet
	tileset = ts
	if ts == null:
		push_error("TileRoom: 加载不到 TileSet %s" % TILESET_PATH)
		return
	floor_layer = _make_layer("FloorLayer", ts, FLOOR_Z, false)
	# 贴地装饰层：紧挨着地板层建（树序在墙/物件之前），用**盖**的方式而不是替换地板。
	# 它的节点 y=0，在 y 排序空间里和地板/墙同档，靠树序排在墙与物件之前、玩家之后。
	decal_layer = _make_layer("DecalLayer", ts, DECAL_Z, false)
	decal_layer.collision_enabled = false
	wall_layer = _make_layer("WallLayer", ts, WALL_Z, false)
	# 物件层的 z 必须和角色一样是 0，遮挡关系才交给 y 排序而不是 z。
	# 如果给它一个负 z（比如 -90），角色就永远画在家具前面，"走到床后面被挡住"就没法发生。
	# 生效前提：从场景根到本节点这一路的 y_sort_enabled 都要开（dorm.tscn / campus.tscn 里已开）。
	prop_layer = _make_layer("PropLayer", ts, 0, true)
	prop_visuals = get_node_or_null("PropVisuals") as Node2D
	if prop_visuals == null:
		prop_visuals = Node2D.new()
		prop_visuals.name = "PropVisuals"
		prop_visuals.y_sort_enabled = true
		add_child(prop_visuals)
func _make_layer(layer_name: String, ts: TileSet, z: int, y_sort: bool) -> TileMapLayer:
	var existing := get_node_or_null(NodePath(layer_name)) as TileMapLayer
	var layer := existing
	if layer == null:
		layer = TileMapLayer.new()
		layer.name = layer_name
		add_child(layer)
	layer.tile_set = ts
	layer.z_index = z
	layer.y_sort_enabled = y_sort
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.collision_enabled = true
	return layer


# ------------------------------------------------------------------ 地板


## 铺一片地板（terrain，自动处理边界）
func paint_floor_cells(cells: Array, material: int) -> void:
	ensure_layers()
	if floor_layer == null:
		return
	floor_layer.set_cells_terrain_connect(_to_packed(cells), TERRAIN_SET_FLOOR, material, false)


## 按图块矩形铺地板，[param rect] 用图块坐标（不是像素、也不是逻辑格）
func paint_floor_rect(rect: Rect2i, material: int) -> void:
	var cells: Array = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, y))
	paint_floor_cells(cells, material)


# ------------------------------------------------------------------ 墙


## 一片实心墙（建筑外壳、挡路的大块）。terrain 只负责描边，内部靠四邻自动接上。
func paint_wall_cells(cells: Array, material: int) -> void:
	ensure_layers()
	if wall_layer == null:
		return
	wall_layer.set_cells_terrain_connect(_to_packed(cells), TERRAIN_SET_WALL, material, false)


## 实心墙矩形（图块坐标）
func paint_wall_rect(rect: Rect2i, material: int) -> void:
	paint_wall_cells(_rect_cells(rect), material)


## 一圈墙环（房间外墙），厚度 [param thickness] 图块。
## 返回环上的格子集合，走查断言要用它核对"房间边界正确"。
func build_wall_ring(outer: Rect2i, material: int, thickness: int = WALL_TILES) -> Array:
	var cells: Array = []
	for y in range(outer.position.y, outer.end.y):
		for x in range(outer.position.x, outer.end.x):
			var on_border := x < outer.position.x + thickness \
					or y < outer.position.y + thickness \
					or x >= outer.end.x - thickness \
					or y >= outer.end.y - thickness
			if on_border:
				cells.append(Vector2i(x, y))
	paint_wall_cells(cells, material)
	return cells


## 一整间房 = 外墙环 + 内部地板。返回 { wall, floor, inner } 三份格子数据。
func build_room(outer: Rect2i, wall_material: int, floor_material: int,
		thickness: int = WALL_TILES) -> Dictionary:
	var wall_cells := build_wall_ring(outer, wall_material, thickness)
	var inner := Rect2i(outer.position + Vector2i(thickness, thickness),
			outer.size - Vector2i(thickness * 2, thickness * 2))
	var floor_cells := _rect_cells(inner)
	paint_floor_cells(floor_cells, floor_material)
	return {"wall": wall_cells, "floor": floor_cells, "inner": inner}


## 把墙环上的某一段挖掉（开门洞/过道）。挖掉之后**碰撞也没了** —— 这正是我们要的：
## 门洞能走过去，是因为那里真的没有墙，而不是"画了墙但把碰撞关了"。
func clear_wall_cells(cells: Array) -> void:
	ensure_layers()
	if wall_layer == null:
		return
	for c_variant in cells:
		wall_layer.erase_cell(c_variant)
	# 挖完必须让四邻重新拼一次，否则洞口两侧还是"内部块"，描边不会补上
	_refresh_wall_neighbours(cells)


## 洞口两侧的墙块需要重算描边：把相邻一圈重新 set 一遍 terrain 即可。
## 不这么做的话，洞口边缘会缺一条描边（看起来像墙被啃了一口）。
func _refresh_wall_neighbours(cells: Array) -> void:
	var touched: Dictionary = {}
	for c_variant in cells:
		var c: Vector2i = c_variant
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			touched[c + d] = true
	var alive: Array = []
	for k in touched:
		var cell: Vector2i = k
		if wall_layer.get_cell_source_id(cell) != -1:
			alive.append(cell)
	if alive.is_empty():
		return
	# 取任意一格已存在的墙块拿材质，保证重拼不会串材质
	var probe: Vector2i = alive[0]
	var data := wall_layer.get_cell_tile_data(probe)
	var material := data.terrain if data != null else 0
	# 先清再拼：如果不清，原有的描边数据会被 terrain 认为"已经对了"而不重算
	for c_variant in alive:
		wall_layer.erase_cell(c_variant)
	wall_layer.set_cells_terrain_connect(_to_packed(alive), TERRAIN_SET_WALL, material, false)


## 把一串相邻格子拼成一条连续的墙（校园围墙/走廊用）
func paint_wall_path(path: Array, material: int) -> void:
	ensure_layers()
	if wall_layer == null:
		return
	wall_layer.set_cells_terrain_path(_to_packed(path), TERRAIN_SET_WALL, material, false)


# ------------------------------------------------------------------ 物件层


## 放一个物件。区域用**图块矩形**，跨多格时按 [param atlas_coords] 为左上角铺开。
##
## 三种形态，按 options 里的标记分派：
##   floor_decal  → 铺进**贴地装饰层**（地毯这类，盖在地板之上、永远不挡人）
##   whole_sprite → 整件精灵（床/桌椅/柜/门窗，参与 y 排序）
##   其余         → 逐格铺进物件层（图块型小物件）
func place_prop(rect: Rect2i, atlas_coords: Vector2i, options: Dictionary = {}) -> bool:
	ensure_layers()
	if bool(options.get("floor_decal", false)):
		return _place_floor_decal(rect, atlas_coords)
	if prop_layer == null:
		return false
	if bool(options.get("whole_sprite", false)):
		return _place_whole_prop(rect, atlas_coords, options)
	var ok := true
	for dy in rect.size.y:
		for dx in rect.size.x:
			var cell := rect.position + Vector2i(dx, dy)
			var src := atlas_coords + Vector2i(dx, dy)
			if not _ensure_prop_tile(src):
				ok = false
				continue
			prop_layer.set_cell(cell, SOURCE_PROPS, src, 0)
	return ok


## 贴地装饰（地毯这类）：铺进**贴地装饰层**，盖在地板**之上**。
##
## 这里踩过两次，两次的错法都记下来，别再犯：
##
## ① 放进**物件层**（用户反馈"走过地毯时图层上下不对"）
##    物件层是 y 排序的，排序只看 y。地毯整件精灵的锚点在它**下沿**（y 最大），
##    玩家走到地毯上半部分时 y 比地毯锚点小 → 地毯排到玩家后面 → 地毯盖住玩家。
##    设 z_index = -10 也没用：进了 y 排序空间，y 就是唯一排序键，z_index 不参与比较。
##
## ② 铺进**地板层本身**（用户反馈"还是有地毯图层问题"）
##    图块一格只能有一个 tile，往地板层写地毯 = 把那几格地板**删掉**。
##    而地毯贴图四周有 2~3px 透明边距（图集里这是留白），于是地毯四周被挖出一圈洞，
##    直接露出场景背景色 —— 看着像"地毯被描了一圈黑边"。
##    实测像素：地毯上沿一圈全是 4c4c4c，正是房间外的空白色，不是地板色。
##
## 正解：**独立一层、盖上去**。装饰层不参与 y 排序（节点 y=0，树序排在墙/物件/角色之前），
## 透明边距底下就是完好的地板，既不挖洞也不会挡人。
## 以后加地垫 / 地画 / 地面阴影贴片，都走这个入口（options 里给 floor_decal = true）。
func _place_floor_decal(rect: Rect2i, atlas_coords: Vector2i) -> bool:
	ensure_layers()
	if decal_layer == null:
		return false
	var ok := true
	for dy in rect.size.y:
		for dx in rect.size.x:
			var cell := rect.position + Vector2i(dx, dy)
			var src := atlas_coords + Vector2i(dx, dy)
			if not _ensure_prop_tile(src):
				ok = false
				continue
			# 写到**装饰层**：地板保持不动，装饰透明的地方露出的就是完好地板
			decal_layer.set_cell(cell, SOURCE_PROPS, src, 0)
			_floor_decals[cell] = true
	return ok


## 哪些格子是贴地装饰（走查断言用：它们必须在装饰层里，不能跑去物件层、也不能顶掉地板）
func floor_decal_cells() -> Array:
	return _floor_decals.keys()



## 把多格家具作为一张完整精灵摆放。根节点在家具脚底中心，因此 y-sort 依据的是
## 「落地点」而不是图片中心；角色在家具后方会被挡住，走到前方会正常盖住家具。
##
## ⚠️ 尺寸必须按「先裁透明边距，再**等比**缩放，最后贴底对齐」三步来（踩过）：
##   生成器出的 PNG 画布是 256x256，真正的内容只占其中一块（实测床 229x230、
##   椅子 149x230），四周是透明边距。如果直接把**画布**按声明占地拉伸，会同时犯三个错：
##     ① 非等比拉伸把图形拉歪 —— 床 32x64 的占地把方图纵向拉了 2 倍，
##        等距视角的床被拉成斜平行四边形，看着像"倒在地上的板子"；
##     ② 碰撞框按画布算 → 比看得见的家具大一整圈且整体偏移
##        （"站在床边明明没碰到"却被挡住）；
##     ③ 透明边距参与了居中和贴底 → 家具看着悬空/靠偏。
##   所以：get_used_rect() 裁边距 → contain 等比缩放装进占地 → 底边贴占地下沿、水平居中
##   → 碰撞按**裁剪后**的显示尺寸算。这样"看到的范围"与"撞到的范围"是同一个矩形。
func _place_whole_prop(rect: Rect2i, atlas_coords: Vector2i, options: Dictionary) -> bool:
	var kind := String(options.get("kind", "prop"))
	var footprint := Vector2(rect.size * Grid.CELL)
	var texture: Texture2D = null
	if options.has("texture_path"):
		texture = _trimmed_texture(String(options.get("texture_path")))
		if texture == null:
			return false
	else:
		var src := tileset.get_source(SOURCE_PROPS) as TileSetAtlasSource
		if src == null or src.texture == null:
			push_warning("TileRoom: 整件物件缺少图集源")
			return false
		var region_pos := Vector2(atlas_coords * Grid.CELL)
		if region_pos.x < 0.0 or region_pos.y < 0.0 \
				or region_pos.x + footprint.x > src.texture.get_width() \
				or region_pos.y + footprint.y > src.texture.get_height():
			push_warning("TileRoom: 整件物件区域越界 %s size=%s" % [str(atlas_coords), str(rect.size)])
			return false
		var atlas := AtlasTexture.new()
		atlas.atlas = src.texture
		atlas.region = Rect2(region_pos, footprint)
		texture = atlas

	var art_size := Vector2(texture.get_width(), texture.get_height())
	# contain：等比缩放到正好装进占地（不拉伸）。
	#
	# ⚠️ `visual_scale` 是"**看起来多大**"的调节口，与占地是两件事：
	#    占地表达的是"这件家具占几格、挡人挡在哪"（导航/碰撞/走查覆盖率都读它），
	#    而不少素材画得比占地更有"存在感"（柜台/洗碗池/餐桌塞满整个占地之后
	#    比主角大出一大截 —— 用户 2026-09-20 实报"打饭台和洗手池也太大了"）。
	#    所以允许把**画面**缩小、**占地**不动：这样挡人的范围、可走通道、
	#    走查里的碰撞覆盖率全都不变，只有视觉变小。
	var fit := minf(footprint.x / art_size.x, footprint.y / art_size.y) \
			* float(options.get("visual_scale", 1.0))
	var sprite_scale := Vector2(fit, fit)
	var display_size := art_size * sprite_scale

	var root := Node2D.new()
	root.name = "%s_%d" % [kind.capitalize(), prop_visuals.get_child_count()]
	# 根 = 占地底边的中点：y-sort 与"脚底"都在这里
	root.position = Vector2(
		(float(rect.position.x) + float(rect.size.x) * 0.5) * Grid.CELL,
		float(rect.end.y) * Grid.CELL)
	var render_group := String(options.get("render_group", "world"))
	if render_group == "floor":
		root.z_index = -10
	elif render_group == "wall":
		root.z_index = -50
	prop_visuals.add_child(root)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = sprite_scale
	sprite.flip_h = bool(options.get("flip_h", false))
	sprite.flip_v = bool(options.get("flip_v", false))
	# Sprite2D 默认以中心为原点；往上移半个「缩放后高度」，把脚底锁在 root.y。
	sprite.position = Vector2(0.0, -display_size.y * 0.5)
	root.add_child(sprite)

	# ---- 备用贴图（`alt_texture_path`）：同一件东西的"另一个状态"的图 ----
	#
	# 用途（2026-09-20 用户："坐的时候替换为这个图，站的时候恢复正常的长椅图"）：
	# 长椅坐下时整条换成"人 + 椅"的成品图、站起来换回空长椅。
	#
	# ⚠️ 两张图**共用同一个 `root`（= 占地下沿中点）**，所以互换时**落地线不动** ——
	#    这正是"换图"能替代"把角色叠上去"的原因。
	# ⚠️ 备用图有自己的显示高度（`alt_display_h`）：它是**另一张画**，长宽比不同，
	#    按主的 contain 尺寸贴会把椅子缩放得和原来不一样（实测差一倍）。
	#    给 0 就退回主的 display_size。
	# ⚠️ 默认 `visible = false`：不给 `alt_texture_path` 的记录里 `alt_sprite` 就是 null，
	#    调用方（`SitSpot`）要自己判空。
	var alt_sprite: Sprite2D = null
	var alt_path := String(options.get("alt_texture_path", ""))
	if alt_path != "" and ResourceLoader.exists(alt_path):
		var alt_tex := _trimmed_texture(alt_path)
		if alt_tex != null:
			var alt_h := float(options.get("alt_display_h", 0.0))
			var alt_fit := fit
			if alt_h > 0.0:
				alt_fit = alt_h / maxf(1.0, float(alt_tex.get_height()))
			alt_sprite = Sprite2D.new()
			alt_sprite.name = "AltSprite"
			alt_sprite.texture = alt_tex
			alt_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			alt_sprite.scale = Vector2(alt_fit, alt_fit)
			alt_sprite.position = Vector2(0.0,
					-float(alt_tex.get_height()) * alt_fit * 0.5)
			alt_sprite.visible = false
			# 压在主图之上：换图的那一帧两者可能同时可见（交叉淡入之类的将来用途）
			alt_sprite.z_index = 1
			root.add_child(alt_sprite)
	elif alt_path != "":
		push_warning("TileRoom: 备用贴图不存在，这件东西不会换图：%s" % alt_path)

	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_prop_coverage[Vector2i(x, y)] = true

	# 可见范围（世界坐标）：底边贴占地下沿、水平居中
	var visual_rect := Rect2(
		root.position - Vector2(display_size.x * 0.5, display_size.y), display_size)
	var record := {
		"kind": kind,
		"cells": rect,
		"footprint": Rect2(Vector2(rect.position * Grid.CELL), footprint),
		"visual": visual_rect,
		"collision": Rect2(),
		"art_size": art_size,
		"scale": sprite_scale,
		"texture_path": String(options.get("texture_path", "")),
		# ⚠️ `label` 必须原样带进记录：走查/自检按它出人名话
		#    （食堂的"红桶/蓝桶/绿桶"、street_prop 的"长椅"…）。
		#    漏掉它的话记录里没有这一项，打印出来全是 kind（"bin"），
		#    断言里那条"回收桶数量与数据一致（3 个）"就只能看数量、看不出是哪个颜色。
		"label": String(options.get("label", kind)),
		# 数据里给什么就原样带进记录（走查要按它核对"这东西本该摆在哪一格"）
		"base_tile": options.get("base_tile", null),
	}

	var collision_variant: Variant = options.get("collision", null)
	# ⚠️ `collision_px` = **像素空间的碰撞矩形**（相对精灵的显示矩形，左上角为 (0,0)）。
	#    为什么需要它：`collision`（归一化 0..1）是相对**显示尺寸**算的，
	#    而 `visual_scale` 会把显示尺寸改小 —— 两者一叠加，"按占地整块挡人"
	#    就写不出来了（占地 64px 高、画出来 44px 高时，归一化写 1.0 只有 44px）。
	#    食堂家具要的正是"画面变小、但挡人的范围仍然覆盖整个占地"（见 canteen.gd）。
	if collision_variant is Rect2 and options.has("collision_px"):
		var px_rect := options.get("collision_px") as Rect2
		record["collision"] = _add_prop_collision_px(root, display_size, px_rect, kind)
	elif collision_variant is Rect2:
		var collision_rect := collision_variant as Rect2
		if bool(options.get("flip_h", false)):
			collision_rect.position.x = 1.0 - collision_rect.position.x - collision_rect.size.x
		if bool(options.get("flip_v", false)):
			collision_rect.position.y = 1.0 - collision_rect.position.y - collision_rect.size.y
		record["collision"] = _add_prop_collision(root, display_size, collision_rect, kind)
	# 备用贴图的两个句柄交给调用方（`SitSpot` 换图）：主图与备用图都挂在这个记录上。
	# ⚠️ 只登记**节点句柄**、不动 `visual` / `footprint` / `collision` 这些"占地理账"字段 ——
	#    走查的"画面不超过 DISPLAY_PX""碰撞覆盖率"读的是那几个，掺进备用图会把它们弄乱。
	record["main_sprite"] = sprite
	record["alt_sprite"] = alt_sprite
	_prop_records.append(record)
	return true


## 载入贴图并裁掉透明边距（结果按路径缓存）。
## 裁完的尺寸才是"看得见的家具"的真实尺寸 —— 后面所有缩放/居中/碰撞都基于它。
func _trimmed_texture(path: String) -> Texture2D:
	if _trim_cache.has(path):
		return _trim_cache[path]
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("TileRoom: 自定义物件贴图加载失败 %s" % path)
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	var used := Rect2i(0, 0, tex.get_width(), tex.get_height())
	var img := tex.get_image()
	if img != null:
		var u := img.get_used_rect()
		if u.size.x > 0 and u.size.y > 0:
			used = u
	atlas.region = Rect2(used)
	_trim_cache[path] = atlas
	return atlas


## collision 用精灵局部的**像素**矩形描述（相对显示矩形左上角）。
##
## 与 `_add_prop_collision`（归一化 0..1）的区别：那个的"1.0"会跟着 `visual_scale` 变小，
## 这个不会 —— 所以"画面缩小、挡人照旧按占地"只能用它写。
## 返回碰撞体的世界矩形，写进 prop_records() 供走查断言核对。
func _add_prop_collision_px(root: Node2D, display_size: Vector2, px: Rect2,
		kind: String) -> Rect2:
	var body := StaticBody2D.new()
	body.name = "%sCollision" % kind.capitalize()
	body.collision_layer = Layers.ENVIRONMENT
	body.collision_mask = 0
	root.add_child(body)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = px.size
	shape.shape = rectangle
	# 精灵在 root 局部占 y ∈ [-display_size.y, 0]，像素矩形 (0,0) 对应精灵左上角
	var local_center := Vector2(
		-display_size.x * 0.5 + px.position.x + px.size.x * 0.5,
		-display_size.y + px.position.y + px.size.y * 0.5)
	shape.position = local_center
	body.add_child(shape)
	_prop_collision_count += 1
	return Rect2(root.position + local_center - rectangle.size * 0.5, rectangle.size)


## collision 用精灵局部的归一化矩形（0..1）描述，只挡住真正落地的部分。
## 柜子/桌子的高立面依然可以遮挡角色，但不会变成一大块「空气墙」。
## 返回碰撞体的世界矩形，写进 prop_records() 供走查断言核对。
func _add_prop_collision(root: Node2D, display_size: Vector2, normalized: Rect2,
		kind: String) -> Rect2:
	var body := StaticBody2D.new()
	body.name = "%sCollision" % kind.capitalize()
	body.collision_layer = Layers.ENVIRONMENT
	body.collision_mask = 0
	root.add_child(body)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(
		display_size.x * normalized.size.x,
		display_size.y * normalized.size.y)
	shape.shape = rectangle
	# 精灵在 root 局部占 y ∈ [-display_size.y, 0]，归一化 (0,0) 对应精灵左上角
	var local_center := Vector2(
		-display_size.x * 0.5 + display_size.x * (normalized.position.x + normalized.size.x * 0.5),
		-display_size.y + display_size.y * (normalized.position.y + normalized.size.y * 0.5))
	shape.position = local_center
	body.add_child(shape)
	_prop_collision_count += 1
	return Rect2(root.position + local_center - rectangle.size * 0.5, rectangle.size)


## 按像素矩形放物件（MapData 里大多用像素写布局，省得再换一遍算）
func place_prop_px(rect: Rect2, atlas_coords: Vector2i) -> bool:
	return place_prop(Grid.rect_to_cells(rect), atlas_coords)


func _ensure_prop_tile(atlas_coords: Vector2i) -> bool:
	if _prop_tiles.has(atlas_coords):
		return true
	var src := tileset.get_source(SOURCE_PROPS) as TileSetAtlasSource
	if src == null:
		push_warning("TileRoom: TileSet 里没有物件源 %d" % SOURCE_PROPS)
		return false
	if not src.has_tile(atlas_coords):
		var tex := src.texture
		if tex == null:
			return false
		var px := atlas_coords * src.texture_region_size
		if px.x < 0 or px.y < 0 or px.x + src.texture_region_size.x > tex.get_width() \
				or px.y + src.texture_region_size.y > tex.get_height():
			push_warning("TileRoom: 物件图块 %s 超出图集范围" % str(atlas_coords))
			return false
		src.create_tile(atlas_coords)
	_prop_tiles[atlas_coords] = true
	return true


# ------------------------------------------------------------------ 查询（走查断言用）


## 某一层在指定格子有没有图块
func has_tile(layer: TileMapLayer, cell: Vector2i) -> bool:
	if layer == null:
		return false
	return layer.get_cell_source_id(cell) != -1


func floor_tile_at(cell: Vector2i) -> bool:
	return has_tile(floor_layer, cell)


func wall_tile_at(cell: Vector2i) -> bool:
	return has_tile(wall_layer, cell)


func prop_tile_at(cell: Vector2i) -> bool:
	return has_tile(prop_layer, cell) or _prop_coverage.has(cell)


func prop_used_cells() -> Array:
	var unique: Dictionary = {}
	if prop_layer != null:
		for cell in prop_layer.get_used_cells():
			unique[cell] = true
	for cell in _prop_coverage:
		unique[cell] = true
	return unique.keys()


func prop_collision_count() -> int:
	return _prop_collision_count


## 每件「整件精灵」家具的几何记录。走查用它断言三件事对齐：
## 看得见的范围（visual）⊆ 声明占地（footprint），碰撞（collision）⊆ 看得见的范围，
## 且家具底边贴在地面（visual.end.y == footprint.end.y）。
func prop_records() -> Array[Dictionary]:
	return _prop_records


## 把"在脚本里自己拼出来的家具"登记进物件层账本。
##
## 为什么需要这个入口：`place_prop()` 走的是**图集/贴图**那条路，
## 而食堂（2026-09-19）的家具是程序化色块拼的 —— 没有 texture_path，也不进 TileMapLayer。
## 如果不登记，走查就数不到它们（"物件层格数=0"）、也量不到碰撞覆盖率，
## 于是"家具忘了加碰撞"这类静默错误会直接漏过去。
##
## 调用方负责把 [param record] 填成与 `place_prop` 同样的形状：
##   kind / cells / footprint / visual / collision / art_size / scale / texture_path
## collision 传空 Rect2 表示"这件不挡人"。
func register_visual_prop(record: Dictionary, collision_counted: bool = true) -> void:
	var rec := record.duplicate()
	var cells: Rect2i = rec.get("cells", Rect2i())
	if cells.size.x > 0 and cells.size.y > 0:
		for y in range(cells.position.y, cells.end.y):
			for x in range(cells.position.x, cells.end.x):
				_prop_coverage[Vector2i(x, y)] = true
	var collision: Rect2 = rec.get("collision", Rect2())
	if collision_counted and collision.size.x > 0.0 and collision.size.y > 0.0:
		_prop_collision_count += 1
	_prop_records.append(rec)


func layer_cell_count(layer: TileMapLayer) -> int:
	if layer == null:
		return 0
	return layer.get_used_cells().size()


## 墙层上所有**实心格**（图块坐标）。导航障碍几何的唯一来源。
##
## 为什么给导航用这一份而不是去问物理空间：墙的碰撞本来就写在 TileSet 物理层里，
## 「有这一格墙就一定挡人」，所以直接把墙层格子当障碍，看到的就是撞到的。
## ⚠️ 门窗那类"整件精灵"（`place_prop(whole_sprite=true)`）**不在**这里 ——
##    它们进的是 `prop_visuals`，走 `prop_records()` 那条路（见 MapNavigation）。
func wall_cells() -> Array:
	if wall_layer == null:
		return []
	return wall_layer.get_used_cells()


## 地板层上所有格子（图块坐标）。导航要它来算"这张图的可走范围有多大"。
func floor_cells() -> Array:
	if floor_layer == null:
		return []
	return floor_layer.get_used_cells()


## 各层的格数，走查里打印/断言最省事
func stats() -> Dictionary:
	return {
		"floor": layer_cell_count(floor_layer),
		"decal": layer_cell_count(decal_layer),
		"wall": layer_cell_count(wall_layer),
		"prop": prop_used_cells().size(),
	}


## 墙层里是否有"有图块却没碰撞"的格子 —— 这类不一致是 TileSet 方案要根除的头号问题，
## 所以专门查一次（TileSet 的物理层里那格必须有至少一个多边形）。
func wall_tiles_without_collision() -> Array:
	var out: Array = []
	if wall_layer == null:
		return out
	for cell in wall_layer.get_used_cells():
		var data := wall_layer.get_cell_tile_data(cell)
		if data == null or data.get_collision_polygons_count(0) == 0:
			out.append(cell)
	return out


# ------------------------------------------------------------------ 内部工具


func _rect_cells(rect: Rect2i) -> Array:
	var cells: Array = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, y))
	return cells


func _to_packed(cells: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for c_variant in cells:
		var c: Vector2i = c_variant
		out.append(Vector2(c))
	return out
