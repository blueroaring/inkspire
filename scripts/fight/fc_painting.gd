extends RefCounted
const STATUS := preload("res://scripts/fight/status_rules.gd")
## 刘丹雅：所有区域与分组均参与正式结算；选择在确认前不修改画作。
const COLORS := ["white", "ink", "red", "yellow", "blue", "rainbow"]
const DYES := ["ink", "red", "yellow", "blue"]
const NAMES := {"white":"白色", "ink":"墨色", "red":"红色", "yellow":"黄色", "blue":"蓝色", "rainbow":"彩色"}
const TINTS := {"white":Color("f1ead8"), "ink":Color("293338"), "red":Color("b85242"), "yellow":Color("d4ac47"), "blue":Color("467a9b"), "rainbow":Color("b697bd")}

static func blank() -> Array:
	return ["white", "white", "white", "white", "white", "white"]

static func _take_group(pool: Dictionary, recipe: Array) -> Array:
	var trial := pool.duplicate(true)
	var result: Array = []
	for color in recipe:
		var key: String = color if not trial[color].is_empty() else "rainbow"
		if trial[key].is_empty(): return []
		result.append(trial[key].pop_front())
	for color in pool: pool[color] = trial[color]
	return result

static func groups(canvas: Array) -> Dictionary:
	var pool: Dictionary = {}
	for color in COLORS: pool[color] = []
	for i in canvas.size(): pool[canvas[i]].append(i)
	var result := {"tri":[], "ink":[]}
	# Greedy exact colors first minimizes wildcard use. All tricolors precede ink.
	for kind in ["tri", "ink"]:
		var recipe: Array = ["red", "yellow", "blue"] if kind == "tri" else ["white", "ink"]
		while true:
			var group := _take_group(pool, recipe)
			if group.is_empty(): break
			result[kind].append(group)
	return result

static func flatten(list: Array) -> Array:
	var result: Array = []
	for group in list: result.append_array(group)
	return result

static func playable(f: RefCounted, id: String) -> bool:
	var g := groups(f.painting)
	var ink: bool = not g.ink.is_empty()
	var tri: bool = not g.tri.is_empty()
	match id:
		"Y07", "Y14": return tri
		"Y08": return ink
		"Y09": return ink and tri
		"Y11": return ink and not f.painting.any(func(color: String) -> bool: return color in ["red", "yellow", "blue"])
		"Y12": return tri and not f.painting.has("ink")
	return true

static func requirement(id: String) -> String:
	return String({"Y07":"需要三色组", "Y08":"需要水墨组", "Y09":"需要不复用区域的三色组与水墨组", "Y11":"只可含白、墨、彩色，且需要水墨组", "Y12":"不可含墨色，且需要三色组", "Y14":"需要三色组"}.get(id, ""))

static func ask(f: RefCounted, title: String, regions: Array, colors: Array, minimum: int, maximum: int, c: Dictionary, done: Callable) -> void:
	if regions.is_empty():
		done.call()
		return
	f.serial += 1
	f.choice = {"kind":"painting", "serial":f.serial, "title":title, "regions":regions.duplicate(), "colors":colors.duplicate(), "min":minimum, "max":maximum, "canvas":f.painting.duplicate(), "preserve_wash":bool(c.get("preserve_wash", false)), "draw_groups":bool(c.get("draw_groups", false))}
	f.choice_callback = func(edits: Dictionary) -> void:
		for index in edits:
			if edits[index] != "white" or not bool(c.get("preserve_wash", false)): f.painting[int(index)] = edits[index]
		done.call()
	f.s.state_changed.emit()

static func choose(f: RefCounted, edits: Dictionary) -> bool:
	var choice: Dictionary = f.choice
	if choice.get("kind", "") != "painting" or edits.size() < int(choice.min) or edits.size() > int(choice.max): return false
	for index in edits:
		if not index is int or not choice.regions.has(index) or not choice.colors.has(edits[index]): return false
	var callback: Callable = f.choice_callback
	f.choice = {}
	f.choice_callback = Callable()
	callback.call(edits.duplicate())
	f.s.state_changed.emit()
	return true

static func wash(f: RefCounted, c: Dictionary, regions: Array) -> void:
	if bool(c.get("preserve_wash", false)): return
	for index in regions: f.painting[int(index)] = "white"

