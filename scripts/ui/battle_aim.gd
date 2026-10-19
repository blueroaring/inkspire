extends Node2D
## A bounded, pointer-transparent aiming overlay in the battle's 1920x1080 space.
var origin := Vector2.ZERO
var pointer := Vector2.ZERO
var target := Rect2()
var targets: Array[Rect2] = []
var accent := Color("f1c785")
var held := false
var clock := 0.0
var preview: Panel
var title: Label
var hint: Label
var icon: TextureRect
const VISUALS := preload("res://scripts/ui/fc_card_visuals.gd")
const THEME := preload("res://scripts/ui/battle_theme.gd")

func _ready() -> void:
	preview = preload("res://scripts/ui/battle_preview_plate.gd").new()
	preview.kind = "drag"
	preview.size = Vector2(284, 80)
	add_child(preview)
	preview.name = "DraggedSkill"
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon = VISUALS.icon(preview, null, Rect2(13, 11, 58, 58))
	title = VISUALS.text(preview, "", Rect2(94, 10, 174, 32), 22, THEME.TEXT)
	title.add_theme_font_override("font", THEME.HEADING)
	hint = VISUALS.text(preview, "", Rect2(94, 44, 174, 25), 16, THEME.MUTED)

func set_skill(card: Dictionary) -> void:
	var id := String(card.get("skill_id", ""))
	icon.texture = FightData.skill_icon(id)
	title.text = String(FightData.skill(id).get("name", "选择目标"))
	var owner := FightSystem.caster_index(card)
	if owner >= 0:
		accent = preload("res://scripts/data/battle_art.gd").accent(preload("res://scripts/data/battle_art.gd").module(FightSystem.allies[owner]))
		var unit: Dictionary = FightSystem.allies[owner]
		var identity := THEME.identity(String(unit.id), String(unit.attribute))
		preview.fill = identity.fill.lerp(Color("e3dccc"), 0.35)
		preview.accent = identity.edge
		preview.family = identity.motif
		THEME.material_identity(preview, identity)
		preview.queue_redraw()

func _process(delta: float) -> void:
	if not visible: return
	clock += delta
	preview.visible = held
	var top := pointer.y-preview.size.y-24
	if target.has_area() and target.size.y > 200:
		# The enemy forecast sits above its HP/name. Keep the held ticket clear of it.
		var forecast_top := target.end.y-(202 if target.size.y >= 300 else 154)
		top = minf(top, forecast_top-preview.size.y-12)
	preview.position = Vector2(clampf(pointer.x + 26, 12, 1920-preview.size.x-12), clampf(top, 12, 1080-preview.size.y-12))
	hint.text = ("点目标确认 · 可取消选取" if preload("res://scripts/ui/tower_mobile.gd").enabled() else "松手释放" if target.has_area() else "拖向目标 · 右键取消")
	hint.add_theme_color_override("font_color", THEME.GREEN if target.has_area() else THEME.MUTED)
	queue_redraw()

func _curve(t: float, end: Vector2) -> Vector2:
	var bend := origin.lerp(end, 0.5) + Vector2(0, -minf(150, origin.distance_to(end) * 0.22))
	return origin.bezier_interpolate(bend, bend, end, t)

func _draw() -> void:
	for rect in targets:
		_corners(rect.grow(5), Color(accent, 0.22), 13, 1.5)
	var locked := target.has_area()
	var end := target.get_center() if locked else pointer
	var color := accent if locked else accent.lerp(Color("91a6bf"), 0.45)
	if origin.distance_to(end) < 18: return
	var points := PackedVector2Array()
	for i in 37: points.append(_curve(float(i) / 36.0, end))
	draw_polyline(points, Color(color, 0.09), 16, true)
	draw_polyline(points, Color(color, 0.32), 6, true)
	draw_polyline(points, Color(color, 0.9), 2.3, true)
	for i in 5:
		var t := fposmod(clock * 0.8 + i * 0.2, 1.0)
		draw_circle(_curve(t, end), 2.0 + t * 2.4, Color(color, t * 0.8), true, -1, true)
	var direction := (end - _curve(0.96, end)).normalized()
	var normal := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([end + direction * 9, end - direction * 17 + normal * 9, end - direction * 10, end - direction * 17 - normal * 9]), color)
	draw_arc(origin, 12, clock, clock + TAU * 0.8, 30, Color(color, 0.7), 2, true)
	if locked:
		var pulse := 0.75 + sin(clock * 8) * 0.25
		_corners(target.grow(6 + pulse * 3), Color(color, 0.9), 26, 3)
		var radius := minf(target.size.x, target.size.y) * 0.19
		for i in 4:
			var angle := clock * 0.6 + i * PI * 0.5
			draw_arc(end, radius, angle, angle + 0.75, 12, Color(color, 0.8), 2, true)
		draw_circle(end, 5, Color("fff1d5"), true, -1, true)

func _corners(rect: Rect2, color: Color, length: float, width: float) -> void:
	for uv in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2.ONE]:
		var corner: Vector2 = rect.position + rect.size * uv
		var inward: Vector2 = Vector2.ONE - uv * 2
		draw_polyline(PackedVector2Array([corner + Vector2(inward.x * length, 0), corner, corner + Vector2(0, inward.y * length)]), color, width, true)
