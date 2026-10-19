extends RefCounted
const SUMMON_LIMIT := 4
const CHALLENGES := preload("res://scripts/fight/enemy_challenges.gd")
const FINALE := preload("res://scripts/fight/finale_rules.gd")
const EXPANSION := preload("res://scripts/fight/enemy_expansion.gd")
const STATUS := preload("res://scripts/fight/status_rules.gd")
## Authored monster mechanics. Runtime state lives on units / FightSystem so previews copy it.
const IDS := ["cupid", "zeus_dean", "biting_book", "nightmare", "panic_throat", "snicker_shadow"]
const CURSES := ["fear_spread", "mockery", "damp", "abyss", "ranking", "wound", "medicine", "shackle", "do_not_tell"]

static func summon_slots(s: Node) -> int:
	var count := 0
	for enemy in s.enemies:
		if s._is_alive(enemy) and (int(enemy.get("summoner", -1)) >= 0 or bool(enemy.get("finale_summon", false))): count += 1
	return maxi(0, SUMMON_LIMIT - count)

static func is_curse(card: Dictionary) -> bool:
	return String(card.get("skill_id", "")) in CURSES

static func notify_added(s: Node, cards: Array, pile: String) -> void:
	if not s.preview_mode and not cards.is_empty(): s.enemy_cards_added.emit(cards.duplicate(true), pile)

static func setup(unit: Dictionary) -> void:
	unit.ai_step = 0
	unit.boss_phase = 1
	if String(unit.id) in ["panic_throat", "inverse_limit"]:
		var total_hp := int(unit.max_hp)
		unit.phase_total_hp = total_hp
		unit.phase_health = [total_hp - ceili(total_hp * 0.65), ceili(total_hp * 0.65) - ceili(total_hp * 0.30), ceili(total_hp * 0.30)]
		unit.max_hp = int(unit.phase_health[0])
		unit.hp = int(unit.max_hp)
	unit.attack_count = 0
	unit.attacker_counts = {}
	unit.sentence_pending = false
	unit.round_attacker_counts = {}
	unit.last_attacker_counts = {}
	unit.skill_counts = {}
	unit.thunder_bonus = 0
	if String(unit.id) in CHALLENGES.IDS: CHALLENGES.setup(unit)
	if String(unit.id) in EXPANSION.IDS: EXPANSION.setup(unit)
	if unit.id == "snicker_shadow":
		unit.statuses.shadow_taunt = {"name":"窃笑嘲讽", "desc":"单体敌方技能必须先选择窃笑之影；不可解除。群攻仍可命中其他敌人。", "turns":-1, "debuff":false, "uncleansable":true, "category":"rule"}
	if unit.id == "zeus_dean":
		unit.statuses.thunder_rule = {"name":"惩戒之雷", "desc":"每名角色每释放3次技能，敌方回合开始受到一次雷击；余数跨回合保留。终结技计数，追击不计数。", "turns":-1, "debuff":false, "uncleansable":true, "category":"rule"}

static func scaled(unit: Dictionary, base: float, growth: float = 0.6) -> int:
	return roundi(base + maxi(0, int(unit.level) - 1) * growth)

static func action(name: String, kind: String, damage: int, effect: String, desc: String, hits: int = 1) -> Dictionary:
	return {"name":name, "kind":kind, "damage":damage, "effect":effect, "status":effect, "desc":desc, "hits":hits}

static func living_shadows(s: Node, boss: int) -> int:
	var count := 0
	for enemy in s.enemies:
		if enemy.id == "snicker_shadow" and int(enemy.get("summoner", -1)) == boss and s._is_alive(enemy): count += 1
	return count

