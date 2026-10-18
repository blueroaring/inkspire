extends Node2D
## The visible projectile and the contact callback share this one clock.
signal arrived
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var duration := 0.28
var kind := "paper"
var bend := 0.0
var age := 0.0
var _paper_style: StyleBoxFlat
const ART := preload("res://scripts/ui/battle_enemy_art.gd")
const ENERGY := preload("res://scripts/ui/battle_finale_energy.gd")

func _ready() -> void:
	if kind in ["abyss","choir","dawn","whisper"]: ENERGY.prepare()
	_paper_style = StyleBoxFlat.new()
	_paper_style.bg_color = Color("ede3dd")
	_paper_style.border_color = Color("9b8096")
	_paper_style.set_border_width_all(1)

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	age += delta
	queue_redraw()
	if age >= duration:
		arrived.emit()
		queue_free()

func _point(t: float) -> Vector2:
	return origin.lerp(destination, t) + Vector2(bend, -105.0 if kind == "paper_small" else -65.0) * sin(t * PI)

func _draw() -> void:
	var t := clampf(age / duration, 0, 1)
	var heading := (destination - origin).angle()
	if kind.begins_with("signature:"):
		var parts := kind.split(":")
		var at := _point(t)
		if parts[1] == "quiet_hacker":
			at = origin.lerp(destination, floorf(t * 8) / 8)
		elif parts[1] in ["fist_phantom", "bruised_hand"]:
			at = origin.lerp(destination, pow(t, 2.5))
		preload("res://scripts/ui/battle_enemy_signature.gd").token(self, parts[1], parts[2], at, 0.85, t, true)
	elif kind in ["inverse_rain", "inverse_injury"]:
		var p := _point(t)
		for i in 7:
			var at := p + Vector2((i-3)*17, sin(i*2.3)*34)
			draw_line(at, at+Vector2(13,-60) if kind=="inverse_rain" else at+Vector2(70,-10), Color("b5e5ef" if kind=="inverse_rain" else "ed9da9", 1-i*0.07), 3,true)
	elif kind == "chains" or kind.begins_with("panic_"):
		var key: String = {"chains":"whip_upper", "panic_pierce":"pierce", "panic_silence":"silence", "panic_doubt":"doubt", "panic_nightmare":"nightmare", "panic_cage":"cage"}.get(kind, "whip_upper")
		var size_box := Vector2(285, 130) if kind in ["chains", "panic_pierce"] else Vector2.ONE * 180
		ART.stamp(self, "panic/panic_" + key, _point(t), size_box, minf(1, t * 6), heading if kind in ["chains", "panic_pierce"] else sin(t * PI) * 0.12)
	elif kind in ["abyss", "choir", "dawn", "whisper"]:
		_draw_finale(t, heading)
	elif kind in ["heart_arrow", "red_pen", "formula", "bite"] and ART.texture(String({"heart_arrow":"fx_cupid_thread", "red_pen":"fx_score_verdict", "formula":"fx_exam_graph", "bite":"fx_book_jaws"}[kind])) != null:
		var key: String = {"heart_arrow":"fx_cupid_thread", "red_pen":"fx_score_verdict", "formula":"fx_exam_graph", "bite":"fx_book_jaws"}[kind]
		ART.stamp(self,key,_point(t),Vector2(240,160),1.0,heading if kind=="heart_arrow" else 0.0)
	elif kind in ["heart_arrow", "thunder", "judgment", "bite", "haunt", "chains", "panic_silence", "panic_pierce", "panic_doubt", "panic_nightmare", "panic_cage", "formula", "red_pen", "mirror"]:
		_draw_authored_trail(t, heading)
	elif kind == "whip":
		var points := PackedVector2Array()
		for i in 26:
			var u := float(i) / 25.0
			var point := origin.lerp(_point(t), u)
			point.y += sin(u * PI * 3.0 - t * 9.0) * sin(u * PI) * 50
			points.append(point)
		draw_polyline(points, Color("b786cf", 0.25), 13, true)
		draw_polyline(points, Color("eed0ff"), 3.5, true)
	elif kind in ["claw", "pounce"]:
		var normal := (destination - origin).normalized().orthogonal()
		for claw in (4 if kind == "pounce" else 3):
			var offset := normal * (claw - 1) * (10.0 if kind == "pounce" else 22.0)
			var points := PackedVector2Array()
			for step in 8:
				points.append(_point(maxf(0.0, t - float(step) * 0.038)) + offset)
			draw_polyline(points, Color("f3d9bd", 0.88), (3.5 if kind == "pounce" else 6.0) - claw * 0.6, true)
	elif kind in ["voice", "shout"]:
		for i in 3:
			var u := maxf(0.0, t - i * 0.07)
			var p := _point(u)
			var radius := 16.0 + t * (72.0 if kind == "shout" else 28.0) + i * 5.0
			draw_arc(p, radius, heading - 1.1, heading + 1.1, 24, Color("e798d7", 0.9 - i * 0.23), 4.0 - i, true)
	else:
		# A fan of actual sheets flies from the beast, each with its own flutter.
		for i in (3 if kind == "paper_small" else 5):
			var p := _point(maxf(0.0, t - i * 0.065)) + Vector2((i - 1) * 14, (i - 1) * -10)
			draw_set_transform(p, heading + PI * 0.5 + sin(t * 15 + i) * 0.28, Vector2(0.8 + 0.2 * sin(t * 20 + i), 1))
			draw_style_box(_paper_style, Rect2(-13, -20, 26, 40))
			for line in 4:
				draw_line(Vector2(-8, -11 + line * 7), Vector2(7, -11 + line * 7), Color("71677b"), 1.3, true)
			draw_line(Vector2(-5, 6), Vector2(8, 14), Color("c34861"), 2, true)
			draw_line(Vector2(7, 5), Vector2(-5, 15), Color("c34861"), 2, true)
		draw_set_transform(Vector2.ZERO)

