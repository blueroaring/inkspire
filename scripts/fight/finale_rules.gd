extends RefCounted
## Rooftop finale. All encounter state lives on units, including in preview copies.
const BOSS := "terminal_echo"
const SUMMONS := ["whisper_silhouette", "terminal_choir", "false_dawn"]
const SUPPORT := ["anya_step", "anya_wait", "anya_resist", "anya_reconcile", "anya_refuse"]
const POWER_PERCENT := [30, 40, 50]

static func boss(s: Node) -> Dictionary:
	for e in s.enemies:
		if e.id == BOSS: return e
	return {}

static func power(e: Dictionary) -> int:
	if String(e.get("id", "")) != BOSS: return 0
	return int(e.get("statuses", {}).get("finale_power", {}).get("base_damage_bonus", 0))

static func event(s: Node, kind: String, data: Dictionary = {}) -> void:
	if not s.preview_mode: s.finale_event.emit(kind, data.duplicate(true))

static func start(s: Node) -> void:
	var e := boss(s)
	if e.is_empty(): return
	e.merge({"edge":0, "hope":0, "countdown":0, "boss_phase":1, "defiance":0, "lock_next":0, "final_ready":false}, true)
	for ally in s.allies: ally.finale_original_max = int(ally.max_hp)
	spawn_wave(s, 1)

static func update_health_cap(s: Node, ally: Dictionary, clamp_current: bool = true) -> void:
	var e := boss(s)
	if e.is_empty() or not ally.has("finale_original_max"): return
	var stage := clampi(int(e.boss_phase), 1, 3)
	ally.finale_heal_cap = maxi(1, floori(int(ally.finale_original_max) * [0.7, 0.5, 0.2][stage - 1]))
	if clamp_current: ally.hp = mini(int(ally.hp), s.healing_ceiling(ally))

static func spawn_wave(s: Node, stage: int) -> void:
	var e := boss(s)
	e.boss_phase = stage
	e.ai_step = 0
	e.statuses.erase("finale_power")
	var id: String = SUMMONS[stage - 1]
	for i in (3 if stage == 2 else 2):
		if s.ENEMY_RULES.summon_slots(s) == 0: break
		var def := FightData.enemy(id)
		var hp := FightData.enemy_hp(id, int(e.level))
		var unit := {"id":id, "name":def.name, "portrait":def.portrait, "attribute":def.attribute, "level":e.level, "max_hp":hp, "hp":hp, "guard":0, "statuses":{}, "marks":{}, "intent":{}, "ai_step":i % 2, "finale_summon":true, "born_round":s.round}
		unit.finale_slot = i
		unit.finale_wave = stage
		s.enemies.append(unit)
	for ally in s.allies:
		update_health_cap(s, ally)
	if stage > 1:
		e.defiance += 1
		if stage == 2:
			add_support(s, "anya_step", 3)
			add_support(s, "anya_wait", 2)
		else:
			add_support(s, "anya_resist", 2)
			add_support(s, "anya_reconcile", 2)
			add_support(s, "anya_resist", 1, true)
			add_support(s, "anya_reconcile", 1, true)
	s._refresh_intents()
	event(s, "wave", {"stage":stage})
	s._add_log("终末回响 · 第%d幕：最高可回复生命限制为开局的%d%%；最大生命不变。" % [stage, [70, 50, 20][stage - 1]], false)

static func add_support(s: Node, id: String, count: int, hand: bool = false) -> void:
	for i in count:
		var card: Dictionary = s.make_card(id, "li_anya")
		if hand and id == "anya_refuse" and s.hand.size() >= s.HAND_LIMIT: s.fc.move_from_hand(s.hand.back(), s.discard_pile)
		if hand: s.fc.to_hand(card)
		else: s.draw_pile.insert(s.fc.random_position(s.draw_pile.size()), card)

