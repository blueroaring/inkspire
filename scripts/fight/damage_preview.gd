extends RefCounted
## Run the real resolver on an off-tree copy. No live signals, rewards, saves or RNG.

static func copy_state(source: Object, destination: Object) -> void:
	for property in source.get_property_list():
		if not int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: continue
		var value: Variant = source.get(property.name)
		if value is Array or value is Dictionary:
			destination.set(property.name, value.duplicate(true))
		elif typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
			destination.set(property.name, value)

static func calculate(source: Node, index: int, target: int, ultimate: bool) -> Dictionary:
	if not source.battle_active or source.resolving_action or source.phase != source.PLAYER_TURN: return {}
	if index < 0 or index >= (source.allies.size() if ultimate else source.hand.size()): return {}
	var owner: int = index if ultimate else source.caster_index(source.hand[index])
	if owner < 0 or not source._is_alive(source.allies[owner]): return {}
	var definition: Dictionary = source.get_ultimate(owner) if ultimate else FightData.skill(String(source.hand[index].skill_id))
	var side := String(definition.get("target", "enemy"))
	if side in ["enemy", "ally"]:
		var units: Array = source.enemies if side == "enemy" else source.allies
		if target < 0 or target >= units.size() or not source._is_alive(units[target]): return {}
		if side == "enemy" and not source.ENEMY_RULES.targeted_enemy(source, target, bool(definition.get("ignore_taunt", false))): return {}
		if bool(definition.get("downed_only", false)) and not bool(units[target].get("downed", false)): return {}
	var simulation: Node = source.get_script().new()
	copy_state(source, simulation)
	copy_state(source.fc, simulation.fc)
	simulation.fc.preview_attributes.clear()
	simulation.preview_mode = true
	simulation.story_rewards_enabled = false
	simulation.active_story_encounter = ""
	var result := {"exact":true, "complete":false, "note":"", "targets":[], "events":[], "name":definition.get("name", "终结技")}
	simulation.effect_requested.connect(func(effect: String, hit_side: String, hit_index: int, hp: int, guard: int) -> void:
		if hp > 0 or guard > 0:
			result.events.append({"effect":effect, "side":hit_side, "index":hit_index, "hp":hp, "guard":guard})
	)
	var done := func() -> void:
		if not ultimate: simulation.fc.ANYA.check_exit(simulation.fc)
		result.complete = true
	if ultimate:
		simulation.fc.ultimate(owner, target, done)
	else:
		var card: Dictionary = simulation.hand[index]
		var count: int = simulation.hand.size()
		var spent: int = simulation.fc.cost(card)
		simulation.hand.remove_at(index)
		simulation.fc.ANYA.spend(simulation.fc, spent)
		simulation.fc.start(owner, card, target, index, count, spent, done)
	result.exact = result.complete and simulation.fc.preview_notes.is_empty()
	result.attributes = simulation.fc.preview_attributes.duplicate(true)
	if not simulation.fc.choice.is_empty():
		result.note = "需先完成选择，最终数值随选择变化"
	elif not simulation.fc.preview_notes.is_empty():
		result.note = "含随机效果，最终数值在结算时确定"
	if simulation.fc.damage_interrupted(source.fc.damage_phases()) and simulation.battle_active:
		result.exact = false
		result.note = "触发Boss转阶段：当前动作剩余伤害停止，不再命中新阶段或新召唤物"
	for hit_side in ["enemy", "ally"]:
		var before: Array = source.enemies if hit_side == "enemy" else source.allies
		var after: Array = simulation.enemies if hit_side == "enemy" else simulation.allies
		for i in before.size():
			var hp_damage := 0
			var guard_damage := 0
			var hits := 0
			for event in result.events:
				if event.side == hit_side and int(event.index) == i:
					hp_damage += int(event.hp)
					guard_damage += int(event.guard)
					hits += 1
			var healing := maxi(0, int(after[i].hp) - int(before[i].hp) + hp_damage)
			var shield := maxi(0, int(after[i].get("guard", 0)) - int(before[i].get("guard", 0)))
			if hp_damage + guard_damage + healing + shield == 0: continue
			result.targets.append({"side":hit_side, "index":i, "name":before[i].name, "hp":hp_damage, "guard":guard_damage, "hits":hits, "healing":healing, "shield":shield, "remaining":maxi(0, int(after[i].hp)), "defeated":not simulation._is_alive(after[i]), "downed":bool(after[i].get("downed", false))})
	result.shared_guard = simulation.shared_guard + simulation.fc.temporary_guard - source.shared_guard - source.fc.temporary_guard
	# Pending choice closures capture the resolver; break those references explicitly.
	simulation.fc.choice_callback = Callable()
	simulation.fc.s = null
	simulation.fc = null
	simulation.free()
	return result
