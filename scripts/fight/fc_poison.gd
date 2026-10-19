extends RefCounted
const STATUS := preload("res://scripts/fight/status_rules.gd")
## 苏婉青：毒层数和引爆计数共存于可净化状态，预览使用相同结算。

static func layers(unit: Dictionary) -> int:
	return int(unit.get("statuses", {}).get("poison", {}).get("stacks", 0))

static func absent(unit: Dictionary) -> bool:
	return unit.get("statuses", {}).has("offstage")

static func debuff(unit: Dictionary, id: String, data: Dictionary) -> bool:
	if bool(unit.get("phase_pending", false)): return false
	var statuses: Dictionary = unit.statuses
	if statuses.has("debuff_immunity") and (not bool(statuses.debuff_immunity.get("cleanseable_only", false)) or not bool(data.get("uncleansable", false))):
		statuses.debuff_immunity.stacks = int(statuses.debuff_immunity.get("stacks", 1)) - 1
		if int(statuses.debuff_immunity.stacks) <= 0: statuses.erase("debuff_immunity")
		return false
	if not bool(data.get("uncleansable", false)) and STATUS.consume_ward(unit):
		return false
	STATUS.apply_debuff(unit, id, data)
	return true

static func cleanse_enemy(f: RefCounted, target: int, id: String = "poison") -> void:
	if target < 0 or target >= f.s.enemies.size(): return
	var unit: Dictionary = f.s.enemies[target]
	var statuses: Dictionary = unit.statuses
	if unit.id == "report_card" and statuses.has("offstage"):
		statuses.erase("offstage")
		unit.hp = 0
		f.s._add_log("成绩单的残影被净化，无法复生。", false)
		return
	if statuses.has(id) and STATUS.is_debuff(statuses[id]) and not bool(statuses[id].get("uncleansable", false)):
		statuses.erase(id)

static func add(f: RefCounted, target: int, amount: int) -> void:
	if amount <= 0 or target < 0 or target >= f.s.enemies.size(): return
	var unit: Dictionary = f.s.enemies[target]
	if not f.s._is_alive(unit): return
	var previous: Dictionary = unit.statuses.get("poison", {})
	if debuff(unit, "poison", {"name":"毒", "desc":"每受到5段攻击引爆一次；固定伤害先扣护盾，随后毒减少1层。净化一次清空。", "stacks":layers(unit) + amount, "counter":int(previous.get("counter", 0)), "turns":-1}):
		f.s.effect_requested.emit("poison_apply", "enemy", target, 0, 0)

static func detonate(f: RefCounted, target: int) -> void:
	if f.damage_interrupted(): return
	var unit: Dictionary = f.s.enemies[target]
	var count := layers(unit)
	if count <= 0 or not f.s._is_alive(unit): return
	if unit.id == f.s.ENEMY_RULES.FINALE.BOSS and not f.finale_card_context.is_empty():
		f.s.ENEMY_RULES.FINALE.touch_card(f.s, f.finale_card_context)
		if not f.s.battle_active: return
	# Fixed damage intentionally bypasses damage_amount, but still consumes shields.
	var bonus := 0.0
	var owner: int = f.s._ally_index("suwanqing")
	if owner >= 0 and f.s._is_alive(f.s.allies[owner]): bonus = float(f.s.allies[owner].get("equipment", {}).get("poison_bonus", 0.0))
	var damage := roundi(count * (1.0 + bonus))
	var result: Dictionary = f.s._take_damage(unit, damage)
	f.ANYA.attacked(f, owner, target, int(result.hp) + int(result.guard))
	if damage > 0: f.s.ENEMY_RULES.CHALLENGES.record_owner(f.s, owner)
	if count == 1: unit.statuses.erase("poison")
	elif unit.statuses.has("poison"):
		unit.statuses.poison.stacks = count - 1
		unit.statuses.poison.counter = 0
	f.s.effect_requested.emit("poison_burst", "enemy", target, result.hp, result.guard)
	f.s._add_log("%s 的毒引爆，造成%d点伤害。" % [unit.name, damage], false)
	for ally in f.s.allies:
		if f.s._is_alive(ally) and ally.statuses.has("gossip_draw"):
			f.s._draw(1)
			break

