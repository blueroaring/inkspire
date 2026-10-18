extends Control
## Battle-only art direction. All decoration ignores input and preserves layout bounds.
const THEME := preload("res://scripts/ui/battle_theme.gd")
const MOTIF := preload("res://scripts/ui/battle_frame_motif.gd")
const GOLD := THEME.TRIM
const PAPER := THEME.SURFACE
const IVORY := THEME.INK
const INK := THEME.TEXT
const BRASS := THEME.GOLD
const SELECTED := THEME.SELECTED
var kind := "ticket"
var accent := Color("9ebcda")
var amount := 0.0
var active := false
var hovered := false
var disabled := false
var downed := false
var clock := 0.0
var lift := 0.0
var temporary := false
var identity: Dictionary = {}
var _surface: Control

func _face() -> Color:
	return identity.get("fill", PAPER)

func _edge() -> Color:
	return identity.get("edge", THEME.quiet(accent))

func _motif(center: Vector2, radius: float, tint: Color) -> void:
	MOTIF.draw_mark(self, String(identity.get("motif", "orbit")), center, radius, tint)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_surface = THEME.decorate(self, accent, true)
	if get_parent() is BaseButton:
		var button := get_parent() as BaseButton
		button.mouse_entered.connect(func() -> void: hovered = true; set_process(true))
		button.mouse_exited.connect(func() -> void: hovered = false; set_process(true))
		button.draw.connect(queue_redraw)
		button.button_down.connect(queue_redraw)
		button.button_up.connect(queue_redraw)
		button.focus_entered.connect(queue_redraw)
		button.focus_exited.connect(queue_redraw)
	set_process(active)

func _process(delta: float) -> void:
	clock += delta
	lift = move_toward(lift, 1.0 if hovered else 0.0, delta * 8)
	if kind == "ticket" and get_parent() is Button:
		(get_parent() as Button).scale = Vector2(1.0 + lift * 0.023, 1.0)
	queue_redraw()
	if not active and not hovered and lift <= 0: set_process(false)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if is_instance_valid(_surface):
		_surface.visible = kind in ["ticket", "ally", "utility", "turn", "guard_badge", "guard_personal", "energy"]
		_surface.profile = kind
		_surface.family = String(identity.get("motif", "quill" if kind == "turn" else "paper"))
		_surface.accent = accent
		_surface.ornate = kind in ["ticket", "ally", "turn"]
		_surface.modulate.a = 0.55 if disabled else 1.0
		_surface.queue_redraw()
	match kind:
		"ticket": _ticket(w, h)
		"ally": _ally(w, h)
		"guard_frame": _guard_frame(w, h)
		"guard_badge", "guard_personal": _guard_badge(w, h)
		"utility": _utility(w, h)
		"energy": _energy(w, h)
		"ultimate": _ultimate(w, h)
		"turn": _turn(w, h)
		"header": _header(w, h)
		"stage": _stage(w, h)

func _shape(points: Array[Vector2], fill: Color, edge: Color = Color.TRANSPARENT, width: float = 1) -> void:
	var packed := PackedVector2Array(points)
	draw_colored_polygon(packed, fill)
	if edge.a > 0:
		packed.append(packed[0])
		draw_polyline(packed, edge, width, true)

func _diamond(center: Vector2, radius: float, color: Color) -> void:
	_shape([center + Vector2(0, -radius), center + Vector2(radius * 0.6, 0), center + Vector2(0, radius), center + Vector2(-radius * 0.6, 0)], color)

func _ring(center: Vector2, radius: float, color: Color, spin: float = 0.0) -> void:
	draw_arc(center, radius, 0, TAU, 80, Color(color, 0.6), 1, true)
	draw_arc(center, radius - 4, spin + 0.15, spin + PI * 0.73, 32, color, 2, true)
	draw_arc(center, radius - 4, spin + PI + 0.15, spin + PI * 1.73, 32, color, 2, true)
	for i in 12:
		var direction := Vector2.from_angle(i * TAU / 12.0 + spin)
		draw_line(center + direction * (radius + 3), center + direction * (radius + (7 if i % 3 == 0 else 5)), Color(color, 0.7), 1, true)

