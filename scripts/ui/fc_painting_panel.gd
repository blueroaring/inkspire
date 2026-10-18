extends Control
## A living scroll; all region edits remain local until the player confirms.
const P := preload("res://scripts/fight/fc_painting.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const T := preload("res://scripts/ui/battle_theme.gd")
const CANVAS := preload("res://scripts/ui/painting_canvas.gd")
const SHORT_NAMES := {"white":"洗去", "ink":"落墨", "red":"朱砂", "yellow":"藤黄", "blue":"石青", "rainbow":"彩色"}
var inspect_only := false
var choice: Dictionary = {}
var edits: Dictionary = {}
var active_region := -1
var regions: Array[Button] = []
var color_buttons: Array[Button] = []
var summary: Label
var confirm: Button
var instructions: Label
var canvas: Control
var _metrics: Array[Label] = []
var _selection: Label
var _undo: Button
var _footer: Label

func _ready() -> void:
	name = "PaintingPanel"
	size = Vector2(1920, 1080)
	z_index = 96
	T.apply(self)
	choice = {"title":"未完的画作", "canvas":FightSystem.fc.painting.duplicate(), "regions":[], "colors":[], "min":0, "max":0} if inspect_only else FightSystem.fc.choice.duplicate(true)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.045, 0.045, 0.84)
	shade.size = size
	add_child(shade)
	var paper := V.panel(self, Rect2(204, 88, 1512, 904), Color("e8dec8"), Color("b49b6a"), 7)
	paper.name = "PaintingDesk"
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	V.panel(paper, Rect2(24, 20, 1464, 864), Color.TRANSPARENT, Color("ac936b", 0.48), 2)
	V.text(paper, "刘丹雅  /  画中丹青", Rect2(48, 27, 1000, 32), 19, Color("936347"))
	var title_parts := String(choice.title).split("：", true, 1)
	var title := V.text(paper, title_parts[0], Rect2(46, 66, 1170, 58), 39, Color("34443f"))
	title.add_theme_font_override("font", T.HEADING)
	instructions = V.text(paper, "墨与色落在同一张纸上，留白亦是画的一部分。" if inspect_only else title_parts[1] if title_parts.size() > 1 else "选择区域，再取色落笔。", Rect2(48, 132, 1190, 38), 22, Color("716754"))
	V.icon(paper, load(FightData.hero("liudanya").portrait), Rect2(1290, 30, 112, 124))
	var seal := V.panel(paper, Rect2(1414, 49, 50, 80), Color("a14e3d"), Color("823c31"), 2)
	V.text(seal, "丹\n青", Rect2(0, 4, 50, 72), 24, Color("fff0d1"), true).add_theme_font_override("font", T.HEADING)
	V.panel(paper, Rect2(42, 188, 960, 582), Color("3d5350"), Color("8e7852"), 3)
	canvas = CANVAS.new()
	canvas.name = "LivingPaintingCanvas"
	canvas.position = Vector2(52, 198)
	canvas.size = Vector2(940, 562)
	canvas.region_pressed.connect(_select_region)
	paper.add_child(canvas)
	regions = canvas.regions
	var rail := V.panel(paper, Rect2(1022, 188, 446, 582), Color("dcd3bd"), Color("b2a17f"), 4)
	V.text(rail, "构图预览" if not inspect_only else "当前构图", Rect2(22, 16, 402, 34), 23, Color("3d5350")).add_theme_font_override("font", T.HEADING)
	for i in 2:
		var metric := V.panel(rail, Rect2(22+i*210, 62, 192, 115), Color("eee5d0"), Color("b3a17d"), 3)
		V.text(metric, "水墨组" if i == 0 else "三色组", Rect2(12, 8, 168, 26), 18, Color("76684e"))
		_metrics.append(V.text(metric, "", Rect2(12, 33, 168, 44), 35, Color("3c554e") if i == 0 else Color("a55340")))
		V.text(metric, "白 ＋ 墨" if i == 0 else "红 ＋ 黄 ＋ 蓝", Rect2(12, 82, 168, 24), 16, Color("7e7058"))
	if inspect_only:
		V.text(rail, "画面颜色", Rect2(24, 206, 398, 38), 25, Color("8b4a3e")).add_theme_font_override("font", T.HEADING)
		for i in P.COLORS.size():
			var color: String = P.COLORS[i]
			var at := Vector2(26+(i%2)*210, 264+(i/2)*82)
			_well(rail, at, color, 28)
			V.text(rail, P.NAMES[color], Rect2(at+Vector2(38, 0), Vector2(86, 28)), 19, Color("5f6556"))
		V.text(rail, "彩色可替代原色，优先补齐三色组。", Rect2(24, 530, 400, 30), 18, Color("807055"))
	else:
		V.text(rail, "取色落笔", Rect2(24, 199, 398, 34), 23, Color("3c554e")).add_theme_font_override("font", T.HEADING)
		for i in choice.colors.size():
			var color: String = choice.colors[i]
			var b := Button.new()
			b.name = "PaintColor_" + color
			b.position = Vector2(22+(i%2)*210, 245+(i/2)*70)
			b.size = Vector2(192, 58)
			b.tooltip_text = "洗去所选区域，恢复留白" if color == "white" else "将所选区域染为" + String(P.NAMES[color])
			_paper_button(b)
			b.pressed.connect(_paint.bind(color))
			rail.add_child(b)
			_well(b, Vector2(14, 12), color, 34)
			V.text(b, SHORT_NAMES[color], Rect2(62, 0, 120, 58), 22, Color("3b4f46"))
			color_buttons.append(b)
		_selection = V.text(rail, "先选择画面中的一处区域", Rect2(24, 468, 398, 35), 20, Color("7e634a"))
		_undo = Button.new()
		_undo.name = "UndoPaintRegion"
		_undo.position = Vector2(22, 517)
		_undo.size = Vector2(402, 44)
		_undo.text = "撤回当前区域"
		_paper_button(_undo)
		_undo.pressed.connect(func() -> void: edits.erase(active_region); _update())
		rail.add_child(_undo)
	summary = V.text(paper, "", Rect2(48, 787, 960, 36), 22, Color("3e6051"))
	_footer = V.text(paper, "", Rect2(48, 835, 960, 32), 18, Color("887554"))
	confirm = Button.new()
	confirm.name = "ConfirmPainting"
	confirm.position = Vector2(1050, 808)
	confirm.size = Vector2(418, 62)
	_paper_button(confirm, true)
	confirm.add_theme_font_size_override("font_size", 24)
	confirm.pressed.connect(func() -> void:
		if inspect_only: queue_free()
		else: FightSystem.choose_painting(edits)
	)
	paper.add_child(confirm)
	_update(false)
	paper.modulate.a = 0.0
	paper.position.y += 12
	var arrival := paper.create_tween().set_parallel(true)
	arrival.tween_property(paper, "modulate:a", 1.0, 0.18)
	arrival.tween_property(paper, "position:y", 88.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _well(parent: Control, at: Vector2, color: String, diameter: float) -> void:
	var well := V.panel(parent, Rect2(at-Vector2.ONE*3, Vector2.ONE*(diameter+6)), Color("e8dfc9"), Color("a69574"), roundi(diameter))
	V.panel(well, Rect2(4, 4, diameter-2, diameter-2), P.TINTS[color], Color("736b59", 0.5), roundi(diameter))
	V.panel(well, Rect2(diameter*0.28, diameter*0.2, diameter*0.32, 4), Color("fff5da", 0.3), Color.TRANSPARENT, 2)

func _paper_button(b: Button, primary: bool = false) -> void:
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", T.HEADING)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", T.frame(Color("a45440") if primary else Color("eee4ce"), Color("874c38") if primary else Color("b6a17b"), 1, 4))
	b.add_theme_stylebox_override("hover", T.frame(Color("ba624b") if primary else Color("f7eed9"), Color("b07e4c"), 2, 4))
	b.add_theme_stylebox_override("pressed", T.frame(Color("8e4435") if primary else Color("dac9a9"), Color("8f6143"), 2, 4))
	b.add_theme_stylebox_override("disabled", T.frame(Color("c7bea9"), Color("b1a588"), 1, 4))
	b.add_theme_stylebox_override("focus", T.frame(Color.TRANSPARENT, Color("ad7040"), 2, 4))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(state, Color("fff0d4") if primary else Color("4a584b"))
	b.add_theme_color_override("font_disabled_color", Color("837d6b"))

