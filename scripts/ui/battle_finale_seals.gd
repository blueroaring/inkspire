extends RefCounted
## Five engraved seals, driven by the cinematic clock rather than independent timers.
const FONT := preload("res://assets/fonts/noto_serif_sc/semibold.tres")
const NUMERALS := ["I", "II", "III", "IV", "V"]
const GOLD := Color("d8ae91")
const LIGHT := Color("ffe7cf")
const EMBER := Color("f47798")

static func location(center: Vector2, index: int) -> Vector2:
	# An open crown below the title: no seal is concealed behind the skill name.
	return center + Vector2(0, 15) + Vector2.from_angle(-PI * .9 - index * PI * .3) * Vector2(350, 225)

static func outline(canvas: CanvasItem, vertices: PackedVector2Array, tint: Color, width: float) -> void:
	var loop := vertices.duplicate()
	loop.append(vertices[0])
	canvas.draw_polyline(loop, tint, width, true)

static func diamond(at: Vector2, half_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at - Vector2(0, half_size.y), at + Vector2(half_size.x, 0), at + Vector2(0, half_size.y), at - Vector2(half_size.x, 0)])

static func draw_seals(canvas: CanvasItem, center: Vector2, progress: float, age: float, release: float) -> void:
	var opacity := smoothstep(0.0, .45, age) * (1.0 if release < 0 else maxf(0, 1 - release / .42))
	if opacity <= 0: return
	# Fine broken chains link the five medallions without crossing the face or title.
	for i in 4:
		var start := location(center, i)
		var end := location(center, i + 1)
		var direction := (end - start).normalized()
		start += direction * 72
		end -= direction * 72
		var active := clampf(progress * 5.5 - i - 1, 0, 1)
		canvas.draw_line(start, end, Color(GOLD, opacity * .16), 1, true)
		for j in 9:
			var u := (j + .5) / 9.0
			var p := start.lerp(end, u)
			var glint := maxf(0, 1 - absf(active - u) * 9) if active < 1 else 0.0
			outline(canvas, diamond(p, Vector2(3, 4)), Color(GOLD.lerp(LIGHT, glint), opacity * (.24 + glint * .66)), 1)
	for i in 5:
		_draw_seal(canvas, location(center, i), i, progress * 5.5 - i, age, opacity)

