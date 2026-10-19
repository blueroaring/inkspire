extends RefCounted
const STATUS := preload("res://scripts/fight/status_rules.gd")
## Equipment and supplies never dispatch card-play, attack or draw events.
static func equip(s: Node, hero: String, slot: int, id: String) -> bool:
	if s.battle_active or s.pending_tutorial_preparation or not s.roster().has(hero) or slot < 0 or slot >= FightEquipmentData.SLOT_COUNT: return false
	if not id.is_empty() and (not FightEquipmentData.ACCESSORIES.has(id) or not GameState.fight_accessories.has(id)): return false
	if not id.is_empty() and String(FightEquipmentData.ACCESSORIES[id].get("exclusive", hero)) != hero: return false
	if not id.is_empty() and FightProgression.hero_level(hero) < FightEquipmentData.required_level(id):
		s.last_configuration_error = "需要 Lv.%d 才能装备。" % FightEquipmentData.required_level(id)
		return false
	if not id.is_empty() and FightEquipmentData.ACCESSORIES[id].has("form") and s.current_attribute(hero) != String(FightEquipmentData.ACCESSORIES[id].form):
		s.last_configuration_error = "这件专武仅限对应形态装备。"
		return false
	var old_owner := FightEquipmentData.owner(id) if not id.is_empty() else ""
	if not old_owner.is_empty():
		var previous := FightEquipmentData.slots(old_owner)
		previous[previous.find(id)] = ""
		GameState.fight_equipment[old_owner] = previous
	var slots := FightEquipmentData.slots(hero)
	slots[slot] = id
	GameState.fight_equipment[hero] = slots
	FightEquipmentData.normalize()
	s.state_changed.emit()
	return true

static func purchase_error(s: Node, id: String) -> String:
	if not String(FightEquipmentData.definition(id).get("exclusive", "")).is_empty(): return "角色专武只能通过尖塔教学实战获得。"
	if TowerRun.active: return "爬塔物品请在每五层的小卖铺购买；专武由角色教学实战奖励。"
	if s.battle_active or s.pending_tutorial_preparation: return "战斗或教程期间不能兑换。"
	var def := FightEquipmentData.definition(id)
	if def.is_empty(): return "物品不存在。"
	if FightEquipmentData.ACCESSORIES.has(id) and GameState.fight_accessories.has(id): return "已经拥有；同一饰品只可获得一件。"
	if def.rarity == "rare" and FightProgression.rank() < 1: return "完成第一次突破后开放。"
	if def.rarity == "uncommon":
		var highest := 1
		for hero in s.roster(): highest = maxi(highest, FightProgression.hero_level(hero))
		if highest < 5: return "任一角色达到 Lv.5 后开放。"
	if not Inventory.has("ink_fragment", int(def.price), GameState.BAG_HIGHSCHOOL): return "墨痕碎片不足。"
	if FightEquipmentData.CONSUMABLES.has(id) and not Inventory.can_accept(id, 1, GameState.BAG_HIGHSCHOOL): return "背包已满。"
	return ""

static func purchase(s: Node, id: String) -> bool:
	s.last_configuration_error = purchase_error(s, id)
	if not s.last_configuration_error.is_empty(): return false
	var def := FightEquipmentData.definition(id)
	if not Inventory.remove("ink_fragment", int(def.price), GameState.BAG_HIGHSCHOOL): return false
	if FightEquipmentData.ACCESSORIES.has(id): GameState.fight_accessories[id] = ""
	else: Inventory.add(id, 1, GameState.BAG_HIGHSCHOOL)
	s.state_changed.emit()
	return true

static func can_guard(unit: Dictionary) -> bool:
	return not unit.statuses.has("no_guard") and not unit.statuses.has("athlete_burst")

static func cleansable(unit: Dictionary) -> Array:
	return unit.statuses.keys().filter(func(id: String) -> bool: return STATUS.is_debuff(unit.statuses[id]) and not bool(unit.statuses[id].get("uncleansable", false)))

