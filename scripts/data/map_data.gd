class_name MapData
extends RefCounted
## 地图布局数据（纯数据，不含任何节点操作）。
##
## 把"地图长什么样"和"怎么生成节点"分开：本文件只描述矩形、材质与物件坐标，
## 由场景脚本读取后交给 TileRoom（TileSet + TileMapLayer）铺出来。
## 改布局 = 改这里，不动代码逻辑。
##
## ------------------------------------------------------------------ 两套格子，别混
##
##   · **逻辑格** Grid.TILE = 32px —— 房间尺寸、相机、出生点、校园分区用它
##   · **图块格** Grid.CELL = 16px —— TileMapLayer 用的一律是这个
## 本文件里凡是 `_TILES` 后缀的都是逻辑格，凡是 `_CELLS` 后缀的都是图块格。
## 换算走 Grid.tile_to_cell() / Grid.rect_to_cells()。
##
## ------------------------------------------------------------------ 图块材质下标
##
## 与 tools/build_tileset.gd 里的 terrain 下标一一对应（改那边就要改这边）：
##   墙 0=木饰面 1=红砖 2=灰石 3=深砖
##   地 0=灰石板 1=拼花木地板 2=米黄瓷砖 3=青瓷砖 4=红砖地 5=沥青路 6=暗灰石板 7=暗红砖地

# ------------------------------------------------------------------ 材质下标

const WALL_WOOD := 0
const WALL_BRICK := 1
const WALL_STONE := 2
const WALL_DARK := 3

const FLOOR_STONE := 0
const FLOOR_PARQUET := 1
const FLOOR_TILE_CREAM := 2
const FLOOR_TILE_CYAN := 3
const FLOOR_BRICK_RED := 4
const FLOOR_ASPHALT := 5


# ------------------------------------------------------------------ 宿舍
#
# 2026-09-18 改成**标准俯视 tile 房间**（用户确认）：
#   外框 16x11 逻辑格 = 32x22 图块 = 512x352px
#   墙环厚 2 图块（32px = 一个逻辑格）
#   内部地板 28x18 图块 = 448x288px
# 原来那面 224px 高的后墙立面没有了 —— 墙的"高度"改由墙环自身的顶面/侧面明暗表达
# （见 tools/build_tileset.gd 里 TOP_FACE_GAIN / SIDE_FACE_GAIN 的说明）。
#
# ⚠️ 尺寸为什么是 16x11 而不是原来的 24x16：Interiors 的家具是按 16px 格子画的
#    （当前单人床是 2x4 图块 = 32x64px）。房间留太大，四个人住会像在体育馆里摆玩具
#    （第一版按 24x16 做出来就是这个效果，截图核对后改小）。28x18 的内部刚好放下
#    四套「床+书桌+椅+书柜」加一条过道。

## 宿舍外框（逻辑格）
const DORM_OUTER_TILES := Vector2i(16, 11)


static func dorm_outer_cells() -> Rect2i:
	return Rect2i(Vector2i.ZERO, Grid.tile_to_cell(DORM_OUTER_TILES))


static func dorm_world_rect() -> Rect2:
	return Grid.cells_to_rect(dorm_outer_cells())


## 内部地板矩形（图块格）
static func dorm_inner_cells() -> Rect2i:
	var outer := dorm_outer_cells()
	var t := TileRoom.WALL_TILES
	return Rect2i(outer.position + Vector2i(t, t), outer.size - Vector2i(t * 2, t * 2))


static func dorm_floor_rect() -> Rect2:
	return Grid.cells_to_rect(dorm_inner_cells())


static func dorm_wall_material() -> int:
	return WALL_WOOD


static func dorm_floor_material() -> int:
	return FLOOR_STONE


## 门：开在左右两面墙上（用户 2026-09-18："门在左侧墙和右侧墙墙上"）。
##
## 门**不是墙洞**：这里门后的墙仍然是实心的，碰撞也在。
## 原因是门外就是场景边界，真开个洞玩家会走出去掉进虚空；
## 而"看得见门 + 撞得到墙 + 有交互区"这三件事在俯视视角下本来就该同时成立。
##
## cells 是门在图块格上占的矩形 —— 走查断言就是拿它去核对"门在预期格子"。
## 用的是 Interiors 图集里**窄版竖门**（2 图块宽 x 3 图块高），它的宽正好等于墙厚。
##
## 2026-09-19：目标地点/出生点/上锁条件**全部搬进门表**（以前写在 dorm.gd 的 if-else 里）。
## 好处：再加一道门只改数据；而且 bathroom 门从此真的通向 `college.bathroom` 场景，
## 不再是那句"卫生间还没做出来"的占位台词。
static func dorm_doors() -> Array:
	var outer := dorm_outer_cells()
	var t := TileRoom.WALL_TILES
	var h := 3                                   ## 窄版竖门高 3 图块 = 48px
	var row := outer.size.y / 2 - h / 2
	return [
		{
			"id": "bathroom",
			"label": "卫生间",
			"side": "left",
			"cells": Rect2i(outer.position.x, row, t, h),
			"atlas": ATLAS_DOOR,
			"whole_sprite": true,
			"visual_scale": 1.0,
			"render_group": "wall",
			"prompt": "进卫生间",
			"target_location": "college.bathroom",
			"target_spawn": "from_dorm",
		},
		{
			"id": "exit",
			"label": "宿舍门",
			"side": "right",
			"cells": Rect2i(outer.end.x - t, row, t, h),
			"atlas": ATLAS_DOOR,
			"whole_sprite": true,
			"visual_scale": 1.0,
			"render_group": "wall",
			"prompt": "出门去校园",
			"target_location": "college.campus",
			"target_spawn": "from_dorm",
			# ⚠️ 用户 2026-09-20："出门去校园也是交互，也不应该之前能做" ——
			#    这扇门与屋里的家具走**同一个开场门槛**（`dorm.gd::OPENING_GATE`，
			#    也就是"跟陈默说过话"）。原来锁的是 `woke_up`（看过手机），
			#    于是"看完手机就能直接出门"，把"跟室友搭话"那一步跳过去了。
			"required_flag": "chatted_with_chenmo",
			"locked_message": "先跟陈默说两句话吧 —— 他也正闲着。",
			"auto_save_on_enter": true,
		},
	]


