extends Control
## Presentation owns input until the one release contact; rules own all combat state.
const X := preload("res://scripts/fight/enemy_expansion.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const SOUND := preload("res://scripts/ui/battle_finale_effect.gd")
const FONT := preload("res://assets/fonts/noto_serif_sc/semibold.tres")
# This legacy cut-in has vertically stretched figures baked into its 16:9 canvas.
# Correct the authored scene once, then keep camera and viewport scaling uniform.
const CG_ART_RECT := Rect2(0, -6, 1920, 810)
var battle: Node
var busy := false
var presentation_phase := "idle"
var dismiss := false
var cinematic: Control
var release_progress := 0.0
var recipients: Array[Vector2] = []
var button: Button
var age := 0.0

func _ready() -> void:
	name = "PhantomAssist"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1920, 1080)
	z_index = 90
	button = preload("res://scripts/ui/battle_phantom_assist_icon.gd").new()
	button.position = Vector2(1760, 754)
	button.pressed.connect(present)
	add_child(button)
	_update_button()

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	age += delta
	_update_button()
	queue_redraw()

func _update_button() -> void:
	var charge := 0
	var alive := false
	for enemy in FightSystem.enemies:
		if String(enemy.id) == "bullied_phantom" and FightSystem._is_alive(enemy):
			charge = int(enemy.get("assist_charge", 0))
			alive = true
	button.visible = alive and not busy
	button.disabled = busy or battle._turn_interaction_locked() or not X.can_resist(FightSystem)
	button.set("charges", charge)
	button.set("available", not button.disabled)
	button.tooltip_text = "站出来，反抗！ · 援助技\n充能 %d / 4 · %s\n击败每个召唤物充能1点，镣铐自行消散不充能。\n释放：全队存活角色终结技充满，清除在场幻影，本体生命不变。" % [charge, "已充满，点击释放" if charge >= 4 else "每亮一块代表1点充能"]

func accept_skip(event: InputEvent) -> void:
	if presentation_phase != "cg": return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]: dismiss = true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: dismiss = true

func present() -> void:
	if busy or battle._turn_interaction_locked() or not X.can_resist(FightSystem): return
	busy = true
	preload("res://scripts/ui/battle_generated_audio.gd").say(battle._effect_layer, "assist_phantom_resist", 3, "anya")
	release_progress = 0.0
	dismiss = false
	presentation_phase = "cg"
	FightSystem.cancel_targeting()
	battle._hide_status_popup()
	battle._clear_drag_visual()
	battle._refresh()
	cinematic = Control.new()
	cinematic.name = "PhantomResistanceCG"
	cinematic.z_index = 20
	cinematic.size = size
	cinematic.clip_contents = true
	cinematic.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cinematic)
	var backdrop := ColorRect.new()
	backdrop.color = Color("0b090f")
	backdrop.size = size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinematic.add_child(backdrop)
	var art := V.icon(cinematic, load("res://assets/graphics/battle/new_effects/fx_resist_cutin.webp"), CG_ART_RECT)
	art.name = "ResistanceIllustration"
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.pivot_offset = CG_ART_RECT.size * 0.5
	art.scale = Vector2.ONE * 1.035
	Settings.battle_tween(art).tween_property(art, "scale", Vector2.ONE, 2.8).set_trans(Tween.TRANS_SINE)
	var ink := ColorRect.new()
	ink.size = size
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){float a=smoothstep(0.51,0.75,UV.y); COLOR=vec4(0.043,0.035,0.059,a);}"
	material.shader = shader
	ink.material = material
	cinematic.add_child(ink)
	var typography := Control.new()
	typography.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinematic.add_child(typography)
	for item in [["援  助  技", Rect2(110, 760, 800, 44), 24], ["站出来，反抗！", Rect2(104, 813, 1350, 100), 72], ["全队终结技充满  /  幻影消散  /  本体生命不变", Rect2(112, 941, 1450, 40), 24]]:
		var label := V.text(typography, item[0], item[1], item[2], Color("ffe3ac"))
		label.add_theme_font_override("font", FONT)
	V.text(cinematic, "点击 / 空格 · 释放", Rect2(1560, 995, 310, 38), 20, Color("e7cfad"))
	typography.position = Vector2(-55, 12)
	typography.modulate.a = 0
	var reveal := Settings.battle_tween(self).set_parallel(true)
	reveal.tween_property(typography, "position", Vector2.ZERO, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(typography, "modulate:a", 1.0, 0.5)
	cinematic.modulate.a = 0
	Settings.battle_tween(self).tween_property(cinematic, "modulate:a", 1.0, 0.22)
	SOUND.sound(self, "dawn", -13)
	var elapsed := 0.0
	while elapsed < 2.8 and not (dismiss and elapsed >= 0.7):
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	await Settings.battle_tween(self).tween_property(cinematic, "modulate:a", 0.0, 0.3).finished
	cinematic.queue_free()
	cinematic = null
	presentation_phase = "release"
	recipients.clear()
	for i in FightSystem.allies.size():
		if FightSystem._is_alive(FightSystem.allies[i]): recipients.append((battle._target_rects["ally_%d" % i] as Rect2).get_center())
	await Settings.battle_tween(self).tween_property(self, "release_progress", 0.35, 0.45).finished
	var dissolve_actors: Array[TextureRect] = []
	for i in FightSystem.enemies.size():
		if String(FightSystem.enemies[i].id) in X.SUMMONS and FightSystem._is_alive(FightSystem.enemies[i]):
			var actor: TextureRect = battle._enemy_portraits.get(i)
			if is_instance_valid(actor):
				# Detach the visible body before the rules retire its combat slot.
				battle._enemy_portraits.erase(i)
				dissolve_actors.append(actor)
	var released := X.resist(FightSystem)
	if released:
		SOUND.sound(self, "dawn", -9)
		for actor in dissolve_actors: _dissolve(actor)
		for point in recipients:
			battle._vfx.play_effect("blessing", point, Vector2(1200, 550), true, 1, "phantom_assist", 0.0)
			battle._spawn_damage_number("终结技充满", point + Vector2(0, -90), Color("ffe3ac"), "ally", "assist", 32)
	await Settings.battle_tween(self).tween_property(self, "release_progress", 1.0, 3.5).finished
	presentation_phase = "idle"
	busy = false
	battle._refresh()

func _dissolve(actor: TextureRect) -> void:
	await actor.dissolve()
	if is_instance_valid(actor): actor.queue_free()

func _draw() -> void:
	if presentation_phase != "release": return
	var alpha := sin(release_progress * PI)
	var origin := Vector2(1200, 540)
	for ring in 4:
		draw_arc(origin, 50 + release_progress * 1000 + ring * 28, 0, TAU, 120, Color("ffdf9d", alpha * (0.34 - ring * 0.065)), 5 - ring, true)
	for point in recipients:
		var t := smoothstep(0.0, 0.4, release_progress)
		var head := origin.lerp(point, t)
		draw_line(origin.lerp(point, maxf(0, t - 0.3)), head, Color("ffe8bc", alpha * 0.8), 4, true)
		if release_progress > 0.3:
			draw_arc(point, 54 + release_progress * 45, 0, TAU, 64, Color("ffe4aa", alpha * 0.7), 3, true)
