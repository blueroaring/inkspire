extends RefCounted
const STATUS := preload("res://scripts/fight/status_rules.gd")
## Li Anya's cards retain physical ownership while borrowing the original actor.
## All mutable state lives on fc_rules so previews deep-copy the complete form.
const ID := "li_anya"
const ROOT := "res://assets/graphics/battle/anya/"

static func owner(f: RefCounted) -> int:
	return f.s._ally_index(ID)

static func phoenix(f: RefCounted) -> bool:
	return not f.anya_state.is_empty()

static func rank_value(values: Array) -> int:
	return int(values[clampi(FightProgression.rank(), 0, 2)])

static func start_battle(f: RefCounted) -> void:
	f.anya_decks.clear()
	for unit in f.s.allies:
		f.anya_decks[String(unit.id)] = f.s.loadout(String(unit.id)).duplicate()
	mark_round(f)

static func mark_round(f: RefCounted) -> void:
	var at := owner(f)
	if at < 0 or phoenix(f) or not f.s._is_alive(f.s.allies[at]): return
	if f.anya_mark_round == f.s.round: return
	f.anya_mark_round = f.s.round
	f.anya_helped.clear()
	f.anya_mark = -1
	var candidates: Array = []
	for i in f.s.enemies.size():
		f.s.enemies[i].statuses.erase("anya_abuser")
		if f.s._is_alive(f.s.enemies[i]): candidates.append(i)
	if candidates.is_empty(): return
	f.anya_mark = int(f.random_entry(candidates))
	show_mark(f)

static func show_mark(f: RefCounted) -> void:
	if f.anya_mark < 0 or f.anya_mark >= f.s.enemies.size() or not f.s._is_alive(f.s.enemies[f.anya_mark]): return
	f.s.enemies[f.anya_mark].statuses.anya_abuser = {"name":"施暴者", "desc":"每位队友本回合首次对其造成攻击、毒爆或反伤，为李安雅增加1点涅槃充能。", "turns":-1, "debuff":false, "uncleansable":true, "category":"mark", "persist_through_phase":true}

static func gain_charge(f: RefCounted, amount: int) -> void:
	var at := owner(f)
	if at < 0 or phoenix(f) or not f.s._is_alive(f.s.allies[at]): return
	f.s.allies[at].ult = mini(12, int(f.s.allies[at].ult) + amount)

static func attacked(f: RefCounted, actor: int, target: int, damage: int) -> void:
	if actor < 0 or actor == owner(f) or target != f.anya_mark or damage <= 0 or phoenix(f): return
	if f.anya_helped.has(actor): return
	f.anya_helped.append(actor)
	gain_charge(f, 1)

static func buffs(f: RefCounted) -> Dictionary:
	var at := owner(f)
	return f.s.allies[at].statuses.duplicate(true) if at >= 0 else {}

static func received_buffs(f: RefCounted, actor: int, before: Dictionary, borrowed: bool = false) -> void:
	var at := owner(f)
	if at < 0 or actor == at or borrowed or phoenix(f): return
	for id in f.s.allies[at].statuses:
		var value: Dictionary = f.s.allies[at].statuses[id]
		if not STATUS.is_buff(value) or id in ["poison_guard", "temporary_guard"]: continue
		if value != before.get(id, {}):
			gain_charge(f, 1)
			return

static func after_card(f: RefCounted, c: Dictionary) -> void:
	if c.has("anya_buffs_before") and not bool(c.get("virtual", false)):
		received_buffs(f, int(c.owner), c.anya_buffs_before, c.card.has("anya_actor"))
	if c.card.has("anya_actor") and not bool(c.get("virtual", false)): gain_charge(f, 1)

static func budget(f: RefCounted) -> int:
	var at := owner(f)
	return int(f.s.allies[at].get("rebirth", 0)) if phoenix(f) and at >= 0 else f.s.action_points