## Interiors 图集里家具/门窗的坐标（图块格）。
## 全部来自 tools/interiors_sprite_catalog.md —— 那张表是把图集放大 4~8 倍逐格目视确认出来的，
## 不要凭印象改这里的数字，改之前先回表里核对。
const ATLAS_BED := Vector2i(7, 80)          ## 单人床 木框+橙棕被（长款）2x4
const ATLAS_BED_ALT := Vector2i(5, 80)      ## 单人床 粉色被（长款）2x4
const ATLAS_DESK := Vector2i(10, 38)        ## 书桌 绿围板+木台面        3x3
const ATLAS_DESK_ALT := Vector2i(5, 35)     ## 学生桌+连体凳              2x2
const ATLAS_CHAIR := Vector2i(9, 31)        ## 木质靠背椅 红条纹坐垫     2x2
const ATLAS_SHELF := Vector2i(13, 38)       ## 书柜 彩色书脊（壁挂）     2x2
const ATLAS_SHELF_ALT := Vector2i(10, 38)   ## 书柜 黑板/深色书脊变体     2x2
const ATLAS_WARDROBE := Vector2i(7, 48)     ## 衣柜 双门木柜             2x3
const ATLAS_WINDOW := Vector2i(0, 28)       ## 窗 木框大窗              2x2
const ATLAS_ART := Vector2i(9, 24)          ## 挂画 木框               2x2
const ATLAS_RUG := Vector2i(0, 42)          ## 地毯 棕底绿边            3x2
const ATLAS_BATH_MAT := Vector2i(13, 20)   ## 小门垫 蓝底金边              2x2
const ATLAS_PLANT := Vector2i(10, 44)       ## 盆栽 大绿植木盆          2x3
const ATLAS_DOOR := Vector2i(9, 48)         ## 门 窄版竖门（宽=墙厚）    2x3
const ATLAS_LAMP := Vector2i(12, 53)        ## 落地灯 蓝罩              1x3
const CUSTOM_BED_TEXTURE := "res://assets/graphics/props/dorm_bed_custom/processed/clean.png"
const CUSTOM_CHAIR_TEXTURE := "res://assets/graphics/props/dorm_chair_custom/processed/clean.png"
const CUSTOM_DESK_TEXTURE := "res://assets/graphics/props/dorm_desk_custom/processed/sheet-transparent.png"
const CUSTOM_SHELF_TEXTURE := "res://assets/graphics/props/dorm_shelf_custom/processed/sheet-transparent.png"

## 宿舍家具**变体**（床/书桌/椅/书柜按四个工位稳定分配，让每个人的角落都有区别）。
##
## ⚠️ `cells` 必须与素材的**长宽比**一致：`place_prop` 会等比缩放到占地里，
##    比例不一致时会被压窄/留空。v2 与 v4 的床是**竖构图**（0.64/0.68），只能给 2x3；
##    塞进 3x3 的话会缩成一条窄床（实测落地只剩 31x48，旁边空一条）。
## 第 0 套（主角自己的）保留原来的自绘素材，其余三套用新图。
const DORM_BED_VARIANTS := [
	{"texture": CUSTOM_BED_TEXTURE, "cells": Vector2i(3, 3)},
	{"texture": "res://assets/graphics/props/dorm_bed_v2/processed/clean.png", "cells": Vector2i(2, 3)},
	{"texture": "res://assets/graphics/props/dorm_bed_v3/processed/clean.png", "cells": Vector2i(3, 3)},
	{"texture": "res://assets/graphics/props/dorm_bed_v4/processed/clean.png", "cells": Vector2i(2, 3)},
]
const DORM_CHAIR_VARIANTS := [
	{"texture": CUSTOM_CHAIR_TEXTURE, "cells": Vector2i(2, 2)},
	{"texture": "res://assets/graphics/props/dorm_chair_v2/processed/clean.png", "cells": Vector2i(2, 2)},
	{"texture": "res://assets/graphics/props/dorm_chair_v3/processed/clean.png", "cells": Vector2i(2, 2)},
	{"texture": "res://assets/graphics/props/dorm_chair_v4/processed/clean.png", "cells": Vector2i(2, 2)},
]
## 书桌和书柜改用独立整件精灵，避免图集相邻区域把桌面/柜体裁掉。
## 四个工位共用同一套完整素材，区别仍由床、椅和位置体现；占地不变。
const DORM_DESK_VARIANTS := [
	{"texture": CUSTOM_DESK_TEXTURE, "cells": Vector2i(3, 3)},
	{"texture": CUSTOM_DESK_TEXTURE, "cells": Vector2i(3, 3)},
	{"texture": CUSTOM_DESK_TEXTURE, "cells": Vector2i(3, 3)},
	{"texture": CUSTOM_DESK_TEXTURE, "cells": Vector2i(3, 3)},
]
## 书柜统一使用完整木框和彩色书脊精灵，保持 2x2 占地。
const DORM_SHELF_VARIANTS := [
	{"texture": CUSTOM_SHELF_TEXTURE, "cells": Vector2i(2, 2)},
	{"texture": CUSTOM_SHELF_TEXTURE, "cells": Vector2i(2, 2)},
	{"texture": CUSTOM_SHELF_TEXTURE, "cells": Vector2i(2, 2)},
	{"texture": CUSTOM_SHELF_TEXTURE, "cells": Vector2i(2, 2)},
]


## 家具「落地碰撞」：用精灵自身的归一化矩形（0..1）描述，只挡住家具真正占地的部分。
##
## ⚠️ 两条踩过的边界，改动前先读：
##
##   ① **不能太大**：整格实心（1,1,1,1）会变成空气墙 —— 角色离家具还有半格就被挡住。
##   ② **不能太小**：一开始只挡"贴地的一条"（椅子只有底部 31% ≈ 10px），结果玩家从
##      椅背那一侧走过去**直接穿过整张椅子**，观感就是"这把椅子没有碰撞"。
##      走查里加了一条"碰撞覆盖率 ≥ 45% 可见面积"的断言把下限钉死。
##
## 现在的口径：挡住家具**主体**（坐垫/桌面/柜体/床身），只留最上面一小条不挡 ——
## 这样玩家仍然能走到家具背后（被家具遮住，做出 3/4 俯视的前后关系），但穿不过去。
##
## ⚠️ 归一化矩形是相对**裁剪掉透明边距后的实际画面**算的（见 TileRoom._place_whole_prop），
##    不是相对声明占地 —— 贴图四周的透明边距不参与，否则碰撞会比看得见的家具大一圈。
const SOLID_BED := Rect2(0.06, 0.14, 0.88, 0.84)
const SOLID_DESK := Rect2(0.08, 0.32, 0.84, 0.66)
const SOLID_CHAIR := Rect2(0.04, 0.10, 0.92, 0.88)
const SOLID_TALL := Rect2(0.10, 0.26, 0.80, 0.72)
const SOLID_PLANT := Rect2(0.14, 0.30, 0.72, 0.68)
const SOLID_LAMP := Rect2(0.05, 0.30, 0.90, 0.68)


