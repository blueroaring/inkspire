extends Control
## Reuses in-game character art; decoration and motion add no bitmap assets.
signal continued
const THEME := preload("res://scripts/ui/battle_theme.gd")
const ART := preload("res://scripts/data/battle_art.gd")
const VISUALS := preload("res://scripts/ui/fc_card_visuals.gd")
const RESULT_MATERIAL := preload("res://assets/shaders/battle_result_material.gdshader")
const FINISH := preload("res://scripts/ui/battle_result_finish.gd")
var won := true
var accent := Color("ebcb8c")
var elapsed := 0.0
var reveal := 0.0
var sheet: Control
var continue_button: Button
var victory_message := "赢了，大家辛苦了。"

func configure(victory: bool, reward: Dictionary, party: Array, rounds: int, returning: bool) -> void:
	won = victory
	accent = Color("ebcb8c") if won else Color("cba4bf")
	name = "BattleResultCinematic"
	z_index = 100
	mouse_filter = MOUSE_FILTER_STOP
	size = Vector2(1920, 1080)
	sheet = Control.new()
	sheet.name = "ResultCard"
	sheet.position = Vector2(280, 192)
	sheet.size = Vector2(1360, 720)
	sheet.modulate.a = 0
	add_child(sheet)
	var paper := Panel.new()
	paper.size = sheet.size
	paper.mouse_filter = MOUSE_FILTER_IGNORE
	paper.add_theme_stylebox_override("panel", THEME.frame(Color("edf0e5") if won else Color("e6e6ed"), accent, 2, 16))
	sheet.add_child(paper)
	_surface(paper, 0, Color("eae3ce") if won else Color("dddbe3"), 16)
	var portrait_panel := Panel.new()
	portrait_panel.size = Vector2(440, 720)
	portrait_panel.clip_contents = true
	portrait_panel.mouse_filter = MOUSE_FILTER_IGNORE
	portrait_panel.add_theme_stylebox_override("panel", THEME.frame(Color("183e47") if won else Color("2a3049"), accent, 0, 16))
	sheet.add_child(portrait_panel)
	_surface(portrait_panel, 1, Color("163d45") if won else Color("2d3049"), 16)
	# Layered orbit engraving behind the existing protagonist cutout.
	for i in 3:
		var ring := Line2D.new()
		ring.width = 1.5
		ring.default_color = Color(accent, 0.2)
		for step in 97:
			var angle := TAU * step / 96.0
			ring.add_point(Vector2(220, 310) + Vector2(cos(angle), sin(angle)) * (145 + 45 * i))
		portrait_panel.add_child(ring)
	if not party.is_empty():
		var actor := TextureRect.new()
		actor.name = "ResultActor"
		actor.texture = ART.actor(ART.module(party[0]))
		if actor.texture == null: actor.texture = load(String(party[0].portrait))
		actor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		actor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		actor.position = Vector2(-40, 54)
		actor.size = Vector2(520, 690)
		actor.modulate = Color("ffffff") if won else Color("9196b3")
		actor.mouse_filter = MOUSE_FILTER_IGNORE
		portrait_panel.add_child(actor)
		var motion := create_tween()
		motion.tween_property(actor, "position:y", 28.0 if won else 64.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("142d3c", 0), Color("142d3c", 0.98)])
	var fade_texture := GradientTexture2D.new()
	fade_texture.gradient = gradient
	fade_texture.fill_from = Vector2(0, 0)
	fade_texture.fill_to = Vector2(0, 1)
	var fade := TextureRect.new()
	fade.texture = fade_texture
	fade.position = Vector2(0, 390)
	fade.size = Vector2(440, 330)
	fade.mouse_filter = MOUSE_FILTER_IGNORE
	portrait_panel.add_child(fade)
	_label(portrait_panel, "VICTORY" if won else "TO BE CONTINUED", Rect2(36, 574, 368, 35), 25, accent)
	_label(portrait_panel, victory_message if won else "换个打法，再试一次。", Rect2(36, 625, 368, 40), 25, Color("edf3e9"))
	_label(sheet, "战 斗 结 算   /   第 %02d 回合" % rounds, Rect2(494, 40, 800, 30), 18, Color("72818a"))
	var title := _label(sheet, "战斗胜利" if won else "战斗失利", Rect2(490, 84, 790, 90), 64, Color("254b4d") if won else Color("5d4c70"))
	if reward.get("wave_clear", false): title.text = "连战 · 本场胜利"
	title.add_theme_font_override("font", THEME.HEADING)
	title.add_theme_color_override("font_shadow_color", Color("fff5d8") if won else Color("f5eef9"))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 2)
	_ornament(sheet, "seal", Rect2(1190, 93, 108, 108))
	_label(sheet, "这场打赢了，看看战斗结果吧。" if won else "先看看哪里没撑住，再调整队伍和技能。", Rect2(494, 183, 800, 36), 23, Color("66757c"))
	_line(sheet, Rect2(494, 237, 802, 2), Color("b9c5bf"))
	if won:
		var item := ItemDb.display_name(String(reward.get("item", "")))
		var values := ["+%d" % int(reward.get("xp", 0)), "¥ " + Currency.format_cents(int(reward.get("money", 0))), "%s ×%d" % [item, int(reward.get("item_count", 1))]]
		var labels := ["每位队员经验", "夜间钱包", "战斗掉落"]
		if reward.get("tower", false):
			if reward.get("replay", false):
				labels = ["重演经验", "爬塔进度", "资源奖励"]
				values = ["+%d / 人" % int(reward.get("xp", 0)), "不变", "未领取"]
			else:
				labels[1] = "爬塔进度"
				values[1] = "第 %d 层" % int(TowerRun.data.highest)
			if reward.get("wave_clear", false) and not reward.get("replay", false):
				labels = ["通关整层后结算", "下一场", "短暂休整"]
				values = ["奖励暂未领取", "%d / %d" % [reward.next_wave, reward.wave_count], "存活队员回复20%生命"]
			elif reward.get("wave_clear", false):
				labels = ["重演经验", "下一场", "短暂休整"]
				values = ["本层结束后领取", "%d / %d" % [reward.next_wave, reward.wave_count], "存活队员回复20%生命"]
			if reward.has("weapon"):
				labels[2] = "专武已解锁"
				values[2] = FightEquipmentData.definition(reward.weapon).name
		for i in 3:
			var tile := Panel.new()
			tile.name = "Reward_%d" % i
			tile.position = Vector2(494 + 272 * i, 264)
			tile.size = Vector2(258, 100)
			tile.mouse_filter = MOUSE_FILTER_IGNORE
			tile.add_theme_stylebox_override("panel", THEME.frame(Color("dce5dc"), Color("c0cec3"), 1, 8))
			sheet.add_child(tile)
			_surface(tile, 2, Color("d8dfd0"), 8)
			_ornament(tile, "slip", Rect2(Vector2.ZERO, tile.size))
			_label(tile, labels[i], Rect2(24, 10, 210, 24), 17, Color("526e60"))
			var value := _label(tile, values[i], Rect2(24, 43, 210, 40), 27 if i < 2 else 22, Color("335747"))
			value.name = "RewardValue"
		var rows: Array = reward.get("growth", [])
		for i in mini(4, rows.size()):
			var row: Dictionary = rows[i]
			var y := 390.0 + i * 41
			var level := "Lv.%d → %d" % [int(row.before_level), int(row.level)] if int(row.level) > int(row.before_level) else "Lv.%d" % int(row.level)
			_label(sheet, String(row.name), Rect2(494, y, 165, 30), 20, Color("34524b"))
			_label(sheet, level, Rect2(666, y, 148, 30), 18, Color("8a6934"))
			var ratio := clampf(float(row.xp) / maxf(1, float(TowerData.xp_needed(int(row.level))) if TowerRun.active else float(row.level) * 100), 0, 1)
			_line(sheet, Rect2(830, y + 11, 276, 7), Color("c8d4cb"))
			var fill := _line(sheet, Rect2(830, y + 11, 0, 7), Color("739d83"))
			create_tween().tween_property(fill, "size:x", 276 * ratio, 0.85).set_delay(0.4 + i * 0.1)
			_label(sheet, ("等待更高楼层" if TowerRun.active else "经验储存") if int(row.level) >= FightProgression.level_cap() else "%d / %d" % [int(row.xp), TowerData.xp_needed(int(row.level)) if TowerRun.active else int(row.level) * 100], Rect2(1126, y, 170, 30), 17, Color("688177"))
	else:
		_label(sheet, "本次挑战未获得战斗奖励", Rect2(494, 263, 802, 36), 26, Color("665675"))
		_label(sheet, "看看敌人要攻击谁，给血量低的队友回血或加护盾。\n出牌前看看伤害预览，也许换个顺序就能打赢。", Rect2(494, 321, 802, 86), 23, Color("76808c"))
		for i in party.size():
			_label(sheet, "%s   /   %s" % [party[i].name, "已退场" if bool(party[i].get("dead", false)) else "濒死" if bool(party[i].get("downed", false)) else "生命 %d" % int(party[i].hp)], Rect2(494 + (i % 2) * 402, 437 + int(i / 2) * 44, 394, 34), 21, Color("665675"))
	if TowerRun.active:
		var recovery_note := "恢复次数 +%d · 已储存 %d 次" % [int(reward.get("recovery", 0)), TowerRun.recovery_charges()] if int(reward.get("recovery", 0)) > 0 else ""
		if not won and reward.get("rewound", false): recovery_note = "已回溯到本场开战前：生命、道具与角色状态已还原，失败记录保留。"
		if not won and reward.get("chain_restarted", false): recovery_note = "已还原本层连战前的生命与道具，再次挑战从第一场开始。"
		_label(sheet, recovery_note, Rect2(494, 553, 802, 26), 18, Color("78633b"))
	_line(sheet, Rect2(494, 583, 802, 1), Color("b9c5bf"))
	_label(sheet, "重演只获得经验，不推进层数或资源" if reward.get("replay", false) else "整层通关后领取奖励" if reward.get("wave_clear", false) else "奖励已领取" if won else "调整好队伍，再来试试", Rect2(494, 620, 560, 40), 19, Color("72818a"))
	continue_button = Button.new()
	continue_button.name = "ResultContinue"
	continue_button.text = "返回尖塔  →" if TowerRun.active else "继续旅程  →" if returning else "返回标题  →"
	if reward.get("wave_clear", false): continue_button.text = "继续连战  →"
	continue_button.position = Vector2(988, 613)
	continue_button.size = Vector2(308, 62)
	THEME.button(continue_button, accent, true)
	continue_button.get_node("SurfaceArt").hide()
	for state in ["normal", "hover", "pressed", "disabled"]:
		continue_button.add_theme_stylebox_override(state, THEME.frame(Color("315a61") if state == "normal" else Color("426c72"), accent, 1, 8))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		continue_button.add_theme_color_override(state, Color("fff0d7"))
	continue_button.add_theme_font_size_override("font_size", 24)
	sheet.add_child(continue_button)
	var button_surface := _surface(continue_button, 3, Color("31545b") if won else Color("4c475e"), 8)
	button_surface.show_behind_parent = true
	# Draw the material below the button's text; only its transparent frame is above it.
	for state in ["normal", "hover", "pressed", "disabled"]:
		var frame := THEME.frame(Color.TRANSPARENT, accent, 1 if state != "hover" else 2, 8)
		continue_button.add_theme_stylebox_override(state, frame)
	continue_button.mouse_entered.connect(func() -> void: button_surface.modulate = Color(1.13, 1.13, 1.13))
	continue_button.mouse_exited.connect(func() -> void: button_surface.modulate = Color.WHITE)
	_ornament(sheet, "frame", Rect2(Vector2.ZERO, sheet.size))
	continue_button.disabled = true
	continue_button.pressed.connect(func() -> void:
		continue_button.disabled = true
		continued.emit()
	)
	var entrance := create_tween().set_parallel(true)
	entrance.tween_property(self, "reveal", 1.0, 0.45)
	entrance.tween_property(sheet, "position:y", 170.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entrance.tween_property(sheet, "modulate:a", 1.0, 0.65).set_delay(0.12)
	entrance.chain().tween_callback(func() -> void:
		continue_button.disabled = false
		continue_button.grab_focus()
	)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("09141e", reveal * 0.88))
	for i in 36:
		var x := fposmod(i * 151.0 + sin(elapsed * 0.4 + i) * 16, 1920)
		var y := fposmod(i * 79.0 + elapsed * (-20 if won else 12), 1080)
		var opacity := reveal * (0.18 + 0.18 * sin(elapsed + i))
		var p := Vector2(x, y)
		if won:
			draw_line(p - Vector2(3, 0), p + Vector2(3, 0), Color(accent, opacity), 1.5, true)
			draw_line(p - Vector2(0, 3), p + Vector2(0, 3), Color(accent, opacity), 1.5, true)
		else: draw_line(p, p + Vector2(-4, 22), Color(accent, opacity * 0.6), 1, true)
	draw_line(Vector2(120, 124), Vector2(1800, 124), Color(accent, reveal * 0.25), 1, true)
	draw_line(Vector2(120, 936), Vector2(1800, 936), Color(accent, reveal * 0.25), 1, true)