static func spend(f: RefCounted, amount: int) -> void:
	if phoenix(f): f.s.allies[owner(f)].rebirth = maxi(0, budget(f) - amount)
	else: f.s.action_points -= amount

static func ultimate(f: RefCounted, at: int) -> Dictionary:
	if not phoenix(f): return FightData.ultimate(ID)
	return return_ultimate()

static func return_ultimate() -> Dictionary:
	return {"name":"这一次，我们在一起！", "desc":"锁定 · 退场时自动释放。重生计数耗尽或三处牌堆均无可负担技能时，平分剩余生命给队友，自身回复至可回复上限回场；被击败时自身濒死、队友1生命，本回合后续伤害取消，其他效果照常结算。变身期间新增的助战牌随原牌组恢复。无论原因，清除全队所有负面效果，并获得3点涅槃充能。", "energy":12, "target":"self", "locked":true, "icon":ROOT + "icons/return.webp"}

static func begin_entry(f: RefCounted, at: int) -> void:
	# Commit the downed beat before the cut-in, while the original party is visible.
	var unit: Dictionary = f.s.allies[at]
	if bool(unit.get("anya_entering", false)): return
	unit.anya_entering = true
	f.lose_hp(at, maxi(0, int(unit.hp) + 1))
	unit.hp = -1
	unit.downed = true
	unit.downed_round = f.s.round
	unit.ult = 0
	f.s.state_changed.emit()

static func enter(f: RefCounted, at: int) -> void:
	if phoenix(f): return
	var s: Node = f.s
	var unit: Dictionary = s.allies[at]
	begin_entry(f, at)
	unit.erase("anya_entering")
	var total_hp := 0
	var total_max_hp := 0
	var friends: Array = []
	for i in s.allies.size():
		if i != at and s._is_alive(s.allies[i]):
			friends.append(i)
			total_hp += maxi(0, int(s.allies[i].hp))
			total_max_hp += int(s.allies[i].max_hp)
	if friends.is_empty():
		total_hp = s.healing_ceiling(unit)
		total_max_hp = int(unit.max_hp)
	for card in s.hand.duplicate(): f.move_from_hand(card, s.discard_pile)
	f.anya_state = {"allies":s.allies.duplicate(true), "friends":friends, "draw":s.draw_pile.duplicate(true), "discard":s.discard_pile.duplicate(true), "exhausted":f.exhausted.duplicate(true), "calculation":f.calculation.duplicate(true), "shared":s.shared_guard, "temporary":f.temporary_guard}
	for i in friends: s.allies[i].anya_hidden = true
	s.hand.clear()
	s.draw_pile.clear()
	s.discard_pile.clear()
	f.calculation.clear()
	f.exhausted.clear()
	s.shared_guard = 0
	f.temporary_guard = 0
	unit.statuses = {}
	unit.marks = {}
	unit.guard = 0
	unit.max_hp = maxi(1, roundi(total_max_hp * 1.5))
	unit.hp = maxi(1, roundi(total_hp * 1.5))
	if unit.has("finale_original_max"):
		# The pooled body has its own seal baseline. Entry is a transfer, not healing.
		unit.finale_original_max = unit.max_hp
		s.ENEMY_RULES.FINALE.update_health_cap(s, unit, false)
	unit.downed = false
	unit.dead = false
	unit.downed_round = -1
	unit.anya_phoenix = true
	unit.portrait = ROOT + "portrait_phoenix.webp"
	unit.rebirth = rank_value([8, 10, 12])
	unit.rebirth_max = unit.rebirth
	for id in f.anya_decks.get(ID, []):
		var code := String(FightData.skill(String(id)).get("code", ""))
		if code.begins_with("LA"): s.draw_pile.append(s.make_card("LP" + code.right(2), ID))
	# Replacing the form's deck is not a passive-triggering card morph.
	f.shuffled(s.draw_pile)
	s._draw(8)
	for enemy in s.enemies: enemy.statuses.erase("anya_abuser")
	s._clear_targeting()
	s._refresh_intents()
	s._add_log("李安雅进入涅槃·幻羽：%d生命，%d护盾，%d重生计数。" % [unit.hp, unit.guard, unit.rebirth])
	s.anya_form_changed.emit("enter")