## 两扇衣柜的列起点（`dorm_props()` 里就是这两个数）。
## 抽成常量是为了让"方位键"和"摆在哪"同源：改布局时两处一起改，
## 不会出现"衣柜挪了一格、文案就找不到"（那种失败只是按 E 没反应）。
const WARDROBE_LEFT_X := 13
const WARDROBE_RIGHT_X := 17


## 宿舍物件：全部是**图块格**矩形 + 贴图来源（自绘整件精灵，或 Interiors 图集区域）。
##
## 坐标是**屏幕方向**的：行号越小越靠上（越远）。下面说的"上/下"都是玩家看到的上/下。
##
## 布局（俯视，内部 28x18 图块 = 列 2..29 / 行 2..19）：
##   上排： 椅 | 床 桌 书 | 柜 柜 | 书 桌 床 | 椅      （椅子紧贴桌子**上方**）
##   中间：            地毯
##   下排： 椅 | 床 桌 书 | 植 灯 | 书 桌 床 | 椅      （椅子同样紧贴桌子上方）
##
## ⚠️ **四把椅子一律紧贴桌子正上方（屏幕上方），且一律不翻转**（踩过三次）：
##    ① 最早给上排椅子加了 flip_v 想让它"朝向桌子"。自绘椅子是**正面视角**贴图
##       （椅背在上、椅腿在下），竖翻它得不到"背面视角"，只会得到一把**倒立的椅子**
##       —— 用户原话"方向不正常"。
##    ② 改成"椅子在桌子下方"：方向对了，但用户要的是**上方**。
##    ③ 椅子在上方但中间空一行：读起来像"一把椅子孤零零站在房间中间"，和桌子不成组。
##    所以现在：椅子在桌子上方且**紧贴**（读作"椅子推进桌下"），保持原朝向。
##    想让椅子换边，就改 chair_top，**不要**去动 flip_v。
##
## ⚠️ 手机（拾取物）摆在书桌上，改桌子行段时必须一起改 dorm_phone_cells()，
##    否则手机会悬在桌子外面（走查里有"手机必须落在某张书桌占格内"的断言兜住）。
##
## ⚠️ **占地尺寸要和美术的实际长宽比对得上**：床用的是自绘贴图，内容是**正方形**（229x230），
##    所以给 3x3（48x48）。给 2x4 会触发非等比拉伸，把等距视角的床纵向拉成斜平行四边形（踩过）。
##
## ⚠️ 这些矩形必须落在 dorm_inner_cells() 之内（列 2..29、行 2..19），
##    越界会被墙盖住；"物件出界 / 占格重叠 / 可见范围超出占地"都由走查断言兜住。
static func dorm_props() -> Array:
	var items: Array = []
	# 工位定义：床/桌/书柜的列起点 + 所在行段；椅子另给行段（一律紧贴桌子**上方**）
	var stations := [
		{"bed_x": 3, "desk_x": 7, "chair_x": 7, "shelf_x": 11, "top": 5, "chair_top": 3},
		{"bed_x": 27, "desk_x": 23, "chair_x": 23, "shelf_x": 20, "top": 5, "chair_top": 3},
		{"bed_x": 3, "desk_x": 7, "chair_x": 7, "shelf_x": 11, "top": 14, "chair_top": 12},
		{"bed_x": 27, "desk_x": 23, "chair_x": 23, "shelf_x": 20, "top": 14, "chair_top": 12},
	]
	for i in stations.size():
		var s: Dictionary = stations[i]
		# 第一套工位（**左上**）是周明远自己的 —— 手机也放在这张书桌上，
		# 文案与"是不是自己的"都按方位判（见上面 `DORM_EXAMINES` 的说明）。
		# 每套工位换一种床/椅（第 0 套是主角自己的，保留原素材）
		var bed: Dictionary = DORM_BED_VARIANTS[i % DORM_BED_VARIANTS.size()]
		var chair: Dictionary = DORM_CHAIR_VARIANTS[i % DORM_CHAIR_VARIANTS.size()]
		var desk: Dictionary = DORM_DESK_VARIANTS[i % DORM_DESK_VARIANTS.size()]
		var shelf: Dictionary = DORM_SHELF_VARIANTS[i % DORM_SHELF_VARIANTS.size()]
		var bed_size: Vector2i = bed["cells"]
		var chair_size: Vector2i = chair["cells"]
		var desk_size: Vector2i = desk["cells"]
		var shelf_size: Vector2i = shelf["cells"]
		items.append({
			"kind": "bed",
			"cells": Rect2i(int(s["bed_x"]), int(s["top"]), bed_size.x, bed_size.y),
			"atlas": ATLAS_BED, "texture_path": String(bed["texture"]),
			"whole_sprite": true, "collision": SOLID_BED,
			"examine": "bed",
		})
		items.append({
			"kind": "desk", "cells": Rect2i(int(s["desk_x"]), int(s["top"]), desk_size.x, desk_size.y),
			"atlas": desk.get("atlas", ATLAS_DESK), "texture_path": String(desk.get("texture", "")),
			"whole_sprite": true, "collision": SOLID_DESK,
			"examine": "desk",
		})
		items.append({
			"kind": "chair",
			"cells": Rect2i(int(s["chair_x"]), int(s["chair_top"]), chair_size.x, chair_size.y),
			"atlas": ATLAS_CHAIR, "texture_path": String(chair["texture"]),
			"whole_sprite": true, "collision": SOLID_CHAIR,
		})
		items.append({
			"kind": "shelf", "cells": Rect2i(int(s["shelf_x"]), int(s["top"]), shelf_size.x, shelf_size.y),
			"atlas": shelf.get("atlas", ATLAS_SHELF), "texture_path": String(shelf.get("texture", "")),
			"whole_sprite": true,
			# 书柜原先没有碰撞（能直接走过去），用户要求补上：和衣柜用同一套"小柜子落地碰撞"
			"collision": SOLID_TALL,
			"examine": "shelf",
		})

	# 衣柜：居中贴上方墙，两扇对称
	# ⚠️ 它们的 x 就是 `WARDROBE_LEFT_X / WARDROBE_RIGHT_X`（方位键按它分左右，见 `dorm_location_key()`）
	items.append({"kind": "wardrobe", "cells": Rect2i(WARDROBE_LEFT_X, 2, 2, 3), "atlas": ATLAS_WARDROBE,
			"whole_sprite": true, "collision": SOLID_TALL, "examine": "wardrobe"})
	items.append({"kind": "wardrobe", "cells": Rect2i(WARDROBE_RIGHT_X, 2, 2, 3), "atlas": ATLAS_WARDROBE,
			"whole_sprite": true, "collision": SOLID_TALL, "examine": "wardrobe"})

	# 中部与下墙：地毯走"贴地装饰"（铺进地板层，不参与 y 排序、永远不挡人），
	# 绿植和落地灯贴下墙（这两件要参与 y 排序，玩家能走到它们背后被挡住）
	items.append({"kind": "rug", "cells": Rect2i(13, 9, 3, 2), "atlas": ATLAS_RUG,
			"floor_decal": true})
	items.append({"kind": "plant", "cells": Rect2i(13, 17, 2, 3), "atlas": ATLAS_PLANT,
			"whole_sprite": true, "collision": SOLID_PLANT})
	items.append({"kind": "lamp", "cells": Rect2i(17, 17, 1, 3), "atlas": ATLAS_LAMP,
			"whole_sprite": true, "collision": SOLID_LAMP})

	# 上方墙上的窗与挂画（render_group=wall 让它们压在墙层之上，视觉上就是"开在墙上"）。
	# 两扇窗使用和宿舍中间挂画、卫生间镜面一致的四格玻璃样式，避免百叶窗贴图显得突兀。
	items.append({"kind": "window", "cells": Rect2i(5, 0, 2, 2), "atlas": ATLAS_ART,
			"whole_sprite": true, "render_group": "wall", "examine": "window"})
	items.append({"kind": "window", "cells": Rect2i(23, 0, 2, 2), "atlas": ATLAS_ART,
			"whole_sprite": true, "render_group": "wall", "examine": "window"})
	items.append({"kind": "art", "cells": Rect2i(14, 0, 2, 2), "atlas": ATLAS_ART,
			"whole_sprite": true, "render_group": "wall"})
	return items


