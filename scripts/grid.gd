class_name Grid
extends RefCounted
## 全项目唯一的"瓦片尺寸"来源。
##
## 需求里暂时不锁分辨率与瓦片规格（用户选择"先不锁，以后再定"），
## 所以所有地图尺寸、坐标、房间大小都必须走这里换算，禁止在场景脚本里写死像素数。
## 将来定下 16px 或 32px 时，只改 TILE 一处；若改用 TileMapLayer，本文件随之废弃。

## 一个瓦片的边长（像素）
const TILE := 32

## TileSet 里一个图块的边长（像素）。
## ⚠️ 项目里现在有**两套格子**，混用会整张图错位一半：
##   · TILE  = 32 逻辑格 —— MapData / 相机 / 出生点 / 房间尺寸用它
##   · CELL  = 16 图块格 —— TileMapLayer 用的一律是这个（Room_Builder 原生 16px）
## 换算只走 tile_to_cell() / cell_to_tile() / rect_to_cells()，不要在场景里写 *2 / /2。
const CELL := 16

## 一个逻辑格里有多少个图块（边长方向）
const CELLS_PER_TILE := TILE / CELL

## 房间尺寸约定（以瓦片为单位）
const DORM_SIZE := Vector2i(20, 14)
const CAMPUS_SIZE := Vector2i(48, 34)


## 瓦片坐标 -> 像素坐标（返回瓦片中心）
static func tile_to_px(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE + TILE * 0.5, tile.y * TILE + TILE * 0.5)


## 像素坐标 -> 瓦片坐标
static func px_to_tile(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


## 以瓦片为单位的长宽 -> 像素尺寸
static func size_to_px(size_tiles: Vector2i) -> Vector2:
	return Vector2(size_tiles.x * TILE, size_tiles.y * TILE)


# ------------------------------------------------------------------ 逻辑格 <-> 图块格


## 逻辑格坐标 -> 图块坐标（该逻辑格左上角的那一格图块）
static func tile_to_cell(tile: Vector2i) -> Vector2i:
	return tile * CELLS_PER_TILE


## 图块坐标 -> 逻辑格坐标（向下取整：图块落在哪个逻辑格里）
static func cell_to_tile(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CELLS_PER_TILE), floori(float(cell.y) / CELLS_PER_TILE))


## 世界像素矩形 -> 图块矩形（四边都对齐到图块；用于把像素写的布局喂给 TileMapLayer）
static func rect_to_cells(rect: Rect2) -> Rect2i:
	var x0 := floori(rect.position.x / CELL)
	var y0 := floori(rect.position.y / CELL)
	var x1 := ceili(rect.end.x / CELL)
	var y1 := ceili(rect.end.y / CELL)
	return Rect2i(x0, y0, maxi(1, x1 - x0), maxi(1, y1 - y0))


## 图块坐标 -> 该图块左上角的世界像素
static func cell_to_px(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x * CELL), float(cell.y * CELL))


## 图块矩形 -> 世界像素矩形
static func cells_to_rect(rect: Rect2i) -> Rect2:
	return Rect2(cell_to_px(rect.position), Vector2(float(rect.size.x * CELL), float(rect.size.y * CELL)))
