extends Node2D
## Procedural secondary motion, using generated cards / feathers / crystal fragments.
const ART := preload("res://scripts/data/battle_art.gd")
var module := "wang"
var foreground := false
var elapsed := 0.0
var tint := Color.WHITE
var fragment: Texture2D

func _ready() -> void:
	tint = ART.accent(module)
	fragment = ART.icon({"wang":"magic_card", "alyina":"blessing_mote", "zhou_math":"pursuit", "zhou_wuji":"self_loss", "chen":"A03", "xu":"self_loss", "liu":"Y03"}.get(module, "magic_card"))

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var reveal := smoothstep(0.12, 0.65, elapsed)
	var fade := reveal * (1.0 - smoothstep(1.85, 2.25, elapsed))
	if fade <= 0.0: return
	var focus := Vector2(1240, 495)
	if module in ["su", "liu"]:
		# Reuse the generated venom art as drifting fragments; leave her face clear.
		var frames := ART.effect_frames("ink" if module == "liu" else "poison")
		if frames == null: return
		for i in (3 if foreground else 6):
			var angle := float(i) * 2.39996 + elapsed * 0.3
			var p := focus + Vector2(cos(angle) * 400, sin(angle) * 255 + 135)
			if foreground: p.y = maxf(680.0, p.y)
			var extent := 165.0 if foreground else 245.0
			var frame := mini(11, 6 + int(fposmod(elapsed * 5 + i, 6)))
			draw_texture_rect(frames.get_frame_texture("default", frame), Rect2(p - Vector2.ONE * extent * 0.5, Vector2.ONE * extent), false, Color(1, 1, 1, fade * (0.42 if foreground else 0.24)))
		return
	if module in ["chen", "xu"]:
		_draw_companion(focus, fade)
		return
	if not foreground:
		for ring in 3:
			var points := PackedVector2Array()
			for i in 100:
				var a := float(i) / 99 * TAU + elapsed * (0.15 + ring * 0.08)
				points.append(focus + Vector2(cos(a) * (340 + ring * 56), sin(a) * (190 + ring * 32)).rotated(-0.24))
			draw_polyline(points, Color(tint, fade * (0.24 - ring * 0.05)), 1.5, true)
		if module == "zhou_math":
			for i in 12:
				var a := float(i) / 12 * TAU + elapsed * 0.12
				var ray := Vector2.from_angle(a)
				draw_line(focus + ray * 325, focus + ray * 341, Color(tint, fade * 0.6), 1.8, true)
	# A bounded set of textured fragments; no node or texture allocation per particle.
	for i in (5 if foreground else 12):
		var seed := float(i + (17 if foreground else 0))
		var angle := seed * 2.39996 + elapsed * (0.5 if module == "wang" else 0.22)
		var radius := 290.0 + fmod(seed * 53, 180.0)
		var p := focus + Vector2(cos(angle) * radius, sin(angle) * radius * 0.66)
		if foreground: p.y = 745 + sin(angle) * 135
		var side := (62.0 if module == "wang" else 34.0) * (1.6 if foreground else 0.7)
		if fragment != null:
			draw_set_transform(p, angle * 0.35 - 0.3, Vector2.ONE)
			draw_texture_rect(fragment, Rect2(Vector2.ONE * -side * 0.5, Vector2.ONE * side), false, Color(1, 1, 1, fade * (0.9 if foreground else 0.5)))
			draw_set_transform(Vector2.ZERO)
	for i in (12 if foreground else 28):
		var seed := float(i)
		var p := Vector2(fposmod(seed * 173 + elapsed * (120 if foreground else 38), 1920), fposmod(seed * 89 - elapsed * 44 + 1080, 1080))
		var alpha := fade * (0.16 + sin(seed * 5 + elapsed * 3) * 0.1)
		draw_line(p, p + Vector2(10 if foreground else 3, -2), Color(tint, alpha), 1.5, true)

func _draw_companion(focus: Vector2, fade: float) -> void:
	if module == "chen":
		if not foreground:
			for ring in 3:
				var scale := 1.0 + ring * 0.18 + smoothstep(0.4, 1.1, elapsed) * 0.06
				var shield := PackedVector2Array()
				for point in [Vector2(-260, -260), Vector2(230, -260), Vector2(220, 130), Vector2(0, 360), Vector2(-250, 120), Vector2(-260, -260)]: shield.append(focus + point * scale)
				draw_polyline(shield, Color(tint, fade * (0.28 - ring * 0.06)), 2, true)
		for i in (4 if foreground else 10):
			var angle := i * 2.4 + elapsed * 0.13
			var p := focus + Vector2(cos(angle) * 380, sin(angle) * 310)
			var shard := PackedVector2Array([p + Vector2(-5, 8), p + Vector2(0, -14), p + Vector2(8, 4)])
			draw_colored_polygon(shard, Color(tint, fade * (0.25 if foreground else 0.12)))
	else:
		for lane in (5 if foreground else 9):
			var travel := fposmod(elapsed * 520 + lane * 163, 1100)
			var start := Vector2(690 + travel, 350 + lane * 65 - travel * 0.25)
			draw_line(start, start + Vector2(-140, 35), Color(tint, fade * (0.16 if foreground else 0.09)), 2 if foreground else 1, true)
		if not foreground:
			for line in 3:
				draw_line(Vector2(820, 1000 + line * 70), Vector2(1680 + line * 85, 200), Color(tint, fade * 0.15), 2, true)
