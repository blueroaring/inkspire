class_name MapBuilder
extends Node2D
## ⚠️ **已被取代，当前没有任何场景引用它**（2026-09-18）。
##
## 地图已改成 TileSet + TileMapLayer（见 scripts/map/tile_room.gd 与 tools/build_tileset.gd）：
##   · 地板/墙不再是"矩形 + ColorRect"，而是图块层的 terrain 自动拼接
##   · 碰撞不再是 add_wall() 的 StaticBody2D 矩形，而是 TileSet 物理层
##   · 家具不再是代码画的伪 3D 盒子，而是 Interiors 图集的精灵
##
## 保留本文件的唯一理由是它上面的**伪 3D 画法约定**（顶面 + 正面 = 体积、墙是立面、
## 高度 = 屏幕上移 + 露出支撑）仍然适用于任何"用代码画立体感"的场合。
## 确认不再需要后，本文件与 scripts/map/map_grid_painter.gd 可以一起删掉。
##
## ------------------------------------------------------------------ 原文说明
##
## 程序化搭地图的工具节点。
##
## 为什么这么做：需求还没锁美术规格（瓦片尺寸待定），也可能以后换成 TileMapLayer。
## 所以先按"数据 -> 几何 + 碰撞"的方式生成地图，所有尺寸走 Grid 常量。
## 换 TileMap 时只需要重写本文件，地图数据（data/map_data.gd）与场景脚本都不用动。
##
## ------------------------------------------------------------------ 伪 3D 画法约定
##
## 本项目的"伪 3D"= 3/4 俯视。能让平面矩形读成有体积的物体，靠的是三条：
##
##   1. **画出两个面**：顶面（受光、较亮）+ 正面（背光、较暗）。
##      只画一个色块 = 俯视贴纸；两个面 = 立方体。见 add_box()。
##   2. **墙是立面**：后墙要画成很高的一面竖直墙（data 里的 DORM_BACK_FACE），
##      能挂窗、能在上面开门的洞。墙太矮，房间就没有高度感。
##   3. **高度 = 屏幕上移 + 露出支撑**：离地越高的东西画得越靠上，**下方必须露出空隙与支撑**
##      （桌腿/床架/爬梯）。"床悬在桌上"这件事只能这样表达，不能把床和桌上下并排切分。
##
## 另外：需要"人物走到背后被挡住"的物件用 cover=true（z_index 按 y 排序）。

const WALL_THICKNESS := 16.0

## z 层次约定（改这里之前先想清楚，本项目为此踩过大坑）：
##
##   地板        z = FLOOR_Z（-1000）—— **必须比任何物件都小**，否则地板会盖住家具
##   普通装饰    z = -150
##   物件/墙/家具 z = -y（屏幕上方=更靠后，越往下越靠前，做出正确遮挡关系）
##
## 坑：物件用 z=-y（例如宿舍里桌子正面是 -246），而地板原本是 -200 ——
## 结果是"地板盖住了桌子"，家具画了却整片看不见，日志还显示节点都存在，极难排查。
## 所以地板必须沉到最底。
const FLOOR_Z := -1000
const DECOR_Z := -150
const WALL_Z := -100

## 地面装饰的瓦片网格线颜色（很淡，用于在纯色占位阶段提供坐标参照）
const GRID_LINE := Color(1, 1, 1, 0.05)

## Undertale 式俯视伪 3D 的三个共用视觉元素（统一从这里取，保证风格一致）：
##   OUTLINE      —— 统一深色描边，物体靠它"跳出来"
##   SHADOW       —— 底部投影，暗示物体离地、有体积
##   BOOK_COLORS  —— 书脊点缀色，避免整屋死板
const OUTLINE := Color(0.10, 0.09, 0.12, 0.85)
const SHADOW := Color(0.0, 0.0, 0.0, 0.22)
const BOOK_COLORS: Array[Color] = [
	Color("#b5524a"), Color("#4a7ab5"), Color("#c8a24a"), Color("#6aa06a"),
]

