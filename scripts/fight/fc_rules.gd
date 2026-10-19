extends RefCounted
const STATUS := preload("res://scripts/fight/status_rules.gd")
const COMPANIONS := preload("res://scripts/fight/fc_companions.gd")
const POISON := preload("res://scripts/fight/fc_poison.gd")
const PAINTING := preload("res://scripts/fight/fc_painting.gd")
const ANYA := preload("res://scripts/fight/fc_anya.gd")
var anya_decks: Dictionary = {}
var anya_state: Dictionary = {}
var anya_return_pending: Dictionary = {}
var anya_damage_block_round := -1
var anya_mark := -1
var anya_mark_round := -1
var anya_helped: Array = []
var anya_next_energy := 0
## fc.md rules. Each physical card has one destination; pending choices block other actions.
var s: Node
var serial := 0
var choice: Dictionary = {}
var choice_callback: Callable
var exhausted: Array = []
var calculation: Array = []
var locked_enemy := -1
var pursuit_count := 0
var pursuit_bonus := 0
var noticed := false
var magic_count := 0
var next_draw := 0
var enchant_next_draw := 0
var scheduled_enchant_draw := 0
var temporary_guard := 0
var painting: Array = PAINTING.blank()
var painting_next_energy := 0
var hp_losses: Dictionary = {}
var preview_notes: Array[String] = []
# Record the attribute actually passed to the resolver, including explicit overrides.
# This is display metadata on the isolated preview copy, never a damage modifier.
var preview_attributes: Array[Dictionary] = []
var preview_pile_uncertain := false
var finale_card_context: Dictionary = {}

func shuffled(cards: Array) -> void:
	if TowerRun.active and TowerRun.pending.get("mode") == "lesson" and not cards.is_empty() and cards[0] is Dictionary and cards[0].has("skill_id"):
		TowerRun.order_lesson_cards(cards)
		return
	if s.preview_mode:
		if cards.size() > 1: preview_notes.append("shuffle")
	else: cards.shuffle()

func random_entry(cards: Array) -> Variant:
	if TowerRun.active and TowerRun.pending.get("mode") == "lesson": return cards[0]
	if s.preview_mode:
		if cards.size() > 1: preview_notes.append("random")
		return cards[0]
	return cards.pick_random()

func random_position(maximum: int) -> int:
	if s.preview_mode:
		# Inserting future cards does not itself change this attack's damage.
		# If a counterfeit pursuit draws from that pile, stop claiming certainty.
		if maximum > 0: preview_pile_uncertain = true
		return 0
	return randi_range(0, maximum)

func _init(system: Node) -> void:
	s = system

func reset() -> void:
	anya_decks.clear()
	anya_state.clear()
	anya_return_pending.clear()
	anya_damage_block_round = -1
	anya_mark = -1
	anya_mark_round = -1
	anya_helped.clear()
	anya_next_energy = 0
	finale_card_context = {}
	choice.clear()
	choice_callback = Callable()
	exhausted.clear()
	calculation.clear()
	locked_enemy = -1
	pursuit_count = 0
	pursuit_bonus = 0
	noticed = false
	magic_count = 0
	next_draw = 0
	enchant_next_draw = 0
	scheduled_enchant_draw = 0
	temporary_guard = 0
	painting = PAINTING.blank()
	painting_next_energy = 0
	hp_losses.clear()

func stamp(card: Dictionary) -> Dictionary:
	if not card.has("uid"):
		serial += 1
		card["uid"] = serial
	return card

func code(card: Dictionary) -> String:
	return String(FightData.skill(String(card.skill_id)).get("code", card.skill_id))

func retained(card: Dictionary) -> bool:
	if s.ENEMY_RULES.is_curse(card): return String(card.skill_id) == "fear_spread"
	return String(card.caster_id) == "alyina" or bool(FightData.skill(String(card.skill_id)).get("retain", false)) or bool(card.get("retain", false)) or int(card.get("retain_round", -1)) == s.round

func cost(card: Dictionary) -> int:
	if String(card.skill_id) in s.ENEMY_RULES.FINALE.SUPPORT: return int(FightData.skill(String(card.skill_id)).cost)
	if s.ENEMY_RULES.is_curse(card): return int(FightData.skill(String(card.skill_id)).cost)
	var owner: int = s.caster_index(card)
	if owner >= 0 and s.allies[owner].statuses.has("swift"): return 0
	if code(card) == "X04" and int(card.get("kept_turns", 0)) >= 1: return 0
	if bool(card.get("free", false)) or int(card.get("free_round", -1)) == s.round or (bool(card.get("curtain", false)) and bool(card.get("enchanted", false))): return 0
	var value := int(FightData.skill(String(card.skill_id)).get("cost", 0))
	if value < 0: return s.action_points
	if code(card) == "N06": value -= int(hp_losses.get(String(card.caster_id), 0))
	if owner >= 0 and int(s.allies[owner].get("equipment_played_round", -1)) != s.round:
		value -= int(s.allies[owner].get("equipment", {}).get("first_discount", 0))
	if owner >= 0 and s.allies[owner].statuses.has("suffocation"): value += 1
	return maxi(0, value + int(card.get("cost_extra", 0)) - int(card.get("anya_discount_once", 0)))

func playable(card: Dictionary) -> bool:
	if String(card.get("caster_id", "")) == ANYA.ID and String(card.skill_id) not in s.ENEMY_RULES.FINALE.SUPPORT:
		var anya := ANYA.owner(self)
		if anya < 0 or not s._is_alive(s.allies[anya]): return false
	if String(card.skill_id).begins_with("LP") and not ANYA.phoenix(self): return false
	if ANYA.phoenix(self) and bool(FightData.skill(String(card.skill_id)).get("morph", false)): return false
	if int(card.get("finale_locked", -1)) == s.round: return false
	if String(card.skill_id) in s.ENEMY_RULES.FINALE.SUPPORT: return not s.ENEMY_RULES.FINALE.boss(s).is_empty()
	if bool(FightData.skill(String(card.skill_id)).get("unplayable", false)): return false
	if s.ENEMY_RULES.slot_blocked(s, s.hand.find(card)): return false
	if int(card.get("sealed_round", -1)) == s.round: return false
	if not s.ENEMY_RULES.EXPANSION.play_allowed(s, card, s.hand.find(card)): return false
	var owner: int = s.caster_index(card)
	if owner < 0: return false
	if not PAINTING.playable(self, code(card)): return false
	if POISON.absent(s.allies[owner]): return false
	if code(card) == "D10" and POISON.partner_options(self, owner).is_empty(): return false
	if COMPANIONS.is_controlled(s.allies[owner]) and code(card) != "C09": return false
	if code(card) == "C09" and not COMPANIONS.is_controlled(s.allies[owner]): return false
	if code(card) == "C11" and int(s.allies[owner].hp) < 1: return false
	if code(card) in ["N07", "N09"] and float(s.allies[owner].hp) >= float(s.allies[owner].max_hp) * 0.3: return false
	return true

func energy(amount: int) -> void:
	# A carried bonus may exceed the normal cap; gaining energy must never delete it.
	s.action_points = mini(maxi(s.action_points, s.action_point_limit()), s.action_points + amount)

