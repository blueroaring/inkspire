extends Node2D
## Constricting breath, hostile attention and a closing cage for each phase.
const ART := preload("res://scripts/ui/battle_enemy_art.gd")
var mode := "idle"
var progress := 0.0
var age := 0.0
var center := Vector2.ZERO
var points: Array[Vector2] = []
var stage := 1
var effect := ""

func _ready() -> void:
	name = "PanicBossEffect"
	z_index = 48

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	age += delta
	queue_redraw()

func rebirth(actor: TextureRect, next_stage: int) -> void:
	stage = next_stage
	center = actor.rest_position + actor.size * Vector2(0.5, 0.45)
	mode = "collapse"
	progress = 0.0
	preload("res://scripts/ui/battle_enemy_audio.gd").emit(get_parent(), "panic_throat", "collapse")
	actor.animating = true
	var fall := Settings.battle_tween(self).set_parallel(true)
	fall.tween_property(actor, "modulate:a", 0.0, 0.46)
	fall.tween_property(actor, "scale", Vector2(0.78, 0.62), 0.46).set_trans(Tween.TRANS_CUBIC)
	fall.tween_property(self, "progress", 1.0, 0.46)
	await fall.finished
	mode = "rebirth"
	progress = 0.0
	preload("res://scripts/ui/battle_enemy_audio.gd").emit(get_parent(), "panic_throat", "rebirth")
	preload("res://scripts/ui/battle_generated_audio.gd").of(get_parent()).rebirth("panic_throat", next_stage)
	var title := preload("res://scripts/ui/battle_enemy_title.gd").new()
	title.skill = "百舌嘲心" if next_stage == 2 else "孤影囚笼"
	title.caption = "第 二 阶 段 · 苏 生" if next_stage == 2 else "第 三 阶 段 · 苏 生"
	title.rank = 2
	title.tint = Color("bfc37f") if next_stage == 2 else Color("86c1ce")
	title.position = Vector2(510, 76)
	title.size = Vector2(660, 155)
	add_child(title)
	actor.position = actor.rest_position + Vector2(0, 38)
	var rise := Settings.battle_tween(self).set_parallel(true)
	rise.tween_property(actor, "modulate:a", 1.0, 0.65).set_delay(0.15)
	rise.tween_property(actor, "scale", Vector2.ONE, 0.72).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(actor, "position", actor.rest_position, 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.tween_property(self, "progress", 1.0, 0.72)
	await rise.finished
	actor.reset_pose()
	queue_free()

func windup(actor: TextureRect, intent: Dictionary) -> void:
	stage = int(intent.get("boss_phase", 1))
	effect = String(intent.get("effect", ""))
	center = actor.rest_position + actor.size * Vector2(0.5, 0.4)
	mode = "windup"
	progress = 0.0
	var duration := 1.05 if effect in ["summon", "nightmare_entry", "cage"] else 0.62
	var tween := Settings.battle_tween(self).set_parallel(true)
	tween.tween_property(self, "progress", 1.0, duration)
	tween.tween_property(actor, "motion_frame", 2.0, duration * 0.7)
	tween.tween_property(actor, "scale", Vector2.ONE * (1.09 if effect in ["summon", "nightmare_entry", "cage"] else 1.04), duration)
	await tween.finished

func impact(targets: Array[Vector2]) -> void:
	points = targets
	mode = "impact"
	progress = 0.0
	# Start on the same frame as the snapshot contact; do not await a finished hit.
	Settings.battle_tween(self).tween_property(self, "progress", 1.0, 0.48)

static func summon_at(parent: Node, at: Vector2, alternate: bool = false) -> void:
	preload("res://scripts/ui/battle_enemy_audio.gd").emit(parent, "panic_throat", "summon")
	var portal := Node2D.new()
	portal.name = "PanicSummonPortal"
	parent.add_child(portal, true)
	var art := Sprite2D.new()
	art.texture = ART.texture("panic/panic_summon_right" if alternate else "panic/panic_summon_left")
	portal.add_child(art)
	portal.position = at
	art.scale = Vector2(0.35, 0.12)
	art.modulate.a = 0.0
	var rise := Settings.battle_tween(portal).set_parallel(true)
	rise.tween_property(art, "modulate:a", 1.0, 0.12)
	rise.tween_property(art, "scale", Vector2(0.45, 0.45), 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.chain().tween_interval(0.18)
	rise.chain().tween_property(art, "modulate:a", 0.0, 0.35)
	rise.chain().tween_callback(portal.queue_free)

func finish() -> void:
	await Settings.battle_tween(self).tween_property(self, "modulate:a", 0.0, 0.22).finished
	queue_free()

func _draw() -> void:
	if mode == "idle": return
	var pulse := sin(progress * PI)
	if mode == "collapse":
		draw_rect(Rect2(0, 0, 1920, 1080), Color("090d22", pulse * 0.32))
		ART.stamp(self, "panic/panic_collapse", center, Vector2.ONE * lerpf(620, 90, progress), pulse, progress * 0.6)
	elif mode == "rebirth":
		draw_rect(Rect2(0, 0, 1920, 1080), Color("090d22", (1.0 - progress) * 0.24))
		ART.stamp(self, "panic/panic_rebirth", center + Vector2(0, 30), Vector2(570, lerpf(80, 640, progress)), minf(1, (1-progress)*3.5))
		if stage == 2:
			ART.stamp(self, "panic/panic_doubt", center + Vector2(0, -70), Vector2(740, 440), pulse * 0.8)
		else:
			ART.stamp(self, "panic/panic_cage", center, Vector2.ONE * 580, pulse * 0.75)
	elif mode == "windup":
		draw_rect(Rect2(0, 0, 1920, 1080), Color("0a0c20", progress * 0.19))
		var key := "guard" if effect in ["panic_guard", "island"] else "cage" if effect == "cage" else "doubt" if effect in ["summon", "weakness"] else "nightmare" if effect == "nightmare_entry" else "silence" if effect == "silence" else "pierce" if effect == "pierce" else "whip_upper"
		var box := Vector2(610, 520) if effect in ["island", "cage", "summon", "nightmare_entry"] else Vector2(420, 350)
		ART.stamp(self, "panic/panic_" + key, center, box * lerpf(1.2, 0.92, progress), progress * 0.85, sin(age * 2) * 0.035)
	elif mode == "impact":
		var key := "guard" if effect in ["panic_guard", "island"] else "cage" if effect == "cage" else "nightmare" if effect == "nightmare_entry" else "doubt" if effect in ["weakness", "summon"] else "silence" if effect == "silence" else "pierce" if effect == "pierce" else "whip_lower"
		var locations := points.duplicate()
		if locations.is_empty(): locations.append(center)
		for at: Vector2 in locations:
			var box := Vector2(330, 310) if key != "cage" else Vector2(350, 440)
			var squeeze := Vector2(lerpf(1.35, 0.72, progress), 1.0) if key in ["silence", "cage"] else Vector2.ONE * lerpf(0.7, 1.22, progress)
			ART.stamp(self, "panic/panic_" + key, at, box * squeeze, 1.0 - progress)
		if effect == "panic_guard": ART.stamp(self, "panic/panic_guard", center, Vector2.ONE * 480, 1-progress)