static func refresh(s: Node, index: int) -> bool:
	var e: Dictionary = s.enemies[index]
	var r = s.ENEMY_RULES
	var even := int(e.get("ai_step", 0)) % 2 == 0
	match String(e.id):
		BOSS:
			var stage := int(e.get("boss_phase", 1))
			if bool(e.get("final_ready", false)):
				e.intent = r.action("等待你的回答", "all", 0, "final_wait", "使用“不，我拒绝！”获得最后一点希望。")
			elif even:
				e.intent = r.action(["一步就好", "一步就好 max", "一步就好 promax"][stage - 1], "single", r.scaled(e, [4, 6, 8][stage - 1], 0.3), "final_debuff", "攻击一名角色并施加负面效果；按施放时边缘值的%d%%（上取整）固定增加本幕后续每段基础伤害，终结倒计时+1。" % POWER_PERCENT[stage - 1])
				e.intent.random_target = true
			else:
				e.intent = r.action(["你只是累了", "你只是累了 max", "你只是累了 promax"][stage - 1], "all" if stage == 3 else "bounce", r.scaled(e, 3 if stage == 3 else 4, 0.15), "final_tired", "造成生命伤害后眩晕；第二幕起清除可移除的正面状态。", 2 if stage == 3 else 3)
		"whisper_silhouette":
			e.intent = r.action("无意义" if even else "世界少你不少", "single", 0, "nullify" if even else "void", "使下一个技能无效，倒计时+1。" if even else "为一人添加1层虚无；5层强制离场。")
		"terminal_choir":
			e.intent = r.action("往下看，是深渊啊" if even else "无人等你", "all", 0, "abyss_card" if even else "void", "往弃牌堆塞入深渊，倒计时+1。" if even else "为两人添加1层虚无。")
		"false_dawn":
			e.intent = r.action("来吧，来吧！" if even else "孤独，孤独", "all", 0, "lock_cards" if even else "void", "下回合随机锁定至多2张手牌，回合结束消耗；倒计时+1。" if even else "全队添加2层虚无，倒计时+1（每次施放只推进一次）。")
		_: return false
	return true

static func add_void(s: Node, owner: int, amount: int) -> void:
	var u: Dictionary = s.allies[owner]
	var n := int(u.statuses.get("void", {}).get("stacks", 0)) + amount
	if not s.fc.POISON.debuff(u, "void", {"name":"虚无", "desc":"累计5层强制离场，净化清空全部；坚毅可以抵挡并清除虚无。", "stacks":n, "turns":-1, "debuff":true}): return
	if n < 5: return
	if s.lab_invincible_allies: return
	if u.statuses.has("resilience"):
		u.statuses.resilience.stacks = int(u.statuses.resilience.get("stacks", 1)) - 1
		if int(u.statuses.resilience.stacks) <= 0: u.statuses.erase("resilience")
		u.statuses.erase("void")
		s._add_log("%s 的坚毅抵挡了虚无。" % u.name, false)
		return
	if s.fc.ANYA.forced_exit(s.fc, u): return
	u.dead = true
	u.downed = false
	u.hp = 0
	s._remove_caster_cards(String(u.id))
	for pile in [s.hand, s.draw_pile, s.discard_pile, s.fc.calculation, s.fc.exhausted]:
		for card in pile.duplicate():
			if String(card.get("original_caster", card.get("caster_id", ""))) == String(u.id): s.fc.remove_card(pile, card)
	s._add_log("%s 因虚无离场。" % u.name, false)

static func countdown(s: Node) -> void:
	var e := boss(s)
	if e.is_empty() or not s.battle_active: return
	e.countdown += 1
	if int(e.countdown) < 5: return
	e.countdown = 0
	var original: Dictionary = e.intent.duplicate(true)
	e.intent = s.ENEMY_RULES.action(["最后通牒", "最后通牒 max", "最后通牒 promax"][int(e.boss_phase) - 1], "all", s.ENEMY_RULES.scaled(e, [16, 20, 24][int(e.boss_phase) - 1], 0.6) + power(e), "ultimatum", "无视护盾的群体真伤，边缘值增加当前幕数。")
	s.enemy_action_started.emit(s.enemies.find(e))
	for owner in s.ENEMY_RULES.targets(s):
		var result: Dictionary = s._take_damage(s.allies[owner], int(e.intent.damage), true, s.enemies.find(e))
		s.effect_requested.emit("最后通牒", "ally", owner, result.hp, result.guard)
		s.action_resolved.emit("ally", owner)
	e.edge += int(e.boss_phase)
	e.intent = original
	check_result(s)

