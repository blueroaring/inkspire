extends RefCounted
## Extra encounter state stays on units so previews and lab resets remain isolated.
const IDS := ["math_exam", "perfect_score", "inverse_limit"]
const FUNCTIONS := ["x", "x+4", "x+3√x+5", "|2x-1|+8", "2x+10", "2x+x²/(x+6)+12", "3x+12", "3x+2^(min(x,8)/2)+12", "4x+24", "4x+x²/(x+6)+30"]

static func setup(e: Dictionary) -> void:
	e.function_stage = 0
	e.score = 0
	e.score_pending = 0
	e.score_hits = 0
	e.mirror = {}
	e.mirror_round = -1
	e.next_draw_penalty = 0
	e.next_energy_penalty = 0
	if e.id == "math_exam":
		e.guard = exam_guard(e)
		describe_function(e)
	if e.id == "perfect_score": describe_score(e)
	if e.id == "inverse_limit": field(e)

static func field(e: Dictionary) -> void:
	var stage := int(e.boss_phase)
	var words := ["脚滑：我方普通攻击、技能与追击每段基础伤害减少S(2)，最低0；毒爆和反伤等固定伤害不受影响。", "伤病复发：每打出一张攻击牌，使用者获得1层隐痛；回合结束一次性失去等于层数的生命，净化清空全部隐痛。", "镜像复制：每回合回放上一回合第一张攻击牌的伤害段，全部指向原使用者；不复制其他效果。"]
	e.statuses.challenge_field = {"name":["阴雨低压", "旧伤回响", "破限镜像"][stage - 1], "art_key":["field_rain", "field_wound", "field_mirror"][stage - 1], "desc":words[stage - 1], "turns":-1, "uncleansable":true, "debuff":false}

static func exam_guard(e: Dictionary) -> int:
	return 40 + roundi(maxi(0, int(e.level) - 1) * (1.2 if TowerRun.active else 2.0))

static func describe_function(e: Dictionary) -> void:
	e.statuses.exam_function = {"name":"函数 · " + FUNCTIONS[int(e.function_stage)], "desc":"每次函数攻击后前进两档；每次损失生命后退一档，护盾吸收不退档。共10档。", "turns":-1, "debuff":false, "uncleansable":true}

static func describe_score(e: Dictionary) -> void:
	e.statuses.score_rule = {"name":"分数 %d/100 · 待结算 +%d" % [e.score, e.score_pending], "desc":"所有正伤害最多结算1点，不能以伤害击败。每次命中计6分，原伤害每20点额外1分，最多额外4分；毒爆、反伤均计入。敌方回合开始加分，100分退场。本轮%d次命中。" % e.score_hits, "turns":-1, "debuff":false, "uncleansable":true}

static func function_damage(e: Dictionary) -> int:
	var x: int = roundi(7 + (int(e.level) - 1) * (0.35 if TowerRun.active else 0.5))
	match int(e.function_stage):
		0: return x
		1: return x + 4
		2: return roundi(x + 3.0 * sqrt(float(x)) + 5.0)
		3: return absi(2 * x - 1) + 8
		4: return 2 * x + 10
		5: return roundi(2 * x + float(x * x) / (x + 6) + 12)
		6: return 3 * x + 12
		7: return roundi(3 * x + pow(2.0, mini(x, 8) / 2.0) + 12)
		8: return 4 * x + 24
		_: return roundi(4 * x + float(x * x) / (x + 6) + 30)

