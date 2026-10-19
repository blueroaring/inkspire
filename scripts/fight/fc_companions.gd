extends RefCounted
const STATUS := preload("res://scripts/fight/status_rules.gd")
## 陈默 / 体育生徐明明。状态留在单位上，使预览与正式结算共用规则。

static func marks(unit: Dictionary) -> int:
	return int(unit.statuses.get("latent_marks", {}).get("stacks", 0))

static func gain_marks(f: RefCounted, owner: int, amount: int) -> void:
	var unit: Dictionary = f.s.allies[owner]
	if amount <= 0 or not f.s._is_alive(unit) or unit.statuses.has("pb_lock"): return
	f.status(owner, "latent_marks", -1, {"name":"潜印", "desc":"弃置手牌积累，回合结束自动弃牌不增加；用于徐明明的爆发技能。", "stacks":marks(unit) + amount, "category":"counter"})

static func consume_marks(f: RefCounted, owner: int, count: int = -1) -> Dictionary:
	var unit: Dictionary = f.s.allies[owner]
	var spent := marks(unit) if count < 0 else mini(count, marks(unit))
	var remaining := marks(unit) - spent
	if remaining == 0: unit.statuses.erase("latent_marks")
	else: unit.statuses.latent_marks.stacks = remaining
	if spent > 0 and unit.statuses.has("restraint"):
		unit.statuses.restraint.stacks -= 1
		if int(unit.statuses.restraint.stacks) <= 0: unit.statuses.erase("restraint")
		gain_marks(f, owner, floori(spent * 0.5))
	return {"spent":spent, "remaining":remaining}

static func discarded(f: RefCounted) -> void:
	var owner: int = f.s._ally_index("xumingming")
	if owner >= 0: gain_marks(f, owner, mini(2, FightProgression.rank()) + 1)

static func timed(f: RefCounted, owner: int, id: String, turns: int, data: Dictionary) -> void:
	data = data.duplicate(true)
	data.fc_after_enemy = true
	f.status(owner, id, turns, data)

static func taunt(f: RefCounted, owner: int, turns: int) -> void:
	var old := int(f.s.allies[owner].statuses.get("taunt", {}).get("turns", 0))
	for ally in f.s.allies: ally.statuses.erase("taunt")
	timed(f, owner, "taunt", old + turns, {"name":"嘲讽", "desc":"吸引单体攻击；陈默同时分担队友的生命伤害。"})

static func reflect(f: RefCounted, owner: int, turns: int) -> void:
	var old := int(f.s.allies[owner].statuses.get("reflect", {}).get("turns", 0))
	timed(f, owner, "reflect", old + turns, {"name":"反伤", "desc":"护盾吸收的伤害等量反弹给攻击者。"})

static func controlled(status: Dictionary, id: String) -> bool:
	return STATUS.is_debuff(status) and (bool(status.get("control", false)) or id in ["stun", "freeze", "frozen", "sleep", "silence", "confusion", "immobilized"])

static func is_controlled(unit: Dictionary) -> bool:
	for id in unit.statuses:
		if controlled(unit.statuses[id], String(id)): return true
	return false

static func healing_blocked(unit: Dictionary) -> bool:
	return unit.statuses.has("last_stand") or unit.statuses.has("athlete_burst")

static func share_owner(f: RefCounted, target: Dictionary) -> int:
	var owner: int = f.s._ally_index("chenmo")
	if owner < 0 or is_same(f.s.allies[owner], target): return -1
	var unit: Dictionary = f.s.allies[owner]
	return owner if f.s._is_alive(unit) and unit.statuses.has("taunt") else -1

static func after_damage(f: RefCounted, target: Dictionary, result: Dictionary, enemy_source: int) -> void:
	if not f.s._is_ally_unit(target): return
	target.round_damage = int(target.get("round_damage", 0)) + int(result.hp) + int(result.guard)
	if enemy_source < 0 or enemy_source >= f.s.enemies.size() or not target.statuses.has("reflect") or int(result.guard) <= 0: return
	var multiplier := (2.0 if target.statuses.has("reflect_double") else 1.0) + float(target.get("equipment", {}).get("reflect_bonus", 0.0))
	var reflected: Dictionary = f.s._take_damage(f.s.enemies[enemy_source], roundi(int(result.guard) * multiplier))
	f.ANYA.attacked(f, f.s.allies.find(target), enemy_source, int(reflected.hp) + int(reflected.guard))
	f.s.ENEMY_RULES.CHALLENGES.record_owner(f.s, f.s._ally_index(String(target.id)))
	f.s.effect_requested.emit("C_reflect", "enemy", enemy_source, reflected.hp, reflected.guard)
	f.s._add_log("%s 反弹 %d 点护盾伤害。" % [target.name, int(reflected.hp) + int(reflected.guard)], false)