static func _draw_seal(canvas: CanvasItem, at: Vector2, index: int, phase: float, age: float, opacity: float) -> void:
	var charging := smoothstep(0.0, .85, clampf(phase, 0, 1))
	var broken := phase >= 1
	var since_break := maxf(0, phase - 1) * 3.65 / 5.5
	var flash := pow(maxf(0, 1 - since_break / .26), 2) if broken else 0.0
	var breathe := .5 + .5 * sin(age * 2.4 + index * .7)
	var life := .23 if broken else .68 + charging * .32
	var metal := GOLD.lerp(EMBER, .7 if broken else charging * .35)
	var scale := 1.0 + charging * .045 + flash * .055
	canvas.draw_set_transform(at, 0, Vector2.ONE * scale)
	# Soft aureole, an interrupted orbital ring, and tiny engraved radial marks.
	for layer in range(4, 0, -1):
		canvas.draw_circle(Vector2.ZERO, 48 + layer * 5, Color(EMBER, opacity * (.008 + charging * .007 + flash * .035)))
	for quadrant in 4:
		var angle := quadrant * PI / 2 + age * .07 * (1 if index % 2 == 0 else -1)
		canvas.draw_arc(Vector2.ZERO, 61, angle + .15, angle + 1.12, 20, Color(metal, opacity * life * .42), 1, true)
		canvas.draw_arc(Vector2.ZERO, 65, angle + .3, angle + .73, 12, Color(metal, opacity * life * .22), 1, true)
	for tick in 32:
		var direction := Vector2.from_angle(tick * TAU / 32)
		var major := tick % 4 == 0
		canvas.draw_line(direction * 56, direction * (60 if major else 58), Color(metal, opacity * life * (.6 if major else .27)), 1, true)
	if phase > 0 and not broken:
		canvas.draw_arc(Vector2.ZERO, 65, -PI / 2, -PI / 2 + TAU * minf(phase, 1), 64, Color(LIGHT, opacity * .8), 1.6, true)
	# Chamfered, faceted metal frame around a dark enamel face.
	var rim := PackedVector2Array([Vector2(0,-60),Vector2(13,-40),Vector2(43,-9),Vector2(43,9),Vector2(13,40),Vector2(0,60),Vector2(-13,40),Vector2(-43,9),Vector2(-43,-9),Vector2(-13,-40)])
	canvas.draw_colored_polygon(rim, Color("100b1a", opacity * .98))
	outline(canvas, rim, Color(metal, opacity * life * .8), 2)
	var outer := diamond(Vector2.ZERO, Vector2(38, 51))
	var inner := diamond(Vector2.ZERO, Vector2(32, 43))
	canvas.draw_colored_polygon(outer, Color("4b293a" if broken else "64414c", opacity * .95))
	for side in 4:
		var next := (side + 1) % 4
		canvas.draw_colored_polygon(PackedVector2Array([outer[side],outer[next],inner[next],inner[side]]), Color(metal, opacity * life * (.5 if side in [0,3] else .17)))
	canvas.draw_colored_polygon(inner, Color("110e1c", opacity))
	outline(canvas, inner, Color(metal, opacity * life * .57), 1)
	canvas.draw_polyline(PackedVector2Array([outer[3],outer[0],outer[1]]), Color(LIGHT, opacity * life * .7), 1.3, true)
	# Engraving remains restrained so the Roman numeral reads at battle scale.
	for sign_y in [-1, 1]:
		var y := float(sign_y)
		canvas.draw_polyline(PackedVector2Array([Vector2(-13,y*25),Vector2(0,y*35),Vector2(13,y*25)]), Color(metal, opacity * life * .54), 1, true)
		canvas.draw_line(Vector2(-8,y*23),Vector2(8,y*23),Color(metal, opacity * life * .34),1,true)
		var gem := Vector2(0,y*51)
		canvas.draw_colored_polygon(diamond(gem,Vector2(4,7)),Color(EMBER.lerp(LIGHT, charging * .7 + flash * .3), opacity * (.42 if broken else .8 + breathe * .2)))
		canvas.draw_line(gem-Vector2(0,5),gem+Vector2(0,1),Color(LIGHT,opacity*life),1,true)
	for sign_x in [-1,1]:
		outline(canvas,diamond(Vector2(sign_x*44,0),Vector2(4,6)),Color(metal,opacity*life),1)
	var numeral: String = NUMERALS[index]
	var baseline := Vector2(-FONT.get_string_size(numeral,HORIZONTAL_ALIGNMENT_LEFT,-1,30).x*.5,11)
	canvas.draw_string_outline(FONT,baseline,numeral,HORIZONTAL_ALIGNMENT_LEFT,-1,30,4,Color("05030a",opacity))
	canvas.draw_string(FONT,baseline+Vector2(0,1),numeral,HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("754754",opacity))
	canvas.draw_string(FONT,baseline,numeral,HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color(LIGHT.lerp(Color("b77c8c"),.6 if broken else 0),opacity))
	if broken:
		# A branching hairline fracture travels around the glyph, then throws debris once.
		var crack := PackedVector2Array([Vector2(-19,-39),Vector2(-10,-26),Vector2(-17,-15),Vector2(-12,-2),Vector2(-20,12),Vector2(-8,28),Vector2(7,42)])
		canvas.draw_polyline(crack,Color(EMBER,opacity*(.16+flash*.3)),6,true)
		canvas.draw_polyline(crack,Color(EMBER.lerp(LIGHT,flash),opacity*(.68+flash*.32)),1.2,true)
		canvas.draw_polyline(PackedVector2Array([Vector2(-20,12),Vector2(-28,16),Vector2(-34,10)]),Color(EMBER,opacity*.55),1,true)
		if since_break < .55:
			canvas.draw_arc(Vector2.ZERO,64+since_break*92,0,TAU,64,Color(EMBER,opacity*flash*.55),1.5,true)
			for shard in 12:
				var direction := Vector2.from_angle(shard*2.399+index)
				var travel := since_break * (60 + (shard % 4) * 24)
				var p := direction * (49 + travel) + Vector2(0,since_break*since_break*40)
				var size := (2.0 + shard % 3) * maxf(0,1-since_break/.55)
				if size < .4: continue # Avoid degenerate subpixel triangles at the end of the fade.
				canvas.draw_colored_polygon(PackedVector2Array([p-direction*size*2,p+direction.orthogonal()*size*.55,p+direction*size]),Color(metal.lerp(LIGHT,.45),opacity*maxf(0,1-since_break/.55)))
	canvas.draw_set_transform(Vector2.ZERO)