static func refresh(s: Node, index: int) -> bool:
	if FINALE.refresh(s, index): return true
	if CHALLENGES.refresh(s, index): return true
	if EXPANSION.refresh(s, index): return true
	var e: Dictionary = s.enemies[index]
	if not String(e.id) in IDS: return false
	if bool(e.get("phase_pending", false)): return true
	var step := int(e.get("ai_step", 0))
	var moves: Array = []
	match String(e.id):
		"cupid":
			moves = [action("意乱神迷箭", "bounce", scaled(e, 5, 0.25), "love_arrow", "随机弹射3次，每次造成生命伤害时增加18 love；不因连续命中减伤。", 3), action("正中靶心", "single", scaled(e, 16, 0.8), "love_heart", "攻击一名角色；造成生命伤害时增加35 love。"), action("爱意弥漫", "single", scaled(e, 8, 0.4), "love_mist", "攻击一名角色，并增加45 love（可被负面免疫抵挡）。")]
		"zeus_dean":
			if bool(e.get("sentence_pending", false)):
				e.intent = action("愚行，无处遁形", "single", scaled(e, 8), "sentence", "无视嘲讽，攻击并标记本次计数期间攻击宙斯次数最多的可攻击角色；同次数按队伍顺序。标记可净化，带有标记时再次被标记才处决退场，只有坚毅可抵挡。")
				return true
			moves = [action("雷霆训诫", "single", scaled(e, 14, 0.8), "zeus_admonition", "攻击上回合命中次数最多的可攻击角色；没有命中记录时随机攻击一人。"), action("发现违纪", "all", scaled(e, 6, 0.3), "discipline", "攻击全体，惩戒之雷基础伤害永久提高2点。")]
		"biting_book":
			moves = [action("知识撕咬", "single", scaled(e, 5, 0.35), "", "对同一角色连续撕咬2次。", 2), action("知识遗忘", "single", scaled(e, 7, 0.5), "forgetfulness", "攻击并施加2层知识遗忘；我方回合结束从最前方逐张消耗手牌，每消耗1张减少1层，剩余层数保留。"), action("天书", "single", scaled(e, 6, 0.4), "book_power", "攻击后永久增加25%普通伤害，最多4层。")]
		"nightmare":
			moves = [action("装神弄鬼", "single", scaled(e, 12, 0.7), "", "攻击一名角色。"), action("黑暗遮蔽", "single", scaled(e, 6, 0.4), "darkness", "攻击并遮蔽2个手牌位置，持续至下个我方回合结束。槽位中的牌不能直接打出，仍可交换、弃置或消耗。"), action("说坏事坏事到", "single", scaled(e, 8, 0.5), "fear", "攻击并向随机手牌位置塞入1费恐惧蔓延；手牌满时将原牌移至弃牌堆。")]
		"panic_throat":
			match int(e.get("boss_phase", 1)):
				1:
					moves = [action("鞭打拷问", "all", scaled(e, 4, 0.3), "", "对全体连续攻击2次。", 2), action("窒息缄默", "single", scaled(e, 10), "silence", "攻击并沉默一名角色，使其下回合不能释放自己的技能。"), action("无人回应", "single", scaled(e, 8, 0.4), "panic_guard", "攻击，获得护盾并永久增加15%伤害；转阶段清除。")]
				2:
					moves = [action("钻心之痛", "single", scaled(e, 16, 0.9), "pierce", "攻击一名角色，无视所有护盾，保留普通伤害减免。"), action("自我怀疑", "all", scaled(e, 6, 0.35), "weakness", "攻击全体并施加1回合虚弱，造成伤害降低25%。"), action("钻心之痛", "single", scaled(e, 16, 0.9), "pierce", "攻击一名角色，无视所有护盾，保留普通伤害减免。")]
					if step > 0 and step % 3 == 2 and living_shadows(s, index) == 0:
						e.intent = action("他们都在看着你", "all", scaled(e, 5, 0.3), "summon", "攻击全体并召唤2个无法解除嘲讽的窃笑之影。仅在两只召唤物均被击败后重现。")
						return true
				3:
					var layers := int(e.statuses.get("self_seal", {}).get("stacks", 0))
					moves = [action("建立孤岛", "all", 0, "island", "蓄力并增加1层自我封闭（每层免伤15%，最高75%）。连续蓄力两回合后释放囚笼合拢。"), action("建立孤岛", "all", 0, "island", "第二回合蓄力并增加1层自我封闭；下回合必定释放囚笼合拢。"), action("囚笼合拢", "all", scaled(e, 12, 0.8) + layers * 4, "cage", "全体高伤；每层自我封闭额外增加4点基础伤害。")]
		"snicker_shadow":
			moves = [action("窃笑", "all", 0, "mockery", "往弃牌堆放入一张嘲弄；无法打出，留在手中到回合结束会对全体造成伤害。")]
	e.intent = moves[step % moves.size()].duplicate(true)
	return true

static func targets(s: Node, random: bool = false, exclude: int = -1) -> Array:
	var result: Array = []
	for i in s.allies.size():
		if i != exclude and s._enemy_targetable(s.allies[i]): result.append(i)
	if random and not result.is_empty(): return [s.fc.random_entry(result)]
	return result

