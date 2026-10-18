extends Control
const THEME := preload("res://scripts/ui/battle_theme.gd")
const VISUALS := preload("res://scripts/ui/fc_card_visuals.gd")
const PLATE := preload("res://scripts/ui/battle_preview_plate.gd")
const ATTRIBUTE_HINT := preload("res://scripts/ui/battle_attribute_hint.gd")
const HURT := Color("9d3d52")
const GUARD := Color("376f94")
const HEAL := Color("276c55")
var _entrance: Tween

func _ready() -> void:
	name = "DamagePreview"
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 40

func clear() -> void:
	if _entrance != null and _entrance.is_valid(): _entrance.kill()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	modulate.a = 1.0

func present(previews: Array, rects: Dictionary, compare: bool, available: bool, context: Dictionary = {}) -> void:
	clear()
	if previews.is_empty(): return
	var exact := true
	var uncertainty := "最终数值随选择变化"
	for preview in previews:
		if not bool(preview.exact):
			exact = false
			if not String(preview.get("note", "")).is_empty(): uncertainty = String(preview.note)
	var compact := false
	for key in rects:
		if String(key).begins_with("enemy_") and rects[key].size.y < 300: compact = true
	_summary(previews[0], context, compare, available, exact, uncertainty, compact)
	for preview in previews:
		if not bool(preview.exact): continue
		for entry in preview.targets:
			if compare and (entry.side != preview.get("compare_side", "enemy") or int(entry.index) != int(preview.get("compare_target", -1))): continue
			var key := "%s_%d" % [entry.side, int(entry.index)]
			if not rects.has(key): continue
			var target: Rect2 = rects[key]
			if entry.side == "ally": _ally_forecast(entry, key, target)
			else:
				_enemy_forecast(entry, key, target, compare)
				_attribute_forecast(preview, entry, key, target)
				_health_loss(entry, target)
	# Only opacity changes; the forecast cannot move pointer hit areas.
	modulate.a = 0.35
	_entrance = create_tween()
	_entrance.tween_property(self, "modulate:a", 1.0, 0.13).set_trans(Tween.TRANS_SINE)

func _attribute_forecast(preview: Dictionary, entry: Dictionary, key: String, target: Rect2) -> void:
	var attacks: Array = []
	for attack in preview.get("attributes", []):
		if int(attack.index) == int(entry.index) and not attacks.has(attack): attacks.append(attack)
	if attacks.is_empty(): return
	var forecast: Control = get_node("Preview_" + key)
	var width := minf(380, target.size.x-24)
	var compact_rows := target.size.y < 300 and attacks.size() > 1
	var height := (30.0 if compact_rows else 42.0) * attacks.size()
	var hint := ATTRIBUTE_HINT.matchup(self, attacks, Rect2(target.get_center().x-width*0.5, forecast.position.y-height-4, width, height), 16 if compact_rows else 20)
	hint.name = "AttributePreview_" + key
	# A clear target outline lets players compare favorable/unfavorable targets
	# without relying on small text. Mixed-source hits keep their separate rows.
	var first := ATTRIBUTE_HINT.relation(String(attacks[0].attribute), String(attacks[0].target_attribute))
	var same_relation := attacks.all(func(attack: Dictionary) -> bool: return ATTRIBUTE_HINT.relation(String(attack.attribute), String(attack.target_attribute)).kind == first.kind)
	if same_relation and first.kind != "neutral":
		var outline := VISUALS.panel(self, target, Color(first.color, 0.035), Color(first.color, 0.8), 12)
		outline.add_theme_stylebox_override("panel", VISUALS.style(Color(first.color, 0.035), Color(first.color, 0.8), 2, 12))
		outline.name = "AttributeTarget_" + key
		move_child(outline, 0)

