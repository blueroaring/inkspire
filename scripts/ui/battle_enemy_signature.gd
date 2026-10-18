extends Node2D
## Semantic overlays accompany the body's authored animation. No combat state changes.
const ART := preload("res://scripts/ui/battle_enemy_art.gd")
const OPTIONAL_ART := {
	"paper_large":"fx_paper_rend", "ink_wolf":"fx_paper_rend", "paper_small":"fx_paper_pounce", "ink_wolf_echo":"fx_paper_pounce",
	"noise":"fx_noise_pressure", "cupid":"fx_cupid_thread", "zeus_dean":"fx_zeus_verdict", "biting_book":"fx_book_jaws",
	"nightmare":"fx_nightmare_veil", "math_exam":"fx_exam_graph", "perfect_score":"fx_score_verdict",
	"self_destructive_pain":"fx_pain_pulse", "fist_phantom":"fx_phantom_fist", "bruised_hand":"fx_bruised_plea"
}
const EXCLUDED := ["panic_throat", "inverse_limit", "terminal_echo", "whisper_silhouette", "terminal_choir", "false_dawn"]
const TITLES := {
	"paper_large":"纸页撕裂", "ink_wolf":"纸页撕裂", "paper_small":"折纸突袭", "ink_wolf_echo":"折纸突袭",
	"noise":"声压共振", "cupid":"心弦牵引", "zeus_dean":"雷霆裁决", "biting_book":"书页啮合",
	"nightmare":"梦魇侵蚀", "snicker_shadow":"窃笑注视", "math_exam":"函数展开", "perfect_score":"朱批判卷",
	"gaokao_countdown":"时间崩解", "report_card":"灰烬排名", "quiet_hacker":"数据入侵",
	"magician_master":"幕布戏法", "self_destructive_pain":"脉搏反噬", "infirmary_demon":"临床处置",
	"bullied_phantom":"帘后禁言", "fist_phantom":"拳压", "whip_phantom":"鞭痕",
	"bruised_hand":"求救掌印", "shackle_phantom":"锁扣闭合", "claustrophobic_box":"空间内折"
}
var enemy_id := ""
var effect := ""
var center := Vector2.ZERO
var age := 0.0
var stage := 1
var hits: Array[Dictionary] = []
var closing := false

func _ready() -> void:
	name = "EnemySignature_" + enemy_id
	z_index = 42
	set_meta("theme", TITLES.get(enemy_id, enemy_id))

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	age += delta
	for hit in hits: hit.age = float(hit.age) + delta
	hits = hits.filter(func(hit: Dictionary) -> bool: return float(hit.age) < 0.72)
	queue_redraw()

func contact(effects: Array, rects: Dictionary) -> void:
	var seen: Array[int] = []
	for hit: Dictionary in effects:
		var index := int(hit.get("target", -1))
		if index in seen: continue
		seen.append(index)
		var area: Rect2 = rects.get("ally_%d" % index, Rect2())
		if area.has_area(): hits.append({"at":area.get_center(), "age":0.0})
	if seen.is_empty(): hits.append({"at":center, "age":0.0})

func finish() -> void:
	closing = true
	var fade := Settings.battle_tween(self)
	fade.tween_property(self, "modulate:a", 0.0, 0.32)
	fade.tween_callback(queue_free)

func _draw() -> void:
	var charge := minf(age / 0.38, 1.0) * (0.7 + sin(age * 4.0) * 0.12)
	if not closing: token(self, enemy_id, effect, center, charge, age, false)
	for hit in hits:
		var time := float(hit.age) / 0.72
		token(self, enemy_id, effect, hit.at, 1.0 - time, time, true)