func charge(owner: int, amount: int) -> void:
	if owner < 0 or is_math(owner) or String(s.allies[owner].id) == ANYA.ID: return
	s.allies[owner].ult = mini(s.ultimate_max(owner), int(s.allies[owner].ult) + amount)

func is_math(owner: int) -> bool:
	return owner >= 0 and String(s.allies[owner].id) == "zhoumingyuan" and String(s.allies[owner].attribute) == "math"

func scaled(owner: int, base: float) -> int:
	return roundi(base * FightData.growth(int(s.allies[owner].level)))

func final_bonus(unit: Dictionary) -> float:
	if String(unit.get("id", "")) != "zhoumingyuan" or String(unit.get("attribute", "none")) != "none": return 0.0
	var rank := mini(2, FightProgression.rank())
	if int(unit.hp) <= 0: return [0.25, 0.30, 0.35][rank]
	return [0.10, 0.15, 0.20][rank] if float(unit.hp) < float(unit.max_hp) * 0.3 else 0.0

func damage_amount(attacker: Dictionary, target: Dictionary, base: float, grow: bool = true, attribute: String = "") -> int:
	if base <= 0: return 0
	var attack_attribute := attribute if not attribute.is_empty() else String(attacker.get("attribute", "none"))
	var buffs: Dictionary = {"equipment": s.EQUIPMENT.damage_bonus(s, attacker, target, attack_attribute)}
	var debuffs: Dictionary = {}
	var poison_weakness := POISON.weakness(self, attacker)
	if poison_weakness > 0: debuffs["毒性虚弱"] = poison_weakness
	var reduction := 0.0
	var final := 1.0 + final_bonus(attacker) + int(attacker.get("finale_defiance", 0)) * 0.25 - int(target.get("finale_defiance", 0)) * 0.15
	for status_id in (attacker.get("statuses", {}) as Dictionary):
		var st: Dictionary = attacker.statuses[status_id]
		var name := String(st.get("name", status_id))
		var out := float(st.get("damage_out_mult", 1.0))
		if out < 1.0: debuffs[name] = float(debuffs.get(name, 0.0)) + 1.0 - out
		elif out > 1.0 and not st.has("final_bonus"): buffs[name] = float(buffs.get(name, 0.0)) + out - 1.0
		buffs[name] = float(buffs.get(name, 0.0)) + float(st.get("damage_bonus", 0.0))
		final += float(st.get("final_bonus", 0.0))
	for status_id in (target.get("statuses", {}) as Dictionary):
		var st: Dictionary = target.statuses[status_id]
		var name := String(st.get("name", status_id))
		buffs[name] = float(buffs.get(name, 0.0)) + maxf(0.0, float(st.get("damage_taken_mult", 1.0)) - 1.0)
		reduction += float(st.get("damage_reduction", maxf(0.0, 1.0 - float(st.get("damage_taken_mult", 1.0)))))
		final += float(st.get("final_taken_bonus", 0.0))
	var attr := attribute if not attribute.is_empty() else String(attacker.get("attribute", "none"))
	var defending := String(target.get("attribute", "none"))
	if FightData.has_advantage(attr, defending): final += 0.5
	elif FightData.has_advantage(defending, attr): final -= 0.5
	var base_bonus := 0.0
	for status_id in (attacker.get("statuses", {}) as Dictionary):
		base_bonus += float(attacker.statuses[status_id].get("base_damage_bonus", 0.0))
	var amount: float = s.ENEMY_RULES.CHALLENGES.base_damage(s, attacker, base + base_bonus, grow)
	if amount <= 0: return 0
	for value in buffs.values(): amount *= maxf(0.0, 1.0 + float(value))
	for value in debuffs.values(): amount *= maxf(0.0, 1.0 - float(value))
	var shield_break := 1.5 if attacker.get("statuses", {}).has("armor_break") and int(target.get("guard", 0)) > 0 else 1.0
	return maxi(1, roundi(amount * maxf(0.0, 1.0 - reduction) * maxf(0.0, final) * shield_break))

func hp_lost(unit: Dictionary, before: int) -> void:
	if int(unit.hp) < before:
		unit.round_hp_damage = int(unit.get("round_hp_damage", 0)) + before - int(unit.hp)
		var id := String(unit.get("id", ""))
		hp_losses[id] = int(hp_losses.get(id, 0)) + 1

func lose_hp(owner: int, amount: int) -> void:
	if s.lab_invincible_allies: return
	var unit: Dictionary = s.allies[owner]
	var before := int(unit.hp)
	unit.hp = before - amount
	unit.downed = int(unit.hp) <= 0
	if unit.downed: unit.downed_round = s.round
	hp_lost(unit, before)
	unit.round_damage = int(unit.get("round_damage", 0)) + amount
	if amount > 0: s.effect_requested.emit("self_loss", "ally", owner, amount, 0)
	if bool(unit.get("anya_phoenix", false)) and int(unit.hp) <= 0: ANYA.forced_exit(self, unit)

func status(owner: int, id: String, turns: int, extra: Dictionary = {}) -> bool:
	var active_source: Variant = s.get_meta("active_skill_source", -1)
	var source := int(active_source) if active_source != null else -1
	if source >= 0 and source != owner and s.allies[owner].statuses.has("isolation"): return false
	id = POISON.STATUS.canonical(id)
	var value := {"name":id, "turns":turns, "debuff":false}
	value.merge(extra, true)
	value = POISON.STATUS.definition(id, value)
	if STATUS.is_debuff(value): return POISON.debuff(s.allies[owner], id, value)
	s.allies[owner].statuses[id] = value
	return true

func shiver(index: int, turns: int) -> void:
	if not s._is_alive(s.enemies[index]): return
	POISON.debuff(s.enemies[index], "shiver", {"turns":turns})

func heal(owner: int, index: int, base: float, grow: bool = true, equipment_boost: bool = true) -> void:
	if not s._is_alive(s.allies[index]): return
	var gear: Dictionary = s.allies[owner].get("equipment", {})
	var bonus := float(gear.get("healing_bonus", 0.0))
	if bool(s.allies[index].get("downed", false)): bonus += float(gear.get("rescue_healing_bonus", 0.0))
	if not equipment_boost: bonus = 0.0
	s._heal(s.allies[index], base * (FightData.growth(int(s.allies[owner].level)) if grow else 1.0) * (1.0 + bonus))
	s.effect_requested.emit("heal", "ally", index, 0, 0)

func cleanse(index: int, one_layer: bool, only_id: String = "") -> void:
	var statuses: Dictionary = s.allies[index].statuses
	var ordered: Array = statuses.keys()
	# Stable priority: disabling controls before other removable debuffs.
	ordered.sort_custom(func(a: String, b: String) -> bool: return int(COMPANIONS.controlled(statuses[a], a)) > int(COMPANIONS.controlled(statuses[b], b)))
	for id in ordered:
		if not only_id.is_empty() and id != only_id: continue
		if bool(statuses[id].get("uncleansable", false)): continue
		if not STATUS.is_debuff(statuses[id]): continue
		if id in ["sleep_bad", "love", "hidden_pain", "void", "forgetfulness"]:
			statuses.erase(id)
			break
		if (one_layer or bool(statuses[id].get("cleanse_one", false))) and int(statuses[id].get("stacks", 1)) > 1:
			statuses[id].stacks -= 1
			if id == "sleep_bad": statuses[id].heal_taken_mult = maxf(0.0, 1.0 - 0.25 * statuses[id].stacks)
			if id == "perishing": statuses[id].final_taken_bonus = float(statuses[id].stacks) * 0.25
			if id == "it_ends":
				statuses[id].final_bonus = -0.2 * int(statuses[id].stacks)
				statuses[id].final_taken_bonus = 0.5 * int(statuses[id].stacks)
		elif one_layer and int(statuses[id].get("turns", 1)) > 1: statuses[id].turns -= 1
		else: statuses.erase(id)
		break

