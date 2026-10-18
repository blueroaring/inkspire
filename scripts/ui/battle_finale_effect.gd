extends Node2D
## Cinematic overlay; all damage remains in the existing contact callback.
const V := preload("res://scripts/ui/fc_card_visuals.gd")
var mode := "charge"
var progress := 0.0
var age := 0.0
var center := Vector2(1190, 400)
var color := Color("b5a0f2")
var ultimate := false
var points: Array[Vector2] = []
var heading: Label
var subheading: Label
var burst_age := -1.0
var actor_id := ""
var cutin_frames: SpriteFrames
var cutin_clip := "cast"
var dominion: ColorRect
var seal_count := 0
var source_actor: TextureRect
var projection: Sprite2D
const SERIF := preload("res://assets/fonts/noto_serif_sc/semibold.tres")
const VEIL := preload("res://assets/graphics/battle/finale/ui/abyss_veil.webp")
const ENERGY := preload("res://scripts/ui/battle_finale_energy.gd")
const SEALS := preload("res://scripts/ui/battle_finale_seals.gd")

static func sound(parent: Node, id: String, volume: float = -10.0) -> void:
	var player := AudioStreamPlayer.new()
	player.name = "FinaleSound_" + id
	player.stream = load("res://assets/audio/sfx/finale/%s.wav" % id)
	player.volume_db = volume
	if AudioServer.get_bus_index("SFX") >= 0: player.bus = "SFX"
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _ready() -> void:
	name = "FinaleCinematic"
	ENERGY.prepare()
	# Node2D has no mouse surface; battle's animation lock owns input.
	set_process(true)

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	age += delta
	if burst_age >= 0: burst_age += delta
	if is_instance_valid(dominion):
		if is_instance_valid(source_actor) and mode == "charge": source_actor.hide()
		_update_projection()
		dominion.material.set_shader_parameter("elapsed", age)
		dominion.material.set_shader_parameter("pressure", progress)
		dominion.material.set_shader_parameter("release", burst_age)
		if ultimate and mode == "charge":
			var closed := mini(5, int(progress * 5.5))
			if closed > seal_count:
				seal_count = closed
				sound(self,"seal",-15.0+closed)
	queue_redraw()