# ---------------------------------------------------------------- 家具的"查看"对话
#
# 加一件**可查看**的家具 = 给它的 prop 加一个 `"examine": "<kind>"` 标记，
# 节点由 dorm.gd 按占地自动建出来，交互区也跟着占地走。
# 文案集中在这里：改台词不用碰几何数据，改布局也不用碰台词。
#
# ⚠️ **哪件是主角自己的、哪件是哪个室友的，一律由"占格算出的方位"决定**
#    （`dorm_location_key()`），prop 上**不再**写 `examine_self` 标记 ——
#    2026-09-20 之前是"标记 → 换一套文案 + 换一个补丁 id"，
#    而"四张床"只能分成"我的/室友的"两类，讲不清"考研那位""陈默""出国交换那位"。
#    现在文案按位置存（左下/右上/左上/右下各一段），标记也就没有存在的意义了
#    —— 两套判据并存迟早会错位（标记在 A、文案写的是 B，而且不报错）。

## `"<kind>.<位置>" -> { name, prompt, lines }`（`name` 只用于默认提示）
##
## 为什么文案要**按位置分开**（2026-09-20 用户给的 08 原文就是四套）：
##   宿舍是四人间，床/书桌/书柜各有四件（左下/右上/左上/右下），它们**长得一样但主人不同** ——
##   "室友的床"这种笼统的说法会把"考研那位""陈默""出国交换那位"三个人讲成一个人。
##   08 里每组都是四条独立台词，所以这里也按位置存。
##   ⚠️ 位置是**屏幕方向**（行号越小越靠上），与 `dorm_props()` 的布局注释同一口径；
##      那个方向键由 `dorm_location_key()` 从占格算出来，不手写（抄坐标迟早会飘）。
const DORM_EXAMINES := {
	# ① 左上：周明远自己（靠窗那张床、笔记本还开着的书桌、自己买的教材）
	"bed.up_left": {
		"name": "我的床铺",
		"prompt": "看看床铺",
		"lines": [
			{"speaker": "", "text": "靠窗那张床是你的，被子揉成一团，枕头掉在地上。"},
			{"speaker": "", "text": "昨晚你到底是几点钟睡着的？你已经记不清了。"},
		],
	},
	"desk.up_left": {
		"name": "我的书桌",
		"prompt": "看看书桌",
		"lines": [
			{"speaker": "", "text": "周明远的书桌。笔记本还开着，桌面已经休眠。"},
			{"speaker": "周明远（内心）", "text": "……看起来昨天忘记关电脑就睡着了。", "emotion": "疲惫"},
		],
	},
	"shelf.up_left": {
		"name": "书柜",
		"prompt": "看看书柜",
		"lines": [
			{"speaker": "", "text": "书柜里只有你先前买的各种上课用的教材，多数还是为了开卷考试买的。"},
			{"speaker": "周明远", "text": "哪天找个机会把这些书卖了。", "emotion": "嫌弃"},
		],
	},
	# ② 右上：陈默（被改造成"小型网吧"的床、抄了作业题的书桌、装满周边的书柜）
	"bed.up_right": {
		"name": "陈默的床铺",
		"prompt": "看看床铺",
		"lines": [
			{"speaker": "", "text": "陈默的床。床上已被陈默改造成了小型网吧的样子，"
				+ "电脑桌子纸巾耳机一应俱全。"},
			{"speaker": "周明远（内心）", "text": "昨晚他是不是又通宵打游戏了？", "emotion": "了然"},
		],
	},
	"desk.up_right": {
		"name": "陈默的书桌",
		"prompt": "看看书桌",
		"lines": [
			{"speaker": "", "text": "陈默的书桌。书桌上有抄好的作业题目。"},
			{"speaker": "周明远",
				"text": "还真给我抄回来了……这门课的老师也是神奇，依旧坚持古法留作业，"
					+ "连课程网站都没有。",
				"emotion": "无语"},
		],
	},
	"shelf.up_right": {
		# ⚠️ 名字里带"陈默"是有意的：艾莉娜**只在周明远自己的东西上插话**
		#    （用户 2026-09-20），而 `AlyinaBanter` 是按物件名判的
		#    （见那边 `NO_BANTER_WORDS`）。叫"书柜"的话她就对着陈默的柜子感叹起来了。
		"name": "陈默的书柜",
		"prompt": "看看书柜",
		"lines": [
			{"speaker": "", "text": "书柜上并没有什么书，但是装满了各种手办，立牌，挂件等物件。"},
			{"speaker": "周明远", "text": "……还好陈默没把等身立牌放宿舍门口。", "emotion": "庆幸"},
		],
	},
	# ③ 左下：考研那位（叠得方方正正的床、一摞考研真题的书桌、专业课教材的书柜）
	"bed.down_left": {
		"name": "室友的床铺",
		"prompt": "看看床铺",
		"lines": [
			{"speaker": "", "text": "室友的床。被子叠的方方正正，床头压着两本考研英语速记。"},
			{"speaker": "周明远", "text": "能天天起早八复习考研之人，真佩服他。", "emotion": "佩服"},
		],
	},
	"desk.down_left": {
		"name": "室友的书桌",
		"prompt": "看看书桌",
		"lines": [
			{"speaker": "", "text": "考研室友的书桌。台灯，水杯，一摞打印出来的考研真题。"},
			{"speaker": "周明远", "text": "卷狗。", "emotion": "苦笑"},
		],
	},
	"shelf.down_left": {
		# ⚠️ 同上：名字带"室友"，她就不会对着别人的柜子插话
		"name": "室友的书柜",
		"prompt": "看看书柜",
		"lines": [
			{"speaker": "", "text": "书柜上排着专业课教材，最下一层塞着几本卷着边的旧书。"},
			{"speaker": "周明远", "text": "《数据结构》，《计算机网络》，《概率论》……全是考研那哥们的书。",
				"emotion": "了然"},
			{"speaker": "周明远",
				"text": "毕竟 ai 时代，大概在大学里也只有应试需求需要买实体书了。", "emotion": "感慨"},
		],
	},
	# ④ 右下：出国交换那位（空床、位置都空着的书柜、收拾干净的书桌）
	"bed.down_right": {
		"name": "空着的床铺",
		"prompt": "看看床铺",
		"lines": [
			{"speaker": "", "text": "这个床现在已经没有人睡了。因为它曾经的主人出国交换了。"},
			{"speaker": "周明远",
				"text": "时差 12 个钟头，现在中午那边正好半夜，他应该还没睡。", "emotion": "怀念"},
		],
	},
	"shelf.down_right": {
		"name": "空书柜",
		"prompt": "看看书柜",
		"lines": [
			{"speaker": "", "text": "书柜里空无一物，因为书柜的主人已经出国交换了。"},
		],
	},
	"desk.down_right": {
		# 08 里"看看书桌"只给了三张（自己的 / 考研那位 / 陈默），
		# 但宿舍里确实有四张桌子 —— 出国交换那张不能是空的（按 E 会变成"没有文案"的警告），
		# 所以照 `shelf.down_right` 的口径补一句最短的旁白。
		"name": "空书桌",
		"prompt": "看看书桌",
		"lines": [
			{"speaker": "", "text": "桌面擦得很干净，连灰都没有 —— 主人出国交换，走之前收拾过一次。"},
		],
	},
	# 衣柜：两扇贴上方墙，**各一句**（08：左衣柜讲旧校服，右衣柜"不是自己的衣柜"）
	"wardrobe.left": {
		"name": "我的衣柜",
		"prompt": "看看衣柜",
		"lines": [
			{"speaker": "周明远", "text": "都是四年没变的旧衣服……最里面的那件旧校服外套还是高中带过来的。",
				"emotion": "平淡"},
			{"speaker": "周明远", "text": "……一直没舍得扔。", "emotion": "沉默"},
			{"speaker": "", "text": "那件衣服白中泛黄，但仍能看出高中校服特有的朴素感。"},
		],
	},
	"wardrobe.right": {
		"name": "别人的衣柜",
		"prompt": "看看衣柜",
		"lines": [
			{"speaker": "周明远（内心）", "text": "不是自己的衣柜，还是不打开看为好。",
				"emotion": "收敛"},
		],
	},
	# 窗：两扇（同一段台词）
	"window.up": {
		"name": "窗户",
		"prompt": "看看窗外",
		"lines": [
			{"speaker": "", "text": "窗外正对着食堂。午间的阳光把宿舍照得发白。"},
			{"speaker": "周明远", "text": "这个点食堂肯定人满为患了。", "emotion": "慵懒"},
			{"speaker": "周明远", "text": "外面一点风也没有。", "emotion": "平静"},
		],
		# ⚠️ 08 定稿（艾莉娜入队那一段）："看看窗外：改为: 旁白：外面的天已经完全被
		#    夕阳点缀成了金黄的一片，静谧又美好。"
		#    原版是**中午**的口径（"午间的阳光…食堂人满为患"），而她入队时
		#    `alyina_cg` 已经把时间拨到 17:00（夕阳）—— 所以这一段是**整体换**，
		#    由 `dorm_examine()` 按 `STORY_ALYINA_FOLLOWS` 选。
		#    她跟着的那句"窗外的景色，真美！"走插话池（窗户命中宿舍那一组）。
		"alyina_lines": [
			{"speaker": "", "text": "外面的天已经完全被夕阳点缀成了金黄的一片，静谧又美好。"},
		],
	},
}