static func single_target(s: Node) -> int:
	var taunt: int = s._taunt_target()
	if taunt >= 0: return taunt
	var options := targets(s)
	return int(s.fc.random_entry(options)) if not options.is_empty() else -1

static func sentence_target(s: Node, e: Dictionary) -> int:
	var chosen := -1
	var highest := -1
	for owner in targets(s):
		var count := int(e.get("attacker_counts", {}).get(String(s.allies[owner].id), 0))
		if count > highest:
			highest = count
			chosen = int(owner)
	return chosen

static func admonition_target(s: Node, e: Dictionary) -> int:
	var chosen := -1
	var highest := 0
	for owner in targets(s):
		var count := int(e.get("last_attacker_counts", {}).get(String(s.allies[owner].id), 0))
		if count > highest:
			highest = count
			chosen = int(owner)
	var available := targets(s)
	return chosen if chosen >= 0 else single_target(s) if not available.is_empty() else -1

static func debuff(s: Node, target: int, id: String, name: String, desc: String, turns: int, extra: Dictionary = {}) -> void:
	if target < 0 or not s._is_alive(s.allies[target]): return
	var data := {"name":name, "desc":desc, "turns":turns, "debuff":true}
	data.merge(extra, true)
	s.fc.POISON.debuff(s.allies[target], id, data)

static func love(s: Node, target: int, amount: int) -> void:
	var unit: Dictionary = s.allies[target]
	if not s._is_alive(unit) or unit.statuses.has("confusion"): return
	var value := int(unit.statuses.get("love", {}).get("stacks", 0)) + amount
	if value >= 100:
		debuff(s, target, "confusion", "迷魂", "不能主动释放技能。抽到自己的攻击牌时免费自动攻击队友，仅结算攻击伤害；无队友时攻击自己。", 1, {"control":true})
		unit.statuses.erase("love")
	else:
		debuff(s, target, "love", "love", "达到100时清空，并进入1回合迷魂。可净化清空。", -1, {"stacks":value})

static func buff(unit: Dictionary, id: String, name: String, bonus: float, cap: int = 99) -> void:
	var layers := mini(cap, int(unit.statuses.get(id, {}).get("stacks", 0)) + 1)
	unit.statuses[id] = {"name":name, "desc":"普通伤害提高%d%%。" % roundi(layers * bonus * 100), "turns":-1, "stacks":layers, "damage_bonus":layers * bonus, "debuff":false}

static func seal(unit: Dictionary) -> void:
	var layers := mini(5, int(unit.statuses.get("self_seal", {}).get("stacks", 0)) + 1)
	unit.statuses.self_seal = {"name":"自我封闭", "desc":"每层免伤15%，最多5层；驱散每次只移除1层。囚笼合拢每层增加4点基础伤害。", "turns":-1, "stacks":layers, "damage_reduction":layers * 0.15, "debuff":false, "cleanse_one":true}

static func dispel(unit: Dictionary, id: String) -> void:
	if not unit.statuses.has(id) or bool(unit.statuses[id].get("uncleansable", false)): return
	if id == "self_seal" and int(unit.statuses[id].stacks) > 1:
		unit.statuses[id].stacks -= 1
		unit.statuses[id].damage_reduction = int(unit.statuses[id].stacks) * 0.15
	else: unit.statuses.erase(id)
	if id == "self_seal" and unit.get("intent", {}).get("effect", "") == "cage":
		unit.intent.damage = scaled(unit, 12, 0.8) + int(unit.statuses.get("self_seal", {}).get("stacks", 0)) * 4

static func spawn_shadows(s: Node, boss: int) -> void:
	if living_shadows(s, boss) > 0: return
	for _i in 2:
		if summon_slots(s) == 0: break
		var profile := FightData.enemy("snicker_shadow")
		var level := int(s.enemies[boss].level)
		var hp := FightData.enemy_hp("snicker_shadow", level)
		var unit := {"id":"snicker_shadow", "name":profile.name, "portrait":profile.portrait, "attribute":profile.attribute, "level":level, "max_hp":hp, "hp":hp, "guard":0, "statuses":{}, "marks":{}, "intent":{}, "summoner":boss, "joined_round":s.round}
		setup(unit)
		s.enemies.append(unit)
		refresh(s, s.enemies.size() - 1)

