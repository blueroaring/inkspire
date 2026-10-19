extends Control
## Read-only relationship diagram, derived from the live combat data table.
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const THEME := preload("res://scripts/ui/battle_theme.gd")
const HINT := preload("res://scripts/ui/battle_attribute_hint.gd")
const NODE_SIZE := Vector2(132, 88)
var selected_attribute := "chinese"
var edges: Array[Dictionary] = []
var _nodes: Dictionary = {}
var _centers: Dictionary = {}
var _details: Panel

func _ready() -> void:
	if preload("res://scripts/ui/tower_mobile.gd").enabled():
		_mobile_chart()
		return
	name = "AttributeChart"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var graph := V.panel(self, Rect2(0, 0, 976, 600), THEME.SURFACE, Color(THEME.LINE, 0.55), 6)
	V.text(graph, "五科克制关系", Rect2(28, 18, 480, 40), 27, THEME.TEXT)
	V.text(graph, "点击学科，突出它的四条关系箭头", Rect2(30, 65, 710, 28), 18, THEME.MUTED)
	var attributes: Array = FightData.ADVANTAGE.keys()
	for i in attributes.size():
		var angle := -PI / 2.0 + TAU * i / attributes.size()
		_centers[attributes[i]] = Vector2(488, 338) + Vector2(cos(angle) * 338, sin(angle) * 190)
	# Draw all connectors before the nodes so every arrow ends outside its card.
	for source in attributes:
		for target in FightData.ADVANTAGE[source]:
			var direction: Vector2 = (_centers[target] - _centers[source]).normalized()
			var inset := minf((NODE_SIZE.x / 2 + 12) / maxf(absf(direction.x), 0.001), (NODE_SIZE.y / 2 + 12) / maxf(absf(direction.y), 0.001))
			var start: Vector2 = _centers[source] + direction * inset
			var end: Vector2 = _centers[target] - direction * inset
			var line := Line2D.new()
			line.name = "Relation_%s_%s" % [source, target]
			line.points = PackedVector2Array([start, end - direction * 9])
			line.antialiased = true
			graph.add_child(line)
			var tip := Polygon2D.new()
			var normal := direction.orthogonal()
			tip.polygon = PackedVector2Array([end, end - direction * 17 + normal * 7, end - direction * 17 - normal * 7])
			graph.add_child(tip)
			edges.append({"source":source, "target":target, "line":line, "tip":tip})
	for attribute in attributes:
		var button := Button.new()
		button.name = "AttributeNode_" + attribute
		button.position = _centers[attribute] - NODE_SIZE / 2
		button.size = NODE_SIZE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = "查看%s的克制关系" % FightData.attr_name(attribute)
		button.add_theme_stylebox_override("hover", THEME.frame(THEME.HOVER, THEME.GOLD, 2, 7))
		button.add_theme_stylebox_override("pressed", THEME.frame(THEME.SELECTED, THEME.GOLD, 2, 7))
		var focus := THEME.frame(Color.TRANSPARENT, THEME.GOLD, 2, 7)
		focus.draw_center = false
		button.add_theme_stylebox_override("focus", focus)
		graph.add_child(button)
		HINT.icon(button, attribute, Rect2(45, 7, 42, 42))
		V.text(button, FightData.attr_name(attribute), Rect2(8, 52, 116, 28), 22, THEME.TEXT, true)
		button.pressed.connect(func() -> void: select_attribute(attribute))
		_nodes[attribute] = button
	_details = V.panel(self, Rect2(1000, 0, 544, 600), THEME.SURFACE, Color(THEME.LINE, 0.55), 6)
	select_attribute(selected_attribute)