static func advance(f: RefCounted, target: int, amount: int) -> void:
	if f.damage_interrupted(): return
	var unit: Dictionary = f.s.enemies[target]
	if layers(unit) <= 0 or not f.s._is_alive(unit): return
	var counter := int(unit.statuses.poison.get("counter", 0)) + amount
	var phases: Array = f.damage_phases()
	while counter >= 5 and layers(unit) > 0 and f.s._is_alive(unit) and not f.damage_interrupted(phases):
		counter -= 5
		detonate(f, target)
	if layers(unit) > 0: unit.statuses.poison.counter = counter

static func attacked(f: RefCounted, target: int) -> void:
	advance(f, target, 1)
	var unit: Dictionary = f.s.enemies[target]
	# The fifth hit detonates first, then 记仇 adds its new layer.
	if f.s._is_alive(unit) and unit.statuses.has("grudge"): add(f, target, 1)

static func enemy_attacked(f: RefCounted, target: int) -> void:
	if f.s.enemies[target].statuses.has("hair_pull"): add(f, target, 2)

static func weakness(f: RefCounted, unit: Dictionary) -> float:
	var owner: int = f.s._ally_index("suwanqing")
	if owner < 0 or not f.s._is_alive(f.s.allies[owner]): return 0.0
	if layers(unit) <= 0 or layers(unit) < ceili(float(unit.get("max_hp", 1)) * 0.1): return 0.0
	return [0.10, 0.15, 0.20][mini(2, FightProgression.rank())]

static func backlash(f: RefCounted, owner: int, stacks: int) -> void:
	if f.s.lab_invincible_allies: return
	var unit: Dictionary = f.s.allies[owner]
	if not f.s._is_alive(unit): return
	var lost := floori(float(unit.max_hp) * 0.05 * stacks)
	unit.max_hp = maxi(1, int(unit.max_hp) - lost)
	if bool(unit.get("downed", false)) or int(unit.hp) <= 0:
		if f.ANYA.forced_exit(f, unit): return
		unit.dead = true
		unit.downed = false
		unit.hp = 0
		f.s._remove_caster_cards(String(unit.id))
		f.s.effect_requested.emit("self_loss", "ally", owner, lost, 0)
		f.s._add_log("%s 因反噬退场。" % unit.name, false)
	else: f.lose_hp(owner, lost)

static func round_started(f: RefCounted) -> void:
	for i in f.s.allies.size():
		var status: Dictionary = f.s.allies[i].statuses.get("backlash", {})
		if not status.is_empty(): backlash(f, i, int(status.stacks))

static func partner_options(f: RefCounted, owner: int) -> Array:
	var options: Array = []
	for i in f.s.allies.size():
		if i != owner and f.s._is_alive(f.s.allies[i]) and not absent(f.s.allies[i]):
			options.append({"label":f.s.allies[i].name, "ally":i})
	return options