static func curse(s: Node, id: String) -> Dictionary:
	# Curses belong to the party, not a hero whose death would erase them.
	return s.make_card(id, "")

static func resolve(s: Node, index: int, inserted: bool = false) -> bool:
	if FINALE.resolve(s, index): return true
	if CHALLENGES.resolve(s, index): return true
	if EXPANSION.resolve(s, index): return true
	var e: Dictionary = s.enemies[index]
	if not String(e.id) in IDS: return false
	revive_phase(e)
	var intent: Dictionary = e.intent
	var was_transition := bool(e.get("phase_pending", false))
	var effect := String(intent.get("effect", ""))
	var kind := String(intent.get("kind", "single"))
	var fixed_target := sentence_target(s, e) if effect == "sentence" else admonition_target(s, e) if effect == "zeus_admonition" else single_target(s)
	var hits := int(intent.get("hits", 1))
	for _hit in hits:
		if not s._is_alive(e): break
		if not was_transition and bool(e.get("phase_pending", false)): break
		var hit_targets := targets(s) if kind == "all" else targets(s, true) if kind == "bounce" else [fixed_target] if fixed_target >= 0 else []
		for target in hit_targets:
			if not s._is_alive(e) or not s._enemy_targetable(s.allies[target]): continue
			if not was_transition and bool(e.get("phase_pending", false)): break
			var damage: int = s.fc.damage_amount(e, s.allies[target], float(intent.get("damage", 0)), false)
			var result: Dictionary = s._take_damage(s.allies[target], damage, effect == "pierce", index)
			if effect == "love_arrow" and (int(result.hp) > 0 or bool(result.get("anya_suppressed", false))): love(s, target, 18)
			if effect == "love_heart" and (int(result.hp) > 0 or bool(result.get("anya_suppressed", false))): love(s, target, 35)
			if effect == "love_mist": love(s, target, 45)
			if effect == "silence": debuff(s, target, "silence", "沉默", "无法释放自己的技能和终结技。", 1, {"control":true})
			if effect == "weakness": debuff(s, target, "weakness", "虚弱", "造成伤害降低25%。", 1, {"damage_out_mult":0.75})
			if effect == "forgetfulness":
				debuff(s, target, "forgetfulness", "知识遗忘", "回合结束逐张消耗最前方手牌，每消耗1张减少1层；剩余层数保留，净化一次清除全部。", -1, {"stacks":int(s.allies[target].statuses.get("forgetfulness", {}).get("stacks", 0)) + 2})
			if effect == "sentence":
				if s.allies[target].statuses.has("sentence"): execute_sentence(s, target)
				else: s.allies[target].statuses.sentence = {"name":"违纪标记", "desc":"已被标记1次；再次被标记时立即处决退场，只有坚毅可抵挡。可净化，净化后重新计为首次标记。释放技能不会触发处决。", "turns":-1, "stacks":1, "debuff":true}
			s.effect_requested.emit(String(intent.name), "ally", target, result.hp, result.guard)
			s.action_resolved.emit("ally", target)
		if int(intent.get("damage", 0)) > 0: s.fc.POISON.enemy_attacked(s.fc, index)
	if not was_transition and bool(e.get("phase_pending", false)):
		s.enemy_action_started.emit(index)
		resolve(s, index)
		return true
	match effect:
		"discipline": e.thunder_bonus = int(e.get("thunder_bonus", 0)) + 2
		"sentence":
			e.sentence_pending = false
			e.attack_count = 0
			e.attacker_counts.clear()
		"book_power": buff(e, "book_power", "天书", 0.25, 4)
		"panic_guard":
			s._add_guard(e, scaled(e, 16, 0.8))
			buff(e, "panic_power", "无人回应", 0.15)
		"island", "nightmare_entry": seal(e)
		"summon": spawn_shadows(s, index)
		"darkness":
			var positions: Array = range(maxi(2, s.hand.size()))
			s.fc.shuffled(positions)
			for slot in positions.slice(0, 2): s.dark_slots[int(slot)] = s.round + 1
		"fear":
			var position: int = s.fc.random_position(mini(s.hand.size(), s.expansion_hand_limit - 1))
			if s.hand.size() >= s.expansion_hand_limit: s.fc.move_from_hand(s.hand[position], s.discard_pile)
			var fear_card := curse(s, "fear_spread")
			s.hand.insert(position, fear_card)
			notify_added(s, [fear_card], "hand")
		"mockery":
			var card := curse(s, "mockery")
			card.curse_damage = scaled(e, 4, 0.25)
			s.discard_pile.append(card)
			notify_added(s, [card], "discard")
	if bool(e.get("phase_pending", false)):
		e.phase_pending = false
		e.ai_step = 0
	elif not inserted: e.ai_step = int(e.get("ai_step", 0)) + 1
	s._add_log("%s · %s" % [e.name, intent.name], false)
	return true