static func resolve(s: Node, index: int) -> bool:
	var e: Dictionary = s.enemies[index]
	if e.id != BOSS and not String(e.id) in SUMMONS: return false
	if s.fc.POISON.STATUS.skip_action(e):
		s._add_log("%s 处于眩晕，本回合无法行动。" % e.name, false)
		return true
	var b := boss(s)
	if b.is_empty(): return true
	var r = s.ENEMY_RULES
	var targets: Array = r.targets(s)
	var effect := String(e.intent.effect)
	var advance_clock := false
	if targets.is_empty(): return true
	var owner: int = r.single_target(s) if effect == "final_debuff" else int(s.fc.random_entry(targets))
	match effect:
		"nullify":
			var n := int(s.allies[owner].statuses.get("nullify", {}).get("stacks", 0)) + 1
			r.debuff(s, owner, "nullify", "无意义", "下一个技能无效，仍消耗牌与费用；可净化。", -1, {"stacks":n})
			advance_clock = true
		"void":
			if e.id != "false_dawn":
				s.fc.shuffled(targets)
				targets = targets.slice(0, 2 if e.id == "terminal_choir" else 1)
			for target in targets: add_void(s, target, 2 if e.id == "false_dawn" else 1)
			# The final wave advances once per cast, never once per affected ally.
			advance_clock = e.id == "false_dawn"
		"abyss_card":
			var abyss_card: Dictionary = s.ENEMY_RULES.curse(s, "abyss")
			s.discard_pile.append(abyss_card)
			s.ENEMY_RULES.notify_added(s, [abyss_card], "discard")
			advance_clock = true
		"lock_cards":
			b.lock_next = mini(s.HAND_LIMIT, int(b.lock_next) + 2)
			advance_clock = true
		"final_debuff":
			var stage := int(b.boss_phase)
			var edge_at_cast := maxi(0, int(b.edge))
			var victim: Dictionary = s.allies[owner]
			var amount: int = s.fc.damage_amount(e, victim, float(e.intent.damage), false)
			var result: Dictionary = s._take_damage(victim, amount, false, index)
			s.fc.POISON.enemy_attacked(s.fc, index)
			if stage == 3:
				var n := mini(2, int(s.allies[owner].statuses.get("it_ends", {}).get("stacks", 0)) + 1)
				r.debuff(s, owner, "it_ends", "该结束了", "每层最终伤害-20%，受到最终伤害+50%；最多2层。", -1, {"stacks":n, "final_bonus":-0.2 * n, "final_taken_bonus":0.5 * n})
			else:
				var u: Dictionary = s.allies[owner]
				var n := int(u.statuses.get("fragile", {}).get("stacks", 0)) + stage
				r.debuff(s, owner, "fragile", "脆弱", "每层获得护盾-15%，不自然消退，净化减1层。", -1, {"stacks":n, "cleanse_one":true})
				r.debuff(s, owner, "shiver", "颤栗", "受到伤害+50%，层数增加持续回合。", stage, {"damage_taken_mult":1.5})
				r.debuff(s, owner, "weakness", "虚弱", "造成伤害-25%，层数增加持续回合。", stage, {"damage_out_mult":0.75})
			var stacks := int(e.statuses.get("finale_power", {}).get("stacks", 0)) + 1
			var increase := ceili(float(edge_at_cast * POWER_PERCENT[stage - 1]) / 100.0)
			var total := power(e) + increase
			e.statuses.finale_power = {"name":"终末逼近", "desc":"每次施放一步就好，按当时边缘值的%d%%上取整并累加；本幕后续每段攻击及终结技基础伤害+%d。转幕清除。" % [POWER_PERCENT[stage - 1], total], "turns":-1, "stacks":stacks, "base_damage_bonus":total, "debuff":false}
			s.effect_requested.emit(String(e.intent.name), "ally", owner, result.hp, result.guard)
			s.action_resolved.emit("ally", owner)
			advance_clock = true
		"final_tired":
			var stunned := false
			for hit in int(e.intent.hits):
				var victims: Array = r.targets(s) if int(b.boss_phase) == 3 else r.targets(s, true)
				for target in victims:
					var u: Dictionary = s.allies[target]
					var amount: int = s.fc.damage_amount(e, u, float(e.intent.damage), false)
					var result: Dictionary = s._take_damage(u, amount, false, index)
					s.effect_requested.emit("你只是累了", "ally", target, result.hp, result.guard)
					if int(result.hp) > 0 or bool(result.get("anya_suppressed", false)):
						r.debuff(s, target, "stun", "眩晕", "下个我方回合不能释放技能。", 1, {"control":true})
						stunned = stunned or u.statuses.has("stun")
						if int(b.boss_phase) > 1:
							for key in u.statuses.keys():
								if not bool(u.statuses[key].get("debuff", false)) and not bool(u.statuses[key].get("uncleansable", false)): u.statuses.erase(key)
					s.action_resolved.emit("ally", target)
				if not s.battle_active: break
			if int(b.boss_phase) == 3 and stunned:
				s.shared_guard = 0
				s.fc.temporary_guard = 0
				for ally in s.allies:
					ally.guard = 0
					ally.statuses.erase("poison_guard")
	e.ai_step += 1
	if effect != "final_tired" and effect != "final_debuff":
		for target in targets:
			s.effect_requested.emit(String(e.intent.name), "ally", target, 0, 0)
			s.action_resolved.emit("ally", target)
	s._add_log("%s · %s" % [e.name, e.intent.name], false)
	if advance_clock: countdown(s)
	return true