## 房间纹理素材（由 tools/generate_room_textures.py 生成）
## 参考 2D 房间的通行做法：**地板是平铺纹理、墙是有材质的立面**，房间才有实体感；
## 纯色块无论怎么调明暗都还是"贴纸"。
const FLOOR_TEXTURE := "res://assets/graphics/props/floor_wood.png"
const WALL_SIDE_TEXTURE := "res://assets/graphics/props/wall_side.png"

## 平铺纹理的地面（用 texture_repeat 无缝铺满指定矩形）
##
## ⚠️ `region_enabled` 的 Sprite2D 会**按 region 的尺寸把节点居中偏移**，
##    所以 position 不能直接写 rect.position，要减去 region 尺寸的一半，
##    否则整块地板会被推到左上角外面（踩过：地板看着还是纯色，其实是纹理画到画面外了）。
func add_textured_floor(rect: Rect2, tex_path: String, z: int = FLOOR_Z) -> void:
	var tex := load(tex_path) as Texture2D
	if tex == null:
		push_warning("MapBuilder: 缺少地面纹理 %s" % tex_path)
		return
	var spr := Sprite2D.new()
	spr.name = "FloorTex"
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.region_enabled = true
	spr.region_rect = Rect2(Vector2.ZERO, rect.size)
	# 抵消 region 居中偏移
	spr.position = rect.position + rect.size * 0.5
	spr.z_index = z
	add_child(spr)


## 有材质的墙面（用于后墙与侧墙）：把纹理按目标矩形拉伸/平铺
## [param tile_y] true = 竖向平铺（侧墙很高时用）；false = 拉伸填满
func add_textured_wall(rect: Rect2, tex_path: String, z: int = WALL_Z,
		tile_y: bool = false) -> void:
	var tex := load(tex_path) as Texture2D
	if tex == null:
		push_warning("MapBuilder: 缺少墙面纹理 %s" % tex_path)
		return
	var spr := Sprite2D.new()
	spr.name = "WallTex"
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	spr.position = rect.position
	spr.z_index = z
	if tile_y and tex.get_height() > 0:
		# 竖向平铺：region 设为整个墙面高度，靠 repeat 重复纹理行
		spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		spr.region_enabled = true
		spr.region_rect = Rect2(Vector2.ZERO, rect.size)
	else:
		spr.scale = Vector2(rect.size.x / float(tex.get_width()),
				rect.size.y / float(tex.get_height()))
	add_child(spr)


## 窗的图片素材（由 tools/generate_window_sprite.py 生成）
const WINDOW_TEXTURE := "res://assets/graphics/props/window.png"
## 窗的层级：**正数**，保证在任何负 z 的墙面/砖缝之上（详见 add_window 注释）
const WINDOW_Z := 100


## 铺地面：整块地板色 + 很淡的网格线
func add_floor(rect: Rect2, base: Color) -> void:
	var cr := ColorRect.new()
	cr.name = "Floor"
	cr.color = base
	cr.position = rect.position
	cr.size = rect.size
	cr.z_index = FLOOR_Z
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cr)

	var lines := Node2D.new()
	lines.name = "FloorGrid"
	lines.z_index = FLOOR_Z + 1
	var grid_painter := MapGridPainter.new()
	grid_painter.rect = rect
	grid_painter.tile = float(Grid.TILE)
	grid_painter.line_color = GRID_LINE
	lines.add_child(grid_painter)
	add_child(lines)


## 铺一个色块（草地/马路/水面等），不产生碰撞
func add_ground(rect: Rect2, color: Color, z: int = -190) -> ColorRect:
	var cr := ColorRect.new()
	cr.color = color
	cr.position = rect.position
	cr.size = rect.size
	cr.z_index = z
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cr)
	return cr