static func targeted_enemy(s: Node, target: int, ignore_taunt: bool = false) -> bool:
	if target < 0 or target >= s.enemies.size() or not s._enemy_targetable(s.enemies[target]): return false
	if ignore_taunt: return true
	var taunting := false
	for enemy in s.enemies:
		if s._is_alive(enemy) and enemy.statuses.has("shadow_taunt"): taunting = true
		if s._is_alive(enemy) and enemy.statuses.has("hand_taunt"): taunting = true
	return not taunting or s.enemies[target].statuses.has("shadow_taunt") or s.enemies[target].statuses.has("hand_taunt")

static func attacked(s: Node, target: int, owner: int = -1) -> void:
	var e: Dictionary = s.enemies[target]
	if owner >= 0 and owner < s.allies.size():
		var attacker_id := String(s.allies[owner].id)
		for zeus in s.enemies:
			if zeus.id == "zeus_dean" and s._is_alive(zeus):
				zeus.round_attacker_counts[attacker_id] = int(zeus.round_attacker_counts.get(attacker_id, 0)) + 1
	if e.id != "zeus_dean" or not s._is_alive(e): return
	e.attack_count = int(e.get("attack_count", 0)) + 1
	if int(e.attack_count) >= 6: e.sentence_pending = true
	if owner >= 0 and owner < s.allies.size():
		var id := String(s.allies[owner].id)
		e.attacker_counts[id] = int(e.attacker_counts.get(id, 0)) + 1
	refresh(s, target)

static func snapshot_attackers(s: Node) -> void:
	for e in s.enemies:
		if e.id != "zeus_dean" or not s._is_alive(e): continue
		e.last_attacker_counts = e.round_attacker_counts.duplicate()
		e.round_attacker_counts.clear()

static func skill_used(s: Node, owner: int) -> void:
	if owner < 0 or not s._is_alive(s.allies[owner]): return
	var unit: Dictionary = s.allies[owner]
	for e in s.enemies:
		if e.id != "zeus_dean" or not s._is_alive(e): continue
		e.skill_counts[unit.id] = int(e.skill_counts.get(unit.id, 0)) + 1
		update_thunder_description(e)

static func update_thunder_description(e: Dictionary) -> void:
	var parts: Array[String] = []
	for id in e.skill_counts: parts.append("%s %d/3" % [FightData.hero(id).name, int(e.skill_counts[id])])
	if e.statuses.has("thunder_rule"):
		e.statuses.thunder_rule.desc = "每名角色每3次技能在敌方回合开始触发雷击；当前基础伤害%d。\n%s" % [scaled(e, 7, 0.5) + int(e.thunder_bonus), "；".join(parts)]

static func execute_sentence(s: Node, owner: int) -> void:
	var unit: Dictionary = s.allies[owner]
	unit.statuses.erase("sentence")
	if s.lab_invincible_allies: return
	if unit.statuses.has("resilience"):
		unit.statuses.resilience.stacks = int(unit.statuses.resilience.get("stacks", 1)) - 1
		if int(unit.statuses.resilience.stacks) <= 0: unit.statuses.erase("resilience")
		s._add_log("%s 的坚毅抵挡了违纪处决。" % unit.name, false)
		return
	if s.fc.ANYA.forced_exit(s.fc, unit): return
	unit.hp = 0
	unit.dead = true
	unit.downed = false
	s._remove_caster_cards(String(unit.id))
	s._add_log("%s 被违纪标记处决，直接退场。" % unit.name, false)

