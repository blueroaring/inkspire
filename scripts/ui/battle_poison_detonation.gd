extends Node2D
## A stationary implosion / rupture, distinct from Su's traveling liquid attack.
signal detonated
const CONTACT_TIME := 0.18
const DURATION := 0.82
const VENOM := Color("b6f56a")
const VIOLET := Color("c391ff")
var big := false
var age := 0.0
var _detonated := false

func _ready() -> void:
	z_index = 8

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	age += delta
	if not _detonated and age >= CONTACT_TIME:
		_detonated = true
		detonated.emit()
	if age >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var power := 1.18 if big else 1.0
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE*power)
	if age < CONTACT_TIME:
		var t := age / CONTACT_TIME
		var radius := lerpf(125, 29, t*t)
		# Toxic motes contract into the target; there is no projectile from the caster.
		for i in 9:
			var angle := i*TAU/9 + t*0.35
			var axis := Vector2.from_angle(angle)
			draw_line(axis*(radius+23), axis*radius, Color(VIOLET, 0.3+t*0.5), 3, true)
			draw_circle(axis*radius, 3+t*2, Color(VENOM, 0.4+t*0.6), true, -1, true)
		draw_circle(Vector2.ZERO, 16+t*22, Color("27113d", 0.75), true, -1, true)
		draw_arc(Vector2.ZERO, 43-t*15, -t*2, TAU-t*2, 48, Color(VIOLET, 0.35+t*0.6), 3, true)
		return
	var t := clampf((age-CONTACT_TIME)/(DURATION-CONTACT_TIME), 0, 1)
	var spread := 1-pow(1-t, 3)
	var fade := pow(1-t, 1.5)
	var radius := 32+225*spread
	# The purple pressure wave and jagged green shards read as an explosion,
	# rather than the curling liquid used by attacks and poison application.
	draw_circle(Vector2.ZERO, radius*0.75, Color("38124f", fade*0.25), true, -1, true)
	for i in 5:
		var r := radius*(1-float(i)*0.055)
		draw_arc(Vector2.ZERO, r, 0, TAU, 72, Color(VIOLET, fade*0.1), 12, true)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 72, Color("29133f", fade), 9, true)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 72, Color(VIOLET, fade*0.95), 4, true)
	draw_arc(Vector2.ZERO, radius*0.86, 0, TAU, 72, Color("e6d7ff", fade*0.55), 2, true)
	for i in 12:
		var angle := i*TAU/12 + 0.16
		var axis := Vector2.from_angle(angle)
		var perpendicular := axis.orthogonal()
		var distance := radius*(0.72+float(i%3)*0.17)
		var length := (30+i%4*9)*(1-t)
		var start := axis*distance
		var middle := axis*(distance+length*0.55)+perpendicular*(6 if i%2 == 0 else -6)
		var end := axis*(distance+length)
		var crack := PackedVector2Array([start, middle, end])
		draw_polyline(crack, Color("28372e", fade*0.8), 7, true)
		draw_polyline(crack, Color(VENOM, fade), 3, true)
		var shard := PackedVector2Array([end, end-axis*9+perpendicular*3, end-axis*6-perpendicular*4])
		draw_colored_polygon(shard, Color(VENOM, fade))
	# Local core flash only; keep the whole battle screen and the damage numbers readable.
	var flash := maxf(0, 1-t/0.17)
	if flash > 0:
		draw_circle(Vector2.ZERO, 32+48*(1-flash), Color(VIOLET, flash*0.7), true, -1, true)
		draw_circle(Vector2.ZERO, 15+24*(1-flash), Color("eeffce", flash*0.95), true, -1, true)
	for i in 8:
		var angle := i*TAU/8 - t*0.3
		var point := Vector2.from_angle(angle)*(45+72*spread)
		draw_arc(point, 10+float(i%3)*4+t*12, angle, angle+1.7, 14, Color(VIOLET, fade*0.55), 2, true)
