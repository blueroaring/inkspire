extends Control
const ART := "res://assets/graphics/battle/finale/anya_ascension/"
## Light and ribbon motifs shared by the CG and its battlefield continuation.
## All positions are in the battle UI's 1920 x 1080 design space.
var skill := "anya_step"
var ambient := false
var age := 0.0
var duration := 2.5
var targets: Array[Vector2] = []
var enemies: Array[Vector2] = []
var accent := Color("ffda9c")
var wings: Texture2D
var phoenix: Texture2D
var sprite_frame := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1920, 1080)
	wings = load(ART + "wings.webp")
	phoenix = load(ART + "phoenix.webp")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	age += delta
	# Six painted poses blend continuously, then hold the open wings before dissolving.
	sprite_frame = minf(3.0, age * 2.8) if age < 1.8 else minf(5.0, 3.0 + (age - 1.8) * 1.8)
	queue_redraw()

func _painted_frame(texture: Texture2D, center: Vector2, extent: Vector2, frame: float, opacity: float) -> void:
	var first := clampi(int(frame), 0, 5)
	var blend := clampf(frame - first, 0, 1)
	var rect := Rect2(center - extent * 0.5, extent)
	var cell := texture.get_size() / Vector2(2, 3)
	for n in 2:
		var index := mini(5, first + n)
		var alpha := opacity * (1.0 - blend if n == 0 else blend)
		if alpha < 0.001: continue
		draw_texture_rect_region(texture, rect, Rect2(Vector2(index % 2, index / 2) * cell, cell), Color(1, 1, 1, alpha))

func _ascension(opacity: float) -> void:
	var rebirth := skill in ["anya_reconcile", "anya_defy", "anya_refuse"]
	var center := Vector2(1180, 465)
	var extent := Vector2(850, 760) if not rebirth else Vector2(820, 820)
	if skill == "anya_step": center.x -= smoothstep(0.5, 2.5, age) * 170
	if rebirth: center.y -= smoothstep(0.5, duration, age) * 95
	if skill == "anya_refuse": extent *= 1.18
	var breathing := 1.0 + sin(age * 2.5) * 0.018
	# A soft amber column ties the descending apparition to the battlefield.
	for i in 18:
		var width := 22.0 + i * 15.0
		draw_rect(Rect2(center.x - width * 0.5, 0, width, 860), Color(accent, opacity * 0.009))
	_painted_frame(phoenix if rebirth else wings, center, extent * breathing, sprite_frame, opacity)
	# Small wing blessings travel onto the real recipients after the main unfurl.
	var blessing := smoothstep(0.65, 1.25, age) * opacity
	for recipient in targets:
		_painted_frame(wings, recipient + Vector2(0, -32), Vector2(370, 290), minf(sprite_frame, 4), blessing * 0.72)
	_motes(center, 450, opacity * 0.65, 65)

func _glow_line(points: PackedVector2Array, color: Color, width: float = 2.0) -> void:
	if points.size() < 2: return
	draw_polyline(points, Color(color, color.a * 0.06), width * 10, true)
	draw_polyline(points, Color(color, color.a * 0.18), width * 4, true)
	draw_polyline(points, color, width, true)

func _ring(center: Vector2, radius: float, color: Color, squash: float = 1.0, start: float = 0.0, sweep: float = TAU) -> void:
	var points := PackedVector2Array()
	for i in 65:
		var a := start + sweep * float(i) / 64.0
		points.append(center + Vector2(cos(a), sin(a) * squash) * radius)
	_glow_line(points, color)

func _motes(center: Vector2, spread: float, opacity: float, count: int = 38) -> void:
	for i in count:
		var seed_angle := float(i) * 2.39996
		var distance := spread * (0.25 + fmod(float(i) * 0.618, 0.75))
		var p := center + Vector2(cos(seed_angle) * distance, sin(seed_angle) * distance * 0.65 - age * (14 + i % 17))
		var alpha := opacity * (0.45 + 0.55 * sin(age * 3 + i) * sin(age * 3 + i))
		var radius := 1.4 + float(i % 3)
		draw_circle(p, radius * 4, Color(accent, alpha * 0.07))
		draw_circle(p, radius, Color(accent, alpha))
		if i % 7 == 0:
			draw_line(p - Vector2(7, 0), p + Vector2(7, 0), Color(accent, alpha), 1, true)
			draw_line(p - Vector2(0, 7), p + Vector2(0, 7), Color(accent, alpha), 1, true)