func _ticket(w: float, h: float) -> void:
	var tint := THEME.LINE if disabled else accent
	var paper := THEME.INK if disabled else _face().lerp(THEME.HOVER, lift * 0.22)
	var outline := _edge() if hovered or active else Color(_edge(), 0.7)
	# The diagonal end and the dark binding make the row a physical card tab.
	_shape([Vector2(12, 4), Vector2(w - 17, 4), Vector2(w, h * 0.5 + 4), Vector2(w - 17, h + 4), Vector2(12, h + 4), Vector2(0, h * 0.5 + 4)], Color(0.015, 0.02, 0.04, 0.28))
	_shape([Vector2(12, 0), Vector2(w - 18, 0), Vector2(w, h * 0.5), Vector2(w - 18, h), Vector2(12, h), Vector2(0, h * 0.5)], paper, outline, 1.5)
	for y in range(2, int(h) - 2):
		var shade := float(y) / h
		draw_line(Vector2(14, y), Vector2(w - 19, y), Color(tint if shade < 0.5 else THEME.RECESSED, absf(shade - 0.5) * (0.12 if shade < 0.5 else 0.25)), 1)
	for i in 9:
		var x := 117.0 + i * 26.0
		draw_line(Vector2(x, 7), Vector2(x + 15, 7), Color(tint, 0.10), 1)
	_shape([Vector2(12, 0), Vector2(99, 0), Vector2(84, h), Vector2(12, h), Vector2(0, h * 0.5)], paper.lerp(tint, 0.23))
	_shape([Vector2(w - 59, 0), Vector2(w - 18, 0), Vector2(w, h * 0.5), Vector2(w - 18, h), Vector2(w - 74, h)], paper.lerp(tint, 0.32))
	draw_line(Vector2(98, 2), Vector2(85, h - 2), tint, 2, true)
	draw_line(Vector2(110, h - 4), Vector2(w - 88, h - 4), Color(tint, 0.22), 1, true)
	draw_line(Vector2(108, 3), Vector2(w - 71, 3), Color(tint, 0.40), 1, true)
	for i in 3: _diamond(Vector2(w - 64 + i * 7, 8), 2.4, Color(tint, 0.65))
	# Interlocking enamel and metal rails frame the name without outlining the text.
	draw_polyline(PackedVector2Array([Vector2(15, 3), Vector2(97, 3), Vector2(83, h - 3), Vector2(15, h - 3)]), Color(THEME.TRIM, 0.65), 1, true)
	draw_polyline(PackedVector2Array([Vector2(w - 19, 5), Vector2(w - 5, h * 0.5), Vector2(w - 19, h - 5)]), Color(THEME.TRIM, 0.65), 1, true)
	_motif(Vector2(w - 77, h * 0.5), 8, Color(_edge(), 0.8))
	if not disabled and (active or lift > 0):
		draw_line(Vector2(104, h - 1), Vector2(w - 78, h - 1), Color(tint, 0.6 + lift * 0.4), 3, true)
		_diamond(Vector2(w - 12, h * 0.5), 6 + lift * 2, tint)
		if active:
			var glint := 109 + fposmod(clock * 100, w - 200)
			_diamond(Vector2(glint, h - 2), 3, Color(THEME.GOLD, 0.85))

func _ally(w: float, h: float) -> void:
	var edge := THEME.LINE if disabled else THEME.RED if downed else _edge()
	var stock := THEME.INK if disabled else _face().lerp(THEME.RED, 0.18) if downed else _face()
	stock = stock.lerp(SELECTED, lift * 0.35)
	_shape([Vector2(0, 13), Vector2(13, 0), Vector2(w - 13, 0), Vector2(w, 13), Vector2(w, h - 13), Vector2(w - 13, h), Vector2(13, h), Vector2(0, h - 13)], stock, Color(edge, 0.48), 1)
	# Coloured satin, inset lines and corner inlays preserve the frame craft.
	for y in range(2, int(h) - 2):
		var inset := maxf(2, 14 - minf(y, h - y))
		var sheen := pow(1.0 - float(y) / h, 2)
		draw_line(Vector2(inset, y), Vector2(w - inset, y), Color(accent, sheen * 0.07), 1)
	for x in range(5, 115):
		draw_line(Vector2(x, 38), Vector2(x, h - 14), Color(accent, sin(float(x - 5) / 110 * PI) * 0.08), 1)
	draw_arc(Vector2(58, 100), 54, -2.7, 1.1, 48, Color(edge, 0.16), 1, true)
	draw_arc(Vector2(58, 100), 49, 0.9, 3.0, 32, Color(edge, 0.1), 1, true)
	draw_line(Vector2(18, 36), Vector2(w - 22, 36), Color(edge, 0.22), 1, true)
	draw_line(Vector2(18, 2), Vector2(100, 2), Color(edge, 0.85), 2, true)
	draw_line(Vector2(18, h - 5), Vector2(w - 18, h - 5), Color(edge, 0.16), 1, true)
	for x in [8.0, w - 8]:
		draw_line(Vector2(x, 20), Vector2(x, 38), Color(edge, 0.7), 1, true)
	_motif(Vector2(w - 25, 20), 11, edge)
	MOTIF.draw_corner(self, String(identity.get("motif", "orbit")), Vector2(w - 6, h - 6), -Vector2.ONE, Color(edge, 0.75))
	draw_line(Vector2(102, 2), Vector2(w - 49, 2), Color(accent, 0.7), 2, true)
	if active and not disabled:
		var alpha := 0.32 + sin(clock * 3) * 0.12
		draw_line(Vector2(8, h - 2), Vector2(w - 18, h - 2), Color(edge, alpha + 0.3), 3, true)

