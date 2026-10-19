extends Control
const RULES := preload("res://scripts/fight/finale_rules.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const ROOT := "res://assets/graphics/battle/finale/"
const CHAPTER_BANNERS := [
	ROOT + "ui/chapter_banner_stage_1.webp",
	ROOT + "ui/chapter_banner_stage_2.webp",
	ROOT + "ui/chapter_banner.webp",
]
const SKILL_FX := preload("res://scripts/ui/anya_skill_fx.gd")
const CG_FONT := preload("res://assets/fonts/noto_serif_sc/semibold.tres")
const SKILL_STYLE := {
	"anya_step": {"color":"f4d1ad", "note":"边缘 −1  /  抽一张牌"},
	"anya_wait": {"color":"ffdc94", "note":"坚毅 +1  /  抵挡一次离场"},
	"anya_resist": {"color":"ffe4ae", "note":"负面免疫 +1"},
	"anya_reconcile": {"color":"ffe5be", "note":"净化一个负面效果"},
	"anya_defy": {"color":"ffda8c", "note":"全队永久强化  /  敌方全体眩晕"},
	"anya_refuse": {"color":"ffe3ae", "note":"希望 +1"},
}
const EFFECT := preload("res://scripts/ui/battle_finale_effect.gd")
var battle: Node
var busy := false
var meters: Control
var defiance: Button
var answer: Button
var answer_glow_age := 0.0
var music_stage := 0
var pending_waves: Array = []
var cinematic: Control
var dismiss := false
var release_fx: Control
var presentation_phase := "idle"
var revealed_waves: Dictionary = {}
var summon_history: Array[int] = []
var visual_caps: Dictionary = {}
var visual_hp: Dictionary = {}
var visual_forms: Dictionary = {}
var wave_phase := "idle"
var victory_started := false
var victory_finished := false

func play_victory_dissolve() -> void:
	if victory_started: return
	victory_started = true
	busy = true
	presentation_phase = "dissolve"
	# Clear the enemy's bars and intent while retaining the actor for its exit.
	battle._refresh()
	Settings.battle_tween(self).tween_property(meters, "modulate:a", 0.0, 0.6)
	var actor: TextureRect = battle._enemy_portraits.get(FightSystem.enemies.find(RULES.boss(FightSystem)))
	if is_instance_valid(actor): await actor.dissolve()
	await Settings.battle_timer(0.45).timeout
	victory_finished = true
	presentation_phase = "finished"
	busy = false

func _ready() -> void:
	name = "FinaleEncounter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	meters = preload("res://scripts/ui/battle_finale_meters.gd").new()
	meters.position = Vector2(534, 768)
	add_child(meters)
	defiance = preload("res://scripts/ui/battle_defiance_button.gd").new()
	defiance.name = "FinaleDefiance"
	defiance.position = Vector2(1558, 776)
	defiance.pressed.connect(func() -> void:
		if battle._turn_interaction_locked(): return
		if preload("res://scripts/ui/tower_mobile.gd").enabled() and bool(Settings.get_value("battle", "touch_confirm_commands", true)):
			preload("res://scripts/ui/tower_mobile.gd").instance().show_help("我不接受这样的结局", defiance.tooltip_text, "确认释放", func(): present("anya_defy", func(): RULES.defy(FightSystem)))
		else: present("anya_defy", func() -> void: RULES.defy(FightSystem))
	)
	add_child(defiance)
	answer = Button.new()
	answer.name = "FinaleAnswer"
	answer.text = "李安雅 · 不，我拒绝！"
	answer.position = Vector2(1644, 793)
	answer.size = Vector2(232, 46)
	answer.add_theme_font_size_override("font_size", 20)
	answer.pressed.connect(func() -> void:
		if battle._turn_interaction_locked(): return
		for i in FightSystem.hand.size():
			if FightSystem.hand[i].skill_id == "anya_refuse":
				FightSystem.play_card(i)
				return
		# The final answer remains available if another skill moved/exhausted its card.
		var e := RULES.boss(FightSystem)
		if not e.is_empty() and bool(e.final_ready):
			present("anya_refuse", func() -> void: RULES.support(FightSystem, "anya_refuse", 0))
	)
	add_child(answer)
	for button in [answer]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("352b31") if state == "normal" else Color("584442") if state == "hover" else Color("201d29")
			style.border_color = Color("e8c78d") if state != "disabled" else Color("766b75")
			style.set_border_width_all(2)
			style.set_corner_radius_all(8)
			button.add_theme_stylebox_override(state, style)
		button.add_theme_color_override("font_color", Color("ffe8b4"))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.tooltip_text = "永久最终增伤25%、最终减伤15%、护盾强效30%，敌方全体眩晕一回合；每次转阶段获得一次使用机会。" if button == defiance else "释放李安雅的最后一张协助牌，将希望从9提升到10。"
	if preload("res://scripts/ui/tower_mobile.gd").enabled():
		defiance.scale = Vector2.ONE * 2
		defiance.position = Vector2(1710, 712)
		answer.position = Vector2(1200, 712)
		answer.size = Vector2(480, 144)
		answer.add_theme_font_size_override("font_size", 36)
	FightSystem.finale_presentation = present
	FightSystem.finale_event.connect(_event)
	for ally in FightSystem.allies:
		visual_caps[String(ally.id)] = float(ally.max_hp)
		visual_hp[String(ally.id)] = float(ally.max_hp)
		visual_forms[String(ally.id)] = bool(ally.get("anya_phoenix", false))
	pending_waves.append(int(RULES.boss(FightSystem).boss_phase))

func _exit_tree() -> void:
	if FightSystem.finale_presentation == Callable(self, "present"): FightSystem.finale_presentation = Callable()

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	var e := RULES.boss(FightSystem)
	if e.is_empty(): return
	meters.update_values(e)
	_update_health_bars()
	defiance.visible = int(e.defiance) > 0 and presentation_phase == "idle"
	defiance.charges = int(e.defiance)
	defiance.first_gain = int(e.defiance) > 0 and not FightSystem.allies.any(func(ally: Dictionary) -> bool: return int(ally.get("finale_defiance", 0)) > 0)
	defiance.tooltip_text = "我不接受这样的结局 · 可用 %d 次\n永久最终增伤25%%、最终减伤15%%、护盾强效30%%，敌方全体眩晕一回合；每次转阶段获得一次使用机会。" % e.defiance
	defiance.disabled = battle._turn_interaction_locked() or not FightSystem.battle_active or FightSystem.phase != FightSystem.PLAYER_TURN
	answer.visible = bool(e.final_ready) and presentation_phase == "idle"
	answer.disabled = battle._turn_interaction_locked() or not FightSystem.battle_active or FightSystem.phase != FightSystem.PLAYER_TURN
	answer_glow_age += delta
	var answer_highlight := answer.visible and not answer.disabled
	for state in ["normal", "hover", "pressed"]:
		var style := answer.get_theme_stylebox(state) as StyleBoxFlat
		style.shadow_size = 12 if answer_highlight else 0
		style.shadow_color = Color("ffd98c", 0.25 + 0.25 * (0.5 + 0.5 * sin(answer_glow_age * 3.8)))
		style.border_color = Color("ffe6aa") if answer_highlight else Color("e8c78d")
		style.set_border_width_all(3 if answer_highlight else 2)
	var stage := int(e.boss_phase)
	if stage != music_stage:
		music_stage = stage
		if battle.play_encounter_music: Music.play(["finale_descent", "finale_resistance", "finale_dawn"][stage - 1], 1.8)
	if not busy and not pending_waves.is_empty() and not battle._turn_interaction_locked():
		var wave: int = pending_waves.pop_front()
		show_wave(wave)

func _event(kind: String, data: Dictionary) -> void:
	if kind == "wave": pending_waves.append(int(data.stage))
	elif kind == "edge_hit":
		var text := V.text(self, "攻击本体  ·  边缘 +1", Rect2(790, 620, 700, 56), 28, Color("ffc1cb"), true)
		text.z_index = 120
		var tween := Settings.battle_tween(self).set_parallel(true)
		tween.tween_property(text, "position:y", 580.0, 1.0)
		tween.tween_property(text, "modulate:a", 0.0, 0.5).set_delay(0.65)
		tween.chain().tween_callback(text.queue_free)

func show_wave(stage: int) -> void:
	busy = true
	wave_phase = "chapter"
	await _chapter_announcement(stage)
	wave_phase = "summon"
	revealed_waves[stage] = true
	summon_history.append(stage)
	var fx := EFFECT.new()
	fx.mode = "summon"
	fx.color = [Color("b998ed"), Color("8fcedd"), Color("edc997")][stage-1]
	battle._effect_layer.add_child(fx)
	EFFECT.sound(fx, "summon", -11)
	var tween := Settings.battle_tween(self).set_parallel(true)
	tween.tween_property(fx, "progress", 1.0, 2.4)
	var boss_actor: TextureRect = battle._enemy_portraits.get(0)
	if is_instance_valid(boss_actor):
		boss_actor.begin_action("cast")
		tween.tween_property(boss_actor,"motion_frame",5.0,2.2)
	for index in battle._enemy_portraits:
		var unit: Dictionary = FightSystem.enemies[index]
		if int(unit.get("finale_wave",0)) != stage: continue
		var actor: TextureRect = battle._enemy_portraits[index]
		var home: Vector2 = actor.rest_position
		fx.points.append(home+Vector2(actor.size.x*0.5,actor.size.y))
		actor.animating = true
		actor.modulate.a = 0.0
		actor.position = home + Vector2(0,70)
		actor.scale = Vector2(0.7,0.25)
		var delay := 0.45+int(unit.finale_slot)*0.18
		tween.tween_property(actor,"position",home,1.15).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(actor,"scale",Vector2.ONE,1.15).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(actor,"modulate:a",1.0,0.8).set_delay(delay)
	await tween.finished
	for index in battle._enemy_portraits:
		var actor: TextureRect = battle._enemy_portraits[index]
		if is_instance_valid(actor) and actor.animating: actor.reset_pose()
	await fx.finish()
	wave_phase = "seal"
	await _seal_health(stage)
	wave_phase = "idle"
	busy = false
	battle._refresh()

func _chapter_announcement(stage: int) -> void:
	var root := Control.new()
	root.name = "FinaleChapterAnnouncement"
	root.position = Vector2(540, 172)
	root.size = Vector2(1260, 445)
	root.pivot_offset = root.size * .5
	root.z_index = 130
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var banner := V.icon(root, load(CHAPTER_BANNERS[clampi(stage, 1, 3) - 1]), Rect2(Vector2.ZERO,root.size))
	banner.name = "ChapterBannerArt"
	banner.stretch_mode = TextureRect.STRETCH_SCALE
	var title := V.text(root,"第  %s  幕" % ["一","二","三"][stage-1],Rect2(280,158,700,38),25,Color("cbb994"),true)
	title.add_theme_font_override("font",CG_FONT)
	var name_label := V.text(root,["低 语 剪 影","终 末 合 唱","假 黎 明"][stage-1],Rect2(240,198,780,65),44,Color("f4e5c5"),true)
	name_label.add_theme_font_override("font",CG_FONT)
	var note := V.text(root,["夜空无声  ·  深渊低语","我仍在这里  ·  回响成潮","拒绝终末  ·  黎明将至"][stage-1],Rect2(280,267,700,35),20,Color("bcb6cb"),true)
	note.add_theme_font_override("font",CG_FONT)
	root.modulate.a = 0
	root.scale = Vector2.ONE*.91
	var enter := Settings.battle_tween(self).set_parallel(true)
	enter.tween_property(root,"modulate:a",1.0,.4)
	enter.tween_property(root,"scale",Vector2.ONE,.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await enter.finished
	await Settings.battle_timer(.7).timeout
	await Settings.battle_tween(self).tween_property(root,"modulate:a",0.0,.35).finished
	root.queue_free()

func health_view(ally: Dictionary) -> Dictionary:
	var id := String(ally.id)
	var phoenix := bool(ally.get("anya_phoenix", false))
	if visual_forms.get(id, false) != phoenix:
		# The same character ID now represents a different body and health pool.
		visual_forms[id] = phoenix
		visual_caps[id] = float(FightSystem.healing_ceiling(ally))
		visual_hp[id] = float(ally.hp)
	var cap := minf(float(ally.max_hp), float(visual_caps.get(id, FightSystem.healing_ceiling(ally))))
	var pending := absf(cap - FightSystem.healing_ceiling(ally)) > .05 or wave_phase == "seal"
	return {"cap":cap, "hp":float(visual_hp.get(id,ally.hp)) if pending else float(ally.hp)}

func _update_health_bars() -> void:
	var shown: Array = battle._confusion_display_allies if not battle._confusion_display_allies.is_empty() else battle._enemy_display_allies if battle._enemy_damage_staged else FightSystem.allies
	for i in shown.size():
		var ally: Dictionary = shown[i]
		var view := health_view(ally)
		if wave_phase != "seal" and absf(float(view.cap)-FightSystem.healing_ceiling(ally)) <= .05:
			visual_hp[String(ally.id)] = float(ally.hp)
		if bool(ally.get("anya_phoenix", false)):
			var frame: Control = battle._ui.get_node_or_null("AnyaPhoenixFrame")
			if is_instance_valid(frame): frame.update_health(view)
			continue
		var sealed: ColorRect = battle.find_child("FinaleSealedHP_%d" % i,true,false)
		if not is_instance_valid(sealed): continue
		var holder: Control = sealed.get_parent()
		var w := holder.size.x
		sealed.position.x = w * float(view.cap)/float(ally.max_hp)
		sealed.size.x = maxf(0,w-sealed.position.x)
		var fill: Control = holder.get_node("Fill")
		fill.size.x = w*clampf(float(view.hp)/float(ally.max_hp),0,1)
		for child in holder.get_children():
			if child is Label: child.text = "%d / %d" % [roundi(float(view.hp)),ally.max_hp]

func _seal_health(stage: int) -> void:
	EFFECT.sound(self,"whisper",-15)
	var tween := Settings.battle_tween(self).set_parallel(true)
	var notices: Array[Control] = []
	for i in FightSystem.allies.size():
		var ally: Dictionary = FightSystem.allies[i]
		var id := String(ally.id)
		var from := Vector2(float(visual_caps.get(id,ally.max_hp)),float(visual_hp.get(id,ally.hp)))
		var to := Vector2(FightSystem.healing_ceiling(ally),ally.hp)
		tween.tween_method(func(value: Vector2) -> void:
			visual_caps[id] = value.x
			visual_hp[id] = value.y
		,from,to,1.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		var rect: Rect2 = battle._target_rects.get("ally_%d" % i,Rect2())
		if rect.size == Vector2.ZERO: continue
		var phoenix := bool(ally.get("anya_phoenix", false))
		var notice_rect := Rect2(rect.position + Vector2(278, 54), Vector2(662, 30)) if phoenix else Rect2(rect.position.x, rect.position.y - 70, rect.size.x, 56)
		var notice := V.panel(self,notice_rect,Color("141a29"),Color("c0bdcc"),8)
		notice.name = "FinaleSealNotice_%d" % i
		notice.z_index = 125
		var words := V.text(notice,"最高可回复 %d%%" % [70,50,20][stage-1],Rect2(4,0,notice_rect.size.x-8,notice_rect.size.y),20 if phoenix else 23,Color("ece8e5"),true)
		words.add_theme_font_override("font",CG_FONT)
		notices.append(notice)
	await tween.finished
	await Settings.battle_timer(.4).timeout
	for notice in notices: notice.queue_free()

func present(id: String, done: Callable, target: int = 0) -> void:
	if busy: return
	var voice: String = {"anya_step":"step_back", "anya_wait":"wait", "anya_resist":"resist", "anya_reconcile":"reconcile", "anya_defy":"refuse_ending", "anya_refuse":"refuse"}.get(id, "")
	var voice_seconds := preload("res://scripts/ui/battle_generated_audio.gd").say(battle._effect_layer, "assist_anya_" + voice, 3, "anya")
	busy = true
	presentation_phase = "cg"
	dismiss = false
	var style: Dictionary = SKILL_STYLE[id]
	var accent := Color(String(style.color))
	var before := _effect_snapshot(target)
	cinematic = Control.new()
	cinematic.name = "AnyaSkillCG"
	cinematic.size = Vector2(1920, 1080)
	cinematic.z_index = 180
	cinematic.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cinematic)
	preload("res://scripts/ui/tower_mobile.gd").register_back(cinematic, func(): dismiss = true)
	var art := V.icon(cinematic, load(ROOT + id + ".webp"), Rect2(Vector2.ZERO, cinematic.size))
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.pivot_offset = cinematic.size * 0.5
	# Feathered ink sits inside the image; no opaque dialogue box or UI frame.
	var shade := ColorRect.new()
	shade.size = cinematic.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ float bottom = smoothstep(0.62, 1.0, UV.y); float left = 1.0 - smoothstep(0.40, 0.96, UV.x); COLOR = vec4(0.055, 0.042, 0.075, bottom * (0.36 + left * 0.49)); }"
	material.shader = shader
	shade.material = material
	cinematic.add_child(shade)
	var atmosphere := SKILL_FX.new()
	atmosphere.ambient = true
	atmosphere.accent = accent
	cinematic.add_child(atmosphere)
	var typography := Control.new()
	typography.name = "AnyaCGTypography"
	typography.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinematic.add_child(typography)
	var byline := _cg_text(typography, "李 安 雅", Rect2(112, 748, 280, 40), 24, accent)
	byline.name = "AnyaCGByline"
	var rule := ColorRect.new()
	rule.position = Vector2(112, 794)
	rule.size = Vector2(62, 2)
	rule.color = accent
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	typography.add_child(rule)
	var heading := V.icon(typography, load(SKILL_FX.ART + id + "_title.webp"), Rect2(88, 799, 980 if id == "anya_defy" else 760, 220))
	heading.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	heading.name = "AnyaCGTitle"
	_cg_text(typography, style.note, Rect2(112, 1020, 1300, 40), 22, Color("e7d5c2"))
	_cg_text(typography, "点击 / 空格  ·  释放", Rect2(1560, 990, 290, 36), 18, Color("ddcbb7"))
	cinematic.gui_input.connect(func(input: InputEvent) -> void:
		if input is InputEventMouseButton and input.button_index == MOUSE_BUTTON_LEFT and input.pressed: dismiss = true
	)
	art.scale = Vector2(1.045, 1.045)
	Settings.battle_tween(art).tween_property(art, "scale", Vector2.ONE, 2.5).set_trans(Tween.TRANS_SINE)
	cinematic.modulate.a = 0
	Settings.battle_tween(cinematic).tween_property(cinematic, "modulate:a", 1.0, 0.18)
	typography.position.y = 18
	typography.modulate.a = 0
	var reveal := Settings.battle_tween(typography).set_parallel(true)
	reveal.tween_property(typography, "position:y", 0.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(typography, "modulate:a", 1.0, 0.40)
	var elapsed := 0.0
	while elapsed < maxf(2.45, voice_seconds if Settings.all_voice_enabled() else 0.0) and not (dismiss and elapsed > 0.65):
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	var voice_keys: Array[String] = ["assist_anya_" + voice]
	preload("res://scripts/ui/battle_generated_audio.gd").of(battle._effect_layer).stop_cues(voice_keys)
	presentation_phase = "transition"
	await Settings.battle_tween(cinematic).tween_property(cinematic, "modulate:a", 0.0, 0.32).finished
	cinematic.queue_free()
	cinematic = null
	# Land on the actual recipient, then resolve exactly once at the light pulse.
	release_fx = SKILL_FX.new()
	release_fx.name = "AnyaReleaseFX"
	release_fx.skill = id
	release_fx.accent = accent
	release_fx.z_index = 179
	release_fx.duration = 4.0 if id in ["anya_defy", "anya_refuse"] else 3.3
	var recipients: Array = []
	if id in ["anya_defy", "anya_refuse"]:
		for i in FightSystem.allies.size():
			if FightSystem._is_alive(FightSystem.allies[i]): recipients.append(i)
	elif id != "anya_step": recipients.append(target)
	for i in recipients:
		var rect: Rect2 = battle._target_rects.get("ally_%d" % i, Rect2())
		if rect.has_area(): release_fx.targets.append(rect.get_center())
	if id in ["anya_defy", "anya_refuse"]:
		for i in FightSystem.enemies.size():
			if not FightSystem._is_alive(FightSystem.enemies[i]): continue
			var rect: Rect2 = battle._target_rects.get("enemy_%d" % i, Rect2())
			if rect.has_area(): release_fx.enemies.append(rect.get_center())
	add_child(release_fx)
	presentation_phase = "release"
	await Settings.battle_timer(1.12).timeout
	done.call()
	_play_release_sound(id)
	var words := _effect_result(id, target, before)
	var result := _cg_text(release_fx, words, Rect2(620, 190, 1120, 100), 32, Color("fff0ce"))
	result.name = "AnyaEffectResult"
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.modulate.a = 0
	Settings.battle_tween(result).tween_property(result, "modulate:a", 1.0, 0.18)
	for center in release_fx.targets:
		var recipient_words := _recipient_result(id)
		if id == "anya_reconcile" and _debuff_count(target) >= int(before.debuffs): recipient_words = "心绪平复"
		var label := _cg_text(release_fx, recipient_words, Rect2(center + Vector2(-180, -120), Vector2(360, 48)), 28, accent)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Settings.battle_tween(label).tween_property(label, "position:y", label.position.y - 25, 1.4)
	await Settings.battle_timer(release_fx.duration - 1.12).timeout
	await Settings.battle_tween(release_fx).tween_property(release_fx, "modulate:a", 0.0, 0.25).finished
	release_fx.queue_free()
	release_fx = null
	presentation_phase = "idle"
	busy = false
	battle._refresh()

func _input(event: InputEvent) -> void:
	if not busy: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER]:
		if presentation_phase == "cg": dismiss = true
		get_viewport().set_input_as_handled()

func _cg_text(parent: Node, words: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := V.text(parent, words, rect, font_size, color)
	label.add_theme_font_override("font", CG_FONT)
	label.add_theme_color_override("font_shadow_color", Color(0.08, 0.04, 0.09, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("shadow_outline_size", 7)
	return label

func _effect_snapshot(target: int) -> Dictionary:
	var e := RULES.boss(FightSystem)
	return {"edge":int(e.get("edge", 0)), "hope":int(e.get("hope", 0)), "debuffs":_debuff_count(target), "hand":FightSystem.hand.size()}

func _debuff_count(target: int) -> int:
	if target < 0 or target >= FightSystem.allies.size(): return 0
	var count := 0
	for status in FightSystem.allies[target].statuses.values():
		if bool(status.get("debuff", false)): count += 1
	return count

func _effect_result(id: String, target: int, before: Dictionary) -> String:
	var e := RULES.boss(FightSystem)
	match id:
		"anya_step": return "边缘  %d → %d    ·    抽牌 +%d" % [before.edge, e.get("edge", 0), maxi(0, FightSystem.hand.size() - int(before.hand))]
		"anya_wait": return "%s  ·  坚毅 +1" % FightSystem.allies[target].name
		"anya_resist": return "%s  ·  负面免疫 +1" % FightSystem.allies[target].name
		"anya_reconcile": return "%s  ·  %s" % [FightSystem.allies[target].name, "负面效果已净化" if _debuff_count(target) < int(before.debuffs) else "当前没有可净化的负面效果"]
		"anya_defy": return "永久增伤 +25%   减伤 +15%   护盾强效 +30%\n敌方全体眩晕一回合"
		"anya_refuse": return "希望  %d → %d    ·    不，我拒绝！" % [before.hope, e.get("hope", 0)]
	return ""

func _recipient_result(id: String) -> String:
	match id:
		"anya_wait": return "坚毅 +1"
		"anya_resist": return "负面免疫 +1"
		"anya_reconcile": return "净化"
		"anya_defy": return "永久强化"
	return "希望"

func _play_release_sound(id: String) -> void:
	var sound := AudioStreamPlayer.new()
	sound.stream = load("res://assets/audio/sfx/finale/dawn.wav")
	sound.volume_db = -12
	sound.pitch_scale = {"anya_step":1.25, "anya_wait":0.95, "anya_resist":1.1, "anya_reconcile":1.4, "anya_defy":0.8, "anya_refuse":1.0}.get(id, 1.0)
	sound.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