func _summary(first: Dictionary, context: Dictionary, compare: bool, available: bool, exact: bool, uncertainty: String, compact: bool) -> void:
	if bool(context.get("finale", false)):
		# During hover the preview replaces the hand heading, leaving the meters clear.
		var banner := _plate(Rect2(42, 99, 420, 73), "summary", Color("d8cdb7"), Color("866b45"))
		banner.name = "ForecastSummary"
		var title := VISUALS.text(banner, String(first.name), Rect2(14, 5, 280, 30), 22, THEME.TEXT)
		title.add_theme_font_override("font", THEME.HEADING)
		VISUALS.text(banner, "可释放" if available else "不可释放", Rect2(302, 8, 104, 25), 17, THEME.MUTED, true)
		VISUALS.text(banner, uncertainty if not exact else "目标对比 · 查看敌人身旁预估" if compare else "释放预估 · 查看目标身旁数值", Rect2(14, 39, 392, 25), 16, THEME.MUTED)
		return
	var unit: Dictionary = context.get("unit", {})
	var identity := THEME.identity(String(unit.get("id", "")), String(unit.get("attribute", "none")))
	# Six-enemy formations need the space above y=802 for their status chips.
	var banner := _plate(Rect2(530, 806 if compact else 774, 1320, 46 if compact else 78), "summary", identity.fill.lerp(Color("e3dccc"), 0.35), identity.edge, identity.motif)
	banner.name = "ForecastSummary"
	var socket_size := 36.0 if compact else 60.0
	var socket := VISUALS.panel(banner, Rect2(13, 5 if compact else 9, socket_size, socket_size), Color("233746"), Color(identity.edge, 0.8), 5)
	var texture: Texture2D = context.get("icon")
	if texture != null:
		VISUALS.icon(socket, texture, Rect2(Vector2(3, 3), Vector2.ONE*(socket_size-6))).name = "ForecastSkillIcon"
	else: VISUALS.glyph(socket, "target", Rect2(Vector2(8, 8), Vector2.ONE*(socket_size-16)), Color("dfc58f"))
	var title := VISUALS.text(banner, String(first.name), Rect2(64 if compact else 91, 6 if compact else 7, 310 if compact else 478, 34), 23 if compact else 26, THEME.TEXT)
	title.name = "ForecastSkillName"
	title.add_theme_font_override("font", THEME.HEADING)
	var owner := String(unit.get("name", ""))
	var subtitle := "释放预估" if owner.is_empty() else "%s · %s / %s预估" % [owner, FightData.attr_name(String(unit.get("attribute", "none"))), context.get("kind", "技能")]
	ATTRIBUTE_HINT.icon(banner, String(unit.get("attribute", "none")), Rect2(382 if compact else 92, 11 if compact else 44, 24, 24))
	VISUALS.text(banner, "%s · %s" % [owner, FightData.attr_name(String(unit.get("attribute", "none")))] if compact else subtitle, Rect2(410 if compact else 120, 11 if compact else 44, 174 if compact else 447, 24), 16 if compact else 17, identity.edge)
	var caption := "各目标独立施放" if compare else "本次施放 · 最终结算"
	var hint := "克制 +50% / 被克制 -50% · 其余增减伤另计"
	if not exact:
		caption = "结算结果尚未确定"
		hint = uncertainty
	elif first.targets.is_empty(): hint = "不直接造成伤害 · 效果见技能说明"
	if exact and int(first.get("shared_guard", 0)) > 0: hint = "全队护盾 +%d · 已计入本次施放" % int(first.shared_guard)
	VISUALS.glyph(banner, "wait" if not exact else "target" if compare else "all", Rect2(605, 12 if compact else 14, 23, 23), identity.edge)
	if compact:
		VISUALS.text(banner, hint if not exact or int(first.get("shared_guard", 0)) > 0 else caption, Rect2(639, 9, 490, 28), 18, THEME.TEXT).name = "ForecastExplanation"
	else:
		VISUALS.text(banner, caption, Rect2(639, 9, 483, 28), 20, THEME.TEXT)
		VISUALS.text(banner, hint, Rect2(609, 42, 520, 26), 17, THEME.MUTED).name = "ForecastExplanation"
	var state := "当前不可释放" if not available else ("含随机效果" if uncertainty.contains("随机") else "等待选择") if not exact else "目标对比" if compare else "确定预估"
	var tone: Color = THEME.MUTED if not available else Color("88612f") if not exact else identity.edge
	var stamp := VISUALS.panel(banner, Rect2(1145, 7 if compact else 23, 152, 32), Color(tone, 0.10), Color(tone, 0.45), 3)
	stamp.name = "ForecastState"
	VISUALS.text(stamp, state, Rect2(6, 1, 140, 29), 18, tone, true)