static func after_enemy_turn(f: RefCounted) -> void:
	for i in f.s.allies.size():
		var unit: Dictionary = f.s.allies[i]
		if bool(unit.get("anya_hidden", false)): continue
		var alive: bool = f.s._is_alive(unit)
		var recorded := int(unit.get("round_damage", 0)) if unit.statuses.has("damage_record") else 0
		var trusted: bool = alive and unit.statuses.has("trust_pending") and int(unit.get("round_hp_damage", 0)) == 0
		if alive and unit.statuses.has("calculation_pending") and int(unit.get("round_hp_damage", 0)) == 0: f.charge(i, 2)
		for id in unit.statuses.keys():
			if id == "cleanseable_immunity":
				f.POISON.STATUS.expire_ward(unit)
				continue
			var status: Dictionary = unit.statuses[id]
			if not bool(status.get("fc_after_enemy", false)) or int(status.get("turns", -1)) < 0: continue
			status.turns -= 1
			if int(status.turns) <= 0: unit.statuses.erase(id)
		if alive:
			if recorded > 0:
				var before_guard := int(unit.guard)
				f.s._add_guard(unit, recorded)
				var gained := int(unit.guard) - before_guard
				if gained > 0: f.s.turn_guard_gained.emit(i, gained)
			if trusted: timed(f, i, "trust", 2, {"name":"信任", "desc":"造成的伤害提高20%（非最终伤害）。", "damage_bonus":0.2})
		unit.round_damage = 0
		unit.round_hp_damage = 0

static func adjacent_enemies(f: RefCounted, target: int) -> Array:
	# Match battle.gd: four foes use a 2x2 formation; five/six use three columns.
	var visible: Array = []
	for i in f.s.enemies.size():
		if f.s._is_alive(f.s.enemies[i]): visible.append(i)
	var at := visible.find(target)
	var columns := visible.size() if visible.size() <= 3 else 2 if visible.size() == 4 else 3
	var result: Array = []
	if at < 0: return result
	for offset in [-1, 1]:
		var next := at + int(offset)
		if next >= 0 and next < visible.size() and next / columns == at / columns: result.append(visible[next])
	return result

static func execute(f: RefCounted, c: Dictionary) -> void:
	var s: Node = f.s
	var o := int(c.owner)
	var t := int(c.target)
	var unit: Dictionary = s.allies[o]
	var id: String = f.code(c.card)
	match id:
		"C01":
			s._add_guard(unit, f.scaled(o, 12))
			taunt(f, o, 1)
		"C02":
			s._add_guard(unit, f.scaled(o, 8))
			reflect(f, o, 1)
		"C03":
			f.ask("全力防御：选择任意数量手牌弃置", f.hand_cards(), 0, s.hand.size(), func(cards: Array) -> void:
				for card in cards: f.move_from_hand(card, s.discard_pile)
				s._add_guard(unit, cards.size() * f.scaled(o, 16))
				f.finish(c)
			)
			return
		"C04": timed(f, o, "damage_record", 1, {"name":"以逸待劳", "desc":"本轮承受的全部护盾及生命伤害，下回合转为护盾。"})
		"C05":
			if t >= 0 and not bool(s.allies[t].downed):
				var lost := floori(int(s.allies[t].hp) * 0.5)
				f.lose_hp(t, lost)
				s._add_guard(unit, lost)
				taunt(f, o, 1)
		"C06":
			f.cleanse(t, false)
			s._add_guard(s.allies[t], f.scaled(o, 26))
		"C07":
			for i in s.allies.size():
				if s._is_alive(s.allies[i]): s._add_guard(s.allies[i], f.scaled(o, 40 if i == o else 12))
			taunt(f, o, 1)
			reflect(f, o, 1)
		"C08": timed(f, t, "trust_pending", 1, {"name":"信任链接", "desc":"本轮未损失生命，下回合获得两回合信任。"})
		"C09":
			if is_controlled(unit):
				for key in unit.statuses.keys():
					if controlled(unit.statuses[key], String(key)) and not bool(unit.statuses[key].get("uncleansable", false)): unit.statuses.erase(key)
				taunt(f, o, 1)
				timed(f, o, "pain_guard", 1, {"name":"无惧疼痛", "desc":"受到伤害降低50%。", "damage_reduction":0.5})
		"C10":
			taunt(f, o, 1)
			reflect(f, o, 1)
			timed(f, o, "calculation_pending", 1, {"name":"精密计算", "desc":"本轮未损失生命，额外获得2点终结技能量。"})
		"C11":
			var lost := maxi(0, int(unit.hp) - 1)
			f.lose_hp(o, lost)
			s._add_guard(unit, lost * 2)
			f.status(o, "last_stand", -1, {"name":"孤注一掷", "desc":"本场战斗无法被治疗，不可净化。", "debuff":true, "uncleansable":true})
		"C12":
			s.shared_guard += f.PAINTING.shield_amount(unit, int(unit.guard))
			unit.guard = 0
		"C13": s._draw(3 if int(unit.guard) >= int(unit.hp) else 2)
		"X01":
			f.hit(c, t, 4)
			gain_marks(f, o, 2)
		"X02":
			gain_marks(f, o, 2)
			f.ask("补水：选择另一张自己的手牌保留", f.hand_cards(func(card: Dictionary) -> bool: return String(card.caster_id) == String(unit.id)), 1, 1, func(cards: Array) -> void:
				for card in cards: card.retain = true
				f.finish(c)
			)
			return
		"X03", "X06", "X11":
			if id == "X11": timed(f, o, "pb_lock", 3, {"name":"PB · 恢复期", "desc":"无法获得潜印（包括本次收力返还），不可净化。", "debuff":true, "uncleansable":true})
			var neighbors := adjacent_enemies(f, t)
			var spent := int(consume_marks(f, o).spent)
			c.mark_damage = true
			var base := 3 if id == "X03" else 8 if id == "X06" else 4
			var per_mark := 3 if id == "X03" else 4 if id == "X06" else 8
			hit_mark_damage(f, c, t, base, per_mark * spent)
			if id == "X06" and spent > 0:
				for neighbor in neighbors: hit_mark_damage(f, c, int(neighbor), 0, spent)
		"X04":
			gain_marks(f, o, 3)
			s._draw(2)
		"X05":
			var drawn: Array = f.take_draw(4)
			# Drawn cards become hand cards before the discard, including at hand cap.
			for card in drawn: s.hand.append(card)
			f.ask("多组训练：弃置抽到的一张，其余获得保留", drawn, 1, 1, func(cards: Array) -> void:
				for card in cards:
					f.move_from_hand(card, s.discard_pile)
					f.remove_card(drawn, card)
				for card in drawn: card.retain = true
				while s.hand.size() > s.expansion_hand_limit: f.move_from_hand(s.hand[-1], s.discard_pile)
				f.finish(c)
			)
			return
		"X07": f.status(o, "restraint", -1, {"name":"收力", "desc":"每次消耗潜印返还50%，向下取整；层数为剩余次数。", "stacks":int(unit.statuses.get("restraint", {}).get("stacks", 0)) + 1})
		"X08":
			var count: int = s.hand.size()
			for card in f.hand_cards(): f.move_from_hand(card, s.discard_pile)
			s._draw(count)
		"X09":
			c.mark_damage = true
			run_burst(f, c)
			return
		"X10": gain_marks(f, o, floori(marks(unit) * 0.5))
		"X12":
			f.ask("下次会进决赛：弃置一张牌，下次使用免费", f.hand_cards(), 1, 1, func(cards: Array) -> void:
				for card in cards:
					card.free = true
					f.move_from_hand(card, s.discard_pile)
				f.finish(c)
			)
			return
		"X13": gain_marks(f, o, int(s.round) * 2)
	f.finish(c)