static func leave(f: RefCounted, defeated: bool = false, present: bool = true) -> void:
	if not phoenix(f): return
	if defeated: f.anya_damage_block_round = f.s.round
	if present and not f.s.preview_mode and f.s.anya_return_presentation.is_valid():
		if not f.anya_return_pending.is_empty(): return
		var ticket := {"serial":f.s.encounter_serial, "cancelled":false, "done":false, "settled":false}
		f.anya_return_pending = ticket
		var settle := func() -> void:
			if ticket.settled or ticket.cancelled or int(ticket.serial) != f.s.encounter_serial: return
			ticket.settled = true
			_settle_leave(f, defeated)
		var complete := func() -> void:
			if ticket.done or ticket.cancelled or int(ticket.serial) != f.s.encounter_serial: return
			settle.call()
			ticket.done = true
			f.anya_return_pending = {}
			f.s.anya_return_finished.emit()
		f.s.anya_return_presentation.call("defeated" if defeated else "return", settle, complete)
		return
	var pending: Dictionary = f.anya_return_pending
	if not pending.is_empty(): pending.cancelled = true
	_settle_leave(f, defeated)
	f.anya_return_pending = {}
	if not pending.is_empty(): f.s.anya_return_finished.emit()

static func _settle_leave(f: RefCounted, defeated: bool) -> void:
	var s: Node = f.s
	var at := owner(f)
	var snapshot: Dictionary = f.anya_state
	var friends: Array = snapshot.friends
	var remaining := maxi(0, int(s.allies[at].hp))
	var share := floori(float(remaining) / maxi(1, friends.size()))
	var support_hand := _carry_support_cards(f, snapshot)
	f.anya_state = {}
	# Preserve dictionary identity: callers may still hold the damaged unit.
	for i in s.allies.size():
		# This encounter-long blessing also reaches sheltered allies. Restoring the
		# pre-transformation body must not roll back stacks gained in phoenix form.
		var defiance := int(s.allies[i].get("finale_defiance", 0))
		s.allies[i].clear()
		s.allies[i].merge(snapshot.allies[i].duplicate(true))
		if defiance > 0: s.allies[i].finale_defiance = maxi(defiance, int(s.allies[i].get("finale_defiance", 0)))
		# A wave may have advanced while the original bodies were sheltered.
		s.ENEMY_RULES.FINALE.update_health_cap(s, s.allies[i])
		if i in friends or i == at:
			s.allies[i].hp = (-1 if i == at else 1) if defeated else (s.healing_ceiling(s.allies[i]) if i == at else mini(s.healing_ceiling(s.allies[i]), share))
			s.allies[i].dead = false
			s.allies[i].downed = int(s.allies[i].hp) <= 0
			s.allies[i].downed_round = s.round if s.allies[i].downed else -1
		for id in s.allies[i].statuses.keys():
			if STATUS.is_debuff(s.allies[i].statuses[id]): s.allies[i].statuses.erase(id)
		s.allies[i].marks.clear()
	s.allies[at].ult = 3
	s.draw_pile = snapshot.draw
	s.discard_pile = snapshot.discard
	f.calculation = snapshot.calculation
	f.exhausted = snapshot.exhausted
	s.hand.clear()
	s.hand.append_array(support_hand)
	s.shared_guard = int(snapshot.shared)
	f.temporary_guard = int(snapshot.temporary)
	if f.anya_mark_round == s.round: show_mark(f)
	else: mark_round(f)
	s._clear_targeting()
	s._refresh_intents()
	s._add_log("这一次，我们在一起！%s，全队负面效果清除，涅槃充能3。" % ("李安雅濒死、队友以1生命回场" if defeated else "李安雅回复至可回复上限，队友各分得至多%d生命" % share))
	s.anya_form_changed.emit("defeated" if defeated else "return")