func _enemy_forecast(entry: Dictionary, key: String, target: Rect2, compare: bool) -> void:
	var damage := int(entry.hp) + int(entry.guard) > 0
	var mixed := damage and int(entry.healing) + int(entry.shield) > 0
	if target.size.y < 300 and not mixed:
		_compact_enemy_forecast(entry, key, target, damage)
		return
	var height := 138.0 if mixed else 112.0
	var width := minf(320, target.size.x - 24)
	var edge := HURT if entry.defeated else Color("866b45")
	var chip := _plate(Rect2(target.get_center().x-width*0.5, target.end.y-90-height, width, height), "target", Color("d8cdb7"), edge)
	chip.name = "Preview_" + key
	VISUALS.glyph(chip, "target", Rect2(13, 8, 17, 17), edge)
	var badge_width := 78.0 if entry.defeated or entry.downed else 62.0
	VISUALS.text(chip, String(entry.name), Rect2(37, 5, width-54-badge_width, 23), 17, THEME.TEXT)
	var outcome := "可击败" if entry.defeated else "濒死" if entry.downed else "对比" if compare else "命中"
	VISUALS.text(chip, outcome, Rect2(width-badge_width-13, 5, badge_width, 23), 17, edge, true)
	_metric(chip, "attack" if damage else "healing", "生命损失" if damage else "获得治疗", int(entry.hp) if damage else int(entry.healing), Rect2(14, 34, width*0.5-23, 48), HURT if damage else HEAL, not damage)
	_metric(chip, "shield_break" if damage else "shield", "护盾损失" if damage else "获得护盾", int(entry.guard) if damage else int(entry.shield), Rect2(width*0.5+11, 34, width*0.5-23, 48), GUARD, not damage)
	if mixed: VISUALS.text(chip, "治疗 +%d   护盾 +%d" % [entry.healing, entry.shield], Rect2(14, 83, width-28, 24), 17, HEAL)
	var remaining := "预计剩余生命 %d" % int(entry.remaining)
	if entry.defeated: remaining = "生命归零 · 可击败"
	elif entry.downed: remaining = "将处于濒死"
	if String(FightSystem.enemies[int(entry.index)].id) == "terminal_echo": remaining = "生命 ∞/∞"
	VISUALS.text(chip, remaining, Rect2(15, height-27, width-115, 22), 16, THEME.TEXT)
	var hits := "%d 段合计" % int(entry.hits) if int(entry.hits) > 1 else ""
	VISUALS.text(chip, hits, Rect2(width-102, height-27, 88, 22), 16, edge, true)

func _compact_enemy_forecast(entry: Dictionary, key: String, target: Rect2, damage: bool) -> void:
	var width := minf(340, target.size.x-24)
	var edge := HURT if entry.defeated else Color("866b45")
	var chip := _plate(Rect2(target.get_center().x-width*0.5, target.end.y-154, width, 64), "target_compact", Color("d8cdb7"), edge)
	chip.name = "Preview_" + key
	var values := [int(entry.hp) if damage else int(entry.healing), int(entry.guard) if damage else int(entry.shield)]
	for i in 2:
		var left := 13.0 + i*width*0.5
		var tone := (HURT if damage else HEAL) if i == 0 else GUARD
		VISUALS.glyph(chip, ("attack" if damage else "healing") if i == 0 else ("shield_break" if damage else "shield"), Rect2(left, 9, 23, 23), tone)
		var number := ("+" if not damage and values[i] > 0 else "") + str(values[i])
		VISUALS.text(chip, number, Rect2(left+31, 3, width*0.5-98, 32), 26 if number.length() < 5 else 19, tone if values[i] > 0 else THEME.FAINT)
		VISUALS.text(chip, ("扣血" if damage else "治疗") if i == 0 else ("破盾" if damage else "护盾"), Rect2(left+width*0.5-64, 10, 38, 22), 16, THEME.MUTED)
	var remaining := "可击败 · 生命归零" if entry.defeated else "将处于濒死" if entry.downed else "预计剩余生命 %d" % int(entry.remaining)
	if String(FightSystem.enemies[int(entry.index)].id) == "terminal_echo": remaining = "生命 ∞/∞"
	VISUALS.text(chip, remaining, Rect2(14, 37, width-115, 22), 16, edge if entry.defeated else THEME.TEXT)
	VISUALS.text(chip, "%d 段合计" % int(entry.hits) if int(entry.hits) > 1 else "", Rect2(width-102, 37, 88, 22), 16, edge, true)

