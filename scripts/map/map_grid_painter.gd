class_name MapGridPainter
extends Node2D
## ⚠️ **已被取代，当前没有任何场景引用它**（2026-09-18，只被 MapBuilder 用）。
## 地图改成图块层后不再需要"在地上画参考网格"。确认不需要后可随 map_builder.gd 一起删。
##
## 只负责画地板网格线的辅助节点（MapBuilder 内部使用）。
##
## 单独拆出来是因为 Node2D.draw_line 仅在 _draw() 内有效，
## 而 MapBuilder 的构建代码是即时执行的普通函数。

var rect: Rect2 = Rect2()
var tile: float = 32.0
var line_color: Color = Color(1, 1, 1, 0.05)


func _draw() -> void:
	if rect.size == Vector2.ZERO:
		return
	var x := rect.position.x
	while x <= rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), line_color, 1.0)
		x += tile
	var y := rect.position.y
	while y <= rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), line_color, 1.0)
		y += tile