static func receives_healing(s: Node, unit: Dictionary) -> bool:
	if s.fc.COMPANIONS.healing_blocked(unit): return false
	for status in unit.statuses.values():
		if float(status.get("heal_taken_mult", 1.0)) <= 0: return false
	return true

static func damage_bonus(s: Node, attacker: Dictionary, target: Dictionary, attribute: String) -> float:
	var gear: Dictionary = attacker.get("equipment", {})
	var bonus := float(attacker.get("damage_bonus", 0.0))
	if float(attacker.get("hp", 1)) < float(attacker.get("max_hp", 1)) * 0.3: bonus += float(gear.get("low_hp_bonus", 0.0))
	if int(attacker.get("hp", 0)) >= int(attacker.get("max_hp", 1)): bonus += float(gear.get("full_hp_bonus", 0.0))
	if int(target.get("guard", 0)) > 0: bonus += float(gear.get("shielded_bonus", 0.0))
	if attribute != "none" and attribute == String(target.get("attribute", "none")): bonus += float(gear.get("matching_bonus", 0.0))
	if s.hand.size() <= 3: bonus += float(gear.get("small_hand_bonus", 0.0))
	return bonus

static func opening(unit: Dictionary) -> void:
	if int(unit.equipment.get("opening_ward", 0)) > 0:
		STATUS.grant_ward(unit, int(unit.equipment.opening_ward), false)

static func round_started(s: Node) -> void:
	for unit in s.allies:
		if not s._is_alive(unit): continue
		var gear: Dictionary = unit.get("equipment", {})
		if int(gear.get("round_heal", 0)) > 0 and s.round > 1: s._heal(unit, int(gear.round_heal))
		if can_guard(unit): unit.guard += s.fc.PAINTING.shield_amount(unit, int(gear.get("round_guard", 0)))
	if s.round != 2: return
	for i in s.allies.size():
		var unit: Dictionary = s.allies[i]
		var amount := int(unit.get("equipment", {}).get("second_guard", 0))
		if amount <= 0 or bool(unit.get("equipment_watch_used", false)): continue
		unit.equipment_watch_used = true
		if not s._is_alive(unit) or not can_guard(unit): continue
		unit.guard += amount
		s.turn_guard_gained.emit(i, amount)
		s._add_log("晚自习怀表：%s 获得 %d 点个人护盾。" % [unit.name, amount], false)

static func before_discard(s: Node) -> void:
	for unit in s.allies:
		if not s._is_alive(unit): continue
		if int(unit.get("equipment", {}).get("retain_every", 0)) <= 0 and (s.round != 1 or int(unit.get("equipment", {}).get("first_retain", 0)) <= 0): continue
		for card in s.hand:
			if String(card.caster_id) != String(unit.id) or s.fc.retained(card): continue
			card.retain_round = s.round
			s._add_log("续页书角：%s 的「%s」保留至下回合。" % [unit.name, FightData.skill(String(card.skill_id)).name], false)
			break

static func dispellable(unit: Dictionary) -> Array:
	return unit.statuses.keys().filter(func(id: String) -> bool: return STATUS.is_buff(unit.statuses[id]) and not bool(unit.statuses[id].get("uncleansable", false)))

static func mint_targets(unit: Dictionary) -> Array:
	return cleansable(unit).filter(func(id: String) -> bool: return id in ["weakness", "sleep_bad"])