static func execute(f: RefCounted, c: Dictionary) -> void:
	var s: Node = f.s
	var o := int(c.owner)
	var t := int(c.target)
	var unit: Dictionary = s.allies[o]
	match f.code(c.card):
		"D01":
			# Only newly applied base layers grow; existing poison never scales again.
			add(f, t, f.scaled(o, 4))
			f.hit(c, t, 3)
		"D02": detonate(f, t)
		"D03":
			if layers(s.enemies[t]) > 0: add(f, t, f.scaled(o, 12))
		"D04":
			var amount := floori(layers(s.enemies[t]) * 0.75)
			for neighbor in f.COMPANIONS.adjacent_enemies(f, t): add(f, int(neighbor), amount)
		"D05":
			for hit in 5:
				if f.damage_interrupted(c.damage_phases): break
				var targets: Array = []
				for i in s.enemies.size():
					if s._is_alive(s.enemies[i]): targets.append(i)
				if targets.is_empty(): break
				f.hit(c, int(f.random_entry(targets)), 2)
		"D06":
			for i in s.enemies.size():
				if f.damage_interrupted(c.damage_phases): break
				advance(f, i, 3)
			f.COMPANIONS.timed(f, o, "offstage", 1, {"name":"离场", "desc":"本回合免疫伤害且不被敌人锁定；无法直接释放技能或终结技。", "category":"special"})
		"D07":
			if debuff(s.enemies[t], "grudge", {"name":"记仇", "desc":"本回合每受到一段攻击，在毒引爆后获得1层毒。", "turns":1}):
				s.effect_requested.emit("D07", "enemy", t, 0, 0)
		"D08":
			detonate(f, t)
			var options: Array = []
			for i in s.enemies.size():
				if i != t and s._is_alive(s.enemies[i]): options.append({"label":s.enemies[i].name, "enemy":i})
			f.ask("替罪羊：选择毒转移的敌人", options, 1, 1, func(cards: Array) -> void:
				if not cards.is_empty():
					var count := layers(s.enemies[t])
					s.enemies[t].statuses.erase("poison")
					add(f, int(cards[0].enemy), count)
				f.finish(c)
			)
			return
		"D09":
			f.ask("借刀杀人：选择本回合封存的手牌", f.hand_cards(), 0, s.hand.size(), func(cards: Array) -> void:
				for card in cards: card.sealed_round = s.round
				add(f, t, cards.size() * 2)
				f.finish(c)
			)
			return
		"D10":
			f.ask("我们是伙伴：选择获得临时护盾的队友", partner_options(f, o), 1, 1, func(cards: Array) -> void:
				if not cards.is_empty():
					var ally := int(cards[0].ally)
					var statuses: Dictionary = s.allies[ally].statuses
					var amount: int = f.PAINTING.shield_amount(s.allies[ally], layers(s.enemies[t]))
					if amount > 0 and not statuses.has("no_guard") and not statuses.has("athlete_burst"):
						amount += int(statuses.get("poison_guard", {}).get("stacks", 0))
						f.COMPANIONS.timed(f, ally, "poison_guard", 1, {"name":"个人临时护盾", "desc":"本回合有效的个人临时护盾，优先于个人普通护盾消耗。", "stacks":amount})
						s.effect_requested.emit("D10", "ally", ally, 0, 0)
				f.finish(c)
			)
			return
		"D11":
			var holder := o
			for i in s.allies.size():
				if s._is_alive(s.allies[i]) and s.allies[i].statuses.has("gossip_draw"): holder = i
			var turns := int(s.allies[holder].statuses.get("gossip_draw", {}).get("turns", 0)) + 1
			f.COMPANIONS.timed(f, holder, "gossip_draw", turns, {"name":"讲个爆的", "desc":"每引爆一次毒抽1张牌；重复使用延长回合数。"})
		"D12":
			if debuff(s.enemies[t], "hair_pull", {"name":"扯头花", "desc":"每段攻击结束后自身获得2层毒；可净化。", "turns":-1}):
				s.effect_requested.emit("D12", "enemy", t, 0, 0)
			var stacks := int(unit.statuses.get("backlash", {}).get("stacks", 0)) + 1
			var applied: bool = f.status(o, "backlash", -1, {"name":"反噬", "desc":"每回合按当时最大生命的5%×层数扣减最大和当前生命，向下取整。濒死时直接退场；净化只减1层。", "debuff":true, "stacks":stacks, "cleanse_one":true})
			# Only the newly applied layer ticks now; older layers already ticked this round.
			if applied: backlash(f, o, 1)
		"D13":
			for i in s.enemies.size():
				var enemy: Dictionary = s.enemies[i]
				enemy.statuses.erase("debuff_immunity")
				enemy.statuses.erase("cleanseable_immunity")
				enemy.guard = 0
				if s._is_alive(enemy): s.effect_requested.emit("D13", "enemy", i, 0, 0)
			var stacks := int(unit.statuses.get("perishing", {}).get("stacks", 0)) + 4
			f.status(o, "perishing", -1, {"name":"消亡", "desc":"每层使受到的最终伤害提高25%，不会自然消退；净化只减1层。", "debuff":true, "stacks":stacks, "cleanse_one":true, "final_taken_bonus":stacks * 0.25})
	f.finish(c)

static func ultimate(f: RefCounted, owner: int, done: Callable) -> void:
	var phases: Array = f.damage_phases()
	for repeat in 3:
		if f.damage_interrupted(phases): break
		for i in f.s.enemies.size():
			if f.damage_interrupted(phases): break
			detonate(f, i)
	f.s.effect_requested.emit("ultimate_su", "ally", owner, 0, 0)
	# Detonations are not attacks; 注意到 can still respond to an enemy-targeted skill.
	var math_owner: int = f.s._ally_index("zhoumingyuan")
	var count := 1 if f.is_math(math_owner) and f.noticed and f.locked_alive() else 0
	f.pursue(math_owner, count, true, done, phases)