## 纯装饰色块，无碰撞。
## cover=true 时按 y 排序（z_index = -y），这样人物走到它下面会被遮住。
## [param z_override] 显式指定层级（比 cover 的 -y 优先级更高）。
##   用途：**贴在同一面墙上的窗/装饰**必须保证在墙之上。本项目在这里踩过三次坑
##   （地板压家具、墙压窗），而"靠节点添加顺序"并不可靠——z 相同时 Godot 才看添加顺序，
##   一旦别处改了 z 就会重新被压住。所以这类"贴在墙上的东西"一律用显式 z。
func add_decor(rect: Rect2, color: Color, cover: bool = false,
		z_override: int = 0) -> ColorRect:
	var cr := ColorRect.new()
	cr.color = color
	cr.position = rect.position
	cr.size = rect.size
	if z_override != 0:
		cr.z_index = z_override
	else:
		cr.z_index = int(-rect.end.y) if cover else DECOR_Z
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cr)
	return cr


## 一段实心矩形障碍（墙 / 建筑外壳 / 家具占地），带碰撞
func add_wall(rect: Rect2, color: Color, cover: bool = false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "Solid"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.position
	add_child(body)

	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	shape.position = rect.size * 0.5
	body.add_child(shape)

	var cr := ColorRect.new()
	cr.color = color
	cr.size = rect.size
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.z_index = int(-rect.end.y) if cover else -100
	cr.name = "Visual"
	body.add_child(cr)

	return body


## 一个矩形区域的墙（只在四条边生成墙块，中间可走）
func add_room(rect: Rect2, wall_color: Color, thickness: float = WALL_THICKNESS,
		cover_bottom: bool = true) -> void:
	var t := thickness
	add_wall(Rect2(rect.position, Vector2(rect.size.x, t)), wall_color)
	add_wall(Rect2(Vector2(rect.position.x, rect.end.y - t), Vector2(rect.size.x, t)), wall_color, cover_bottom)
	add_wall(Rect2(rect.position, Vector2(t, rect.size.y)), wall_color)
	add_wall(Rect2(Vector2(rect.end.x - t, rect.position.y), Vector2(t, rect.size.y)), wall_color)


## ------------------------------------------------------------------ 伪 3D 积木


## 一个有"顶面 + 正面"的盒子 —— 伪 3D 的基础积木。
##
## [param foot]   占地矩形（在地板上的位置）
## [param height] 高出地面的像素高度（屏幕上画在占地上方）
## [param top_color] 顶面（受光，亮）   [param front_color] 正面（背光，暗）
##
## 顶面画在正面之上、占一个"占地进深"的高度 —— 这正是 3/4 俯视看到的样子。
func add_box(foot: Rect2, height: float, top_color: Color, front_color: Color,
		outline: Color = Color(0, 0, 0, 0)) -> void:
	if height <= 0.5:
		add_decor(foot, top_color, true)
		return
	# 正面
	add_decor(Rect2(Vector2(foot.position.x, foot.end.y - height),
			Vector2(foot.size.x, height)), front_color, true)
	# 顶面
	add_decor(Rect2(Vector2(foot.position.x, foot.end.y - height - foot.size.y),
			Vector2(foot.size.x, foot.size.y)), top_color, true)
	# 顶面与正面的交界暗线：体积感的关键一笔
	if outline.a > 0.0:
		add_decor(Rect2(Vector2(foot.position.x, foot.end.y - height),
				Vector2(foot.size.x, 2.0)), outline, true)


## **Undertale 式墙面**：一整块有砖纹的竖直墙面 + 纯黑描边。
##
## 这是"房间感"的来源（用户拿了参考图指出：只画厚带永远像地板上的边框）。
## 画法：底色 → 横向砖缝（每行）+ 交错竖缝 → 四周黑描边。
## [param brick_w] 单块砖宽  [param row_h] 每行砖高
func add_wall_face(rect: Rect2, base: Color, brick_w: float = 32.0, row_h: float = 16.0) -> void:
	add_decor(rect, base, true)
	var seam := base.darkened(0.28)
	var hi := base.lightened(0.14)
	var rows := int(maxf(1.0, floorf(rect.size.y / row_h)))
	for i in rows:
		var y := rect.position.y + float(i) * row_h
		# 每行上沿一条亮线（砖块的受光边），下沿一条砖缝
		add_decor(Rect2(Vector2(rect.position.x, y), Vector2(rect.size.x, 2.0)), hi, true)
		if i < rows - 1:
			add_decor(Rect2(Vector2(rect.position.x, y + row_h - 2.0),
					Vector2(rect.size.x, 2.0)), seam, true)
		# 竖缝：奇数行错开半块砖
		var offset := 0.0 if i % 2 == 0 else brick_w * 0.5
		var x := rect.position.x + offset
		while x < rect.end.x:
			add_decor(Rect2(Vector2(x, y), Vector2(2.0, row_h)), seam, true)
			x += brick_w
	# 四周描边（Undertale 的墙都有清楚的黑边）
	add_decor(Rect2(rect.position, Vector2(rect.size.x, 3.0)), OUTLINE, true)
	add_decor(Rect2(Vector2(rect.position.x, rect.end.y - 3.0), Vector2(rect.size.x, 3.0)),
			OUTLINE, true)
	add_decor(Rect2(rect.position, Vector2(3.0, rect.size.y)), OUTLINE, true)
	add_decor(Rect2(Vector2(rect.end.x - 3.0, rect.position.y), Vector2(3.0, rect.size.y)),
			OUTLINE, true)


## 一扇门 —— 画在**侧墙的竖直立面**上（宽≈墙厚、高≈140），所以是**竖着的门**。
##
## 为什么和"下沿墙的门"画法不同：下沿墙是俯视看到的窄条，门只能画成横长条；
## 而侧墙是正对镜头的竖直墙面（像 Undertale 房间左右的墙），在上面开门就是一个
## 竖立的长方形洞口。用户 2026-09-18 明确要求门开在左右墙上，因此走这套画法。
##
## 层次（都在正数 z，保证压在负 z 的砖墙之上）：
##   ① 门框（比墙略亮的木色，向上向下各延伸一点）
##   ② 门洞暗部（表示门后还有空间）
##   ③ 门板（略内缩，带两段凹板线）
##   ④ 把手 + 门上沿受光边
func add_door(rect: Rect2, face_height: float, frame_color: Color,
		panel_color: Color, handle_color: Color) -> void:
	var z := WINDOW_Z                       # 用同一套"贴在墙上"的层级
	var jamb := 5.0
	# ① 门框：比门洞四周各外扩 jamb
	var frame := rect.grow(jamb)
	add_decor(frame, frame_color, false, z + 4)
	add_decor(Rect2(frame.position, Vector2(frame.size.x, 4.0)),
			frame_color.lightened(0.28), false, z + 5)          # 门楣受光
	# ② 门洞暗部
	add_decor(rect, Palette.DOOR_VOID, false, z + 3)
	# ③ 门板：内缩 3px，带两段凹板线
	var slab := rect.grow(-3.0)
	add_decor(slab, panel_color, false, z + 2)
	add_decor(Rect2(slab.position, Vector2(slab.size.x, 3.0)),
			panel_color.lightened(0.30), false, z + 2)           # 门板上沿受光
	for i in 2:
		var ph := slab.size.y * 0.34
		add_decor(Rect2(Vector2(slab.position.x + 4.0, slab.position.y + 12.0 + i * (ph + 6.0)),
				Vector2(slab.size.x - 8.0, ph)), panel_color.darkened(0.20), false, z + 1)
	# ④ 把手（靠门的外侧，像向外开）
	add_decor(Rect2(Vector2(slab.end.x - 11.0, slab.get_center().y - 7.0), Vector2(7.0, 14.0)),
			handle_color, false, z)


## 墙面上的窗：**贴图片素材**。
##
## 为什么从"代码画矩形"改成"贴图"（这是本项目最折腾的一处，返工五次）：
##   用一堆 ColorRect 拼窗时，每一层都要跟墙的砖缝争 z_index，
##   而砖缝是几十条横线、各带不同 z，无论怎么排都会有一条盖到窗上
##   （用户原话："砖纹图层在窗户上面"）。
##   改成**一张整体贴图**后，绘制顺序问题直接消失：图片内部层次是固定的，
##   只要保证"这张图在墙之后画/层级更高"就行，一件事只有一个变量。
##
## [param rect] 窗的世界矩形（按它还缩放贴图，尺寸取素材原比例）
func add_window(rect: Rect2, frame: Color, glass: Color) -> void:
	var tex := load(WINDOW_TEXTURE) as Texture2D
	if tex == null:
		# 素材缺失时退回一个纯色块，避免"什么都没有"这种更难查的状态
		push_warning("MapBuilder: 缺少窗素材 %s，已用纯色代替" % WINDOW_TEXTURE)
		add_decor(rect, glass, false, WINDOW_Z)
		return
	var spr := Sprite2D.new()
	spr.name = "Window"
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 像素风：禁止平滑
	# 按 rect 尺寸等比缩放（素材是正方形，取两轴较小比例以免变形）
	var s := minf(rect.size.x / float(tex.get_width()), rect.size.y / float(tex.get_height()))
	spr.scale = Vector2(s, s)
	spr.position = rect.get_center()
	spr.z_index = WINDOW_Z       # 正数：保证在任何负 z 的砖缝/墙面之上
	add_child(spr)


## 一套"上床下桌"（伪 3D）。
##
## 画法顺序（从下到上 = 从远到近）：
##   1. 桌子：顶面 + 正面 + 桌腿（地面这一层有桌子）
##   2. 书柜：立在桌面靠墙一侧，也是盒子；格子里塞几本书
##   3. 椅子：摆在桌子外侧、朝房间中心，同样有顶面与正面，另有椅背
##   4. 床：**整体上移 lift**，下方露出架空间隙与支撑柱
##   5. 到顶立柱 + 爬梯：让"上床"这件事有现实依据
func add_bunk(foot: Rect2, lift: float, bed_h: float, facing: int = 1) -> void:
	var w := foot.size.x
	var edge := 8.0          ## 正面（侧壁厚度）：俯视能看到的物体厚度
	var shelf_h := 30.0

	# ---- 1) 桌子：投影 + 顶面 + 正面 + 描边 ----
	add_decor(Rect2(foot.position + Vector2(3.0, 5.0), foot.size), SHADOW, true)
	add_decor(foot, Palette.DESK.lightened(0.34), true)                                  # 桌面
	add_decor(Rect2(Vector2(foot.position.x, foot.end.y - edge), Vector2(w, edge)),
			Palette.DESK.darkened(0.34), true)                                           # 正面
	add_decor(Rect2(Vector2(foot.position.x, foot.position.y), Vector2(w, 3.0)),
			OUTLINE, true)

	# ---- 2) 书柜：靠墙一侧，也是"顶面 + 正面"，两格 + 书脊 ----
	var shelf_w := w * 0.42
	var shelf_x := foot.position.x + 4.0 if facing > 0 else foot.end.x - shelf_w - 4.0
	var shelf := Rect2(Vector2(shelf_x, foot.position.y - 4.0),
			Vector2(shelf_w, foot.size.y - 6.0))
	add_decor(shelf, Palette.BOOK_SHELF, true)
	add_decor(Rect2(Vector2(shelf.position.x, shelf.end.y - 6.0), Vector2(shelf_w, 6.0)),
			Palette.BOOK_SHELF_FRAME, true)
	add_decor(shelf.grow(1.0), OUTLINE, false)
	var gw := (shelf.size.x - 12.0) * 0.5
	for i in 2:
		var g := Rect2(Vector2(shelf.position.x + 4.0 + i * (gw + 4.0), shelf.position.y + 5.0),
				Vector2(gw, shelf.size.y - 18.0))
		add_decor(g, Palette.BOOK_SHELF_FRAME, true)
		add_decor(Rect2(g.position + Vector2(2.0, 2.0), Vector2(g.size.x - 4.0, g.size.y - 6.0)),
				BOOK_COLORS[i % BOOK_COLORS.size()], true)

	# ---- 3) 椅子：桌子外侧，座面 + 椅背 ----
	var chair_w := 28.0
	var chair_x := foot.end.x + 5.0 if facing > 0 else foot.position.x - chair_w - 5.0
	var chair := Rect2(Vector2(chair_x, foot.get_center().y - 11.0), Vector2(chair_w, 26.0))
	add_decor(Rect2(chair.position + Vector2(2.0, 4.0), chair.size), SHADOW, true)
	add_decor(chair, Palette.CHAIR.lightened(0.32), true)
	add_decor(chair.grow(1.0), OUTLINE, false)
	var back_x := chair.position.x - 1.0 if facing > 0 else chair.end.x - 4.0
	add_decor(Rect2(Vector2(back_x, chair.position.y - 7.0), Vector2(5.0, chair.size.y + 7.0)),
			Palette.CHAIR.darkened(0.30), true)

	# ---- 4) 床：画在桌子**上方**的独立矩形（它在上面一层）+ 床上阴影 ----
	var bed := Rect2(Vector2(foot.position.x, foot.position.y - lift),
			Vector2(w, foot.size.y - 8.0))
	add_decor(Rect2(bed.position + Vector2(4.0, bed.size.y + 4.0), Vector2(w, 9.0)), SHADOW, true)
	add_decor(bed, Palette.BED, true)                                                    # 床垫
	add_decor(Rect2(Vector2(bed.position.x, bed.end.y - edge), Vector2(w, edge)),
			Palette.BED_FRAME, true)                                                     # 床沿厚度
	add_decor(bed.grow(1.0), OUTLINE, false)
	add_decor(Rect2(bed.position + Vector2(6.0, 5.0), Vector2(w * 0.44, bed.size.y * 0.34)),
			Palette.BED.lightened(0.18), true)                                           # 枕头
	add_decor(Rect2(Vector2(bed.position.x + 3.0, bed.position.y + bed.size.y * 0.46),
			Vector2(w - 6.0, bed.size.y * 0.5)), Palette.BED_SHEET, true)                 # 被子

	# ---- 5) 支撑柱 + 爬梯：让"床在桌上方"有现实依据 ----
	var post_x := foot.position.x + 2.0 if facing > 0 else foot.end.x - 8.0
	add_decor(Rect2(Vector2(post_x, bed.end.y - 4.0), Vector2(6.0, lift + 10.0)),
			Palette.BED_FRAME, true)
	for i in 4:
		add_decor(Rect2(Vector2(post_x - 3.0, bed.end.y + 1.0 + i * 9.0), Vector2(12.0, 4.0)),
				Palette.DESK.lightened(0.1), true)


## 建筑外壳：实心块 + 屋顶色带
func add_building(rect: Rect2, body_color: Color, roof_color: Color) -> void:
	add_wall(rect, body_color, true)
	add_decor(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.22)), roof_color, true)