static func refresh(s: Node, index: int) -> bool:
	var e: Dictionary = s.enemies[index]
	if not String(e.id) in IDS: return false
	if bool(e.get("phase_pending", false)): return true
	var r = s.ENEMY_RULES
	var step := int(e.ai_step)
	var moves: Array = []
	match String(e.id):
		"math_exam":
			if step % 3 == 2:
				e.intent = r.action("无从下手", "all", 0, "exam_guard", "获得%d护盾；下回合继续函数攻击。" % exam_guard(e))
			else:
				e.intent = r.action("f(x) = " + FUNCTIONS[int(e.function_stage)], "single", function_damage(e), "function", "当前函数造成%d基础伤害；本次攻击后函数进两档。每次损失生命使函数退一档。" % function_damage(e))
			return true
		"perfect_score":
			moves = [r.action("你落后了！", "single", r.scaled(e, 12, 0.65), "lowest_hp", "无视嘲讽，锁定当前生命最低的可攻击角色。"), r.action("继续做！", "all", r.scaled(e, 10, 0.6), "non_attackers", "攻击上一回合未造成攻击、毒爆或反伤的角色；所有人均参与攻击时没有目标。")]
		"inverse_limit":
			match int(e.boss_phase):
				1:
					moves = [r.action("状态低迷", "single", r.scaled(e, 10), "low_state", "攻击；下回合少抽1张牌、少1能量。"), r.action("阴雨连绵", "all", r.scaled(e, 5, 0.3), "damp", "攻击全体，抽牌堆随机加入2张潮湿；每抽到一张，全队获得一层脆弱（盾量-15%，可叠加）。"), r.action("热身不足", "single", r.scaled(e, 9, 0.5), "warmup", "攻击并获得护盾。")]
				2:
					if step % 3 == 2 and int(e.hp) < float(e.max_hp) * 0.5:
						e.intent = r.action("封闭针", "all", 0, "injection", "恢复最大生命10%，解除自身一个可解除的负面效果。不会倒退阶段。")
						return true
					moves = [r.action("疼痛放大", "single", r.scaled(e, 12, 0.7), "pain", "单体伤害后，额外结算一次该角色的隐痛；不消耗层数。")]
				3:
					moves = [r.action("极限施压", "single", r.scaled(e, 16, 0.9), "pressure", "锁定上一回合第一张攻击牌的使用者；没有记录或原使用者已退场则随机选择。")]
	e.intent = moves[step % moves.size()].duplicate(true)
	return true

static func hit(s: Node, index: int, target: int, base: float, name: String, attribute: String = "") -> void:
	if target < 0 or not s._is_alive(s.enemies[index]) or not s._enemy_targetable(s.allies[target]): return
	var damage: int = s.fc.damage_amount(s.enemies[index], s.allies[target], base, false, attribute)
	var result: Dictionary = s._take_damage(s.allies[target], damage, false, index)
	s.effect_requested.emit(name, "ally", target, result.hp, result.guard)
	s.action_resolved.emit("ally", target)
	if damage > 0: s.fc.POISON.enemy_attacked(s.fc, index)

static func pain(s: Node, owner: int) -> void:
	if not s._is_alive(s.allies[owner]): return
	var layers := int(s.allies[owner].statuses.get("hidden_pain", {}).get("stacks", 0))
	# One HP-loss event for the full stack total, never N one-point hits.
	if layers > 0: s.fc.lose_hp(owner, layers)

static func drawn(s: Node, card: Dictionary) -> void:
	if card.skill_id != "damp": return
	for i in s.allies.size():
		var layers := int(s.allies[i].statuses.get("fragile", {}).get("stacks", 0)) + 1
		if TowerRun.active: layers = mini(3, layers)
		s.ENEMY_RULES.debuff(s, i, "fragile", "脆弱", "每层使获得的护盾降低15%，层数加算（最低0）；不随回合减少，每次净化只移除1层。", -1, {"stacks":layers, "cleanse_one":true})
		if TowerRun.active and s.allies[i].statuses.has("fragile"):
			s.allies[i].statuses.fragile.desc = "每层使护盾量降低15%，尖塔中最多3层；不自然消退，每次净化移除1层。"

static func record_owner(s: Node, owner: int) -> void:
	if owner >= 0 and owner < s.allies.size(): s.allies[owner].challenge_attack_round = s.round

static func mirror_owner(s: Node, e: Dictionary) -> int:
	var record: Dictionary = e.get("mirror", {})
	if int(e.get("mirror_round", -1)) == s.round:
		var owner := int(record.get("owner", -1))
		if owner >= 0 and owner < s.allies.size() and s._enemy_targetable(s.allies[owner]): return owner
	return -1