func _ribbon(center: Vector2, span: float, opacity: float, phase: float) -> void:
	var points := PackedVector2Array()
	for i in 65:
		var u := float(i) / 64.0
		points.append(center + Vector2((u - 0.5) * span, sin(u * TAU + age * 1.4 + phase) * 22 - u * 42))
	_glow_line(points, Color("c76564", opacity * 0.65), 4)
	_glow_line(points, Color(accent, opacity * 0.8), 1)

func _draw() -> void:
	if ambient:
		_motes(Vector2(1000, 1010), 1020, 0.42, 60)
		_ribbon(Vector2(480, 1040), 1120, 0.24, 0)
		return
	var fade := clampf(age / 0.25, 0, 1) * clampf((duration - age) / 0.65, 0, 1)
	var impact := clampf((age - 0.9) / 0.65, 0, 1)
	var bloom := sin(impact * PI) * fade
	draw_rect(Rect2(0, 0, 1920, 1080), Color("13152b", fade * 0.42))
	if skill in ["anya_defy", "anya_refuse"]:
		var origin := Vector2(1170, 650)
		for i in 18:
			var a := -PI + float(i) / 17.0 * PI
			var ray := Vector2(cos(a), sin(a))
			draw_colored_polygon(PackedVector2Array([origin, origin + ray.rotated(-0.018) * 1600, origin + ray.rotated(0.018) * 1600]), Color(accent, fade * 0.045))
		_ring(origin, 80 + impact * 1100, Color(accent, (1.0 - impact) * fade), 0.65)
		_motes(origin, 1000, fade * 0.85, 90)
		for enemy in enemies:
			_ring(enemy, 64 + impact * 48, Color(accent, fade), 0.35)
			for j in 5:
				var a := float(j) * TAU / 5 + age * 0.6
				var p := enemy + Vector2(cos(a) * 75, -90 + sin(a) * 15)
				draw_circle(p, 4, Color(accent, fade))
	if skill == "anya_step":
		_ribbon(Vector2(1170, 600), 1000, fade, 0)
		_ring(Vector2(1170, 776), 100 + impact * 410, Color(accent, fade * (1 - impact)), 0.12)
	for center in targets:
		_motes(center, 170, fade)
		_ring(center + Vector2(0, 55), 130 + sin(age * 2) * 8, Color(accent, fade * 0.85), 0.28)
		_ribbon(center, 330, fade * 0.8, 1)
		if skill == "anya_wait":
			var clock_center := center + Vector2(0, -95)
			_ring(clock_center, 90, Color(accent, fade))
			_ring(clock_center, 100, Color(accent, fade * 0.4))
			for i in 12:
				var a := float(i) * TAU / 12
				var ray := Vector2(sin(a), -cos(a))
				draw_line(clock_center + ray * 76, clock_center + ray * 86, Color(accent, fade), 3, true)
			_glow_line(PackedVector2Array([clock_center + Vector2(-40, -25), clock_center, clock_center + Vector2(sin(age * 2), -cos(age * 2)) * 65]), Color(accent, fade), 3)
		elif skill == "anya_resist":
			_ring(center + Vector2(0, -55), 120 + impact * 70, Color(accent, fade * (1 - impact)))
		elif skill == "anya_reconcile":
			for i in 3:
				_ring(center + Vector2(0, -30 - fmod(age * 90 + i * 55, 165)), 100, Color(accent, fade * 0.7), 0.3)
			for i in 12:
				var a := i * TAU / 12.0
				var p := center + Vector2(cos(a), sin(a)) * (65 + impact * 100) + Vector2(0, -80)
				draw_line(p, p + Vector2(cos(a + 0.4), sin(a + 0.4)) * 22, Color("b7a5d6", fade * (1 - impact)), 5, true)
		else:
			_ring(center, 65 + impact * 130, Color(accent, fade * (1 - impact)))
	_ascension(fade)
	if bloom > 0:
		draw_rect(Rect2(0, 0, 1920, 1080), Color(accent, bloom * 0.07))