func take_draw(amount: int) -> Array:
	if s.preview_mode and preview_pile_uncertain and amount > 0: preview_notes.append("random_draw")
	# Preserve the discard/reshuffle boundary even if the same UID is drawn again
	# before the action's final state_changed signal.
	s.card_piles_changed.emit()
	var result: Array = []
	for _i in amount:
		if s.draw_pile.is_empty():
			if s.discard_pile.is_empty(): break
			s.draw_pile.append_array(s.discard_pile)
			s.discard_pile.clear()
			shuffled(s.draw_pile)
			s.card_piles_changed.emit()
		var card: Dictionary = s.draw_pile.pop_back()
		if bool(card.get("anya_free_on_draw", false)):
			card.erase("anya_free_on_draw")
			card.free = true
		var owner: int = s.caster_index(card)
		if owner < 0 or not s._is_alive(s.allies[owner]): continue
		stamp(card)
		s.ENEMY_RULES.CHALLENGES.drawn(s, card)
		if card.skill_id == "abyss": s.action_points = maxi(0, s.action_points - 1)
		if s.ENEMY_RULES.confused_draw(s, card): continue
		if enchant_next_draw > 0:
			enchant(card)
			enchant_next_draw -= 1
		result.append(card)
	return result

func to_hand(card: Dictionary, position: int = -1) -> void:
	if s.hand.size() >= s.expansion_hand_limit: s.discard_pile.append(card)
	elif position < 0: s.hand.append(card)
	else: s.hand.insert(clampi(position, 0, s.hand.size()), card)

func enchant(card: Dictionary) -> void:
	if bool(card.get("enchanted", false)): return
	stamp(card)
	card.enchanted = true
	card.enchant_bonus = [0.20, 0.25, 0.30][mini(2, FightProgression.rank())]
	var magician: int = s._ally_index("wangjiaqi")
	if magician >= 0 and s._is_alive(s.allies[magician]): card.enchant_bonus += float(s.allies[magician].get("equipment", {}).get("enchant_bonus", 0.0))
	s.card_enchanted.emit(card)

func random_enchant(cards: Array) -> void:
	var candidates: Array = cards.filter(func(c: Dictionary) -> bool: return not bool(c.get("enchanted", false)))
	if not candidates.is_empty(): enchant(random_entry(candidates))

func ask(title: String, options: Array, minimum: int, maximum: int, callback: Callable, ordered: bool = false) -> void:
	if options.is_empty() or maximum == 0:
		callback.call([])
		return
	for c in options: stamp(c)
	choice = {"title":title, "options":options.duplicate(), "min":mini(minimum, options.size()), "max":mini(maximum, options.size()), "ordered":ordered}
	choice_callback = callback
	s.state_changed.emit()

func choose(ids: Array) -> bool:
	if choice.get("kind", "") == "painting": return false
	if choice.is_empty() or ids.size() < int(choice.min) or ids.size() > int(choice.max): return false
	var selected: Array = []
	var seen: Array = []
	for uid in ids:
		if seen.has(uid): return false
		seen.append(uid)
		var found: Array = (choice.options as Array).filter(func(c: Dictionary) -> bool: return int(c.uid) == int(uid))
		if found.is_empty(): return false
		selected.append(found[0])
	var callback := choice_callback
	choice = {}
	choice_callback = Callable()
	callback.call(selected)
	s.state_changed.emit()
	return true

func remove_card(pile: Array, card: Dictionary) -> void:
	# Dictionary equality would accidentally remove another identical copy.
	stamp(card)
	for i in pile.size():
		if int(stamp(pile[i]).uid) == int(card.uid):
			if is_same(pile, s.hand): card.erase("kept_turns")
			pile.remove_at(i)
			return

func hand_cards(filter: Callable = Callable()) -> Array:
	return s.hand.filter(filter) if filter.is_valid() else s.hand.duplicate()

func context(owner: int, card: Dictionary, target: int, position: int, hand_size: int, done: Callable) -> Dictionary:
	var def := FightData.skill(String(card.skill_id))
	var attack := def.has("damage") or code(card) in ["N12", "N13"]
	var life: bool = attack and s.allies[owner].statuses.has("lifesteal")
	if life: s.allies[owner].statuses.erase("lifesteal")
	var preserve_wash: bool = s.allies[owner].statuses.has("sketch")
	s.allies[owner].statuses.erase("sketch")
	PAINTING.consume_swift(s.allies[owner])
	return {"owner":owner, "card":card, "target":target, "position":position, "hand_size":hand_size, "def":def, "done":done, "hits":[], "destination":"discard", "lifesteal":life, "enchanted":bool(card.get("enchanted", false)), "extra_pursuits":0, "virtual":false, "defeated":false, "preserve_wash":preserve_wash, "damage_phases":damage_phases()}

func damage_phases() -> Array:
	return s.enemies.map(func(enemy: Dictionary) -> int: return int(enemy.get("boss_phase", 1)))

func damage_interrupted(phases: Array = []) -> bool:
	if not s.battle_active or s.ENEMY_RULES.pending_transition(s): return true
	# Also catches instant finale wave changes, which do not use phase_pending.
	for i in mini(phases.size(), s.enemies.size()):
		if int(phases[i]) != int(s.enemies[i].get("boss_phase", 1)): return true
	return false

func start(owner: int, card: Dictionary, target: int, position: int, count: int, spent: int, done: Callable) -> void:
	if String(card.skill_id) in s.ENEMY_RULES.FINALE.SUPPORT:
		var resolve_support := func() -> void:
			s.ENEMY_RULES.FINALE.support(s, String(card.skill_id), target)
			if card.skill_id == "anya_refuse": exhausted.append(card)
			else: s.discard_pile.append(card)
			done.call()
		if not s.preview_mode and s.finale_presentation.is_valid(): s.finale_presentation.call(String(card.skill_id), resolve_support, target)
		else: resolve_support.call()
		return
	if s.ENEMY_RULES.FINALE.nullified(s, owner):
		charge(owner, spent)
		for flag in ["free_round", "free", "kept_turns"]: card.erase(flag)
		if bool(FightData.skill(String(card.skill_id)).get("exhaust", false)) or bool(card.get("borrow_exhaust", false)): exhausted.append(card)
		else: s.discard_pile.append(card)
		done.call()
		return
	var ctx := context(owner, card, target, position, count, done)
	ctx.anya_buffs_before = ANYA.buffs(self)
	s.ENEMY_RULES.FINALE.card_started(s, ctx)
	s.ENEMY_RULES.CHALLENGES.card_started(s, ctx)
	ctx.spent = spent
	if retained(card):
		var alyina: int = s._ally_index("alyina")
		if alyina >= 0 and s._is_alive(s.allies[alyina]): temporary_guard += PAINTING.shield_amount(s.allies[alyina], roundi(float(s.allies[alyina].max_hp) * [0.03, 0.05, 0.10][mini(2, FightProgression.rank())]))
	if not card.has("anya_actor"): charge(owner, spent)
	card.erase("free_round")
	card.erase("free")
	card.erase("anya_discount_once")
	card.erase("kept_turns")
	execute(ctx)

