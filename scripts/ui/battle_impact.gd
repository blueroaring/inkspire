extends Node2D
## Procedural accents complement the authored sprite sheets without per-spark nodes.
var family := "slash"
var accent := Color("ffc68b")
var direction := Vector2.RIGHT
var big := false
var hits := 1
var flight := false
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var age := 0.0
var duration := 0.46

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	age += delta
	if age >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(age / duration, 0, 1)
	if flight:
		var head := origin.lerp(destination, t * t)
		for i in 12:
			var previous := maxf(0, t - i * 0.018)
			var tail := origin.lerp(destination, previous * previous)
			draw_line(tail, head, Color(accent, (1.0 - float(i) / 12) * 0.5), maxf(1, 8 - i * 0.55), true)
			head = tail
		return
	var fade := pow(1.0 - t, 1.6)
	if family == "poison":
		# Liquid curls complement the generated venom; no white flash or hard shock ring.
		for i in 7:
			var angle := i * TAU / 7.0 + t * 0.8
			var p := Vector2.from_angle(angle) * (22 + t * (70 + i * 9))
			draw_arc(p, 8 + i % 3 * 4, angle, angle + 1.8, 12, Color(accent, fade * 0.5), 2, true)
		return
	var power := (1.4 if big else 1.0) * minf(1.4, 1.0 + log(float(maxi(1, hits))) * 0.065)
	var radius := (25 + 125 * (1 - pow(1 - t, 3))) * power
	var support := family in ["blessing", "barrier"]
	draw_arc(Vector2.ZERO, radius, 0, TAU, 72, Color(accent, fade * 0.7), (2 if support else 4) * power, true)
	if age < 0.055:
		draw_circle(Vector2.ZERO, (28 if support else 52) * power, Color("fff4df", 0.65 * (1.0 - age / 0.055)), true, -1, true)
	var rays := 8 if support else 16
	for i in rays:
		var angle := float(i) * TAU / rays + (0.3 if family == "math" else 0.0)
		var ray := Vector2.from_angle(angle)
		var travel := radius * (0.75 + float(i % 3) * 0.28)
		if support:
			var point := ray * travel + Vector2(0, -t * 45)
			draw_line(point - Vector2(4, 0), point + Vector2(4, 0), Color(accent, fade), 2, true)
			draw_line(point - Vector2(0, 4), point + Vector2(0, 4), Color(accent, fade), 2, true)
		else:
			draw_line(ray * travel, ray * (travel + (14 + i % 4 * 7) * (1 - t)), Color(accent, fade), 2 + float(i % 2), true)
	if family == "slash":
		var axis := direction.rotated(-0.4)
		draw_line(-axis * 135 * power, axis * 135 * power, Color("fff1d0", fade), 11 * fade + 1, true)
		draw_line(-axis.rotated(0.6) * 88, axis.rotated(0.6) * 88, Color(accent, fade), 5 * fade + 1, true)
	elif family in ["math", "magic", "barrier"]:
		var vertices := PackedVector2Array()
		var sides := 4 if family == "math" else 6
		for i in sides + 1: vertices.append(Vector2.from_angle(i * TAU / sides + t * 0.5) * radius * 0.8)
		draw_polyline(vertices, Color(accent, fade), 2.5, true)
