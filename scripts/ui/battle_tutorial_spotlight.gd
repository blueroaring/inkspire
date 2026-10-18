class_name BattleTutorialSpotlight
extends CanvasLayer
## 只让高亮区域接收鼠标；rect 使用战斗界面的 1920×1080 坐标。

const SCREEN := Vector2(1920, 1080)
var _root: Control
var _focus: Rect2

func _ready() -> void:
	layer = 90
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	get_viewport().size_changed.connect(_redraw)
	_redraw()

func focus(rect: Rect2) -> void:
	_focus = rect
	if is_inside_tree():
		_redraw()

func _redraw() -> void:
	if not is_instance_valid(_root):
		return
	for child in _root.get_children():
		child.queue_free()
	var viewport := get_viewport().get_visible_rect().size
	_root.size = viewport
	var scale: float = minf(viewport.x / SCREEN.x, viewport.y / SCREEN.y)
	var origin := (viewport - SCREEN * scale) * 0.5
	var hole := Rect2(origin + _focus.position * scale, _focus.size * scale).intersection(Rect2(Vector2.ZERO, viewport))
	if hole.size.x <= 0 or hole.size.y <= 0:
		_add_shade(Rect2(Vector2.ZERO, viewport))
		return
	_add_shade(Rect2(Vector2.ZERO, Vector2(viewport.x, hole.position.y)))
	_add_shade(Rect2(Vector2(0, hole.end.y), Vector2(viewport.x, viewport.y - hole.end.y)))
	_add_shade(Rect2(Vector2(0, hole.position.y), Vector2(hole.position.x, hole.size.y)))
	_add_shade(Rect2(Vector2(hole.end.x, hole.position.y), Vector2(viewport.x - hole.end.x, hole.size.y)))
	var border := Panel.new()
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiKit.panel_style(Color.TRANSPARENT, Color("#ffe08b"), 5, 8)
	style.draw_center = false
	border.add_theme_stylebox_override("panel", style)
	_root.add_child(border)
	border.position = hole.position
	border.size = hole.size

func _add_shade(rect: Rect2) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.06, 0.76)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)
	shade.position = rect.position
	shade.size = rect.size
