class_name Palette
extends RefCounted
## 占位配色表。
##
## 美术素材到位前，所有场景用这些颜色以"纯色块"方式先把地图和交互跑通。
## 换素材时只需要把场景里的 ColorRect/Polygon2D 换成 Sprite2D/TileMapLayer，
## 颜色值集中在这里，方便统一调整风格。

# 地面 / 建筑
## 室内地板用**冷色**（蓝灰水泥地），刻意与家具的暖棕拉开色差。
## 踩过的坑：地板原本是暖棕 #5a4a3c，与"桌子顶面"的色差只有 0.075，
## 结果家具画出来了却看不出来（连像素断言都误判成"没画"）。冷暖分离后一眼就能分辨。
## 再压暗一档：地板越暗，浅色家具越跳。
const FLOOR_INDOOR := Color("#2b2d36")
const FLOOR_WALL := Color("#3b3128")
const FLOOR_TILE := Color("#4a4c58")
const GRASS := Color("#4a7a3a")
const GRASS_DARK := Color("#3d6830")
const ROAD := Color("#4a4a52")
const ROAD_LINE := Color("#c9c48f")
const PATH := Color("#8a7a63")
const WATER := Color("#2e5f8a")

# 家具 / 物件
const BED := Color("#c8c2b0")
const BED_SHEET := Color("#7fa8c9")
## 家具木色：整体偏亮，保证与深冷色地板的色差足够大（≥0.3），否则"画了看不见"
const DESK := Color("#c49a63")
## 书架：框体深、格面亮，靠明暗对比把"格架"读出来（之前太暗，远看糊成一团）
const BOOK_SHELF := Color("#9c7a4e")
const BOOK_SHELF_FRAME := Color("#4a361f")
const CHAIR := Color("#6b4f33")
const DOOR := Color("#a8763f")
const DOOR_FRAME := Color("#6b4a2a")
const DOOR_HANDLE := Color("#d8c98a")
## 门洞里的暗部（表示门后还有空间）与门槛/门内地面
const DOOR_VOID := Color("#1a1410")
const DOOR_THRESHOLD := Color("#6b5a45")
## 上床下桌：床架、床板与桌面之间的架空间隙
const BED_FRAME := Color("#6b5236")
const BED_GAP := Color("#3a2c1e")
const WINDOW := Color("#8fb8d4")
const BUILDING := Color("#b9a68c")
const BUILDING_ROOF := Color("#8a5f4a")
const TREE_TRUNK := Color("#5a4030")
const TREE_LEAF := Color("#3f7a35")
const FENCE := Color("#9a9a9a")

# 墙面立体感：墙顶（俯视能看到的那一面）比墙身亮，底座比墙身暗
const WALL_CAP := Color("#5c4b3c")
const WALL_BASE := Color("#2b231c")
## 后墙立面专用（比左右墙略亮，读作"被光照到的墙面"）
const WALL_FACE := Color("#7a6349")

# 角色
const PLAYER_BODY := Color("#3f6fb5")
const PLAYER_HEAD := Color("#e8c39e")
const PLAYER_HAIR := Color("#2b2b33")
const NPC_BODY := Color("#b56f4a")
const NPC_HEAD := Color("#e8c39e")

# UI
const UI_PANEL := Color("#12131c")
const UI_BORDER := Color("#dbd6a8")
const UI_TEXT := Color("#f2efe0")
const UI_DIM := Color("#9a9788")