static func after_damage(s: Node, target: Dictionary) -> void:
	if not bool(target.get("finale_summon", false)) or s._is_alive(target) or bool(target.get("finale_counted", false)): return
	target.finale_counted = true
	var e := boss(s)
	if e.is_empty(): return
	var stage := SUMMONS.find(String(target.id)) + 1
	e.hope += 2 if stage == 3 else 1
	e.edge = maxi(0, int(e.edge) - stage)
	e.countdown = maxi(0, int(e.countdown) - 1)
	for other in s.enemies:
		if bool(other.get("finale_summon", false)) and s._is_alive(other): return
	if stage < 3:
		e.countdown = 0
		spawn_wave(s, stage + 1)
	else:
		e.final_ready = true
		add_support(s, "anya_refuse", 1, true)
		event(s, "dawn")
		refresh(s, s.enemies.find(e))

static func card_started(s: Node, c: Dictionary) -> void:
	var e := boss(s)
	if not e.is_empty(): s.fc.finale_card_context = c

static func card_finished(s: Node, c: Dictionary) -> void:
	if is_same(s.fc.finale_card_context, c): s.fc.finale_card_context = {}

static func touch_card(s: Node, c: Dictionary) -> void:
	if not s.battle_active or bool(c.get("virtual", false)) or bool(c.get("finale_counted", false)): return
	var e := boss(s)
	if e.is_empty(): return
	c.finale_counted = true
	e.edge += 1
	if not s.preview_mode:
		s._add_log("攻击终末回响本体：边缘 +1（%d/10）。" % int(e.edge), false)
		event(s, "edge_hit", {"value":int(e.edge)})
	check_result(s)

static func end_hand(s: Node) -> void:
	var e := boss(s)
	if e.is_empty(): return
	for pile in [s.hand, s.draw_pile, s.discard_pile, s.fc.calculation]:
		for card in pile.duplicate():
			if int(card.get("finale_locked", -1)) == s.round:
				s.fc.remove_card(pile, card)
				s.fc.exhausted.append(card)
	e.edge += 1
	check_result(s)

static func lock_hand(s: Node) -> void:
	var e := boss(s)
	if e.is_empty() or int(e.lock_next) <= 0: return
	var options: Array = s.hand.filter(func(card: Dictionary) -> bool: return card.skill_id != "anya_refuse")
	s.fc.shuffled(options)
	for card in options.slice(0, mini(int(e.lock_next), options.size())): card.finale_locked = s.round
	e.lock_next = 0

static func nullified(s: Node, owner: int) -> bool:
	var u: Dictionary = s.allies[owner]
	if not u.statuses.has("nullify"): return false
	u.statuses.nullify.stacks -= 1
	if int(u.statuses.nullify.stacks) <= 0: u.statuses.erase("nullify")
	s._add_log("%s 的技能被无意义吞没。" % u.name, false)
	return true

static func support(s: Node, id: String, target: int) -> void:
	var e := boss(s)
	if e.is_empty(): return
	match id:
		"anya_step":
			e.edge = maxi(0, int(e.edge) - 1)
			s._draw(1)
		"anya_wait":
			var n := int(s.allies[target].statuses.get("resilience", {}).get("stacks", 0)) + 1
			s.fc.status(target, "resilience", -1, {"name":"坚毅", "stacks":n, "desc":"抵挡一次致命伤害或虚无离场；抵挡虚无后清除虚无。"})
		"anya_resist": s.fc.status(target, "debuff_immunity", -1, {"name":"负面免疫", "stacks":int(s.allies[target].statuses.get("debuff_immunity", {}).get("stacks", 0)) + 1})
		"anya_reconcile": s.fc.cleanse(target, false)
		"anya_refuse":
			if bool(e.final_ready) and s.battle_active:
				e.final_ready = false
				e.hope += 1
	check_result(s)

static func defy(s: Node) -> bool:
	var e := boss(s)
	if e.is_empty() or not s.battle_active or s.phase != s.PLAYER_TURN or s.resolving_action or s.pending_turn_draw > 0 or int(e.defiance) <= 0: return false
	e.defiance -= 1
	for u in s.allies:
		var n := int(u.get("finale_defiance", 0)) + 1
		u.finale_defiance = n
	for unit in s.enemies:
		if s._is_alive(unit): unit.statuses.stun = s.fc.POISON.STATUS.definition("stun", {"turns":int(unit.statuses.get("stun", {}).get("turns", 0)) + 1, "tick_on_action":true})
	event(s, "support", {"id":"anya_defy"})
	s._add_log("我不接受这样的结局：永久最终增伤+25%、最终减伤+15%、护盾强效+30%。敌方眩晕一回合。", false)
	s.state_changed.emit()
	return true

static func check_result(s: Node) -> void:
	var e := boss(s)
	if e.is_empty() or not s.battle_active or s.preview_mode: return
	if int(e.edge) >= 10 and not s.lab_invincible_allies:
		s._add_log("边缘值达到10，终末回响吞没了希望。", false)
		s._finish_loss("边缘值达到10。战斗失败。")
	elif int(e.hope) >= 10:
		s._add_log("不，我拒绝！希望值达到10。", false)
		s._finish_victory()