func _guard_frame(w: float, h: float) -> void:
	# One quiet ward rail per layer; never stack two full boxes around the party.
	var y := 2.0 if temporary else h - 2.0
	var direction := 1.0 if temporary else -1.0
	var points := PackedVector2Array([Vector2(0, y + direction * 30), Vector2(0, y + direction * 12), Vector2(12, y), Vector2(w - 12, y), Vector2(w, y + direction * 12), Vector2(w, y + direction * 30)])
	draw_polyline(points, Color(accent, 0.035), 9, true)
	draw_polyline(points, Color(accent, 0.35), 1, true)
	for x in [16.0, w - 16]: _diamond(Vector2(x, y), 3, Color(accent, 0.8))

func _guard_badge(w: float, h: float) -> void:
	var tint := THEME.quiet(accent)
	_shape([Vector2(9, 1), Vector2(w - 8, 1), Vector2(w - 1, 8), Vector2(w - 1, h - 8), Vector2(w - 8, h - 1), Vector2(9, h - 1), Vector2(1, h - 9), Vector2(1, 9)], THEME.RECESSED, Color(tint, 0.35), 1)
	for y in range(3, int(h) - 3):
		draw_line(Vector2(10, y), Vector2(w - 10, y), Color(tint, 0.1 * pow(1.0 - float(y) / h, 2)), 1)
	draw_line(Vector2(11, 3), Vector2(w - 12, 3), Color(tint, 0.25), 1, true)
	var radius := 14.0 if kind == "guard_personal" else 18.0
	var c := Vector2(20 if kind == "guard_personal" else 24, h * 0.5)
	var crest: Array[Vector2] = [c + Vector2(0, -radius), c + Vector2(radius * 0.78, -radius * 0.55), c + Vector2(radius * 0.6, radius * 0.38), c + Vector2(0, radius), c + Vector2(-radius * 0.6, radius * 0.38), c + Vector2(-radius * 0.78, -radius * 0.55)]
	_shape(crest, tint.darkened(0.6), tint.lightened(0.2), 1.2)
	_shape([crest[0], crest[1], crest[3], c], Color(tint, 0.7))
	_shape([crest[0], c, crest[5]], tint.lightened(0.12))
	draw_line(c + Vector2(0, -radius + 3), c + Vector2(0, radius - 3), Color(THEME.TEXT, 0.5), 1, true)
	if temporary:
		draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), THEME.TEXT, 1.5, true)
		draw_line(c + Vector2(5, -5), c + Vector2(-5, 5), THEME.TEXT, 1.5, true)
	if amount > 0: _diamond(Vector2(w - 7, h * 0.5), 3, GOLD)

func _utility(w: float, h: float) -> void:
	var unavailable := _unavailable()
	var button := get_parent() as BaseButton
	var pressed := button != null and button.is_pressed() and not unavailable
	var focus := button != null and button.has_focus()
	var stock := IVORY if unavailable or pressed else PAPER.lerp(THEME.quiet(accent), 0.06 + lift * 0.10)
	_shape([Vector2(5, 0), Vector2(w, 0), Vector2(w, h - 5), Vector2(w - 5, h), Vector2(0, h), Vector2(0, 5)], Color(stock, 0.9), Color(BRASS if hovered or focus else THEME.LINE, 0.7 if focus else 0.3))
	var tint := THEME.LINE if unavailable else THEME.quiet(accent)
	draw_line(Vector2(10, 3), Vector2(w - 8, 3), Color(tint, 0.22), 1, true)
	_shape([Vector2(0, 5), Vector2(5, 0), Vector2(13, 0), Vector2(0, 13)], Color(tint, 0.65))
	draw_line(Vector2(8, h - 3), Vector2(25, h - 3), Color(tint, 0.65), 1, true)
	if not unavailable and (hovered or focus):
		draw_line(Vector2(10, h - 2), Vector2(w - 10, h - 2), Color(BRASS, 0.7), 1, true)