## 树：树干 + 树冠
func add_tree(pos: Vector2, trunk: Color, leaf: Color) -> void:
	add_wall(Rect2(pos - Vector2(7, 4), Vector2(14, 22)), trunk, true)
	var crown := Node2D.new()
	crown.z_index = int(-(pos.y - 20))
	crown.name = "Crown"
	add_child(crown)
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	var r := 26.0
	for i in 8:
		var ang := TAU * float(i) / 8.0
		pts.append(pos - Vector2(0, 20) + Vector2(cos(ang), sin(ang)) * r)
	poly.polygon = pts
	poly.color = leaf
	crown.add_child(poly)


## 一块可碰撞的门板（只画门板本身，不含门框/门洞）
func add_door_slab(rect: Rect2, color: Color) -> StaticBody2D:
	return add_wall(rect, color, true)


## 给某个 StaticBody2D 加一个可交互区域（门板既有碰撞又能被探测到）
func attach_interactable(host: StaticBody2D, script_path: String, area_rect: Rect2,
		props: Dictionary = {}) -> Area2D:
	var area := Area2D.new()
	area.name = "InteractArea"
	area.collision_layer = 4
	area.collision_mask = 0
	area.position = area_rect.position
	area.set_script(load(script_path))
	for key: String in props:
		area.set(key, props[key])
	host.add_child(area)

	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = area_rect.size
	shape.shape = rs
	shape.position = area_rect.size * 0.5
	area.add_child(shape)

	return area