func _draw_finale(t: float, heading: float) -> void:
	var color: Color = {"abyss":Color("dd98df"), "choir":Color("8dd2e1"), "dawn":Color("ffe0aa"), "whisper":Color("b8a2ec")}[kind]
	var p := _point(t)
	var normal := (destination-origin).normalized().orthogonal()
	var width := 110.0 if kind=="abyss" else 80.0 if kind=="dawn" else 62.0
	var tail := _point(maxf(0,t-.72))
	for layer in 3:
		var offset := normal*sin(t*9+layer*2.1)*float(layer)*14
		ENERGY.ribbon(self,tail+offset,p,width*(1+layer*.6),color,age*3+layer,.86 if layer==0 else .23)
	ENERGY.vortex(self,p,62 if kind=="abyss" else 38,color,age*7,.7)
	if kind == "abyss":
		draw_circle(p,13,Color("070511",.9))
		for i in 7:
			var point := p+Vector2.from_angle(i*2.399+t*3)*(22+i*5)
			var direction := Vector2.from_angle(heading+i*.4)
			draw_colored_polygon(PackedVector2Array([point-direction*12,point+direction.orthogonal()*4,point+direction*7]),Color(color,.65))
	elif kind == "choir":
		for i in 3: ENERGY.vortex(self,_point(maxf(0,t-i*.12)),42+i*9,color,age*5+i,.7-i*.14,.55)
	elif kind == "dawn":
		for i in 5:
			var feather := normal*(i-2)*15
			ENERGY.ribbon(self,tail+feather*2,p+feather,32,color.lightened(.2),age*5+i,.72)
	else:
		ENERGY.ribbon(self,tail-normal*30,p+normal*16,110,color,age*2,.26)