static func _carry_support_cards(f: RefCounted, snapshot: Dictionary) -> Array:
	# Preserve the physical support cards and their current pile, including exhaustion.
	# Phoenix skills and enemy-inserted cards belong only to the temporary deck.
	var hand: Array = []
	var seen: Dictionary = {}
	for pile in [snapshot.draw, snapshot.discard, snapshot.exhausted, snapshot.calculation]:
		for card in pile: seen[card.uid] = true
	for pair in [[f.s.hand, hand], [f.s.draw_pile, snapshot.draw], [f.s.discard_pile, snapshot.discard], [f.exhausted, snapshot.exhausted], [f.calculation, snapshot.calculation]]:
		for card in pair[0]:
			if String(card.skill_id) not in f.s.ENEMY_RULES.FINALE.SUPPORT or seen.has(card.uid): continue
			pair[1].append(card)
			seen[card.uid] = true
	return hand

static func check_exit(f: RefCounted) -> bool:
	if not phoenix(f): return false
	if budget(f) <= 0:
		leave(f)
		return true
	for card in f.s.hand + f.s.draw_pile + f.s.discard_pile:
		if not String(card.get("skill_id", "")).begins_with("LP"): continue
		var price: int = 0 if bool(card.get("anya_free_on_draw", false)) else f.cost(card)
		if price <= budget(f): return false
	leave(f)
	return true

static func forced_exit(f: RefCounted, unit: Dictionary) -> bool:
	if not phoenix(f) or String(unit.get("id", "")) != ID: return false
	if unit.statuses.has("anya_unbroken"):
		unit.hp = maxi(1, int(unit.hp))
		unit.downed = false
		unit.dead = false
		f.s._add_log("我还在这里：李安雅抵挡了强制退场。", false)
	else: leave(f, true)
	return true

static func buffer_damage(f: RefCounted, unit: Dictionary, amount: int, enemy_source: int) -> int:
	if not unit.statuses.has("anya_buffer") or amount <= 0: return amount
	var status: Dictionary = unit.statuses.anya_buffer
	var reflect := bool(status.get("reflect", false))
	status.stacks -= 1
	if int(status.stacks) <= 0: unit.statuses.erase("anya_buffer")
	f.s.effect_requested.emit("anya_buffer", "ally", f.s.allies.find(unit), 0, 0)
	if reflect and enemy_source >= 0 and enemy_source < f.s.enemies.size():
		var hit: Dictionary = f.s._take_damage(f.s.enemies[enemy_source], amount)
		f.s.effect_requested.emit("LP09", "enemy", enemy_source, hit.hp, hit.guard)
	return 0

static func morph_options(f: RefCounted, source: Dictionary, rarity: String) -> Array:
	var options: Array = []
	if phoenix(f): return options
	var own := String(source.get("caster_id", "")) == ID
	for hero in f.anya_decks:
		if (own and hero == ID) or (not own and hero != ID): continue
		var at: int = f.s._ally_index(String(hero))
		if at < 0 or not f.s._is_alive(f.s.allies[at]): continue
		var seen: Array = []
		for id in f.anya_decks[hero]:
			var def := FightData.skill(String(id))
			if seen.has(id) or bool(def.get("morph", false)) or String(id) == String(source.skill_id): continue
			seen.append(id)
			var high := String(def.get("rarity", "common")) == "rare"
			if rarity == "high" and not high or rarity == "low" and high: continue
			options.append({"skill_id":id, "caster_id":hero, "anya_pick_actor":hero})
	return options