static func item_error(s: Node, id: String, target: int, require_target: bool) -> String:
	if not s.can_use_items(): return "当前不能使用道具。"
	var def: Dictionary = FightEquipmentData.CONSUMABLES.get(id, {})
	if def.is_empty(): return "该物品不是战斗消耗品。"
	if s.items_used >= FightEquipmentData.ITEMS_PER_BATTLE: return "本场已用完 2 次道具机会。"
	if s.item_used_round == s.round: return "本回合已使用过道具。"
	if def.rarity == "rare" and s.rare_item_used: return "本场已使用过稀有道具。"
	if not Inventory.has(id, 1, GameState.BAG_HIGHSCHOOL): return "道具数量不足。"
	if def.has("energy") and s.action_points >= s.action_point_limit(): return "能量已满。"
	if def.has("party_guard") and not s.allies.any(func(unit: Dictionary) -> bool: return s._is_alive(unit) and can_guard(unit)): return "当前没有可获得护盾的队友。"
	if def.has("draw"):
		if s.hand.size() >= s.expansion_hand_limit: return "手牌已满。"
		if s.draw_pile.is_empty() and s.discard_pile.is_empty(): return "当前没有可抽取的牌。"
	if def.has("retain_hand") and not s.hand.any(func(card: Dictionary) -> bool: return not s.fc.retained(card)): return "当前没有需要保留的手牌。"
	if require_target and def.target in ["ally", "enemy"]:
		var units: Array = s.allies if def.target == "ally" else s.enemies
		if target < 0 or target >= units.size() or not s._is_alive(units[target]): return "请选择尚未退场的目标。"
		var unit: Dictionary = units[target]
		if def.target == "enemy" and s.fc.POISON.absent(unit): return "目标暂时离场。"
		if def.target == "enemy" and not s.ENEMY_RULES.targeted_enemy(s, target): return "必须先选择具有嘲讽的窃笑之影。"
		if def.has("heal") or def.has("rescue"):
			if not receives_healing(s, unit): return "目标当前无法接受治疗。"
			if def.has("heal") and int(unit.hp) >= int(unit.max_hp): return "目标生命已满。"
			if def.has("rescue") and not bool(unit.get("downed", false)): return "归息羽只能用于濒死队友。"
		if def.has("ult") and int(unit.ult) >= s.ultimate_max(target): return "目标终结技能量已满。"
		if (def.has("guard") or def.has("permanent_guard")) and not can_guard(unit): return "目标当前无法获得护盾。"
		if def.has("cleanse") and cleansable(unit).is_empty(): return "目标没有可净化的负面状态。"
		if def.has("cleanse_ids") and mint_targets(unit).is_empty(): return "目标没有可清除的虚弱或睡眠不佳。"
		if def.has("strip_guard") and int(unit.get("guard", 0)) <= 0: return "目标没有个人常驻护盾。"
		if def.has("ward") and (unit.statuses.has("debuff_immunity") or int(unit.statuses.get("cleanseable_immunity", {}).get("temporary_stacks", 0)) > 0): return "目标已有负面免疫或临时可净化负面免疫。"
		if def.has("dispel") and dispellable(unit).is_empty(): return "目标没有可移除的正面状态。"
		if def.has("enemy_status"):
			if unit.statuses.has("debuff_immunity") or unit.statuses.has("cleanseable_immunity"): return "目标具有负面状态免疫。"
			if String(def.enemy_status) != "weakness" and unit.statuses.has(String(def.enemy_status)): return "目标已经受到该道具的影响。"
	return ""

static func temporary_guard(s: Node, target: int, amount: int) -> void:
	var unit: Dictionary = s.allies[target]
	if not s._is_alive(unit) or not can_guard(unit): return
	var previous := int(unit.statuses.get("poison_guard", {}).get("stacks", 0))
	unit.statuses.poison_guard = STATUS.definition("poison_guard", {"stacks":previous + amount, "turns":1, "fc_after_enemy":true})
	# The supply presentation shows the gain at contact, not at next turn's banner.