static func token(c: CanvasItem, id: String, fx: String, at: Vector2, a: float, t: float, impact: bool) -> void:
	if a <= 0: return
	var optional := String(OPTIONAL_ART.get(id, ""))
	if id == "gaokao_countdown" and fx != "countdown_burst": optional = "fx_countdown_tick"
	if id == "report_card" and fx == "rankings": optional = "fx_report_rank"
	if id == "quiet_hacker" and fx == "steal_card": optional = "fx_hacker_theft"
	if id == "magician_master" and fx != "magic_summon": optional = "fx_magician_cards"
	if id == "infirmary_demon" and fx != "isolate": optional = "fx_infirmary_medicine"
	if not optional.is_empty() and ART.texture(optional) != null:
		_art_token(c, id, optional, at, a, t, impact)
		return
	c.draw_set_transform(at)
	match id:
		"paper_large", "paper_small", "ink_wolf", "ink_wolf_echo", "report_card":
			var ash := id == "report_card"
			if ash and fx in ["ash_bounce", "report_absent"]:
				ART.stamp(c, "fx_report_rebirth", at, Vector2.ONE * (280 if impact else 390), a, t * 0.8)
				return
			for i in (8 if ash else 5):
				var p := Vector2((i-2)*29.0, sin(i*2.3+t*8)*21 + (t*70 if impact else -45))
				c.draw_set_transform(at+p, (i-2)*0.16+t*(1 if impact else 0.15))
				c.draw_colored_polygon(PackedVector2Array([Vector2(-15,-24),Vector2(15,-24),Vector2(15,13),Vector2(4,25),Vector2(-15,16)]), Color("efe6d1", a*0.85))
				for row in 3: c.draw_line(Vector2(-9,-14+row*9),Vector2(10,-14+row*9),Color("b14255",a),1.8,true)
				if impact: c.draw_line(Vector2(-22,22),Vector2(25,-28),Color("efe6d1",a),3,true)
		"noise":
			var wave := PackedVector2Array()
			for i in 65:
				var x := -160.0+i*5.0
				wave.append(Vector2(x,sin(i*0.72-t*18)*sin(i*PI/64)*42*a))
			c.draw_polyline(wave,Color("d783d9",a*0.22),14,true)
			c.draw_polyline(wave,Color("ffe1ef",a),3,true)
			for side in [-1,1]: c.draw_arc(Vector2(side*145,0),35+t*35,-1.1 if side>0 else PI-1.1,1.1 if side>0 else PI+1.1,28,Color("f8b4e7",a),3,true)
		"cupid":
			for i in 7:
				var p: Vector2 = Vector2.from_angle(i*TAU/7+t*1.7)*(55+t*70 if impact else 95)
				c.draw_set_transform(at+p, sin(t*5+i)*0.4)
				c.draw_circle(Vector2(-5,-3),7,Color("ffa4d0",a))
				c.draw_circle(Vector2(5,-3),7,Color("ffa4d0",a))
				c.draw_colored_polygon(PackedVector2Array([Vector2(-12,0),Vector2(12,0),Vector2(0,16)]),Color("ffa4d0",a))
				if fx == "love_mist": c.draw_arc(Vector2.ZERO,20,0,TAU,24,Color("fbd3e5",a*0.3),10,true)
		"zeus_dean":
			for i in 3:
				var x := (i-1)*65.0
				var points := PackedVector2Array([Vector2(x-15,-160),Vector2(x+14,-85),Vector2(x-13,-93),Vector2(x+5,-10),Vector2(x-22,-29),Vector2(x+10,62)])
				c.draw_polyline(points,Color("92caff",a*0.25),17,true)
				c.draw_polyline(points,Color("e8faff" if fx != "sentence" else "ffe0a7",a),3.5,true)
			if fx == "sentence":
				c.draw_line(Vector2(-84,85),Vector2(84,85),Color("ffe0a7",a),4,true)
				c.draw_line(Vector2(-60,95),Vector2(60,95),Color("ffe0a7",a),2,true)
		"biting_book":
			var gap := (12+(1-a)*62) if impact else 40+sin(t*8)*16
			for side in [-1,1]:
				c.draw_line(Vector2(-95,side*gap),Vector2(95,side*gap),Color("dbc7a5",a),8,true)
				for i in 7:
					var x := -90+i*27.0
					c.draw_colored_polygon(PackedVector2Array([Vector2(x,side*gap),Vector2(x+22,side*gap),Vector2(x+11,side*(gap-24))]),Color("fff0ce",a))
			if fx == "forgetfulness":
				for i in 6: c.draw_line(Vector2(-50+i*19,-65),Vector2(-42+i*19,65),Color("9579ad",a),2,true)
		"nightmare", "snicker_shadow":
			if id == "snicker_shadow":
				ART.stamp(c,"panic/panic_doubt",at,Vector2(350,230),a)
				return
			for i in 9:
				var p := Vector2.from_angle(i*2.399+t)*(20+i*13)
				c.draw_circle(p,26+i*2,Color("18132f",a*0.24))
				if i%2 == 0:
					c.draw_arc(p,12,0.12,PI-0.12,20,Color("c9a4fa",a),2,true)
					c.draw_circle(p+Vector2(0,3),3,Color("ead5ff",a))
		"math_exam":
			c.draw_line(Vector2(-145,60),Vector2(145,60),Color("a9eee3",a*0.7),2,true)
			c.draw_line(Vector2(-100,-115),Vector2(-100,100),Color("a9eee3",a*0.7),2,true)
			var curve := PackedVector2Array()
			for i in 46:
				var x := -105.0+i*5
				curve.append(Vector2(x,60-pow(maxf(0, (x+85)/14),1.65)*a))
			c.draw_polyline(curve,Color("75f8d9",a),4,true)
			c.draw_string(ThemeDB.fallback_font,Vector2(-60,-48),"f(x) = x  + a",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("d1fff2",a))
		"perfect_score":
			var reach := 85*a if impact else 85.0
			c.draw_line(Vector2(-reach,-reach),Vector2(reach,reach),Color("ff6c77",a*0.3),17,true)
			c.draw_line(Vector2(-reach,-reach),Vector2(reach,reach),Color("ff6c77",a),5,true)
			c.draw_line(Vector2(reach,-reach),Vector2(-reach,reach),Color("ff9c9b",a),5,true)
		"gaokao_countdown":
			if fx == "countdown_burst":
				ART.stamp(c,"fx_countdown_burst",at,Vector2.ONE*lerpf(480,240,a),a,t*0.8)
				return
			for i in 12:
				var dir := Vector2.from_angle(i*TAU/12-PI/2)
				c.draw_line(dir*75,dir*(92 if i%3==0 else 84),Color("ffa79e",a),3,true)
			c.draw_line(Vector2.ZERO,Vector2.from_angle(-PI/2+t*6)*65,Color("fff0dd",a),4,true)
			c.draw_line(Vector2.ZERO,Vector2.from_angle(t*2)*43,Color("ff7a77",a),6,true)
		"quiet_hacker":
			if fx == "trojan": ART.stamp(c,"fx_hacker_trojan",at,Vector2.ONE*280,a)
			c.draw_set_transform(at)
			for i in 10:
				var x := -130+i*28.0
				var y := fmod(i*37+t*220,150)-75
				c.draw_string(ThemeDB.fallback_font,Vector2(x,y),"01" if i%2==0 else "10",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("7ff5ce",a*0.85))
			if fx == "steal_card":
				var p := Vector2(lerpf(70,-70,t if impact else fmod(t,1)),0)
				c.draw_rect(Rect2(p-Vector2(23,34),Vector2(46,68)),Color("91ffe0",a),false,2)
		"magician_master":
			ART.stamp(c,"fx_magician_summon",at,Vector2.ONE*(380 if fx=="magic_summon" else 260),a)
			c.draw_set_transform(at)
			for i in 3:
				c.draw_set_transform(at+Vector2(sin(t*5+i*TAU/3)*85,-35+cos(t*5+i*TAU/3)*28),(i-1)*0.3)
				c.draw_rect(Rect2(-17,-27,34,54),Color("f4d2a7",a))
				c.draw_rect(Rect2(-12,-22,24,44),Color("813c54",a),false,2)
		"self_destructive_pain":
			var line := PackedVector2Array([Vector2(-160,0),Vector2(-60,0),Vector2(-36,-12),Vector2(-20,38),Vector2(0,-80*a),Vector2(22,30),Vector2(40,0),Vector2(160,0)])
			c.draw_polyline(line,Color("d45072",a*0.25),18,true)
			c.draw_polyline(line,Color("ffb3c2",a),3,true)
			if impact:
				for i in 7:
					var dir := Vector2.from_angle(i*TAU/7)
					c.draw_line(dir*20,dir*(140*(1-a)+30),Color("d75b7b",a),3,true)
		"infirmary_demon":
			if fx == "isolate": ART.stamp(c,"fx_infirmary_isolation",at,Vector2(310,360),a)
			c.draw_set_transform(at)
			if fx == "anesthetic":
				for i in 8: c.draw_circle(Vector2(-135+i*36,sin(i*2+t*5)*23),28,Color("c2e9da",a*0.13))
			else:
				for i in 5:
					var p := Vector2((i-2)*38.0,sin(t*6+i)*32)
					c.draw_line(p-Vector2(7,0),p+Vector2(7,0),Color("e7faea",a),13,true)
					c.draw_line(p,p+Vector2(7,0),Color("7acbb1",a),13,true)
			if fx == "critical":
				c.draw_line(Vector2(-60,0),Vector2(60,0),Color("ff9f9f",a),18,true)
				c.draw_line(Vector2(0,-60),Vector2(0,60),Color("ff9f9f",a),18,true)
		"bullied_phantom":
			if fx == "do_not_tell":
				for i in 5: c.draw_line(Vector2(-85,-24+i*12),Vector2(85,-24+i*12),Color("dfd7dd",a),4,true)
			else: ART.stamp(c,"fx_infirmary_isolation",at,Vector2(430,360),a*0.6)
		"fist_phantom", "bruised_hand":
			var hand := id == "bruised_hand"
			var spread := (1-a)*40 if impact else sin(t*5)*10
			c.draw_rect(Rect2(-42,-22,84,68),Color("9e7da7",a*0.55))
			for i in (5 if hand else 4):
				var x := (i-2)*20.0
				c.draw_line(Vector2(x,-15),Vector2(x+(i-2)*spread*0.15,-60-(18 if hand and i in [1,2,3] else 0)),Color("d7b8cf",a),13,true)
			if impact:
				for side in [-1,1]:
					for i in 3: c.draw_line(Vector2(side*(62+i*10),-30+i*25),Vector2(side*(100+t*55),-45+i*30),Color("eed0eb",a),3,true)
		"whip_phantom":
			ART.stamp(c,"fx_phantom_whip",at,Vector2(330,240),a,-0.3+t*0.6)
		"shackle_phantom":
			ART.stamp(c,"fx_shackle_lock",at,Vector2.ONE*(210+80*a),a)
		"claustrophobic_box":
			ART.stamp(c,"fx_claustrophobic_compress",at,Vector2.ONE*(400-160*a if impact else 390),a)
			c.draw_set_transform(at)
			for side in [-1,1]:
				var x: float = side*(135-70*a)
				c.draw_polyline(PackedVector2Array([Vector2(x+side*30,-100),Vector2(x,-100),Vector2(x,100),Vector2(x+side*30,100)]),Color("c7eee2",a),4,true)
	c.draw_set_transform(Vector2.ZERO)