func hit(ctx: Dictionary, target: int, base: float, grow: bool = true, attr: String = "") -> void:
	if damage_interrupted(ctx.get("damage_phases", [])): return
	if target < 0 or target >= s.enemies.size() or not s._is_alive(s.enemies[target]): return
	var enemy: Dictionary = s.enemies[target]
	if enemy.id == s.ENEMY_RULES.FINALE.BOSS:
		s.ENEMY_RULES.FINALE.touch_card(s, ctx)
		if not s.battle_active: return
	var old_hp := int(enemy.hp)
	var old_phase := String(enemy.get("intent", {}).get("kind", ""))
	var attribute := attr if not attr.is_empty() else String(ctx.def.get("attribute", s.allies[ctx.owner].attribute))
	var amount := damage_amount(s.allies[ctx.owner], enemy, maxf(base, 0.0001), grow, attribute)
	s.ENEMY_RULES.CHALLENGES.attack_segment(s, ctx, target, base, grow, attribute)
	s.ENEMY_RULES.CHALLENGES.record_owner(s, int(ctx.owner))
	if bool(ctx.get("mark_damage", false)) and s.allies[ctx.owner].statuses.has("athlete_burst"): amount *= 2
	s.set_meta("magician_evaded", false)
	s.set_meta("direct_player_attack", true)
	var result: Dictionary = s._take_damage(enemy, amount, bool(ctx.get("ignore_guard", false)))
	s.set_meta("direct_player_attack", false)
	var evaded := bool(s.get_meta("magician_evaded", false))
	s.set_meta("magician_evaded", false)
	if int(result.hp) + int(result.guard) > 0:
		report_attack_attribute(target, attribute, "终结技" if String(ctx.card.skill_id).begins_with("ultimate") else "技能")
		s.ENEMY_RULES.attacked(s, target, int(ctx.owner))
	if int(result.hp) + int(result.guard) > 0 and not ctx.hits.has(target): ctx.hits.append(target)
	ANYA.attacked(self, int(ctx.owner), target, int(result.hp) + int(result.guard))
	s.effect_requested.emit("magician_dodge" if evaded else String(ctx.card.skill_id), "enemy", target, int(result.hp), int(result.guard))
	s.selected_enemy = target
	s.action_resolved.emit("enemy", target)
	if ctx.lifesteal: heal(ctx.owner, ctx.owner, mini(maxi(0, old_hp), int(result.hp)), false, false)
	if damage_interrupted(ctx.get("damage_phases", [])):
		ctx.defeated = true
		return
	if ctx.enchanted and int(ctx.position) == 0:
		var extra := roundi(float(int(result.hp) + int(result.guard)) * float(ctx.card.get("enchant_bonus", 0.1)))
		if extra > 0 and s._is_alive(enemy):
			var before := int(enemy.hp)
			var true_result: Dictionary = s._take_damage(enemy, extra, true)
			s.effect_requested.emit("enchant_true", "enemy", target, true_result.hp, 0)
			if ctx.lifesteal: heal(ctx.owner, ctx.owner, mini(maxi(0, before), int(true_result.hp)), false, false)
	if not damage_interrupted(ctx.get("damage_phases", [])): POISON.attacked(self, target)
	if damage_interrupted(ctx.get("damage_phases", [])): ctx.defeated = true
	if not s._is_alive(enemy) or (old_phase != "split" and String(enemy.get("intent", {}).get("kind", "")) == "split"): ctx.defeated = true

func all_hit(ctx: Dictionary, base: float, grow: bool = true) -> void:
	for i in s.enemies.size():
		if damage_interrupted(ctx.get("damage_phases", [])): break
		hit(ctx, i, base, grow)

func report_attack_attribute(target: int, attribute: String, source: String) -> void:
	var info := {"index":target, "attribute":attribute, "target_attribute":String(s.enemies[target].attribute), "source":source}
	if s.preview_mode: preview_attributes.append(info)
	else: s.attack_attribute_resolved.emit(info)