static func shield_amount(unit: Dictionary, amount: int) -> int:
	var fragile := int(unit.get("statuses", {}).get("fragile", {}).get("stacks", 0))
	return roundi(amount * (1.0 + float(unit.get("statuses", {}).get("shield_strength", {}).get("bonus", 0.0)) + int(unit.get("finale_defiance", 0)) * 0.3) * maxf(0.0, 1.0 - fragile * 0.15))

static func consume_swift(unit: Dictionary) -> void:
	if not unit.statuses.has("swift"): return
	unit.statuses.swift.stacks -= 1
	if int(unit.statuses.swift.stacks) <= 0: unit.statuses.erase("swift")

static func execute(f: RefCounted, c: Dictionary) -> void:
	var s: Node = f.s
	var o := int(c.owner)
	var t := int(c.target)
	var id: String = f.code(c.card)
	var unit: Dictionary = s.allies[o]
	if not playable(f, id):
		f.finish(c)
		return
	var g := groups(f.painting)
	var done := func() -> void: f.finish(c)
	match id:
		"Y01":
			f.hit(c, t, 7)
			ask(f, "点缀色彩：选择一格染色", range(6), DYES, 1, 1, c, done)
			return
		"Y02":
			s._add_guard(unit, f.scaled(o, 10))
			ask(f, "留白：选择一格洗去", range(6), ["white"], 1, 1, c, done)
			return
		"Y03":
			ask(f, "折枝写意：选择两格，各自染色或洗去", range(6), ["white"] + DYES, 2, 2, c, done)
			return
		"Y04":
			ask(f, "肆意涂抹：任选区域染成墨色", range(6), ["ink"], 0, 6, c, done)
			return
		"Y05":
			var regions: Array = []
			for i in 6:
				if f.painting[i] != "ink": regions.append(i)
			wash(f, c, regions)
			s._draw(2)
		"Y06":
			var regions: Array = []
			for i in 6:
				if f.painting[i] == "ink": regions.append(i)
			ask(f, "色彩改稿：逐格为墨色选择红、黄或蓝", regions, ["red", "yellow", "blue"], regions.size(), regions.size(), c, done)
			return
		"Y07":
			for i in s.allies.size():
				if not s._is_alive(s.allies[i]): continue
				var turns := int(s.allies[i].statuses.get("armor_break", {}).get("turns", 0)) + 4
				f.COMPANIONS.timed(f, i, "armor_break", turns, {"name":"碎甲", "desc":"攻击有护盾的目标时，整段伤害提高50%；层数只延长回合。"})
			wash(f, c, g.tri[0])
		"Y08":
			for i in s.allies.size():
				if not s._is_alive(s.allies[i]): continue
				var bonus := float(s.allies[i].statuses.get("shield_strength", {}).get("bonus", 0.0)) + 0.5
				f.COMPANIONS.timed(f, i, "shield_strength", 1, {"name":"护盾强效", "desc":"获得的个人护盾提高%d%%；共享盾按施盾者计算一次，临时盾同样生效。" % roundi(bonus * 100), "bonus":bonus})
			wash(f, c, g.ink[0])
		"Y09":
			for i in s.allies.size():
				if i == o or not s._is_alive(s.allies[i]): continue
				var stacks := int(s.allies[i].statuses.get("swift", {}).get("stacks", 0)) + 1
				f.status(i, "swift", -1, {"name":"疾行", "desc":"下一次技能耗能为0；每次释放消耗一层。", "stacks":stacks})
			wash(f, c, g.tri[0] + g.ink[0])
		"Y10":
			ask(f, "色彩调度：选择一格染成彩色", range(6), ["rainbow"], 1, 1, c, done)
			return
		"Y11":
			var stacks: int = int(s.allies[t].statuses.get("debuff_immunity", {}).get("stacks", 0)) + g.ink.size()
			f.status(t, "debuff_immunity", -1, {"name":"负面免疫", "desc":"每层抵消一次负面效果施加；同次同名的多层效果只消耗一层。", "stacks":stacks})
			wash(f, c, flatten(g.ink))
		"Y12":
			f.energy(2 * g.tri.size())
			f.painting_next_energy += g.tri.size()
			wash(f, c, flatten(g.tri))
		"Y13":
			for i in 6:
				if f.painting[i] in ["red", "yellow", "blue"]: f.painting[i] = "ink"
				elif f.painting[i] == "ink": f.painting[i] = f.random_entry(["red", "yellow", "blue"])
		"Y14":
			var regions := flatten(g.tri)
			ask(f, "决意：逐格选择洗去或染墨", regions, ["white", "ink"], regions.size(), regions.size(), c, func() -> void: _resolve(c, f))
			return
		"Y15": f.status(o, "sketch", -1, {"name":"素描", "desc":"仅下次技能抵消全部洗去；下次无洗去也会消失。"})
		"Y16":
			_mix(f, c, f.painting.duplicate(), 0)
			return
	f.finish(c)