func _label(parent: Control, words: String, rect: Rect2, font: int, color: Color) -> Label:
	return VISUALS.text(parent, words, rect, font, color)

func _surface(parent: Control, finish: int, tint: Color, radius: float) -> ColorRect:
	var surface := ColorRect.new()
	surface.name = "ResultMaterial"
	surface.mouse_filter = MOUSE_FILTER_IGNORE
	surface.size = parent.size
	var shader := ShaderMaterial.new()
	shader.shader = RESULT_MATERIAL
	shader.set_shader_parameter("surface_size", parent.size)
	shader.set_shader_parameter("base_tint", tint)
	shader.set_shader_parameter("metal_tint", Color("b19663") if won else Color("a392ad"))
	shader.set_shader_parameter("finish", finish)
	shader.set_shader_parameter("radius", radius)
	surface.material = shader
	parent.add_child(surface)
	return surface

func _ornament(parent: Control, kind: String, rect: Rect2) -> Control:
	var finish := FINISH.new()
	finish.name = "ResultFinish_" + kind
	finish.kind = kind
	finish.victory = won
	finish.gold = Color("b19663") if won else Color("a392ad")
	finish.position = rect.position
	finish.size = rect.size
	parent.add_child(finish)
	return finish

func _line(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.position = rect.position
	line.size = rect.size
	line.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(line)
	return line