func execute(c: Dictionary) -> void:
	if code(c.card).begins_with("LA") or code(c.card).begins_with("LP"):
		ANYA.execute(self, c)
		return
	if code(c.card).begins_with("Y"):
		PAINTING.execute(self, c)
		return
	if code(c.card).begins_with("D"):
		POISON.execute(self, c)
		return
	if code(c.card).begins_with("C") or code(c.card).begins_with("X"):
		COMPANIONS.execute(self, c)
		return
	var o := int(c.owner)
	var t := int(c.target)
	var u: Dictionary = s.allies[o]
	var id := code(c.card)
	match id:
		"N01": hit(c, t, 6)
		"N02":
			hit(c, t, 12)
			shiver(t, 3)
		"N03":
			var lost := roundi(float(u.max_hp) * 0.25)
			lose_hp(o, lost)
			s._add_guard(u, lost if int(u.hp) <= 0 else roundi(float(lost) * 0.5))
		"N04":
			lose_hp(o, roundi(float(u.max_hp) * 0.2))
			for _i in 2: hit(c, t, 8)
		"N05":
			var down := int(u.hp) <= 0
			heal(o, o, float(u.max_hp) * 0.25, false, false)
			if down and int(u.hp) > 0: s._draw(2)
		"N06": hit(c, t, 35)
		"N07":
			lose_hp(o, int(u.hp))
			energy(2)
		"N08":
			all_hit(c, 10)
			for i in s.enemies.size(): shiver(i, 2 if int(u.hp) <= 0 else 1)
		"N09":
			var options: Array = s.discard_pile.filter(func(card: Dictionary) -> bool: return String(card.caster_id) == String(u.id) and (FightData.skill(String(card.skill_id)).has("damage") or code(card) in ["N12", "N13"]))
			ask("选择自己的攻击牌：本回合首次使用免费", options, 1, 1, func(cards: Array) -> void:
				for card in cards:
					remove_card(s.discard_pile, card)
					card.free_round = s.round
					to_hand(card)
				finish(c)
			)
			return
		"N10":
			hit(c, t, 48)
			status(o, "no_guard", 3, {"name":"迎着死亡", "desc":"无法获得个人护盾；共享护盾有效。", "debuff":true})
		"N11": status(o, "lifesteal", -1, {"name":"吸血", "desc":"下一次攻击造成的实际生命伤害等量回复生命。"})
		"N12":
			var lost := roundi(float(u.max_hp) * 0.2)
			lose_hp(o, lost)
			hit(c, t, lost, false)
		"N13":
			if int(u.hp) <= 0:
				all_hit(c, absi(int(u.hp)), false)
		"red_pen":
			for i in s.enemies.size():
				var name := String(s.enemies[i].name)
				hit(c, i, 10 if name.contains("试卷") or name.contains("考试") or name.contains("作业") else 5, true, "none")
		"A01": heal(o, t, 10)
		"A02": s.shared_guard += PAINTING.shield_amount(u, scaled(o, 24))
		"A03": s._add_guard(s.allies[t], scaled(o, 14))
		"A04":
			ask("应急包扎：弃置一张手牌", hand_cards(), 1, 1, func(cards: Array) -> void:
				for card in cards: move_from_hand(card, s.discard_pile)
				heal(o, t, 10)
				cleanse(t, true)
				finish(c)
			)
			return
		"A05":
			ask("休息一下：选择目标角色的一张手牌", hand_cards(func(card: Dictionary) -> bool: return String(card.caster_id) == String(s.allies[t].id)), 1, 1, func(cards: Array) -> void:
				for card in cards:
					card.retain_round = s.round
					card.sealed_round = s.round
				finish(c)
			)
			return
		"A06":
			ask("把机会留给你：检索一张牌（本回合免费，用后消耗）", s.draw_pile, 1, 1, func(cards: Array) -> void:
				for card in cards:
					remove_card(s.draw_pile, card)
					card.free_round = s.round
					card.borrow_exhaust = true
					to_hand(card)
				finish(c)
			)
			return
		"A07":
			ask("我的这份也给你：消耗另一张艾莉娜牌", hand_cards(func(card: Dictionary) -> bool: return String(card.caster_id) == "alyina"), 1, 1, func(cards: Array) -> void:
				if not cards.is_empty():
					move_from_hand(cards[0], exhausted)
					energy(2)
					s._draw(1)
				finish(c)
			)
			return
		"A08":
			for i in s.allies.size(): heal(o, i, 8)
			ask("家，温暖的家：选择任意数量手牌赋予保留", hand_cards(), 0, s.hand.size(), func(cards: Array) -> void:
				for card in cards: card.retain = true
				finish(c)
			)
			return
		"A09": next_draw += 3
		"A10":
			for i in s.allies.size():
				if s._is_alive(s.allies[i]):
					heal(o, i, 16)
					cleanse(i, false)
		"A11":
			ask("归来吧：回收至多两张保留牌", s.discard_pile.filter(retained), 0, 2, func(cards: Array) -> void:
				for card in cards:
					remove_card(s.discard_pile, card)
					to_hand(card)
				finish(c)
			)
			return
		"A12":
			var lost_total := 0
			for ally in s.allies:
				if s._is_alive(ally): lost_total += maxi(0, int(ally.max_hp) - int(ally.hp))
			temporary_guard += PAINTING.shield_amount(u, lost_total)
		"A13":
			ask("点到谁就是谁：赋予保留并永久加1费", hand_cards(func(card: Dictionary) -> bool: return not retained(card)), 1, 1, func(cards: Array) -> void:
				for card in cards:
					card.retain = true
					card.cost_extra = int(card.get("cost_extra", 0)) + 1
				finish(c)
			)
			return
		"hang_on":
			if bool(s.allies[t].downed) and not COMPANIONS.healing_blocked(s.allies[t]):
				s.allies[t].hp = mini(s.healing_ceiling(s.allies[t]), maxi(1, int(s.allies[t].max_hp) / 2))
				s.allies[t].downed = false
		"W01":
			hit(c, t, 7)
			random_enchant(s.hand)
		"W02":
			if s.hand.size() >= 2:
				ask("换一下顺序：选择两张手牌互换位置", hand_cards(), 2, 2, func(cards: Array) -> void:
					var a: int = s.hand.find(cards[0])
					var b: int = s.hand.find(cards[1])
					s.hand[a] = cards[1]
					s.hand[b] = cards[0]
					finish(c)
				)
				return
		"W03":
			s._add_guard(u, scaled(o, 10))
			random_enchant(s.hand)
		"W04", "W11":
			ask("选择一张已附魔的手牌", hand_cards(func(card: Dictionary) -> bool: return bool(card.get("enchanted", false))), 1, 1, func(cards: Array) -> void:
				for card in cards: card["retain" if id == "W04" else "curtain"] = true
				finish(c)
			)
			return
		"W05":
			var drawn := take_draw(5)
			ask("重排脚本：依次选择两张放回牌顶（先选的先抽）", drawn, mini(2, drawn.size()), mini(2, drawn.size()), func(cards: Array) -> void:
				for card in cards: remove_card(drawn, card)
				put_top(cards)
				place_cards(drawn, func() -> void: finish(c))
			, true)
			return
		"W06":
			var slots: Array = []
			for i in s.hand.size(): slots.append(i)
			shuffled(slots)
			slots = slots.slice(0, mini(int(c.get("spent", 0)), slots.size()))
			slots.sort()
			for i in range(slots.size() - 1, -1, -1): move_from_hand(s.hand[slots[i]], s.discard_pile)
			var drawn := take_draw(int(c.get("spent", 0)))
			for i in drawn.size():
				var was_enchanted := bool(drawn[i].get("enchanted", false))
				enchant(drawn[i])
				if not was_enchanted and String(drawn[i].caster_id) == String(u.id): energy(1)
				to_hand(drawn[i], int(slots[i]) if i < slots.size() else -1)
		"W07":
			var top: Array = s.draw_pile.slice(maxi(0, s.draw_pile.size() - 3))
			top.reverse()
			ask("预测未来：依次排列接下来抽到的牌", top, top.size(), top.size(), func(cards: Array) -> void:
				for card in cards: remove_card(s.draw_pile, card)
				var already_enchanted: Array = cards.filter(func(card: Dictionary) -> bool: return bool(card.get("enchanted", false))).map(func(card: Dictionary) -> int: return int(card.uid))
				random_enchant(cards)
				var fresh_uids: Array = []
				for i in cards.size():
					if bool(cards[i].get("enchanted", false)) and not already_enchanted.has(int(cards[i].uid)):
						fresh_uids.append(int(cards[i].uid))
				present_top_cards(c, cards, fresh_uids)
			, true)
			return
		"W08":
			var sample: Array = s.draw_pile.duplicate()
			shuffled(sample)
			sample = sample.slice(0, 7)
			ask("翻到需要的那一页：选择一张置于手牌首位并附魔", sample, 1, 1, func(cards: Array) -> void:
				for card in sample: remove_card(s.draw_pile, card)
				for card in cards:
					remove_card(sample, card)
					enchant(card)
					to_hand(card, 0)
				put_bottom(sample)
				finish(c)
			)
			return
		"W09":
			s._draw(3)
			ask("换个出场次序：选择两张手牌置于牌底并附魔", hand_cards(), mini(2, s.hand.size()), mini(2, s.hand.size()), func(cards: Array) -> void:
				for card in cards:
					remove_card(s.hand, card)
					enchant(card)
				put_bottom(cards)
				finish(c)
			)
			return
		"W10":
			var sample: Array = s.draw_pile + s.discard_pile
			shuffled(sample)
			sample = sample.slice(0, 8)
			ask("魔术返场：选择至多四张，依次放到牌顶并附魔", sample, 0, 4, func(cards: Array) -> void:
				var fresh_uids: Array = []
				for card in cards:
					remove_card(s.draw_pile, card)
					remove_card(s.discard_pile, card)
					if not bool(card.get("enchanted", false)): fresh_uids.append(int(card.uid))
					enchant(card)
				present_top_cards(c, cards, fresh_uids)
			, true)
			return
		"W12":
			var count := 1 if c.enchanted else 0
			for card in s.hand + s.draw_pile + s.discard_pile:
				if bool(card.get("enchanted", false)): count += 1
			for _i in count: all_hit(c, 8)
		"W13":
			scheduled_enchant_draw += s.hand.size()
			for card in hand_cards(): move_from_hand(card, s.discard_pile)
		"M01":
			locked_enemy = t
			hit(c, t, 6)
			c.destination = "calculation"
		"M02":
			locked_enemy = t
			c.destination = "calculation"
			s.discard_pile.append(s.make_card("M02", String(u.id)))
		"M03":
			locked_enemy = t
			pursuit_bonus += 3
			hit(c, t, 10)
		"M04", "M08":
			ask("选择一张演算牌" + ("弃置并抽三张" if id == "M04" else "返回手牌"), calculation, 1, 1, func(cards: Array) -> void:
				for card in cards:
					remove_card(calculation, card)
					restore_owner(card)
					if id == "M04":
						s.discard_pile.append(card)
						s._draw(3)
					else: to_hand(card)
				finish(c)
			)
			return
		"M05":
			c.destination = "calculation"
			ask("查找条件：检索一张自己的牌", s.draw_pile.filter(func(card: Dictionary) -> bool: return String(card.caster_id) == String(u.id)), 1, 1, func(cards: Array) -> void:
				for card in cards:
					remove_card(s.draw_pile, card)
					to_hand(card)
				finish(c)
			)
			return
		"M06":
			var drawn := take_draw(7)
			var distribute := func() -> void:
				var rest: Array = []
				for card in drawn:
					if String(card.caster_id) == String(u.id): calculation.append(card)
					else: rest.append(card)
				put_top(rest)
				finish(c)
			if not s.preview_mode and s.draft_presentation.is_valid() and not drawn.is_empty():
				s.draft_presentation.call(o, drawn, distribute)
			else: distribute.call()
			return
		"M07":
			for _i in 4:
				if damage_interrupted(c.damage_phases): break
				var candidates: Array = []
				for i in s.enemies.size():
					if s._is_alive(s.enemies[i]): candidates.append(i)
				if candidates.is_empty(): break
				hit(c, random_entry(candidates), 2)
			c.extra_pursuits = c.hits.size()
			c.destination = "calculation"
		"M09":
			locked_enemy = t
			pursue(o, pursuit_count, false, func() -> void: finish(c), c.damage_phases)
			return
		"M10":
			locked_enemy = t
			var count := calculation.size()
			for _i in count: s.draw_pile.insert(random_position(s.draw_pile.size()), s.make_card("M02", String(u.id)))
			pursue(o, count, true, func() -> void:
				# The skill clears all remaining ammunition even when the locked foe dies early.
				for card in calculation:
					restore_owner(card)
					s.discard_pile.append(card)
				calculation.clear()
				finish(c)
			, c.damage_phases)
			return
		"M11":
			ask("伪证：选择他人的一张手牌作为特殊弹药", hand_cards(func(card: Dictionary) -> bool: return String(card.caster_id) != String(u.id)), 1, 1, func(cards: Array) -> void:
				for card in cards:
					remove_card(s.hand, card)
					card.original_caster = card.caster_id
					card.caster_id = String(u.id)
					card.counterfeit = true
					calculation.append(card)
				finish(c)
			)
			return
		"M12":
			c.destination = "calculation"
			ask("等价关系：将一张手牌变为暂存假设", hand_cards(), 1, 1, func(cards: Array) -> void:
				for card in cards:
					card.skill_id = "M02"
					card.caster_id = String(u.id)
				finish(c)
			)
			return
		"M13":
			u.ult = s.ultimate_max(o)
	finish(c)