static func _art_token(c: CanvasItem, id: String, key: String, at: Vector2, a: float, t: float, impact: bool) -> void:
	var box := Vector2(360, 280)
	var angle := 0.0
	var shift := Vector2.ZERO
	match id:
		"paper_large", "ink_wolf":
			box = Vector2(440, 280) * Vector2(1 + (1-a)*0.3, 1)
			angle = -0.18 + (1-a)*0.32 if impact else -0.15
		"paper_small", "ink_wolf_echo":
			box = Vector2(230, 210)
			shift = Vector2(0, -sin(t*PI)*22)
		"noise":
			box = Vector2(400, 240) * Vector2(1+(1-a)*0.7, 0.82+sin(t*34)*0.06)
		"cupid":
			box = Vector2(350, 220)
			angle = -0.15
			shift.y = sin(t*5)*16
		"zeus_dean":
			box = Vector2(300, 460)
			shift.y = -80
		"biting_book":
			var gap := (1-a)*74 if impact else 28+sin(t*7)*13
			ART.stamp(c,"fx_book_upper",at+Vector2(0,-gap-30),Vector2(340,150),a)
			ART.stamp(c,"fx_book_lower",at+Vector2(0,gap+30),Vector2(340,150),a)
			return
		"nightmare":
			box = Vector2(330, 340) * Vector2(1.3-a*0.3,1)
			angle = sin(t*2)*0.06
		"math_exam":
			box = Vector2(390, 310) * Vector2(1,0.45+a*0.55)
		"perfect_score":
			box = Vector2(270, 270) * (0.78+a*0.25)
			angle = -0.09
		"gaokao_countdown":
			box = Vector2(310, 310)
			angle = floorf(t*6)*0.12
		"report_card":
			box = Vector2(370, 250)
			angle = sin(t*6)*0.12
		"quiet_hacker":
			box = Vector2(350, 240) * Vector2(1,0.93+fmod(t*12,1)*0.12)
			shift.x = (floorf(t*14) as int % 2)*12
		"magician_master":
			box = Vector2(370, 250)
			angle = sin(t*4)*0.14
		"self_destructive_pain":
			box = Vector2(390, 260) * (1+sin(t*22)*0.035)
		"infirmary_demon":
			box = Vector2(380, 240)
			shift.x = t*22 if impact else sin(t*2)*12
		"fist_phantom":
			box = Vector2(285, 285) * (0.8+a*0.25)
			angle = -0.22
		"bruised_hand":
			box = Vector2(270, 320) * Vector2(1,0.86+a*0.14)
			shift.y = -sin(t*PI)*25
	ART.stamp(c,key,at+shift,box,a,angle)