func _select_region(index: int) -> void:
	if inspect_only or not choice.regions.has(index): return
	active_region = index
	if choice.colors.size() == 1: _paint(String(choice.colors[0]))
	else: _update()

func _paint(color: String) -> void:
	if active_region < 0 or not choice.regions.has(active_region): return
	if not edits.has(active_region) and edits.size() >= int(choice.max):
		instructions.text = "已达到区域上限，可修改已选区域，或先撤回一处。"
		return
	edits[active_region] = color
	_update()

func _update(animate: bool = true) -> void:
	if not inspect_only:
		var title_parts := String(choice.title).split("：", true, 1)
		instructions.text = title_parts[1] if title_parts.size() > 1 else "选择区域，再取色落笔。"
	var preview: Array = choice.canvas.duplicate()
	for index in edits:
		if edits[index] != "white" or not bool(choice.get("preserve_wash", false)): preview[index] = edits[index]
	var before := P.groups(choice.canvas)
	var g := P.groups(preview)
	canvas.set_canvas(preview, active_region, edits, choice.regions, animate)
	for i in 2:
		var key: String = ["ink", "tri"][i]
		_metrics[i].text = "%d → %d" % [before[key].size(), g[key].size()] if before[key].size() != g[key].size() else "%d 组" % g[key].size()
	for b in color_buttons:
		b.disabled = active_region < 0
		b.modulate.a = 0.5 if b.disabled else 1.0
	if is_instance_valid(_undo):
		_undo.disabled = not edits.has(active_region)
		_selection.text = "先选择画面中的一处区域" if active_region < 0 else "区域 %02d  ·  %s%s" % [active_region+1, P.NAMES[preview[active_region]], "  ·  已选" if edits.has(active_region) else ""]
	var requirement := str(choice.min) if choice.min == choice.max else "%d–%d" % [choice.min, choice.max]
	summary.text = "水墨 %d 组    三色 %d 组" % [g.ink.size(), g.tri.size()]
	if bool(choice.get("draw_groups", false)): summary.text += "    完成后抽 %d 张牌" % [g.ink.size()+g.tri.size()]
	elif not inspect_only: summary.text += "    已选 %d / %s 处" % [edits.size(), requirement]
	_footer.text = "每处只计入一组 · 画面标记显示所属分组" if inspect_only else "已选 %d 处 · 未操作的区域保持原样，确认后统一落笔" % edits.size()
	if bool(choice.get("preserve_wash", false)): _footer.text = "素描生效：本次洗去会保留原色；染色正常生效。"
	confirm.text = "收起画作" if inspect_only else "保留原画并确认" if edits.is_empty() and int(choice.min) == 0 else "确认落笔  ·  %d 处" % edits.size()
	confirm.disabled = not inspect_only and edits.size() < int(choice.min)

func _unhandled_input(event: InputEvent) -> void:
	if inspect_only and event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