func _draw_authored_trail(t: float, heading: float) -> void:
	var p := _point(t)
	var color: Color = {"heart_arrow":Color("ff85bc"), "thunder":Color("c3eaff"), "judgment":Color("ffbd8d"), "bite":Color("f6dfb7"), "haunt":Color("b8a1ef"), "chains":Color("7bb8c6"), "panic_silence":Color("a77fae"), "panic_pierce":Color("e7a3ba"), "panic_doubt":Color("b8bd7a"), "panic_nightmare":Color("96b4db"), "panic_cage":Color("7dc3c9"), "formula":Color("67e2da"), "red_pen":Color("ff696f"), "mirror":Color("a3e8f3")}[kind]
	if kind in ["thunder", "judgment"]:
		var top := p - Vector2(0, 170)
		var bolt := PackedVector2Array([top, top+Vector2(-16, 45), top+Vector2(14, 64), top+Vector2(-10, 115), p])
		draw_polyline(bolt, Color(color, 0.3), 13, true)
		draw_polyline(bolt, color, 4, true)
		if kind == "judgment":
			draw_arc(p, 34 + 10 * sin(t * TAU), 0, TAU, 36, Color(color, 0.8), 3, true)
			draw_line(top + Vector2(22, 30), p + Vector2(18, 0), Color("fff2cf", 0.72), 2, true)
		return
	if kind == "chains":
		for i in 9:
			var pos := _point(maxf(0, t - i * 0.035))
			draw_set_transform(pos, heading, Vector2(1.6, 0.65))
			draw_arc(Vector2.ZERO, 9, 0, TAU, 16, Color(color, 1.0-i*0.08), 2.5, true)
		draw_set_transform(Vector2.ZERO)
		return
	if kind.begins_with("panic_"):
		var tail := _point(maxf(0.0, t - 0.22))
		for side in [-1.0, 1.0]:
			var normal: Vector2 = Vector2.from_angle(heading).orthogonal() * float(side)
			draw_line(tail + normal * 20.0, p + normal * (8.0 if kind == "panic_pierce" else 27.0), Color(color, 0.78), 3.0, true)
		if kind == "panic_pierce":
			draw_colored_polygon(PackedVector2Array([p + Vector2.from_angle(heading) * 46, p + Vector2.from_angle(heading + 2.4) * 15, p + Vector2.from_angle(heading - 2.4) * 15]), Color("ffe7e4"))
		elif kind == "panic_silence":
			for i in 3: draw_arc(p, 20 + i * 18, heading - 1.1, heading + 1.1, 28, Color(color, 0.85 - i * 0.2), 3, true)
		elif kind == "panic_doubt":
			for i in 5:
				var offset := Vector2.from_angle(i * TAU / 5.0 + age) * (15 + i * 6)
				draw_line(p + offset, p + offset * 1.8, Color(color, 0.8), 3, true)
		elif kind == "panic_nightmare":
			for i in 5:
				var eye := p + Vector2.from_angle(i * TAU / 5.0) * 36.0
				draw_arc(eye, 9.0, 0, TAU, 16, Color(color, 0.65), 2.0, true)
		elif kind == "panic_cage":
			for i in 4:
				var offset := (i - 1.5) * 17.0
				draw_line(p + Vector2(offset, -43), p + Vector2(offset, 43), Color(color, 0.8), 3, true)
		return
	var tail := PackedVector2Array()
	for i in 9: tail.append(_point(maxf(0, t - i * 0.025)))
	draw_polyline(tail, Color(color, 0.3), 12, true)
	draw_polyline(tail, color, 3, true)
	draw_set_transform(p, heading)
	match kind:
		"heart_arrow":
			draw_line(Vector2(-32, 0), Vector2(14, 0), Color("ffe4a5"), 3, true)
			draw_colored_polygon(PackedVector2Array([Vector2(22, 0), Vector2(7, -10), Vector2(2, -5), Vector2(2, 5), Vector2(7, 10)]), color)
		"bite":
			for side in [-1, 1]:
				for i in 4:
					var x := -24 + i * 15
					draw_colored_polygon(PackedVector2Array([Vector2(x, side*24), Vector2(x+12, side*24), Vector2(x+6, side*5)]), color)
		"haunt":
			for i in 3: draw_arc(Vector2(-i*12, 0), 14+i*6, -1.4, 1.4, 20, Color(color, 0.8-i*0.2), 4, true)
		"formula":
			draw_arc(Vector2.ZERO, 20, 0, TAU, 24, color, 2, true)
			draw_line(Vector2(-27, 0), Vector2(27, 0), color, 2, true)
			draw_line(Vector2(0, -27), Vector2(0, 27), color, 2, true)
		"red_pen":
			draw_line(Vector2(-32, 0), Vector2(4, 0), color, 8, true)
			draw_colored_polygon(PackedVector2Array([Vector2(4,-6), Vector2(23,0), Vector2(4,6)]), Color("ffe0ac"))
		"mirror":
			for i in 3:
				var offset := Vector2(-i*14, (i-1)*12)
				draw_colored_polygon(PackedVector2Array([offset+Vector2(18,0), offset+Vector2(-6,-9), offset+Vector2(-12,6)]), Color(color, 0.95-i*0.2))
	draw_set_transform(Vector2.ZERO)