func _metric(parent: Control, glyph: String, caption: String, amount: int, rect: Rect2, color: Color, positive: bool) -> void:
	VISUALS.glyph(parent, glyph, Rect2(rect.position+Vector2(0, 7), Vector2(27, 27)), color)
	var number := ("+" if positive and amount > 0 else "") + str(amount)
	var label := VISUALS.text(parent, number, Rect2(rect.position+Vector2(35, -1), Vector2(rect.size.x-35, 33)), 30 if number.length() <= 5 else 23, color if amount > 0 else THEME.FAINT)
	label.name = "ForecastValue_" + glyph
	VISUALS.text(parent, caption, Rect2(rect.position+Vector2(35, 31), Vector2(rect.size.x-35, 20)), 16, THEME.MUTED)

func _ally_forecast(entry: Dictionary, key: String, target: Rect2) -> void:
	# Outside the ally card: current HP, shield, statuses and portrait stay readable.
	var width := target.size.x
	var danger: bool = entry.defeated or entry.downed or int(entry.hp) > 0
	var edge := HURT if danger else HEAL
	var chip := _plate(Rect2(target.position.x, minf(target.end.y+10, 1040), width, 34), "ribbon", Color("c3d5c9") if not danger else Color("dcc5c4"), edge, "wing")
	chip.name = "Preview_" + key
	var delta := "-%d" % int(entry.hp) if int(entry.hp) > 0 else "+%d" % int(entry.healing)
	VISUALS.glyph(chip, "attack" if int(entry.hp) > 0 else "healing", Rect2(10, 6, 22, 22), edge)
	VISUALS.text(chip, delta, Rect2(37, 3, width*0.32-41, 28), 22 if delta.length() < 6 else 17, edge)
	var shield_delta := "-%d" % int(entry.guard) if int(entry.guard) > 0 else "+%d" % int(entry.shield)
	VISUALS.glyph(chip, "shield_break" if int(entry.guard) > 0 else "shield", Rect2(width*0.32+8, 6, 22, 22), GUARD)
	VISUALS.text(chip, shield_delta, Rect2(width*0.32+35, 3, width*0.31-38, 28), 22 if shield_delta.length() < 6 else 17, GUARD)
	var tail := "将退场" if entry.defeated else "将濒死" if entry.downed else "余 %d 生命" % int(entry.remaining)
	VISUALS.text(chip, tail, Rect2(width*0.63+4, 3, width*0.37-11, 28), 17, edge, true)

func _health_loss(entry: Dictionary, target: Rect2) -> void:
	if int(entry.hp) <= 0: return
	var unit: Dictionary = FightSystem.enemies[int(entry.index)]
	if String(unit.id) == "terminal_echo": return
	var maximum := maxf(1, float(unit.max_hp))
	var current := clampf(float(unit.hp) / maximum, 0, 1)
	var remaining := clampf(float(entry.remaining) / maximum, 0, current)
	var rect := Rect2(target.position.x+12+(target.size.x-24)*remaining, target.end.y-56, (target.size.x-24)*(current-remaining), 22)
	var ghost := _plate(rect, "loss", Color.TRANSPARENT, Color("ffe0a1"))
	ghost.name = "PredictedHealthLoss_%d" % int(entry.index)

func _plate(rect: Rect2, kind: String, fill: Color, accent: Color, family: String = "quill") -> Panel:
	var panel := PLATE.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.kind = kind
	panel.fill = fill
	panel.accent = accent
	panel.family = family
	add_child(panel)
	return panel