func _energy(w: float, h: float) -> void:
	_shape([Vector2(26, 7), Vector2(w - 8, 7), Vector2(w, 15), Vector2(w, h - 10), Vector2(w - 8, h - 2), Vector2(26, h - 2)], Color(IVORY, 0.96), Color(THEME.LINE, 0.4))
	var c := Vector2(29, h * 0.5)
	draw_circle(c, 27, IVORY)
	_ring(c, 28, Color(THEME.BLUE, 0.65))
	draw_arc(c, 27, 0, TAU, 64, Color(THEME.LINE, 0.4), 1, true)
	_shape([c + Vector2(0, -17), c + Vector2(10, 0), c + Vector2(0, 18), c + Vector2(-10, 0)], Color("4ea2bf"), THEME.BLUE)
	_shape([c + Vector2(0, -17), c + Vector2(0, 3), c + Vector2(-10, 0)], Color("8bd8d3"))
	_shape([c + Vector2(0, 3), c + Vector2(10, 0), c + Vector2(0, 18)], Color("396580"))
	draw_arc(c, 23, -PI * 0.5, -PI * 0.5 + TAU * maxf(0.002, amount), 64, THEME.BLUE, 2, true)

func _ultimate(w: float, _h: float) -> void:
	var center := Vector2(w * 0.5, w * 0.5)
	var radius := w * 0.5 - 7
	var tint := BRASS if active else THEME.quiet(accent)
	draw_circle(center, radius + 3, IVORY)
	_ring(center, radius + 3, Color(tint, 0.55), clock * 0.08 if active else 0)
	draw_arc(center, radius - 1, -PI * 0.5, -PI * 0.5 + TAU * maxf(0.002, amount), 64, Color(tint, 0.95 if active else 0.6), 2, true)
	if active:
		_diamond(center + Vector2(0, -radius - 5), 4, BRASS)

func _turn(w: float, h: float) -> void:
	var stock := IVORY if _unavailable() else Color("c5b28a").lerp(Color("d2bf97"), lift * 0.7)
	var edge := THEME.LINE if _unavailable() else BRASS
	_shape([Vector2(9, 0), Vector2(w - 9, 0), Vector2(w, 9), Vector2(w, h - 9), Vector2(w - 9, h), Vector2(0, h), Vector2(0, 9)], stock, Color(edge, 0.6), 1)
	draw_line(Vector2(25, h - 5), Vector2(w - 25, h - 5), Color(edge, 0.4), 1, true)

	_shape([Vector2(5, 12), Vector2(12, 5), Vector2(w - 12, 5), Vector2(w - 5, 12), Vector2(w - 5, h - 12), Vector2(w - 12, h - 5), Vector2(5, h - 5)], Color.TRANSPARENT, Color(edge, 0.22), 1)
	for x in [14.0, w - 14]: _diamond(Vector2(x, h * 0.5), 3, Color(edge, 0.65))

func _unavailable() -> bool:
	return disabled or (get_parent() is BaseButton and (get_parent() as BaseButton).disabled)

func _header(w: float, h: float) -> void:
	draw_line(Vector2(0, h - 8), Vector2(w, h - 8), Color(GOLD, 0.28), 1, true)
	_diamond(Vector2(0, h - 8), 3, Color(GOLD, 0.6))
	_diamond(Vector2(w, h - 8), 3, Color(GOLD, 0.6))
	draw_line(Vector2(0, h - 5), Vector2(64, h - 5), Color(GOLD, 0.28), 1, true)

func _stage(w: float, h: float) -> void:
	# Quiet framing is confined to the edges; enemy silhouettes remain unobscured.
	for i in 100:
		var fade := pow(1.0 - float(i) / 100, 2)
		draw_line(Vector2(i * 2, 0), Vector2(i * 2, h), Color("0b1226", fade * 0.12), 2)
		draw_line(Vector2(0, h - i * 2), Vector2(w, h - i * 2), Color("0b1226", fade * 0.15), 2)
	draw_line(Vector2(24, 88), Vector2(466, 88), Color(GOLD, 0.22), 1, true)
	draw_line(Vector2(704, 49), Vector2(834, 49), Color(GOLD, 0.55), 1, true)
	draw_line(Vector2(1086, 49), Vector2(1370, 49), Color(GOLD, 0.35), 1, true)
	_diamond(Vector2(824, 49), 3, Color(GOLD, 0.6))
	_diamond(Vector2(1096, 49), 3, Color(GOLD, 0.6))
	for center in [Vector2(31, h - 35), Vector2(w - 31, h - 35)]:
		_ring(center, 13, Color(GOLD, 0.4))