static func _resolve(c: Dictionary, f: RefCounted) -> void:
	var count: int = groups(f.painting).ink.size()
	var options: Array = []
	for i in f.s.allies.size():
		if f.s._is_alive(f.s.allies[i]): options.append({"label":f.s.allies[i].name, "ally":i})
	f.ask("决意：选择检索技能的角色", options, 1, 1, func(selected: Array) -> void:
		var cards: Array = []
		if not selected.is_empty():
			var owner: String = f.s.allies[int(selected[0].ally)].id
			cards = f.s.draw_pile.filter(func(card: Dictionary) -> bool: return String(card.caster_id) == owner)
		f.ask("决意：选择至多%d张技能加入手牌" % count, cards, 0, count, func(chosen: Array) -> void:
			for card in chosen:
				f.remove_card(f.s.draw_pile, card)
				f.to_hand(card)
			wash(f, c, range(6))
			f.finish(c)
		)
	)

static func _cleanse_random(f: RefCounted) -> Dictionary:
	var options: Array = []
	for i in f.s.allies.size():
		if not f.s._is_alive(f.s.allies[i]): continue
		for id in f.s.allies[i].statuses:
			var st: Dictionary = f.s.allies[i].statuses[id]
			if STATUS.is_debuff(st) and not bool(st.get("uncleansable", false)): options.append({"ally":i, "id":id})
	if options.is_empty(): return {}
	var picked: Dictionary = f.random_entry(options)
	picked["name"] = String(f.s.allies[int(picked.ally)].statuses[String(picked.id)].get("name", picked.id))
	f.cleanse(int(picked.ally), false, String(picked.id))
	return picked

static func _mix(f: RefCounted, c: Dictionary, canvas: Array, at: int) -> void:
	# The live scene releases one region only after the preceding effects finish.
	# Rules-only callers and previews use the identical resolver synchronously.
	if not f.s.preview_mode and f.s.painting_region_presentation.is_valid():
		f.s.painting_region_presentation.call(int(c.owner), canvas, at, _resolve_mix_region.bind(f, c, canvas, at))
		return
	_resolve_mix_region(f, c, canvas, at)

static func _resolve_mix_region(f: RefCounted, c: Dictionary, canvas: Array, at: int) -> void:
	if at >= canvas.size():
		f.finish(c)
		return
	var color: String = canvas[at]
	if color in ["white", "rainbow"]:
		var amount := shield_amount(f.s.allies[c.owner], f.scaled(c.owner, 5))
		f.s.shared_guard += amount
		f.s.painting_effect_resolved.emit("guard", int(c.owner), amount, "共享护盾 +%d" % amount)
	var next := func() -> void:
		if color in ["red", "yellow", "blue", "rainbow"]:
			var cleared := _cleanse_random(f)
			f.s.painting_effect_resolved.emit("cleanse", int(cleared.get("ally", -1)), 0, "无可净化的负面效果" if cleared.is_empty() else "%s · 净化%s" % [f.s.allies[int(cleared.ally)].name, cleared.name])
		f.s.state_changed.emit()
		_mix(f, c, canvas, at + 1)
	if color in ["ink", "rainbow"]:
		# Each region is one attack; pursuit settles before proceeding to the next region.
		c.hits = []
		f.all_hit(c, 6)
		var math_owner: int = f.s._ally_index("zhoumingyuan")
		var count := 1 if f.is_math(math_owner) and f.locked_alive() and (c.hits.has(f.locked_enemy) or f.noticed) else 0
		f.pursue(math_owner, count, true, next, c.damage_phases)
	else: next.call()

static func ultimate(f: RefCounted, owner: int, done: Callable) -> void:
	var unit: Dictionary = f.s.allies[owner]
	var c := {"preserve_wash":unit.statuses.has("sketch"), "draw_groups":true}
	unit.statuses.erase("sketch")
	consume_swift(unit)
	ask(f, "一气呵成：任选0–6处染色或洗去，未选区域保留原样", range(6), ["white"] + DYES, 0, 6, c, func() -> void:
		var g := groups(f.painting)
		f.s._draw(g.tri.size() + g.ink.size())
		f.s.effect_requested.emit("ultimate_liu", "ally", owner, 0, 0)
		done.call()
	)