func select_attribute(attribute: String) -> void:
	if not FightData.ADVANTAGE.has(attribute): return
	selected_attribute = attribute
	for edge in edges:
		var active: bool = edge.source == attribute or edge.target == attribute
		var tint := THEME.GREEN if edge.source == attribute else THEME.RED if edge.target == attribute else Color(THEME.LINE, 0.23)
		edge.line.default_color = tint
		edge.line.width = 3.5 if active else 1.6
		edge.line.z_index = 1 if active else 0
		edge.tip.color = tint
		edge.tip.z_index = 1 if active else 0
	for key in _nodes:
		var border := THEME.GOLD if key == attribute else THEME.GREEN if FightData.has_advantage(attribute, key) else THEME.RED
		_nodes[key].add_theme_stylebox_override("normal", THEME.frame(THEME.HOVER if key == attribute else THEME.SURFACE, border, 3 if key == attribute else 1, 7))
	for child in _details.get_children():
		if child.name != "SurfaceArt":
			_details.remove_child(child)
			child.queue_free()
	HINT.icon(_details, attribute, Rect2(26, 22, 48, 48))
	V.text(_details, "从%s出手" % FightData.attr_name(attribute), Rect2(88, 22, 410, 43), 28, THEME.TEXT)
	V.text(_details, "箭头指向被克制的一方", Rect2(28, 76, 488, 28), 18, THEME.MUTED)
	V.text(_details, "克制  +50%", Rect2(28, 124, 488, 34), 23, THEME.GREEN)
	var targets: Array = FightData.ADVANTAGE[attribute]
	for i in targets.size(): _matchup_row(attribute, targets[i], 166 + i * 52, THEME.GREEN, "+50%")
	V.text(_details, "被克制  −50%", Rect2(28, 284, 488, 34), 23, THEME.RED)
	var incoming: Array = []
	for source in FightData.ADVANTAGE:
		if FightData.has_advantage(source, attribute): incoming.append(source)
	for i in incoming.size(): _matchup_row(attribute, incoming[i], 326 + i * 52, THEME.RED, "−50%")
	V.text(_details, "左图：绿箭头向外，红箭头指向当前学科", Rect2(28, 440, 490, 30), 17, THEME.MUTED)
	var neutral := V.panel(_details, Rect2(24, 487, 496, 90), THEME.RECESSED, Color(THEME.LINE, 0.5), 4)
	HINT.icon(neutral, "none", Rect2(14, 19, 48, 48))
	V.text(neutral, "无极不克制，也不被克制", Rect2(76, 12, 400, 30), 21, THEME.TEXT)
	V.text(neutral, "同属性之间也无克制修正", Rect2(76, 47, 400, 26), 17, THEME.MUTED)

func _matchup_row(source: String, target: String, y: float, tint: Color, modifier: String) -> void:
	HINT.icon(_details, source, Rect2(30, y + 5, 32, 32))
	V.text(_details, FightData.attr_name(source), Rect2(72, y, 70, 42), 20, THEME.TEXT)
	V.text(_details, "攻击 →", Rect2(143, y, 100, 42), 18, THEME.MUTED, true)
	HINT.icon(_details, target, Rect2(256, y + 5, 32, 32))
	V.text(_details, FightData.attr_name(target), Rect2(298, y, 74, 42), 20, THEME.TEXT)
	V.text(_details, modifier, Rect2(390, y, 120, 42), 23, tint, true)

func _mobile_chart() -> void:
	var pages := preload("res://scripts/ui/tower_mobile_pages.gd")
	var scroll := ScrollContainer.new()
	scroll.size = size if size.x > 0 else Vector2(1544, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 24)
	scroll.add_child(rows)
	pages.text(rows, "属性克制 · 造成伤害 +50%，被克制 −50%", 42)
	pages.text(rows, "无极与同属性之间均无克制修正。")
	for attribute in FightData.ADVANTAGE:
		var targets := PackedStringArray()
		var sources := PackedStringArray()
		for target in FightData.ADVANTAGE[attribute]: targets.append(FightData.attr_name(target))
		for source in FightData.ADVANTAGE:
			if FightData.has_advantage(source, attribute): sources.append(FightData.attr_name(source))
		pages.text(rows, "%s\n克制：%s\n被克制：%s" % [FightData.attr_name(attribute), " / ".join(targets), " / ".join(sources)])