static func morph(f: RefCounted, source: Dictionary, rarity: String, done: Callable, top: bool = false, free: bool = false) -> void:
	var options := morph_options(f, source, rarity)
	if options.is_empty():
		f.s._add_log("没有符合条件的已携带非幻形牌。", false)
		done.call({})
		return
	f.ask("幻形 · 选择本局携带的%s" % ("高级牌" if rarity == "high" else "低级牌" if rarity == "low" else "技能"), options, 1, 1, func(selected: Array) -> void:
		if selected.is_empty():
			done.call({})
			return
		var pick: Dictionary = selected[0]
		for pile in [f.s.hand, f.s.draw_pile, f.s.discard_pile, f.calculation, f.exhausted]: f.remove_card(pile, source)
		var transformed: Dictionary = f.s.make_card(String(pick.skill_id), ID)
		transformed.anya_actor = String(pick.anya_pick_actor)
		if free: transformed.free = true
		if top: f.s.draw_pile.append(transformed)
		else: f.to_hand(transformed)
		var at := owner(f)
		if at >= 0: f.s._add_guard(f.s.allies[at], rank_value([2, 3, 4]))
		f.s.anya_morphed.emit(transformed)
		done.call(transformed)
	)

static func morph_many(f: RefCounted, cards: Array, done: Callable) -> void:
	if cards.is_empty():
		done.call()
		return
	var card: Dictionary = cards.pop_front()
	morph(f, card, "any", func(_new: Dictionary) -> void: morph_many(f, cards, done))

static func self_morph(f: RefCounted, c: Dictionary, rarity: String, follow: Callable = Callable()) -> void:
	morph(f, c.card, rarity, func(card: Dictionary) -> void:
		if not card.is_empty(): c.destination = "morphed"
		if follow.is_valid(): follow.call(card)
		f.finish(c)
	)

static func buffer(f: RefCounted, at: int, count: int, reflect: bool) -> void:
	var previous: Dictionary = f.s.allies[at].statuses.get("anya_buffer", {})
	f.status(at, "anya_buffer", -1, {"name":"缓冲", "desc":"抵挡下一次护盾结算后的生命伤害。" + ("按阻挡值反伤。" if reflect else ""), "stacks":int(previous.get("stacks", 0)) + count, "reflect":reflect or bool(previous.get("reflect", false))})

static func retrieve(f: RefCounted, pile: Array, discount: bool, done: Callable) -> void:
	f.ask("检索 · 选择一张技能", pile, 1, 1, func(cards: Array) -> void:
		for card in cards:
			f.remove_card(pile, card)
			if discount: card.anya_discount_once = int(card.get("anya_discount_once", 0)) + 1
			else: card.retain = true
			f.to_hand(card)
		done.call()
	)