func windup(actor: TextureRect, intent: Dictionary) -> void:
	actor_id = actor.enemy_id
	ultimate = String(intent.get("effect", "")) == "ultimatum"
	if actor_id == "terminal_echo" and actor.has_node("EnemyBodyAnimation"):
		cutin_frames = actor.get_node("EnemyBodyAnimation").sprite_frames
		cutin_clip = actor.motion_name
	var boss := actor_id == "terminal_echo"
	color = Color("ffd2a1") if actor_id == "false_dawn" else Color("83c9e5") if actor_id == "terminal_choir" else Color("c5a2ef")
	if ultimate: color = Color("ff9da9")
	center = actor.rest_position + actor.size * Vector2(0.5, 0.4)
	if boss:
		source_actor = actor
		source_actor.hide()
		dominion = ColorRect.new()
		dominion.name = "AbyssScreenPressure"
		dominion.size = Vector2(1920,1080)
		dominion.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dominion.z_index = -2
		var shader := ShaderMaterial.new()
		shader.shader = preload("res://scripts/ui/finale_dominion.gdshader")
		shader.set_shader_parameter("power",1.0 if ultimate else 0.72)
		shader.set_shader_parameter("focus",center/Vector2(1920,1080))
		dominion.material = shader
		add_child(dominion)
		projection = Sprite2D.new()
		projection.name = "BossPoseProjection"
		projection.centered = false
		projection.z_index = -1
		projection.material = source_actor.material
		add_child(projection)
		_update_projection()
	heading = V.text(self, String(intent.get("name", "")), Rect2(540, 122, 1260, 76), 54 if ultimate else 38, color, true)
	heading.add_theme_constant_override("outline_size", 10)
	heading.add_theme_color_override("font_outline_color", Color("080c19"))
	subheading = V.text(self, "最  后  通  牒    /    全  队  真  伤" if ultimate else "终  末  回  响" if boss else "低  语  正  在  汇  聚" if actor_id == "whisper_silhouette" else "终  末  合  唱" if actor_id == "terminal_choir" else "虚  假  的  黎  明", Rect2(600, 193, 1140, 42), 20, Color("d6c9d9"), true)
	heading.modulate.a = 0
	subheading.modulate.a = 0
	heading.hide()
	subheading.hide()
	var skill_title := preload("res://scripts/ui/battle_enemy_title.gd").new()
	skill_title.skill = String(intent.get("name",""))
	skill_title.rank = 2 if ultimate else 1 if boss else 0
	skill_title.tint = color
	skill_title.caption = "终  末  回  响  ·  全  队  真  伤" if ultimate else subheading.text
	skill_title.position = Vector2(590, 90) if boss else Vector2(710, 108)
	skill_title.size = Vector2(1160,200) if boss else Vector2(920,160)
	add_child(skill_title)
	sound(self, "abyss_charge" if ultimate else "choir" if boss or actor_id == "terminal_choir" else "dawn" if actor_id == "false_dawn" else "whisper", -8 if ultimate else -13)
	var seconds := 3.65 if ultimate else 2.05 if boss else 1.15
	var tween := Settings.battle_tween(self).set_parallel(true)
	tween.tween_property(self, "progress", 1.0, seconds).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(actor, "motion_frame", 2.0, seconds*0.6)
	tween.tween_property(actor, "scale", Vector2.ONE*(1.16 if ultimate else 1.07), seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_property(actor, "position", actor.rest_position+Vector2(0,-28 if boss else -16), seconds)
	tween.tween_property(heading, "modulate:a", 1.0, 0.3)
	tween.tween_property(subheading, "modulate:a", 1.0, 0.5).set_delay(0.2)
	await tween.finished
	# Brief held apex, then a sharp release instead of equal timing for every pose.
	await Settings.battle_timer(0.32 if ultimate else 0.12).timeout

func impact(targets: Array[Vector2]) -> void:
	points = targets
	burst_age = 0.0
	mode = "impact"
	sound(self, "abyss_impact" if ultimate else "impact", -7 if ultimate else -15)

func finish() -> void:
	if ultimate: await Settings.battle_timer(0.38).timeout
	if is_instance_valid(source_actor): source_actor.show()
	var tween := Settings.battle_tween(self)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(source_actor): source_actor.show()

func _update_projection() -> void:
	if not is_instance_valid(projection) or not is_instance_valid(source_actor): return
	var body: AnimatedSprite2D = source_actor.get_node("EnemyBodyAnimation")
	projection.texture = body.sprite_frames.get_frame_texture(body.animation,body.frame)
	var extent := lerpf(1050,1500,progress) if ultimate else lerpf(900,1120,progress)
	projection.scale = Vector2.ONE*extent/projection.texture.get_width()
	projection.position = center-Vector2(extent*.5,extent*.52)
	var fade := minf(1,age*1.6)*(1.0 if burst_age<0 else maxf(0,1-burst_age/.85))
	projection.modulate = Color(.87,.63,.94,fade*.94)

func _ring(c: Vector2, radius: float, alpha: float, spin: float, width: float = 2.0) -> void:
	for k in 3:
		var start := spin + k*TAU/3
		draw_arc(c, radius, start, start+1.65, 40, Color(color, alpha), width, true)
	for k in 12:
		var direction := Vector2.from_angle(k*TAU/12+spin)
		draw_line(c+direction*(radius-5), c+direction*(radius+5), Color(color,alpha),1.5,true)

func _draw() -> void:
	if mode == "summon":
		draw_rect(Rect2(0,0,1920,1080),Color(0.015,0.018,0.045,0.42*sin(progress*PI)))
		for i in points.size():
			var c: Vector2 = points[i]
			var p := clampf((progress-i*0.08)*1.3,0,1)
			var alpha := sin(p*PI)
			ENERGY.vortex(self,c,150*sqrt(p),color,age,alpha,.28)
			draw_set_transform(c,0,Vector2(1,0.28))
			draw_circle(Vector2.ZERO,95*sqrt(p),Color("030815",alpha))
			_ring(Vector2.ZERO,100*sqrt(p),alpha,age,3)
			_ring(Vector2.ZERO,125*sqrt(p),alpha*0.5,-age*0.7,2)
			draw_set_transform(Vector2.ZERO)
			for k in 20:
				var d := Vector2(sin(k*4.7)*85, -fmod(age*130+k*17,210))
				draw_line(c+d,c+d+Vector2(0,16),Color(color,alpha*(0.2+0.5*float(k%3)/3)),2,true)
		return
	if actor_id == "terminal_echo":
		_draw_dominion()
		return
	var weight := (0.45 if ultimate else 0.25)*minf(1,age*2)
	if mode == "impact": weight *= maxf(0,1-burst_age*2)
	draw_rect(Rect2(0,0,1920,1080),Color(0.008,0.01,0.028,weight))
	if mode == "charge":
		if ultimate and cutin_frames != null:
			var opacity := minf(1,age*2.0)
			var silhouette := cutin_frames.get_frame_texture("cast", mini(2, int(progress*3)))
			var panel := PackedVector2Array([Vector2(420,100),Vector2(1000,100),Vector2(850,780),Vector2(270,780)])
			draw_colored_polygon(panel,Color(0.03,0.025,0.07,0.82*opacity))
			draw_texture_rect(silhouette,Rect2(250+progress*55,70,780,780),false,Color(0.85,0.65,0.95,opacity))
			draw_line(Vector2(420,100),Vector2(1000,100),Color(color,opacity),3,true)
			draw_line(Vector2(270,780),Vector2(850,780),Color(color,opacity),3,true)
		ENERGY.vortex(self,center,lerpf(145,90,progress),color,age,.45+progress*.45)
		for i in 6:
			var angle := i*TAU/6+age*.25
			var start := center+Vector2.from_angle(angle)*(220-progress*80)*Vector2(1,.72)
			ENERGY.ribbon(self,start,center,38+progress*40,color,age+i,.25+progress*.45)
		if actor_id == "terminal_choir":
			for i in 3: ENERGY.vortex(self,center+Vector2((i-1)*62,-35),58,color,age+i,.5,.65)
		elif actor_id == "false_dawn":
			for i in 8:
				var d := Vector2.from_angle(i*TAU/8+age*.1)
				ENERGY.ribbon(self,center+d*30,center+d*(90+progress*70),35,color,age+i,.65)
		if ultimate:
			# Large countdown seals close around the boss before the party-wide strike.
			for i in 5:
				var a := -PI/2+i*TAU/5
				var p := center+Vector2.from_angle(a)*(180-progress*45)
				draw_circle(p,12,Color(color,0.2))
				draw_arc(p,14,0,TAU,24,Color(color,0.9),2,true)
				draw_line(p-Vector2(5,5),p+Vector2(5,5),color,2,true)
			draw_rect(Rect2(0,0,1920,48),Color(0.01,0.01,0.02,0.8))
			draw_rect(Rect2(0,1032,1920,48),Color(0.01,0.01,0.02,0.8))
	else:
		var a := maxf(0,1-burst_age/0.65)
		if ultimate: draw_rect(Rect2(0,0,1920,1080),Color(color,0.23*maxf(0,1-burst_age/0.12)))
		if ultimate:
			for i in 18:
				var d := Vector2.from_angle(i*2.399)
				var crack := PackedVector2Array([center+d*70,center+d*250+d.orthogonal()*35,center+d*420-d.orthogonal()*18,center+d*800])
				draw_polyline(crack,Color(color,a*.35),12,true)
				draw_polyline(crack,Color("fff0dc",a*.8),2,true)
		_ring(center,50+burst_age*700,a*0.65,age,5)
		for target in points:
			ENERGY.ribbon(self,center,target,95,color,age,a*.75)
			ENERGY.vortex(self,target,65+burst_age*110,color,age*2,a)

func _draw_dominion() -> void:
	var strength := 1.0 if ultimate else 0.65
	var enter := minf(1,age*1.6)
	var release_fade := 1.0 if burst_age<0 else maxf(0,1-burst_age/0.85)
	var ink := Color("03020b",enter*release_fade)
	# Two hand-painted planes drift at different depths as the sky closes in.
	for depth in 2:
		var zoom := lerpf(1.20,1.0,progress)+depth*.08
		var dimensions := Vector2(1920,1080)*zoom
		var drift := Vector2(sin(age*.32+depth)*13,cos(age*.27+depth)*9)
		var veil_area := Rect2(Vector2(960,540)-dimensions*.5+drift,dimensions)
		draw_texture_rect(VEIL,veil_area,false,Color(.83,.62,.83,enter*release_fade*strength*(.87 if depth==0 else .16)))
	# The projection shares the actor's continuous pose shader, without ghost duplicates.
	# Serrated black curtains press in from the edges; each has an independent path.
	for i in 8:
		var angle := i*TAU/8+.12
		var d := Vector2.from_angle(angle)
		var cross := d.orthogonal()
		var reach := lerpf(810,410+sin(i*3.1)*90,progress)*Vector2(1.35,.85)
		var tip := center+d*reach
		var outer := center+d*Vector2(1500,1000)
		var spine := center+d*(reach+Vector2(180,150))+cross*sin(age*.7+i)*45
		var polygon := PackedVector2Array([outer-cross*18,spine-cross*9,tip,spine+cross*3,outer+cross*15])
		draw_colored_polygon(polygon,Color(ink,.4*enter*release_fade))
	if mode == "charge":
		ENERGY.vortex(self,center+Vector2(0,65),lerpf(190,115,progress)*strength,color,age,.5+progress*.4)
		for i in 7:
			var d := Vector2.from_angle(i*TAU/7-age*.2)
			var start := center+Vector2(0,65)+d*(350-progress*120)*Vector2(1,.75)
			ENERGY.ribbon(self,start,center+Vector2(0,65),48+progress*40,color,age+i,enter*(.25+progress*.35))
		# Perspective debris travels toward the camera, against the inward smoke.
		for i in 62:
			var phase := fmod(age*.18+i*.071,1)
			var direction := Vector2.from_angle(i*2.399)
			var p := center+direction*(130+pow(phase,2)*1100)*Vector2(1,.68)
			var sz := (2+pow(phase,3)*18)*strength
			var shard := PackedVector2Array([p-direction*sz*3,p+direction.orthogonal()*sz*.6,p+direction*sz,p-direction.orthogonal()*sz])
			draw_colored_polygon(shard,Color("0a0613",enter*.9))
			draw_line(shard[0],shard[1],Color("e386a0",phase*.5*enter),1,true)
		if ultimate:
			SEALS.draw_seals(self,center,progress,age,burst_age)
			# A thin vertical tear opens at the apex, anticipating the strike axis.
			var tear := smoothstep(.65,1.0,progress)
			draw_line(center-Vector2(0,390),center+Vector2(0,440),Color("be235a",tear*.26),24*tear+1,true)
			draw_line(center-Vector2(0,390),center+Vector2(0,440),Color("ffe3df",tear*.85),2,true)
	else:
		var fade := maxf(0,1-burst_age/.95)
		if ultimate: SEALS.draw_seals(self,center,progress,age,burst_age)
		# Wide shock front, then a torn white-hot shaft across each victim.
		for target in points:
			var tip := target+Vector2(0,75)
			var top := Vector2(target.x+170,-80)
			ENERGY.ribbon(self,top,tip,220 if ultimate else 110,Color("f298c6"),age*3,fade)
			ENERGY.ribbon(self,top+Vector2(34,0),tip,350 if ultimate else 180,Color("9e59cf"),-age*2,fade*.4)
			ENERGY.vortex(self,tip,100+burst_age*140,Color("ffb6c5"),age*2,fade,.6)
			for j in 8:
				var d := Vector2.from_angle(j*2.399)
				var shards := PackedVector2Array([tip+d*35,tip+d*(150+burst_age*600)+d.orthogonal()*13,tip+d*(110+burst_age*500)])
				draw_colored_polygon(shards,Color("f4b6c2",fade*.6))
		for i in 7:
			var d := Vector2.from_angle(i*2.399)
			ENERGY.ribbon(self,center+d*35,center+d*1500,70,Color("d389d8"),age+i,fade*.55)
		ENERGY.vortex(self,center,140+burst_age*600,Color("e799d9"),age,fade*.8)
	var bars := (88 if ultimate else 48)*enter*release_fade
	draw_rect(Rect2(0,0,1920,bars),Color("020208",.96))
	draw_rect(Rect2(0,1080-bars,1920,bars),Color("020208",.96))