## 某件家具在房间里的**方位**键（屏幕方向：行号小 = 上，列号小 = 左）。
##
## ⚠️ 为什么要算而不是手写：文案是按位置分的（见 `DORM_EXAMINES`），
##    而家具坐标由 `dorm_props()` 的工位表生成 —— 手写"哪件是左上"迟早会跟布局飘开，
##    表现是"看左上那张床，说的是右下那位室友的事"，而且不报错。
##
## ⚠️ 贴**上墙**的那几件分两种情况（2026-09-20 按 08 改）：
##    · **两扇衣柜各有一句不同的话**（08：左衣柜是"旧校服外套"，右衣柜是
##      "不是自己的衣柜，还是不打开看为好"）→ 它们用 `"left"` / `"right"`；
##    · **两扇窗共用一句**（08 只给了一套）→ 它们用 `"up"`。
##    分错的后果是"按 E 没反应"（键对不上表里的条目），或两件说了同一句。
static func dorm_location_key(cells: Rect2i) -> String:
	# 墙上的东西（行 0..2 都是墙线）：没有上/下之分。
	# ⚠️ 两扇衣柜的 x 是写死的（`dorm_props()` 里 13 与 17），这里按它们分左右；
	#    两扇窗（5 / 23）与挂画走 `"up"`，共用一套词（08 只给了一套）。
	if cells.position.y <= 2:
		if cells.position.x == WARDROBE_LEFT_X:
			return "left"
		if cells.position.x == WARDROBE_RIGHT_X:
			return "right"
		return "up"
	var vertical := "up" if cells.position.y < 10 else "down"
	var horizontal := "left" if cells.position.x < 15 else "right"
	return "%s_%s" % [vertical, horizontal]