static func hit_mark_damage(f: RefCounted, c: Dictionary, target: int, base: int, mark_bonus: int) -> void:
	# Only the constant base grows. Keep its fraction until the shared damage
	# calculation rounds; marks still receive normal buffs/attribute modifiers.
	var growth := FightData.growth(int(f.s.allies[c.owner].level))
	f.hit(c, target, base * growth + mark_bonus, false)

static func run_burst(f: RefCounted, c: Dictionary) -> void:
	var s: Node = f.s
	while marks(s.allies[c.owner]) >= 2:
		if f.damage_interrupted(c.damage_phases): break
		var targets: Array = []
		for i in s.enemies.size():
			if s._is_alive(s.enemies[i]): targets.append(i)
		if targets.is_empty(): break
		var remaining := int(consume_marks(f, int(c.owner), 2).remaining)
		var target: int = f.random_entry(targets)
		hit_mark_damage(f, c, target, 2, 2 * remaining)
		var math_owner: int = s._ally_index("zhoumingyuan")
		if f.is_math(math_owner) and f.locked_alive() and (target == f.locked_enemy or f.noticed):
			# Most pursuits finish synchronously. Only a counterfeit choice suspends the loop.
			var completion := [false, true]
			f.pursue(math_owner, 1, true, func() -> void:
				completion[0] = true
				if not completion[1]: run_burst(f, c)
			, c.damage_phases)
			completion[1] = false
			if not completion[0]: return
	f.finish(c)

static func ultimate(f: RefCounted, owner: int) -> void:
	var unit: Dictionary = f.s.allies[owner]
	if String(unit.id) == "chenmo":
		taunt(f, owner, 2)
		reflect(f, owner, 2)
		f.s._add_guard(unit, f.scaled(owner, 30))
		timed(f, owner, "reflect_double", 2, {"name":"都往我这边站", "desc":"反伤倍率提高至200%。"})
		f.s.effect_requested.emit("ultimate_chen", "ally", owner, 0, 0)
	else:
		gain_marks(f, owner, 3)
		timed(f, owner, "athlete_burst", 1, {"name":"一级运动员", "desc":"消耗潜印的伤害翻倍；无法被治疗或获得个人护盾。不可净化。", "uncleansable":true, "category":"special"})
		f.s.effect_requested.emit("ultimate_xu", "ally", owner, 0, 0)