static func resolve(s: Node, index: int) -> bool:
	var e: Dictionary = s.enemies[index]
	if not String(e.id) in IDS: return false
	var r = s.ENEMY_RULES
	var intent: Dictionary = e.intent.duplicate(true)
	r.revive_phase(e)
	var effect := String(intent.get("effect", ""))
	var transition := bool(e.get("phase_pending", false))
	var chosen: Array = r.targets(s) if intent.kind == "all" else [r.single_target(s)]
	if effect == "lowest_hp":
		chosen = r.targets(s)
		chosen.sort_custom(func(a: int, b: int) -> bool: return int(s.allies[a].hp) < int(s.allies[b].hp))
		chosen = chosen.slice(0, 1)
	if effect == "non_attackers":
		chosen = chosen.filter(func(i: int) -> bool: return int(s.allies[i].get("challenge_attack_round", -1)) != s.round)
	if effect == "pressure":
		var owner := mirror_owner(s, e)
		chosen = [owner] if owner >= 0 else [r.single_target(s)]
	var hits := int(intent.get("hits", 1))
	if effect == "downpour":
		var damp_count := 0
		for pile in [s.hand, s.draw_pile, s.discard_pile, s.fc.calculation]:
			for card in pile.duplicate():
				if card.skill_id == "damp":
					pile.erase(card)
					s.fc.exhausted.append(card)
					damp_count += 1
		hits = 1 + (mini(3, damp_count) if TowerRun.active else damp_count)
	for _h in hits:
		if not s._is_alive(e) or (not transition and bool(e.get("phase_pending", false))): break
		for target in chosen:
			if not transition and bool(e.get("phase_pending", false)): break
			if float(intent.damage) > 0: hit(s, index, target, float(intent.damage), String(intent.name))
			if effect == "pain" and target >= 0: pain(s, target)
	if not transition and bool(e.get("phase_pending", false)):
		s.enemy_action_started.emit(index)
		resolve(s, index)
		return true
	match effect:
		"exam_guard": s._add_guard(e, exam_guard(e))
		"function":
			e.function_stage = mini(FUNCTIONS.size() - 1, int(e.function_stage) + 2)
			describe_function(e)
		"low_state":
			e.next_draw_penalty = int(e.next_draw_penalty) + 1
			e.next_energy_penalty = int(e.next_energy_penalty) + 1
		"damp":
			var added: Array = []
			for _i in 2:
				var card: Dictionary = r.curse(s, "damp")
				s.draw_pile.insert(s.fc.random_position(s.draw_pile.size()), card)
				added.append(card)
			r.notify_added(s, added, "deck")
		"warmup": s._add_guard(e, r.scaled(e, 18, 0.9))
		"injection":
			e.hp = mini(int(e.max_hp), int(e.hp) + roundi(float(e.max_hp) * 0.1))
			for id in e.statuses.keys():
				if bool(e.statuses[id].get("debuff", false)) and not bool(e.statuses[id].get("uncleansable", false)):
					r.dispel(e, id)
					break
		"tendon":
			# Entry consumes the captured phase-two total, never the live mutable total.
			e.pain_entry_total = 0
			for ally in s.allies: ally.statuses.erase("hidden_pain")
	if transition:
		e.phase_pending = false
		e.ai_step = 0
	else: e.ai_step = int(e.ai_step) + 1
	s._add_log("%s · %s" % [e.name, intent.name], false)
	return true

static func incoming(s: Node, target: Dictionary, amount: int) -> int:
	if amount <= 0 or not s._is_alive(target) or bool(target.get("phase_pending", false)): return amount
	if target.get("id", "") == "perfect_score":
		target.score_pending = int(target.get("score_pending", 0)) + 6 + mini(4, amount / 20)
		target.score_hits = int(target.get("score_hits", 0)) + 1
		describe_score(target)
		return 1
	if target.get("id", "") == "inverse_limit" and int(target.get("boss_phase", 1)) == 3:
		var layers := int(target.statuses.get("limit", {}).get("stacks", 0))
		if amount < float(target.max_hp) * minf(0.20, layers * 0.005): return 1
	return amount

static func after_damage(s: Node, target: Dictionary, result: Dictionary) -> void:
	var id := String(target.get("id", ""))
	if id == "math_exam" and int(result.hp) > 0:
		target.function_stage = maxi(0, int(target.function_stage) - 1)
		describe_function(target)
		refresh(s, s.enemies.find(target))
	if id == "inverse_limit" and int(target.get("boss_phase", 1)) == 3 and int(result.hp) + int(result.guard) > 0:
		var layers := int(target.statuses.get("limit", {}).get("stacks", 0)) + 1
		target.statuses.limit = {"name":"极限", "desc":"每层伤害提高4%；将小于最大生命0.5%×层数的伤害变为1（阈值上限20%）。本次命中后叠层，只影响后续伤害。", "turns":-1, "stacks":layers, "damage_bonus":layers * 0.04, "debuff":false}

static func phase_change(s: Node, e: Dictionary, old_phase: int) -> void:
	field(e)
	var r = s.ENEMY_RULES
	if old_phase == 1:
		e.intent = r.action("暴雨倾盆", "all", r.scaled(e, 3, 0.2), "downpour", "强制结束我方回合；消耗手牌、抽牌、弃牌与验算区全部潮湿。基础1段，每张潮湿额外1段群攻。")
	else:
		var total := 0
		for ally in s.allies: total += int(ally.statuses.get("hidden_pain", {}).get("stacks", 0))
		e.pain_entry_total = total
		e.intent = r.action("跟腱断裂", "all", r.scaled(e, 10, 0.5) + total * 2, "tendon", "转阶段第一回合仅一次：全体基础伤害10 + 上阶段全队隐痛总层数×2；结算后清除全队隐痛。")