## 取某件家具的"查看"文案。
##
## [param kind] prop 上的 `examine` 标记；[param cells] 家具占格（用来分辨是哪一位室友的）。
## ⚠️ 先按 `<kind>.<方位>` 取，取不到再退回 `<kind>`（
##    这样"四件共用一套文案"的家具仍然只写一条数据，见 `dorm_examine_fallback` 的用法）。
static func dorm_examine(kind: String, cells: Rect2i) -> Dictionary:
	var key := "%s.%s" % [kind, dorm_location_key(cells)]
	var def: Dictionary = DORM_EXAMINES[key] if DORM_EXAMINES.has(key) \
			else DORM_EXAMINES.get(kind, {})
	# "她入队之后整体换一段"的家具（08："看看窗外：改为…"）。
	# 必须等艾莉娜登场 CG 完成，不能在"课不上了"阶段提前出现。
	if def.has("alyina_lines") and GameFlow.has_flag(TeachingData.STORY_ALYINA_MET):
		var out := def.duplicate(true)
		out["lines"] = def["alyina_lines"]
		return out
	return def


## 这件家具的文案块 id（对话补丁/对话编辑器按它登记；每个位置一个，互不覆盖）
static func dorm_examine_id(kind: String, cells: Rect2i) -> String:
	return "map.dorm_examine.%s.%s" % [kind, dorm_location_key(cells)]


## 这件家具是不是**主角自己**那一件（左上那一套工位）。
##
## ⚠️ 判据是**位置**，不是 prop 上的 `examine_self` 标记：标记与文案必须同源，
##    否则"标记在 A、文案写的是 B"这类错位只能靠肉眼发现。
static func dorm_examine_is_self(cells: Rect2i) -> bool:
	return dorm_location_key(cells) == "up_left"



## 手机摆在左上那套书桌的桌面上（书桌 = 列 7..9 / 行 5..7）。
## ⚠️ 必须跟着 dorm_props() 里那张桌子的行段走：桌子挪了而这里没挪，
##    手机就会悬在桌子外面（走查里有"手机必须落在某张书桌占格内"的断言兜住）。
## 2026-09-18 起手机是**可拾取物**（进背包），位置仍由 dorm_pickups() 引用这里。
static func dorm_phone_cells() -> Vector2i:
	return Vector2i(7, 6)


static func dorm_phone_pos() -> Vector2:
	return Grid.cell_to_px(dorm_phone_cells()) + Vector2(Grid.CELL * 0.5, Grid.CELL * 0.5)


## 宿舍里**可以捡起来进背包**的东西（2026-09-18：手机从"固定交互物"改成拾取物）。
##
## 数据驱动：dorm.gd 只按这张表建 ItemPickup，加一件可捡的东西在这里加一行即可。
## ⚠️ cells 必须落在某张书桌的占格里（走查有断言兜住），且**必须能从出生点够到** ——
##    开场玩家是锁着移动的，够不到就是硬卡死。
## `release_movement_lock`：捡到它就放开开场的移动锁（够到手机 = 人已经起来了）。
## 之后"看手机"这一步靠出口门的 `woke_up` 拦截 + HUD 提示引导，不再锁移动 ——
## 硬锁移动会让不知道按 B 的玩家以为游戏卡死。
## `pickup_id`：一次性拾取的存档键。**必须给**，否则重进场景会把东西再刷一遍
## （手机被无限复制就是这么来的）。
## `interact_priority`：交互候选里的排位（大的排前面）。手机给高优先级，是为了
## "开局按 E 就是拿手机"—— 光按距离排的话，旁边那张刚爬起来的床会把它挤到第二位，
## 玩家得先按 Tab，很反直觉。
static func dorm_pickups() -> Array:
	return [
		{
			"id": "phone",
			"pickup_id": "college.dorm/phone",
			"item_id": "phone",
			"count": 1,
			"cells": dorm_phone_cells(),
			"prompt": "捡起手机",
			"pickup_text": "手机就搁在桌面上，屏幕还亮着。",
			"release_movement_lock": true,
			"interact_priority": 10,
		},
	]


## 宿舍里各角色的出生位置（世界像素）。
##
## 用户要求：**出生点在床旁边**（床本身有碰撞 SOLID_BED，不能站上去）。
## 第一张床占格 (3,5) 3x3 图块 → 像素 x 48..96 / y 80..128，
## 其碰撞是 x 50.9..93.1 / y 86.7..127。取**床正下方(床尾)** (72, 138)：
##   · 离床碰撞下沿还有 11px 余量，玩家（半径约 8）不会卡住
##   · 这一带是两排家具之间的空过道，附近没有桌/椅/柜的碰撞
##   · 距桌上手机 (120,104) = 59px < 交互半径 96 → 开场（移动被锁）就能按 E 看手机
static func dorm_spawns() -> Dictionary:
	return {
		"default": Vector2(176.0, 136.0),
		"bed_2": Vector2(72.0, 138.0),
		"from_campus": Vector2(440.0, 184.0),
		## 从卫生间出来：站在左墙那道门**内侧**的过道上（列 3 / 行 11 = 中间那条走道，
		## 上下两排家具都不占这一行），面朝房间内（+x）。
		"from_bathroom": Vector2(56.0, 184.0),
	}