func move_from_hand(card: Dictionary, pile: Array, reason: String = "消耗", trigger_discard: bool = true) -> void:
	var count: int = s.hand.size()
	remove_card(s.hand, card)
	if s.hand.size() == count: return
	pile.append(card)
	if is_same(pile, exhausted) and not s.preview_mode:
		s.hand_card_exhausted.emit(card.duplicate(true), reason)
	if trigger_discard and is_same(pile, s.discard_pile): COMPANIONS.discarded(self)

func put_top(cards: Array) -> void:
	for i in range(cards.size() - 1, -1, -1): s.draw_pile.append(cards[i])

func put_bottom(cards: Array) -> void:
	for card in cards: s.draw_pile.push_front(card)

func place_cards(cards: Array, done: Callable) -> void:
	if cards.is_empty():
		done.call()
		return
	var card: Dictionary = cards.pop_front()
	if s.hand.size() >= s.expansion_hand_limit:
		s.discard_pile.append(card)
		place_cards(cards, done)
		return
	var options: Array = []
	var count: int = s.hand.size() + 1
	for i in count:
		var positions: Array[String] = []
		if i == 0: positions.append("首位")
		if i == ceili(float(count) / 2.0) - 1: positions.append("中位")
		if i == count - 1: positions.append("末位")
		options.append({"label":"第 %d 位" % [i + 1], "slot":i, "placement_count":count, "positions":positions})
	ask("放置「%s」：选择手牌位置" % FightData.skill(String(card.skill_id)).get("name", "技能"), options, 1, 1, func(selected: Array) -> void:
		to_hand(card, int(selected[0].slot))
		place_cards(cards, done)
	)

func present_top_cards(c: Dictionary, cards: Array, fresh_uids: Array) -> void:
	var skill_id := String(c.card.skill_id)
	for i in cards.size():
		var change := "获得附魔" if fresh_uids.has(int(cards[i].uid)) else "保留附魔" if cards[i].get("enchanted", false) else "未附魔"
		s._add_log("%s：放回抽牌堆顶部，第%d张将抽取的「%s」%s。" % [FightData.skill(skill_id).name, i+1, FightData.skill(String(cards[i].skill_id)).name, change], false)
	var settle := func() -> void:
		put_top(cards)
		finish(c)
	if not s.preview_mode and s.forecast_presentation.is_valid() and not cards.is_empty():
		s.forecast_presentation.call(cards, fresh_uids, skill_id, settle)
	else: settle.call()

func finish(c: Dictionary) -> void:
	if c.enchanted and not c.virtual:
		c.card.erase("enchanted")
		c.card.erase("enchant_bonus")
		if int(c.position) == ceili(float(c.hand_size) / 2.0) - 1 and String(c.def.get("target", "")) in ["ally", "party", "self"]: s._draw(1)
		if int(c.position) == int(c.hand_size) - 1:
			magic_count += 1
			if magic_count >= 3:
				magic_count = 0
				energy(1)
	if code(c.card) == "W12":
		for card in s.hand + s.draw_pile + s.discard_pile + calculation + exhausted:
			card.erase("enchanted")
			card.erase("enchant_bonus")
	var math_owner: int = s._ally_index("zhoumingyuan")
	var count := 0
	if is_math(math_owner) and s._is_alive(s.allies[math_owner]) and locked_alive():
		if code(c.card) == "M07": count = int(c.extra_pursuits)
		elif (c.hits as Array).has(locked_enemy) or (noticed and String(c.def.get("target", "")) in ["enemy", "all_enemies"]): count = 1
	# The math ultimate never triggers pursuit, even with 注意到.
	# M09/M10/X09/Y16 already release their explicitly specified pursuit skills.
	if code(c.card) in ["M09", "M10", "M13", "X09", "Y16"]: count = 0
	if damage_interrupted(c.get("damage_phases", [])): count = 0
	pursue(math_owner, count, true, func() -> void: settle(c), c.get("damage_phases", []))