static func resolve_item(s: Node, id: String, target: int) -> void:
	var def: Dictionary = FightEquipmentData.CONSUMABLES[id]
	if not Inventory.remove(id, 1, GameState.BAG_HIGHSCHOOL): return
	if TowerRun.active and not s.preview_mode and not TowerRun.record.is_empty(): TowerRun.record.items.append({"id":id, "round":s.round, "target":target})
	s.items_used += 1
	s.item_used_round = s.round
	if def.rarity == "rare": s.rare_item_used = true
	if def.has("party_heal"):
		for unit in s.allies:
			if s._is_alive(unit): s._heal(unit, roundi(unit.max_hp * float(def.party_heal)))
	if def.has("ult"): s.allies[target].ult = mini(s.ultimate_max(target), int(s.allies[target].ult) + int(def.ult))
	if def.has("party_cleanse"):
		for unit in s.allies:
			if s._is_alive(unit):
				for key in cleansable(unit): unit.statuses.erase(key)
	if def.has("area_damage"):
		for i in s.enemies.size():
			if not s._enemy_targetable(s.enemies[i]): continue
			s.set_meta("phantom_attack_hit", true)
			var hit: Dictionary = s._take_damage(s.enemies[i], int(def.area_damage))
			s.set_meta("phantom_attack_hit", false)
			s.effect_requested.emit("item_flash", "enemy", i, hit.hp, hit.guard)
	if def.has("permanent_guard"): s.allies[target].guard += int(def.permanent_guard)
	if def.has("next_draw_only"): s.fc.next_draw += int(def.next_draw_only)
	if def.has("heal"):
		s._heal(s.allies[target], int(def.heal))
		s.effect_requested.emit("heal", "ally", target, 0, 0)
	if def.has("rescue"):
		var unit: Dictionary = s.allies[target]
		unit.hp = mini(s.healing_ceiling(unit), maxi(1, roundi(float(unit.max_hp) * float(def.rescue))))
		unit.downed = false
		s.effect_requested.emit("heal", "ally", target, 0, 0)
	if def.has("energy"): s.action_points = mini(s.action_point_limit(), s.action_points + int(def.energy))
	if def.has("guard"): temporary_guard(s, target, int(def.guard))
	if def.has("party_guard"):
		for i in s.allies.size(): temporary_guard(s, i, int(def.party_guard))
	if def.has("cleanse"):
		for key in cleansable(s.allies[target]): s.allies[target].statuses.erase(key)
		s.effect_requested.emit("cleanse", "ally", target, 0, 0)
	if def.has("cleanse_ids"):
		for key in mint_targets(s.allies[target]): s.allies[target].statuses.erase(key)
		s.effect_requested.emit("cleanse", "ally", target, 0, 0)
	if def.has("strip_guard"):
		var stripped := mini(int(s.enemies[target].guard), int(def.strip_guard))
		s.enemies[target].guard -= stripped
		s.effect_requested.emit("item_powder", "enemy", target, 0, stripped)
	if def.has("enemy_status"):
		var status := {"turns":1} if String(def.enemy_status) == "weakness" else {"name":"破绽墨迹", "desc":"受到普通伤害提高15%，本轮敌方行动结束后消失。", "turns":1, "debuff":true, "damage_taken_mult":1.15}
		s.fc.POISON.debuff(s.enemies[target], String(def.enemy_status), status)
	if def.has("ward"):
		s.fc.POISON.STATUS.grant_ward(s.allies[target], int(def.ward), true)
	if def.has("draw"):
		s._draw(int(def.draw))
		s.fc.next_draw += int(def.get("next_draw", 0))
	if def.has("retain_hand"):
		for card in s.hand:
			if not s.fc.retained(card): card.retain_round = s.round
	if def.has("dispel"):
		for key in dispellable(s.enemies[target]): s.ENEMY_RULES.dispel(s.enemies[target], key)
	if def.has("damage"):
		s.set_meta("phantom_attack_hit", true)
		var damage: Dictionary = s._take_damage(s.enemies[target], int(def.damage))
		s.set_meta("phantom_attack_hit", false)
		s.effect_requested.emit("item_flash", "enemy", target, damage.hp, damage.guard)
	s._add_log("使用%s · %s，消耗 1 个（本战 %d/%d）。" % [def.name, FightEquipmentData.rarity(id).name, s.items_used, FightEquipmentData.ITEMS_PER_BATTLE])

static func party_bonus(s: Node, key: String) -> int:
	var amount := 0
	for unit in s.allies:
		if s._is_alive(unit): amount += int(unit.get("equipment", {}).get(key, 0))
	return mini(2, amount)