# ------------------------------------------------------------------ 宿舍 · 卫生间

# 2026-09-19：卫生间从"门口一句占位台词"升级成**独立场景**（用户要求：要包含洗手台、淋浴头、马桶）。
# 宿舍门表里的那道 `bathroom` 门从此真的通到这里，不再是 ExamineObject 占位。
#
# 尺寸按"四人间公共卫浴"收紧：外框 8x6 逻辑格 = 16x12 图块 = 256x192px，
# 墙环厚 2 图块，内部 12x8 图块 = 192x128px（6x4 逻辑格）。
#
# 布局（俯视，内部图块格 列 2..13 / 行 2..9）。门在东墙（列 14..15 / 行 4..6），
# 所以摆放按**进门动线**来：进门右手边就是洗手台 → 马桶居中 → 淋浴间在最里侧角落，
# 洗衣机贴东南角（紧挨着门，接上下水也近）：
#   北墙一排（行 2..4）： 淋浴间(列 2..4) | 马桶(列 6..7) | 洗手台(列 9..11)
#   南墙（行 8..9）：     洗衣机(列 10..11)
#   门口地垫（列 10..11 / 行 5..6，贴地装饰层，不挡人）
#
# ⚠️ 行号只到 **9**：外框 6 逻辑格 = 12 图块，减掉上下各 2 图块厚墙 = 内部 8 行（2..9）。
#    旧版把洗衣机写到 (2, 16)，那是**外框之外**；现在所有物件都压在收紧后的内部地板里。
#
# ⚠️ 尺寸口径（2026-09-19 返工）：**先量玩家再定家具**。
#    玩家可见像素实测 **22x40 px**（player_walk.png 首帧包围盒），已验收的宿舍床是 48x48。
#    第一版卫浴件按"图块数"拍脑袋定成洗手台 96x64 / 马桶 48x64，等于洗手台宽到 4.4 个玩家宽、
#    马桶比玩家还高 —— 用户实报"物品太大了"。现在四件一律 ≤ 床的口径（见 bathroom_props()）。
#
# 门为什么仍是"实心墙上的门板"而不是墙洞：与宿舍同一口径 —— 门外就是场景边界，
# 真开洞玩家会走出地图掉进虚空（理由详见 dorm_doors() 的注释）。

## 卫生间外框（逻辑格）
const BATHROOM_OUTER_TILES := Vector2i(8, 6)


static func bathroom_outer_cells() -> Rect2i:
	return Rect2i(Vector2i.ZERO, Grid.tile_to_cell(BATHROOM_OUTER_TILES))


static func bathroom_world_rect() -> Rect2:
	return Grid.cells_to_rect(bathroom_outer_cells())


## 内部地板矩形（图块格）
static func bathroom_inner_cells() -> Rect2i:
	var outer := bathroom_outer_cells()
	var t := TileRoom.WALL_TILES
	return Rect2i(outer.position + Vector2i(t, t), outer.size - Vector2i(t * 2, t * 2))


static func bathroom_wall_material() -> int:
	## 灰石墙 + 青瓷砖地 = 一眼读成"水房/卫生间"，和宿舍的木饰面 + 灰石板区分开
	return WALL_STONE


static func bathroom_floor_material() -> int:
	return FLOOR_TILE_CYAN


# ---------------------------------------------------------------- 卫浴三件套 + 洗衣机
#
# 素材来源：**本项目自绘占位图**（tools/generate_bathroom_props.py），
# 因为现有 Interiors 免费图集里**没有任何卫浴件**
# （tools/interiors_sprite_catalog.md 第 109 行已核实："洗衣机、马桶、浴缸"都没有）。
#
# 换正式美术时**只改这四个常量指向的文件**，不用动布局/交互/碰撞：
# 画布按"占地像素"出图就是 1:1（洗手台 96x64、马桶 48x64、淋浴间 64x64、洗衣机 48x48），
# 缩放系数正好 1.0，像素不会被重采样；换成别的等比画布也只是等比缩一下。
const BATHROOM_SINK_TEXTURE := "res://assets/graphics/props/bathroom_sink/processed/clean.png"
const BATHROOM_TOILET_TEXTURE := "res://assets/graphics/props/bathroom_toilet/processed/clean.png"
const BATHROOM_SHOWER_TEXTURE := "res://assets/graphics/props/bathroom_shower/processed/clean.png"
const BATHROOM_WASHER_TEXTURE := "res://assets/graphics/props/bathroom_washer/processed/clean.png"

## 落地碰撞（归一化矩形，相对**裁掉透明边距后**的实际画面）。
## 口径与宿舍一致：挡住主体、只留最上面一条不挡，玩家能走到背面被遮住，但穿不过去。
const SOLID_BATH_SINK := Rect2(0.05, 0.30, 0.90, 0.68)
const SOLID_BATH_TOILET := Rect2(0.10, 0.26, 0.80, 0.72)
const SOLID_BATH_SHOWER := Rect2(0.04, 0.22, 0.92, 0.76)
const SOLID_BATH_WASHER := Rect2(0.06, 0.14, 0.88, 0.84)