func settle(c: Dictionary) -> void:
	if code(c.card) == "N13" and c.defeated:
		# All lifesteal and triggered recovery resolve before the explicit assignment.
		s.allies[c.owner].hp = 1
		s.allies[c.owner].downed = false
	if not c.virtual and String(c.destination) != "morphed" and s._is_alive(s.allies[c.owner]):
		if bool(c.def.get("exhaust", false)) or bool(c.card.get("borrow_exhaust", false)): exhausted.append(c.card)
		elif String(c.destination) == "calculation": calculation.append(c.card)
		else: s.discard_pile.append(c.card)
	for i in s.allies.size():
		if String(c.def.get("target", "")) == "party" or i == (int(c.target) if String(c.def.get("target", "")) == "ally" else int(c.owner)):
			if String(c.def.get("target", "")) in ["self", "ally", "party"]: s.effect_requested.emit(String(c.card.skill_id), "ally", i, 0, 0)
	s._add_log("%s 使用%s。" % [s.allies[c.owner].name, c.def.get("name", c.card.skill_id)])
	if not c.virtual: s.ENEMY_RULES.skill_used(s, int(c.owner))
	s.ENEMY_RULES.CHALLENGES.card_finished(s, c)
	s.ENEMY_RULES.FINALE.card_finished(s, c)
	ANYA.after_card(self, c)
	c.done.call()

func locked_alive() -> bool:
	return locked_enemy >= 0 and locked_enemy < s.enemies.size() and s._is_alive(s.enemies[locked_enemy])

func restore_owner(card: Dictionary) -> void:
	if card.has("original_caster"):
		card.caster_id = card.original_caster
		card.erase("original_caster")
	card.erase("counterfeit")

func pursue(owner: int, count: int, consume: bool, done: Callable, phases: Array = []) -> void:
	# Rules-only callers and previews stay synchronous, even for a large M09 count.
	# In battle, each hit waits for its own cut-in before spending ammo or dealing damage.
	if phases.is_empty(): phases = damage_phases()
	while count > 0:
		if damage_interrupted(phases) or owner < 0 or not locked_alive() or not s._is_alive(s.allies[owner]) or (consume and calculation.is_empty()): break
		if not s.preview_mode and s.pursuit_presentation.is_valid():
			s.pursuit_presentation.call(owner, locked_enemy, pursuit_count + 1, consume, _resolve_presented_pursuit.bind(owner, count, consume, done, phases))
			return
		count -= 1
		var ammo := _pursuit_hit(owner, consume)
		if _settle_pursuit_ammo(owner, ammo, count, consume, done, phases): return
	done.call()

func _resolve_presented_pursuit(owner: int, count: int, consume: bool, done: Callable, phases: Array) -> void:
	if damage_interrupted(phases) or not locked_alive() or not s._is_alive(s.allies[owner]) or (consume and calculation.is_empty()):
		done.call()
		return
	var ammo := _pursuit_hit(owner, consume)
	if not _settle_pursuit_ammo(owner, ammo, count - 1, consume, done, phases):
		pursue(owner, count - 1, consume, done, phases)

func _pursuit_hit(owner: int, consume: bool) -> Dictionary:
	var ammo: Dictionary = calculation.pop_front() if consume else {}
	if s.enemies[locked_enemy].id == s.ENEMY_RULES.FINALE.BOSS and not finale_card_context.is_empty():
		s.ENEMY_RULES.FINALE.touch_card(s, finale_card_context)
		if not s.battle_active: return ammo
	pursuit_count += 1
	s.allies[owner].ult = mini(s.ultimate_max(owner), int(s.allies[owner].ult) + 1)
	var base := (6.0 + float(pursuit_bonus) / FightData.growth(int(s.allies[owner].level))) * (1.0 + float(s.allies[owner].get("equipment", {}).get("pursuit_bonus", 0.0)))
	var amount := damage_amount(s.allies[owner], s.enemies[locked_enemy], base, true, "math")
	var previous_hp := int(s.enemies[locked_enemy].hp)
	# Capture the pre-hit display and attribute the projectile to Zhou, not the triggering ally.
	s.player_action_started.emit(owner, "pursuit")
	s.set_meta("phantom_attack_hit", true)
	var result: Dictionary = s._take_damage(s.enemies[locked_enemy], amount)
	s.set_meta("phantom_attack_hit", false)
	s.ENEMY_RULES.CHALLENGES.record_owner(s, owner)
	if int(result.hp) + int(result.guard) > 0:
		report_attack_attribute(locked_enemy, "math", "追击")
		s.ENEMY_RULES.attacked(s, locked_enemy, owner)
	s.effect_requested.emit("pursuit", "enemy", locked_enemy, result.hp, result.guard)
	POISON.attacked(self, locked_enemy)
	if s.allies[owner].statuses.has("lifesteal"):
		s.allies[owner].statuses.erase("lifesteal")
		heal(owner, owner, mini(maxi(0, previous_hp), int(result.hp)), false, false)
	s._add_log("验算 · 第%d次追击 → 敌人%d「%s」，造成%d伤害。" % [pursuit_count, locked_enemy + 1, s.enemies[locked_enemy].name, amount], false)
	return ammo

func _settle_pursuit_ammo(owner: int, ammo: Dictionary, remaining: int, consume: bool, done: Callable, phases: Array) -> bool:
	if ammo.is_empty(): return false
	if not s.battle_active:
		restore_owner(ammo)
		s.discard_pile.append(ammo)
		return false
	if bool(ammo.get("lemma", false)):
		exhausted.append(ammo)
		energy(1)
	elif bool(ammo.get("counterfeit", false)) and not damage_interrupted(phases):
		var after := func() -> void:
			restore_owner(ammo)
			s.discard_pile.append(ammo)
			pursue(owner, remaining, consume, done, phases)
		var def := FightData.skill(String(ammo.skill_id))
		var target_type := String(def.get("target", "self"))
		if target_type == "ally":
			var options: Array = []
			for i in s.allies.size():
				if s._is_alive(s.allies[i]): options.append({"label":s.allies[i].name, "ally":i})
			ask("伪证效果：选择支援对象", options, 1, 1, func(cards: Array) -> void: replay(owner, ammo, int(cards[0].ally), after))
		elif target_type == "enemy" and not locked_alive(): after.call()
		else: replay(owner, ammo, locked_enemy, after)
		return true
	else:
		restore_owner(ammo)
		s.discard_pile.append(ammo)
	return false

func replay(owner: int, card: Dictionary, target: int, done: Callable) -> void:
	var c := context(owner, card, target, -1, 0, done)
	c.virtual = true
	c.enchanted = false
	c.spent = 0
	execute(c)

func math_ultimate(owner: int, target: int, done: Callable) -> void:
	s.present_ultimate(owner, func() -> void: _math_ultimate_effect(owner, target, done))