static func thunder(s: Node) -> void:
	for i in s.enemies.size():
		var e: Dictionary = s.enemies[i]
		if e.id != "zeus_dean" or not s._is_alive(e): continue
		var original: Dictionary = e.intent
		e.intent = action("惩戒之雷", "single", scaled(e, 7, 0.5) + int(e.thunder_bonus), "zeus_thunder", "每3次技能触发一次雷击。")
		var started := false
		for owner in s.allies.size():
			var unit: Dictionary = s.allies[owner]
			var count := int(e.skill_counts.get(unit.id, 0))
			e.skill_counts[unit.id] = count % 3
			for _hit in count / 3:
				if not s._is_alive(e) or not s._enemy_targetable(unit): break
				if not started:
					s.enemy_action_started.emit(i)
					started = true
				var amount: int = s.fc.damage_amount(e, unit, e.intent.damage, false)
				var result: Dictionary = s._take_damage(unit, amount, false, i)
				s.effect_requested.emit("惩戒之雷", "ally", owner, result.hp, result.guard)
				s.action_resolved.emit("ally", owner)
				if int(result.hp) + int(result.guard) > 0: s.fc.POISON.enemy_attacked(s.fc, i)
		e.intent = original
		update_thunder_description(e)

static func clamp_boss_damage(target: Dictionary, hp_damage: int) -> int:
	if target.get("id", "") == FINALE.BOSS: return mini(hp_damage, maxi(0, int(target.hp) - 1))
	if target.get("id", "") == "perfect_score": return mini(hp_damage, maxi(0, int(target.hp) - 1))
	if not target.get("id", "") in ["panic_throat", "inverse_limit"]: return hp_damage
	if bool(target.get("phase_pending", false)): return 0
	return mini(hp_damage, maxi(0, int(target.hp)))

static func after_damage(s: Node, target: Dictionary, result: Dictionary = {}) -> void:
	FINALE.after_damage(s, target)
	EXPANSION.after_damage(s, target, result)
	if not target.get("id", "") in ["panic_throat", "inverse_limit"] or bool(target.get("phase_pending", false)): return
	var stage := int(target.get("boss_phase", 1))
	if stage >= 3 or int(target.hp) > 0: return
	target.boss_phase = stage + 1
	target.phase_pending = true
	target.phase_rebirth = true
	# Phase lifetime is explicit, independent of whether an effect is neutral.
	# Li Anya's target mark belongs to her ongoing character mechanic.
	for id in target.statuses.keys():
		if not bool(target.statuses[id].get("persist_through_phase", false)): target.statuses.erase(id)
	target.marks.clear()
	target.guard = 0
	if target.id == "inverse_limit":
		CHALLENGES.phase_change(s, target, stage)
		s._add_log("破限心魔·逆限转入第%d阶段，打断我方回合。" % target.boss_phase, false)
		return
	target.intent = action("他们都在看着你", "all", scaled(target, 5, 0.3), "summon", "转入百舌嘲心：强制结束我方回合，群攻并召唤2个窃笑之影。") if stage == 1 else action("坠入，无边噩梦", "bounce", scaled(target, 5, 0.3), "nightmare_entry", "转入孤影囚笼：强制结束我方回合，随机弹射5次并增加1层自我封闭；随后连续两回合建立孤岛。", 5)
	s._add_log("%s 转入%s，清除全部状态并打断我方回合。" % [target.name, "百舌嘲心" if stage == 1 else "孤影囚笼"], false)

static func revive_phase(target: Dictionary) -> void:
	if not bool(target.get("phase_rebirth", false)): return
	target.max_hp = int(target.phase_health[int(target.boss_phase) - 1])
	target.hp = int(target.max_hp)
	target.phase_rebirth = false

static func pending_transition(s: Node) -> bool:
	for e in s.enemies:
		if bool(e.get("phase_pending", false)): return true
	return false

static func slot_blocked(s: Node, index: int) -> bool:
	return index >= 0 and int(s.dark_slots.get(index, -1)) >= s.round