## 卫生间物件（图块格矩形 + 贴图来源）。
##
## ⚠️ 尺寸口径：**先量玩家，再定家具**（玩家可见 22x40 px，宿舍床 48x48）。四件都 ≤ 床的口径。
## ⚠️ 画布尺寸 = 占地像素时，落地缩放正好 1.0（像素不被重采样）——
##    每件的贴图就按这个尺寸出图/归一化，改占地就要一起改图（见各目录的 SOURCE.txt）。
## ⚠️ 必须落在 bathroom_inner_cells()（列 2..13 / 行 2..9）之内，越界会被墙盖住。
static func bathroom_props() -> Array:
	var items: Array = []
	# 淋浴间：底盘 + 挡水条 + 立杆花洒，3x3 图块格（48x48px）—— 与宿舍床同口径
	items.append({
		"kind": "shower", "cells": Rect2i(2, 2, 3, 3),
		"texture_path": BATHROOM_SHOWER_TEXTURE,
		"whole_sprite": true, "collision": SOLID_BATH_SHOWER,
		"examine": "shower",
	})
	# 马桶：水箱在上、桶身朝镜头，2x2 图块格（32x32px；画布 20x32，等比居中）
	# —— 宽度只有玩家的 0.9 倍（上一版是 2.2 倍，比人还高）
	items.append({
		"kind": "toilet", "cells": Rect2i(6, 2, 2, 2),
		"texture_path": BATHROOM_TOILET_TEXTURE,
		"whole_sprite": true, "collision": SOLID_BATH_TOILET,
		"examine": "toilet",
	})
	# 洗手台：台面 + 双台盆 + 龙头 + 镜子，3x2 图块格（48x32px）
	# —— 宽是玩家的 2.2 倍（与床同级），但很浅（0.8 个人高）
	items.append({
		"kind": "sink", "cells": Rect2i(9, 2, 3, 2),
		"texture_path": BATHROOM_SINK_TEXTURE,
		"whole_sprite": true, "collision": SOLID_BATH_SINK,
		"examine": "sink",
	})
	# 洗衣机：楼里共用那台（2x2 图块格 = 32x32px，正方形画布），贴东南角、紧挨着门
	# —— 上一版放在西北角，进门要穿过整间屋子才够得到（用户说"位置不合理"）
	items.append({
		"kind": "washer", "cells": Rect2i(10, 8, 2, 2),
		"texture_path": BATHROOM_WASHER_TEXTURE,
		"whole_sprite": true, "collision": SOLID_BATH_WASHER,
		"examine": "washer",
	})
	# 门口地垫：走**贴地装饰层**（盖在地板之上、不参与 y 排序、永远不挡人）
	items.append({
		"kind": "mat", "cells": Rect2i(10, 5, 2, 2), "atlas": ATLAS_BATH_MAT,
		"floor_decal": true,
	})
	# 淋浴区脚垫：和门口同款小蓝垫，给空出的中段一个明确的"湿区"落点。
	items.append({
		"kind": "shower_mat", "cells": Rect2i(2, 5, 2, 2), "atlas": ATLAS_BATH_MAT,
		"floor_decal": true,
	})
	return items


## 卫生间的门。只有一道：回宿舍（与宿舍左墙那道门正对）。
## 目标地点/出生点写在数据里，dorm.gd / bathroom.gd 都只是照读。
static func bathroom_doors() -> Array:
	var outer := bathroom_outer_cells()
	var t := TileRoom.WALL_TILES
	var h := 3                                   ## 窄版竖门高 3 图块 = 48px
	var row := floori(float(outer.size.y - h) * 0.5) ## 竖直居中，明确向下取整避免半格漂移
	return [
		{
			"id": "dorm",
			"label": "宿舍门",
			"side": "right",
			"cells": Rect2i(outer.end.x - t, row, t, h),
			"atlas": ATLAS_DOOR,
			"whole_sprite": true,
			"visual_scale": 1.0,
			"render_group": "wall",
			"prompt": "回宿舍",
			"target_location": "college.dorm",
			"target_spawn": "from_bathroom",
		},
	]


# ---------------------------------------------------------------- 卫生间家具的"查看"文案
#
# 与宿舍同一套机制：prop 上写 `"examine": "<kind>"`，节点由场景脚本按占地自动建出来。
# 台词集中在这里，改词不用碰几何数据。
const BATHROOM_EXAMINES := {
	"sink": {
		"name": "洗手台",
		"prompt": "看看洗手台",
		"lines": [
			{"speaker": "", "text": "四人间共用的洗手台。台面上贴着一条胶带，划出四个杯位。"},
			{"speaker": "周明远", "text": "镜子上的水汽还没干。昨晚最后一个洗漱的人应该是我。", "emotion": "疲惫"},
			{"speaker": "周明远", "text": "（镜子里这张脸，跟高三那会儿比，也没精神多少。）", "emotion": "沉默"},
		],
	},
	"toilet": {
		"name": "马桶",
		"prompt": "看看马桶",
		"lines": [
			{"speaker": "", "text": "马桶圈是掀起来的，水箱在滴水，一滴一滴，很规律。"},
			{"speaker": "周明远", "text": "报修单填了三次，没人来。后来我们就当白噪音听了。", "emotion": "无奈"},
		],
	},
	"shower": {
		"name": "淋浴间",
		"prompt": "看看淋浴间",
		# 台词照 `request/08_DIALOG.md`（"看看淋浴间的对话"）
		"lines": [
			{"speaker": "", "text": "三楼的水压总是不稳定。淋浴头的温度调节也很不灵敏，"
				+ "一念冰封，一念火炉。"},
			{"speaker": "周明远", "text": "更别提大家掉头发还会堵住下水道了。", "emotion": "嫌弃"},
		],
	},
	"washer": {
		"name": "洗衣机",
		"prompt": "看看洗衣机",
		"lines": [
			{"speaker": "", "text": "楼里共用一台洗衣机，投币或者扫码，一次两块五。"},
			{"speaker": "周明远", "text": "上次投了币没转起来，钱吞了，衣服还是手洗的。", "emotion": "自嘲"},
		],
	},
}


## 取卫生间某件家具的"查看"文案
static func bathroom_examine(kind: String) -> Dictionary:
	return BATHROOM_EXAMINES.get(kind, {})


## 卫生间出生点（世界像素）。
## ⚠️ 运行期的真身是 scenes/college/bathroom.tscn 里 SpawnPoints 下的 Marker2D；
##    这里这份是**同一份数据的可读镜像**，bathroom.gd 的自检会拿它对账（对不上会报出来）。
static func bathroom_spawns() -> Dictionary:
	return {
		"default": Vector2(200.0, 88.0),
		"from_dorm": Vector2(200.0, 88.0),
	}


# ------------------------------------------------------------------ 校园（已迁出）
#
# 校园的分区数据与几何工具 2026-09-19 迁到 **scripts/data/campus_data.gd**（class_name CampusData）：
# 校园从"一张图塞 8 栋楼"改成**三个区 + 区间切换场景**，数据量翻了几倍，
# 再堆在本文件里会让"宿舍 / 卫生间 / 校园"三套东西混在一起。
# 本文件从此只管宿舍与卫生间。