static func attack_segment(s: Node, c: Dictionary, target: int, base: float, grow: bool, attribute: String) -> void:
	if bool(c.get("virtual", false)): return
	if not c.has("mirror_segments"): c.mirror_segments = []
	if not c.has("mirror_target_hits"): c.mirror_target_hits = {}
	var aoe: bool = c.def.get("target", "") == "all_enemies" and not s.fc.code(c.card) in ["M07", "X09"]
	c.mirror_target_hits[target] = int(c.mirror_target_hits.get(target, 0)) + 1
	if aoe and int(c.mirror_target_hits[target]) <= c.mirror_segments.size(): return
	c.mirror_segments.append({"base":maxf(0.0, base) * (FightData.growth(int(s.allies[c.owner].level)) if grow else 1.0), "attribute":attribute})

static func card_finished(s: Node, c: Dictionary) -> void:
	if bool(c.get("virtual", false)): return
	var attack: bool = c.def.has("damage") or not c.get("mirror_segments", []).is_empty()
	if not attack: return
	var owner := int(c.owner)
	record_owner(s, owner)
	for e in s.enemies:
		if e.id != "inverse_limit" or not s._is_alive(e): continue
		if int(e.get("mirror_round", -1)) != s.round:
			e.mirror = {"owner":owner, "name":c.def.get("name", c.card.skill_id), "segments":c.get("mirror_segments", []).duplicate(true)}
			e.mirror_round = s.round
		if int(c.get("challenge_phase", int(e.boss_phase))) == 2:
			var layers := int(s.allies[owner].statuses.get("hidden_pain", {}).get("stacks", 0)) + 1
			s.ENEMY_RULES.debuff(s, owner, "hidden_pain", "隐痛", "回合结束一次性失去等于层数的生命，可陷入濒死；疼痛放大额外结算，层数不消耗。净化清除全部层数。", -1, {"stacks":layers})
			# A phase-crossing card belongs to the arena in which it was played.
			if bool(e.get("phase_pending", false)) and e.intent.get("effect", "") == "tendon":
				var total := 0
				for ally in s.allies: total += int(ally.statuses.get("hidden_pain", {}).get("stacks", 0))
				e.pain_entry_total = total
				e.intent.damage = s.ENEMY_RULES.scaled(e, 10, 0.5) + total * 2

static func card_started(s: Node, c: Dictionary) -> void:
	for e in s.enemies:
		if e.id == "inverse_limit" and s._is_alive(e):
			c.challenge_phase = int(e.boss_phase)
			break

static func base_damage(s: Node, attacker: Dictionary, base: float, grow: bool) -> float:
	var amount := base * (FightData.growth(int(attacker.get("level", 1))) if grow else 1.0)
	if s._is_ally_unit(attacker):
		for e in s.enemies:
			if e.id == "inverse_limit" and s._is_alive(e) and int(e.boss_phase) == 1:
				amount = maxf(0.0, amount - 2 * FightData.growth(int(e.level)))
	return amount

static func end_hand(s: Node) -> void:
	for i in s.allies.size(): pain(s, i)

static func before_enemy(s: Node) -> void:
	for e in s.enemies:
		if e.id != "perfect_score" or not s._is_alive(e): continue
		e.score = mini(100, int(e.score) + int(e.score_pending))
		e.score_pending = 0
		e.score_hits = 0
		describe_score(e)
		if int(e.score) >= 100:
			e.intent = s.ENEMY_RULES.action("执念消散", "all", 0, "score_dissolve", "达到100分，执念消散。")
			s.enemy_action_started.emit(s.enemies.find(e))
			e.hp = 0
			e.dead = true
			s._add_log("满分的执念达到100分，执念消散。", false)
	for i in s.enemies.size():
		var e: Dictionary = s.enemies[i]
		if e.id != "inverse_limit" or not s._is_alive(e) or int(e.boss_phase) != 3 or bool(e.get("phase_pending", false)): continue
		var owner := mirror_owner(s, e)
		if owner < 0 or e.mirror.get("segments", []).is_empty(): continue
		var original: Dictionary = e.intent
		e.intent = s.ENEMY_RULES.action("镜像 · " + String(e.mirror.name), "single", 0, "mirror", "仅复制攻击段的基础伤害。")
		s.enemy_action_started.emit(i)
		for part in e.mirror.segments:
			hit(s, i, owner, float(part.base), String(e.intent.name), String(part.attribute))
		e.intent = original

static func consume_penalty(s: Node, key: String) -> int:
	var result := 0
	for e in s.enemies:
		result += int(e.get(key, 0))
		if e.has(key): e[key] = 0
	return result