func _math_ultimate_effect(owner: int, target: int, done: Callable) -> void:
	s.allies[owner].statuses.erase("sketch")
	PAINTING.consume_swift(s.allies[owner])
	s.allies[owner].ult = 0
	s.effect_requested.emit("ultimate_math", "ally", owner, 0, 0)
	if not noticed:
		noticed = true
		status(owner, "noticed", -1, {"name":"注意到", "desc":"作用于敌方的技能即可触发追击；数学终结技本身不触发。"})
		done.call()
		return
	if target < 0:
		var options: Array = []
		for i in s.enemies.size():
			if s._is_alive(s.enemies[i]): options.append({"label":s.enemies[i].name, "enemy":i})
		ask("解已确定：选择新的锁定目标", options, 1, 1, func(cards: Array) -> void:
			if cards.is_empty(): done.call()
			else:
				add_lemmas(owner, int(cards[0].enemy))
				done.call()
		)
		return
	add_lemmas(owner, target)
	done.call()

func add_lemmas(owner: int, target: int) -> void:
	locked_enemy = target
	for _i in 2:
		var card: Dictionary = s.make_card("lemma", String(s.allies[owner].id))
		card.lemma = true
		calculation.append(card)

func ultimate(owner: int, target: int, done: Callable) -> void:
	if String(s.allies[owner].id) == ANYA.ID:
		if ANYA.phoenix(self):
			done.call()
			return
		ANYA.begin_entry(self, owner)
		s.present_ultimate(owner, func() -> void:
			ANYA.enter(self, owner)
			done.call()
		)
		return
	var before := ANYA.buffs(self)
	var original_done := done
	done = func() -> void:
		ANYA.received_buffs(self, owner, before)
		original_done.call()
	if s.ENEMY_RULES.FINALE.nullified(s, owner):
		s.allies[owner].ult = 0
		done.call()
		return
	if is_math(owner):
		math_ultimate(owner, target, done)
		return
	s.present_ultimate(owner, func() -> void: _ultimate_effect(owner, target, done))

func _ultimate_effect(owner: int, target: int, done: Callable) -> void:
	var unit: Dictionary = s.allies[owner]
	unit.ult = 0
	if String(unit.id) == "liudanya":
		PAINTING.ultimate(self, owner, done)
		return
	# All ultimates are skills, including a non-painting skill under 素描 / 疾行.
	if String(unit.id) != "zhoumingyuan":
		unit.statuses.erase("sketch")
		PAINTING.consume_swift(unit)
	if String(unit.id) == "suwanqing":
		POISON.ultimate(self, owner, done)
		return
	if String(unit.id) in ["chenmo", "xumingming"]:
		COMPANIONS.ultimate(self, owner)
		done.call()
		return
	if String(unit.id) == "wangjiaqi":
		for card in s.hand: enchant(card)
		s.effect_requested.emit("ultimate_wang", "ally", owner, 0, 0)
		place_cards(take_draw(3), done)
		return
	if String(unit.id) == "alyina":
		for i in s.allies.size():
			if s._is_alive(s.allies[i]):
				status(i, "rally", 2, {"name":"总攻", "desc":"最终伤害提高25%。", "final_bonus":0.25, "damage_out_mult":1.25})
				s.effect_requested.emit("ultimate_alyina", "ally", i, 0, 0)
		done.call()
		return
	var card := {"skill_id":"ultimate_zhoumingyuan", "caster_id":String(unit.id)}
	var c := context(owner, card, target, -1, 0, done)
	c.def = {"target":"enemy", "damage":20, "attribute":"none"}
	c.lifesteal = unit.statuses.has("lifesteal")
	if c.lifesteal: unit.statuses.erase("lifesteal")
	c.virtual = true
	hit(c, target, 20)
	var layers := int(unit.statuses.get("resilience", {}).get("stacks", 0)) + 1
	status(owner, "resilience", -1, {"name":"坚毅", "desc":"免疫一次致命伤害，可叠加。", "stacks":layers})
	finish(c)

func before_enemy_turn() -> void:
	s.EQUIPMENT.before_discard(s)
	for ally in s.allies: ally.downed_at_enemy_start = bool(ally.get("downed", false))
	s.ENEMY_RULES.end_hand(s)
	for card in s.hand.duplicate():
		if not retained(card): move_from_hand(card, s.discard_pile, "回合结束", false)
		elif code(card) == "X04": card.kept_turns = int(card.get("kept_turns", 0)) + 1
		card.erase("retain_round")
		card.erase("sealed_round")
	for pile in [s.hand, s.draw_pile, s.discard_pile, calculation]:
		for card in pile: card.erase("free_round")
	pursuit_bonus = 0

func before_player_turn() -> void:
	COMPANIONS.after_enemy_turn(self)
	temporary_guard = 0
	enchant_next_draw = scheduled_enchant_draw
	scheduled_enchant_draw = 0

func describe(card: Dictionary) -> String:
	var tags: Array[String] = []
	if card.has("anya_actor"): tags.append("幻形 · 李安雅所有 / %s执行" % FightData.hero(String(card.anya_actor)).get("name", "原角色"))
	if String(card.skill_id).begins_with("LP"): tags.append("消耗重生计数")
	if int(card.get("finale_locked", -1)) == s.round: tags.append("假黎明锁定：无法打出，回合结束破碎消耗")
	if s.ENEMY_RULES.slot_blocked(s, s.hand.find(card)): tags.append("黑暗遮蔽：此位置无法直接出牌")
	if s.ENEMY_RULES.is_curse(card): tags.append("敌方干扰")
	if bool(card.get("trojan", false)): tags.append("木马：必须优先打出，效果无效")
	if int(s.get_meta("shackle_lock_round", -1)) == s.round and not s.hand.find(card) in [0, int(s.hand.size() / 2), s.hand.size() - 1]: tags.append("锁缚：当前手牌位置无法打出")
	if retained(card): tags.append("保留")
	if bool(card.get("enchanted", false)): tags.append("附魔")
	if bool(card.get("curtain", false)): tags.append("谢幕")
	if int(card.get("sealed_round", -1)) == s.round: tags.append("本轮封存")
	if bool(card.get("borrow_exhaust", false)) or bool(FightData.skill(String(card.skill_id)).get("exhaust", false)): tags.append("消耗")
	return " / ".join(tags)

func effect_keys(card: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	if s.ENEMY_RULES.slot_blocked(s, s.hand.find(card)): keys.append("darkness")
	if s.ENEMY_RULES.is_curse(card): keys.append("curse")
	if bool(card.get("trojan", false)): keys.append("trojan")
	if retained(card): keys.append("retain")
	if bool(card.get("enchanted", false)): keys.append("enchant")
	if bool(card.get("curtain", false)): keys.append("curtain")
	if int(card.get("sealed_round", -1)) == s.round: keys.append("sealed")
	if bool(card.get("borrow_exhaust", false)) or bool(FightData.skill(String(card.skill_id)).get("exhaust", false)): keys.append("exhaust")
	if bool(FightData.skill(String(card.skill_id)).get("innate", false)): keys.append("innate")
	if bool(card.get("counterfeit", false)): keys.append("counterfeit")
	return keys