static func end_hand(s: Node) -> void:
	FINALE.end_hand(s)
	CHALLENGES.end_hand(s)
	EXPANSION.end_hand(s)
	# Snapshot adjacency before transforming; newly infected cards spread next round only.
	var infected: Array = []
	# Mockery can retire a hero and remove their cards while this loop runs.
	var ending_hand: Array = s.hand.duplicate()
	for i in ending_hand.size():
		var card: Dictionary = ending_hand[i]
		if card.skill_id == "fear_spread":
			for neighbor in [i - 1, i + 1]:
				if neighbor >= 0 and neighbor < ending_hand.size() and not infected.has(ending_hand[neighbor]): infected.append(ending_hand[neighbor])
		elif card.skill_id == "mockery":
			for target in targets(s):
				var amount: int = s.fc.damage_amount({"attribute":"none", "statuses":{}}, s.allies[target], float(card.get("curse_damage", 4)), false)
				var result: Dictionary = s._take_damage(s.allies[target], amount)
				s.effect_requested.emit("嘲弄", "ally", target, result.hp, result.guard)
	for card in infected:
		if not s.hand.has(card): continue
		var uid: int = card.uid
		card.clear()
		card.merge({"uid":uid, "skill_id":"fear_spread", "caster_id":""})
	var forget := 0
	for unit in s.allies:
		if not s._is_alive(unit) or not unit.statuses.has("forgetfulness"): continue
		forget += int(unit.statuses.forgetfulness.stacks)
	for _i in mini(forget, s.hand.size()):
		s.fc.move_from_hand(s.hand[0], s.fc.exhausted, "知识遗忘")
		for unit in s.allies:
			if not s._is_alive(unit) or not unit.statuses.has("forgetfulness"): continue
			unit.statuses.forgetfulness.stacks -= 1
			if int(unit.statuses.forgetfulness.stacks) <= 0: unit.statuses.erase("forgetfulness")
			break
	for slot in s.dark_slots.keys():
		if int(s.dark_slots[slot]) <= s.round: s.dark_slots.erase(slot)

static func confused_draw(s: Node, card: Dictionary) -> bool:
	var owner: int = s.caster_index(card)
	if owner < 0 or not s.allies[owner].statuses.has("confusion"): return false
	var def := FightData.skill(String(card.skill_id))
	var code: String = s.fc.code(card)
	if not def.has("damage") and not code in ["N12", "N13"]: return false
	var unit: Dictionary = s.allies[owner]
	var attack_targets := targets(s, false, owner)
	if attack_targets.is_empty(): attack_targets = [owner]
	var base := float(def.get("damage", 0)) * FightData.growth(int(unit.level))
	var hits := 2 if code == "N04" else 4 if code == "M07" else 1
	if code == "N12": base = roundi(float(unit.max_hp) * 0.2)
	if code == "N13": base = absi(int(unit.hp)) if int(unit.hp) <= 0 else 0
	if code in ["X03", "X06", "X11"]:
		base += int(s.fc.COMPANIONS.consume_marks(s.fc, owner).spent) * (3 if code == "X03" else 4 if code == "X06" else 8)
	if code == "W12":
		hits = 1 if card.get("enchanted", false) else 0
		for other in s.hand + s.draw_pile + s.discard_pile:
			if bool(other.get("enchanted", false)): hits += 1
	if code == "X09": hits = int(s.fc.COMPANIONS.marks(unit)) / 2
	var presentation := {"before":s.get_allies().duplicate(true), "shared_before":s.shared_guard, "temporary_before":s.fc.temporary_guard, "contacts":[]}
	var shown_card: Dictionary = card.duplicate(true)
	s.confused_draw_resolving = true
	for _hit in hits:
		if code == "X09": base = 2 * FightData.growth(int(unit.level)) + int(s.fc.COMPANIONS.consume_marks(s.fc, owner, 2).remaining) * 2
		var chosen: Array = attack_targets if def.get("target", "") == "all_enemies" and not code in ["M07", "X09"] else [s.fc.random_entry(attack_targets)]
		for target in chosen:
			var amount: int = s.fc.damage_amount(unit, s.allies[target], base, false, String(def.get("attribute", unit.attribute)))
			var result: Dictionary = s._take_damage(s.allies[target], amount)
			s.effect_requested.emit("迷魂 · " + String(def.name), "ally", target, result.hp, result.guard)
			presentation.contacts.append({"target":target, "hp":result.hp, "guard":result.guard, "after":s.allies[target].duplicate(true), "shared":s.shared_guard, "temporary":s.fc.temporary_guard})
	s.confused_draw_resolving = false
	card.erase("enchanted")
	if bool(def.get("exhaust", false)) or bool(card.get("borrow_exhaust", false)): s.fc.exhausted.append(card)
	else: s.discard_pile.append(card)
	skill_used(s, owner)
	s.confused_draw_count += 1
	s._add_log("%s 因迷魂自动打出%s，攻击队友。" % [unit.name, def.name], false)
	if not s.preview_mode: s.confused_card_played.emit(owner, shown_card, presentation)
	return true