static func execute(f: RefCounted, c: Dictionary) -> void:
	var s: Node = f.s
	var at := int(c.owner)
	var unit: Dictionary = s.allies[at]
	var code: String = f.code(c.card)
	match code:
		"LA01":
			s._add_guard(s.allies[c.target], f.scaled(at, 6))
			self_morph(f, c, "high")
			return
		"LA02":
			s._draw(1)
			f.ask("迈入深渊 · 选择幻形并置顶的手牌", f.hand_cards(), 1, 1, func(cards: Array) -> void:
				if cards.is_empty(): f.finish(c)
				else: morph(f, cards[0], "low", func(_card: Dictionary) -> void: f.finish(c), true)
			)
			return
		"LA03":
			self_morph(f, c, "low", func(card: Dictionary) -> void:
				if card.is_empty(): return
				var recipient: int = s.caster_index(card)
				if recipient >= 0:
					s._add_guard(s.allies[recipient], f.scaled(at, 10))
					f.COMPANIONS.taunt(f, recipient, 1)
			)
			return
		"LA04", "LP04":
			var hits: Array = []
			for _i in (4 if code == "LA04" else 3):
				if f.damage_interrupted(c.damage_phases): break
				var targets: Array = []
				for j in s.enemies.size():
					if s._is_alive(s.enemies[j]): targets.append(j)
				if targets.is_empty(): break
				var target := int(f.random_entry(targets))
				f.hit(c, target, 3 if code == "LA04" else 9)
				if not hits.has(target): hits.append(target)
				if code == "LP04": f.shiver(target, 2)
			if code == "LA04":
				if not hits.is_empty(): f.shiver(int(f.random_entry(hits)), 2)
				if hits.size() >= 3:
					self_morph(f, c, "high")
					return
			elif hits.size() >= 2:
				for target in hits:
					var buffs_to_remove: Array = s.EQUIPMENT.dispellable(s.enemies[target])
					if not buffs_to_remove.is_empty(): s.enemies[target].statuses.erase(buffs_to_remove[0])
		"LA05":
			var downed := bool(s.allies[c.target].downed)
			f.heal(at, int(c.target), 10)
			if downed: f.status(int(c.target), "resilience", -1, {"stacks":int(s.allies[c.target].statuses.get("resilience", {}).get("stacks", 0)) + 1})
		"LA06":
			# Two results are one morph event: award the passive once, even if only one tier is available.
			var original_guard := int(unit.guard)
			morph(f, c.card, "low", func(low: Dictionary) -> void:
				if not low.is_empty(): c.destination = "morphed"
				morph(f, c.card, "high", func(high: Dictionary) -> void:
					if not high.is_empty(): c.destination = "morphed"
					if not low.is_empty() and not high.is_empty(): unit.guard = maxi(original_guard, int(unit.guard) - f.PAINTING.shield_amount(unit, rank_value([2, 3, 4])))
					f.finish(c)
				), false, true)
			return
		"LA07":
			f.ask("你说过……什么？ · 检索并保留", s.draw_pile + s.discard_pile, 1, 1, func(cards: Array) -> void:
				for card in cards:
					f.remove_card(s.draw_pile, card)
					f.remove_card(s.discard_pile, card)
					card.retain = true
					f.to_hand(card)
				f.finish(c)
			)
			return
		"LA08":
			var discard: Array = f.hand_cards(func(card: Dictionary) -> bool: return String(card.caster_id) != ID)
			for card in discard: f.move_from_hand(card, s.discard_pile)
			s._draw(discard.size())
			var candidates: Array = f.hand_cards(func(card: Dictionary) -> bool: return String(card.caster_id) == ID)
			f.ask("孤立无援 · 选择任意数量自己的牌幻形", candidates, 0, candidates.size(), func(cards: Array) -> void: morph_many(f, cards.duplicate(), func() -> void: f.finish(c)))
			return
		"LA09":
			s._add_guard(unit, f.scaled(at, 12))
			buffer(f, at, 1, false)
		"LA10":
			for i in s.allies.size():
				if not s._is_alive(s.allies[i]): continue
				f.cleanse(i, false)
				f.status(i, "debuff_immunity", -1, {"stacks":int(s.allies[i].statuses.get("debuff_immunity", {}).get("stacks", 0)) + 1})
		"LA11":
			var options: Array = []
			for i in s.allies.size():
				if i != at and bool(s.allies[i].get("dead", false)): options.append({"label":s.allies[i].name, "ally":i})
			f.ask("想要离开…… · 选择退场队友复活", options, 1, 1, func(chosen: Array) -> void:
				for pick in chosen:
					var ally: Dictionary = s.allies[int(pick.ally)]
					ally.dead = false
					ally.downed = false
					ally.downed_round = -1
					ally.hp = maxi(1, roundi(int(ally.max_hp) * 0.3))
					s._remove_caster_cards(String(ally.id))
					for id in f.anya_decks.get(String(ally.id), []): s.draw_pile.append(s.make_card(String(id), String(ally.id)))
					f.shuffled(s.draw_pile)
				f.finish(c)
			)
			return
		"LA12":
			for i in s.allies.size():
				if s._is_alive(s.allies[i]): f.status(i, "rally", 2, {"name":"总攻", "final_bonus":0.2, "damage_out_mult":1.2})
			f.next_draw += 2
			f.anya_next_energy += 2
		"LA13":
			var cards: Array = f.hand_cards(func(card: Dictionary) -> bool: return String(card.caster_id) != ID and not s.ENEMY_RULES.is_curse(card))
			f.ask("救救我…… · 将队友牌幻形为自己的非幻形牌", cards, 0, cards.size(), func(selected: Array) -> void: morph_many(f, selected.duplicate(), func() -> void: f.finish(c)))
			return
		"LP01":
			s._add_guard(unit, f.scaled(at, 18))
			f.COMPANIONS.timed(f, at, "anya_shelter", 1, {"name":"不惧，我在", "damage_reduction":0.1})
		"LP02":
			s._draw(1)
			f.ask("迈向希望 · 置顶，下次抽到首次免费", f.hand_cards(), 1, 1, func(cards: Array) -> void:
				for card in cards:
					f.remove_card(s.hand, card)
					card.anya_free_on_draw = true
					s.draw_pile.append(card)
				f.finish(c)
			)
			return
		"LP03":
			c.ignore_guard = true
			f.hit(c, int(c.target), 15)
		"LP05":
			f.heal(at, at, 24)
			f.cleanse(at, false)
		"LP06":
			var options: Array = s.hand.duplicate()
			for _i in mini(2, options.size()):
				var card: Dictionary = f.random_entry(options)
				options.erase(card)
				card.free = true
			f.ask("我就在身边 · 弃置一张手牌", f.hand_cards(), 1, 1, func(cards: Array) -> void:
				for card in cards: f.move_from_hand(card, s.discard_pile)
				f.finish(c)
			)
			return
		"LP07":
			retrieve(f, s.discard_pile, true, func() -> void: retrieve(f, s.draw_pile, true, func() -> void: f.finish(c)))
			return
		"LP08":
			var count: int = s.hand.size()
			for card in s.hand.duplicate(): f.move_from_hand(card, s.discard_pile)
			s._draw(count)
			for _i in count:
				if f.damage_interrupted(c.damage_phases): break
				var lowest := -1
				for i in s.enemies.size():
					if s._is_alive(s.enemies[i]) and (lowest < 0 or int(s.enemies[i].hp) < int(s.enemies[lowest].hp)): lowest = i
				if lowest >= 0: f.hit(c, lowest, 10)
		"LP09": buffer(f, at, 2, true)
		"LP10":
			for enemy in s.enemies:
				if s._is_alive(enemy): enemy.guard = 0
			f.status(at, "debuff_immunity", -1, {"stacks":int(unit.statuses.get("debuff_immunity", {}).get("stacks", 0)) + 2})
		"LP11": f.status(at, "anya_unbroken", -1, {"name":"我还在这里", "desc":"仅重生计数耗尽或无可负担技能时退场；生命最低保留1。", "uncleansable":true})
		"LP12":
			var stacks := int(unit.statuses.get("anya_rally", {}).get("stacks", 0)) + 1
			f.status(at, "anya_rally", -1, {"name":"总攻·直到天亮", "final_bonus":stacks * 0.2, "stacks":stacks})
			var adjacent: Array = f.COMPANIONS.adjacent_enemies(f, int(c.target))
			f.hit(c, int(c.target), 42)
			for i in adjacent:
				if f.damage_interrupted(c.damage_phases): break
				var amount: int = f.damage_amount(unit, s.enemies[i], 21)
				var result: Dictionary = s._take_damage(s.enemies[i], amount)
				f.report_attack_attribute(i, "none", "溅射")
				s.effect_requested.emit("LP12", "enemy", i, result.hp, result.guard)
		"LP13":
			f.ask("这一次，由我来救你！ · 弃牌回复重生计数", f.hand_cards(), 0, s.hand.size(), func(cards: Array) -> void:
				for card in cards: f.move_from_hand(card, s.discard_pile)
				unit.rebirth = int(unit.rebirth) + cards.size()
				f.finish(c)
			)
			return
	f.finish(c)
