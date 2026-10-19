extends RefCounted
const STATUS := preload("res://scripts/fight/status_rules.gd")
## Additional 14.md enemies. State lives on units so combat previews can copy it.
const IDS := ["gaokao_countdown", "report_card", "quiet_hacker", "magician_master", "self_destructive_pain", "infirmary_demon", "bullied_phantom", "fist_phantom", "whip_phantom", "bruised_hand", "shackle_phantom", "claustrophobic_box"]
const SUMMONS := ["fist_phantom", "whip_phantom", "bruised_hand", "shackle_phantom"]
const CURSES := ["ranking", "wound", "medicine", "shackle", "do_not_tell"]
const SUMMON_ROTATION := ["shackle_phantom", "bruised_hand", "fist_phantom"]

static func setup(unit: Dictionary) -> void:
	unit.expansion_step = 0
	if unit.id == "gaokao_countdown": unit.countdown = 3
	if unit.id == "report_card":
		unit.revivals = 0
		unit.revive_on = -1
		unit.statuses.damage_cap = {"name":"难以销毁", "desc":"每段攻击造成的生命伤害有上限；前两次倒下后会短暂失去实体，再以部分生命复生。", "turns":-1, "debuff":false, "uncleansable":true, "category":"passive"}
	if unit.id == "self_destructive_pain": unit.hp = maxi(1, roundi(float(unit.max_hp) * 0.5))
	if unit.id == "magician_master": unit.statuses.evasion = {"name":"遁逃术", "desc":"有50%概率闪避每段直接攻击；毒和反伤不受影响。", "turns":-1, "debuff":false, "uncleansable":true, "category":"passive"}
	if unit.id == "bullied_phantom":
		unit.assist_charge = 0
		unit.summon_cursor = 0
		unit.summon_due = true
		unit.support_step = 0
		unit.expansion_opened = false
		unit.statuses.helpless = {"name":"习得性无助", "desc":"本体不攻击；召唤幻影、施加干扰。部分幻影与本体共享生命。击败幻影为反抗援助充能。", "turns":-1, "debuff":false, "uncleansable":true, "category":"passive"}
	if unit.id in ["fist_phantom", "whip_phantom", "shackle_phantom"]:
		unit.summon_hits = 5 if unit.id != "whip_phantom" else 3
		update_summon_hits(unit)
	if unit.id == "claustrophobic_box": unit.statuses.no_escape = {"name":"无处可逃", "desc":"在场时手牌上限为8；满手牌打出一张后抽一张。空间压缩可将上限降至2张。", "turns":-1, "debuff":false, "uncleansable":true, "category":"rule"}
	if unit.id == "infirmary_demon": unit.statuses.blood_draw = {"name":"抽血", "desc":"攻击造成生命伤害时，回复该伤害150%的生命。", "turns":-1, "debuff":false, "uncleansable":true, "category":"passive"}

static func start(s: Node) -> void:
	for i in s.enemies.size():
		if s.enemies[i].id == "bullied_phantom" and not bool(s.enemies[i].expansion_opened):
			s.enemies[i].expansion_opened = true
			spawn(s, i, "fist_phantom")
			spawn(s, i, "whip_phantom")
			s._add_log("噩梦开幕：拳头与皮鞭的幻影出现。", false)
	refresh_hand_limit(s)

static func refresh_hand_limit(s: Node) -> void:
	var box_present := false
	for enemy in s.enemies:
		if enemy.id == "claustrophobic_box" and s._is_alive(enemy): box_present = true
	s.expansion_hand_limit = maxi(2, 8 - int(s.get_meta("box_compressions", 0)) * 2) if box_present else s.HAND_LIMIT
	for enemy in s.enemies:
		if enemy.id == "claustrophobic_box" and s._is_alive(enemy):
			enemy.hand_limit = s.expansion_hand_limit
			enemy.statuses.no_escape.desc = "当前手牌上限%d张；满手牌打出一张后抽一张。空间压缩每次减少2张，最低2张；超出上限的末端手牌进入弃牌堆，击败所有窒息之笼后恢复。" % s.expansion_hand_limit
	while s.hand.size() > s.expansion_hand_limit:
		s.discard_pile.append(s.hand.pop_back())

static func spawn(s: Node, boss: int, id: String) -> bool:
	if s.ENEMY_RULES.summon_slots(s) == 0: return false
	var profile := FightData.enemy(id)
	var level := int(s.enemies[boss].level)
	var hp := FightData.enemy_hp(id, level)
	var unit := {"id":id, "name":profile.name, "portrait":profile.portrait, "attribute":profile.attribute, "level":level, "max_hp":hp, "hp":hp, "guard":0, "statuses":{}, "marks":{}, "intent":{}, "summoner":boss, "joined_round":s.round}
	if id in ["fist_phantom", "whip_phantom", "shackle_phantom"]:
		unit.max_hp = int(s.enemies[boss].max_hp)
		unit.hp = int(s.enemies[boss].hp)
	setup(unit)
	s.enemies.append(unit)
	refresh(s, s.enemies.size() - 1)
	return true

static func living_of(s: Node, boss: int, id: String = "") -> int:
	var count := 0
	for enemy in s.enemies:
		if int(enemy.get("summoner", -1)) == boss and s._is_alive(enemy) and (id.is_empty() or enemy.id == id): count += 1
	return count

static func next_summon(s: Node, boss: int) -> int:
	# Only search the unconsumed part of this rotation. A defeated summon must
	# not rewind the cursor and starve the later summon skills.
	var cursor := int(s.enemies[boss].get("summon_cursor", 0)) % SUMMON_ROTATION.size()
	for slot in range(cursor, SUMMON_ROTATION.size()):
		var id: String = SUMMON_ROTATION[slot]
		if living_of(s, boss, id) == 0 or (id == "fist_phantom" and living_of(s, boss, "whip_phantom") == 0): return slot
	return cursor

static func refresh(s: Node, index: int) -> bool:
	var e: Dictionary = s.enemies[index]
	if not String(e.id) in IDS: return false
	var r = s.ENEMY_RULES
	var step := int(e.get("expansion_step", 0))
	var moves: Array = []
	match String(e.id):
		"gaokao_countdown":
			e.intent = r.action("倒计时归零", "single", r.scaled(e, 17, 0.8), "countdown_burst", "倒计时归零：主目标及相邻角色受到伤害并眩晕1回合；自身消失。") if int(e.countdown) <= 1 else r.action("倒计时逼近", "single", r.scaled(e, 7, 0.4), "countdown_hit", "攻击并给予1回合虚弱；倒计时还剩%d回合。" % int(e.countdown))
			return true
		"report_card":
			if e.statuses.has("offstage"):
				e.intent = r.action("无实体", "all", 0, "report_absent", "无法被直接攻击；执行此意图后立即复生，可用敌方净化提前击败。")
				return true
			moves = [r.action("排名宣读", "single", r.scaled(e, 6, 0.3), "rankings", "攻击并向弃牌堆放入2张排名：留在手中到回合结束会施加颤栗。"), r.action("灰烬回响", "bounce", r.scaled(e, 5, 0.35), "ash_bounce", "弹射%d次，复生次数越多段数越多。" % (3 + int(e.revivals)), 3 + int(e.revivals))]
		"quiet_hacker":
			moves = [r.action("夺旗", "single", r.scaled(e, 11, 0.55), "steal_card", "攻击并暂时夺走目标的一张随机技能牌；黑客被击败后还回弃牌堆。"), r.action("黑客侵入", "single", r.scaled(e, 5, 0.25), "trojan", "攻击并使抽牌堆随机一张牌感染木马；在手牌时必须优先打出，效果无效。")]
		"magician_master":
			if step == 0 or (step % 4 == 0 and not has_countdown(s)):
				e.intent = r.action("大变活人！", "single", r.scaled(e, 6, 0.3), "magic_summon", "攻击并召唤两只高考倒计时；场上已有倒计时则改用其他技能。")
				return true
			moves = [r.action("扑克牌魔术", "single", r.scaled(e, 12, 0.65), "card_ban", "攻击；下一回合抽到目标角色的牌会改入弃牌堆。"), r.action("读心术", "single", r.scaled(e, 6, 0.3), "mind_read", "攻击当前生命最低角色并施加两回合支配：自己的牌仅在手牌首位时可打出。"), r.action("三仙归洞", "single", r.scaled(e, 15, 0.7), "shell_game", "攻击当前生命最低角色，获得护盾并提高后续伤害。")]
		"self_destructive_pain":
			if step == 0:
				e.intent = r.action("痛楚", "all", 0, "pain_awake", "首次行动将当前生命翻倍，不超过最大生命。")
				return true
			moves = [r.action("麻木", "single", 0, "numb", "消耗自身当前生命15%，对一名角色造成等量无视护盾的伤害。"), r.action("自毁", "bounce", 0, "self_harm", "消耗自身当前生命30%，按消耗量弹射并施加痛楚；每层回合结束失去1生命。")]
		"infirmary_demon":
			moves = [r.action("药物依赖", "single", r.scaled(e, 7, 0.35), "medicine", "攻击并向弃牌堆放入5张伤口及1张特效药。"), r.action("隔离观察", "single", r.scaled(e, 6, 0.3), "isolate", "攻击一名角色两次，并隔离3回合：暂时提高30%最大生命，隔离期间受伤无视护盾。", 2), r.action("病危通知", "single", r.scaled(e, 14, 0.7), "critical", "优先攻击被隔离角色，先清除其可驱散增益。"), r.action("麻醉喷雾", "all", r.scaled(e, 5, 0.25), "anesthetic", "攻击全体；低于半血者晕眩1回合，其余获得1回合虚弱。")]
		"bullied_phantom":
			if s.ENEMY_RULES.summon_slots(s) > 0 and (living_of(s, index) < 3 or bool(e.get("summon_due", true))):
				var slot := next_summon(s, index)
				var missing: String = SUMMON_ROTATION[slot]
				e.intent = r.action("镣铐拖行" if missing == "shackle_phantom" else "淤青之手" if missing == "bruised_hand" else "残影召唤", "all", 0, "phantom_summon", "召唤幻影并干扰手牌；幻影数量达到上限时改为非召唤技能。")
				e.intent.summon_id = missing
				e.intent.summon_slot = slot
				return true
			moves = [r.action("消毒水雾", "all", 0, "disinfect", "解除本体负面状态，所有在场幻影伤害提高。"), r.action("不准告人", "all", 0, "do_not_tell", "向抽牌堆放入2张不准告人，并治疗在场幻影。")]
			e.intent = moves[int(e.get("support_step", 0)) % moves.size()].duplicate(true)
			return true
		"fist_phantom": moves = [r.action("殴打", "single", r.scaled(e, 8, 0.4), "fist", "攻击单体；被直接攻击5次后消散。")]
		"whip_phantom": moves = [r.action("抽打", "all", r.scaled(e, 5, 0.28), "whip", "攻击全体；被直接攻击3次后消散。"), r.action("闪电五连鞭", "bounce", r.scaled(e, 3, 0.2), "whip_bounce", "随机弹射5次；每名被命中角色最多获得1层虚弱。", 5)]
		"bruised_hand": moves = [r.action("救救我……", "all", 0, "hand_guard", "获得1回合嘲讽与少量免伤。"), r.action("崩溃哭喊", "single", int(e.hp), "hand_burst", "按自爆时的剩余生命结算伤害；被护盾吸收的伤害治疗首领。")]
		"shackle_phantom": moves = [r.action("锁缚", "all", 0, "shackle_lock", "下一回合只有手牌首位、中位及末位可打出；随后幻影消散。被直接攻击5次也会消散。")]
		"claustrophobic_box": moves = [r.action("窒息拥抱", "all", r.scaled(e, 9, 0.5), "suffocate", "攻击全体并施加1回合窒息：技能费用+1；自身伤害提高。"), r.action("空间压缩", "all", 0, "compress", "本场手牌上限减少2，超出上限的末端手牌进入弃牌堆，最低为2张。")]
	e.intent = moves[step % moves.size()].duplicate(true)
	return true

static func has_countdown(s: Node) -> bool:
	for e in s.enemies:
		if e.id == "gaokao_countdown" and s._is_alive(e): return true
	return false

static func lowest_target(s: Node) -> int:
	var chosen := -1
	for i in s.allies.size():
		if not s._enemy_targetable(s.allies[i]): continue
		if chosen < 0 or int(s.allies[i].hp) < int(s.allies[chosen].hp): chosen = i
	return chosen

static func attack(s: Node, index: int, target: int, base: int, name: String, pierce: bool = false) -> Dictionary:
	if target < 0 or not s._enemy_targetable(s.allies[target]): return {"hp":0,"guard":0}
	var e: Dictionary = s.enemies[index]
	var previous_hp := maxi(0, int(s.allies[target].hp))
	var amount: int = s.fc.damage_amount(e, s.allies[target], float(base), false)
	var result: Dictionary = s._take_damage(s.allies[target], amount, pierce, index)
	if e.id == "infirmary_demon" and int(result.hp) > 0: s._heal(e, mini(previous_hp, int(result.hp)) * 1.5)
	return result

static func add_debuff(s: Node, target: int, id: String, name: String, desc: String, turns: int, extra: Dictionary = {}) -> void:
	if target < 0 or not s._is_alive(s.allies[target]): return
	var data := {"name":name,"desc":desc,"turns":turns,"debuff":true}
	data.merge(extra, true)
	s.fc.POISON.debuff(s.allies[target], id, data)

static func add_curse(s: Node, id: String, destination: Array, count: int = 1, pile: String = "discard") -> void:
	var added: Array = []
	for _i in count:
		var card: Dictionary = s.make_card(id, "")
		destination.append(card)
		added.append(card)
	s.ENEMY_RULES.notify_added(s, added, pile)

static func resolve(s: Node, index: int) -> bool:
	var e: Dictionary = s.enemies[index]
	if not String(e.id) in IDS: return false
	if e.statuses.has("offstage"):
		e.statuses.erase("offstage")
		e.hp = maxi(1, roundi(float(e.max_hp) * (0.5 if int(e.revivals) == 1 else 0.25)))
		e.revive_on = -1
		s.effect_requested.emit("report_rebirth", "enemy", index, 0, 0)
		s._refresh_intents(index)
		s._add_log("成绩单从灰烬中复生。", false)
		return true
	var intent: Dictionary = e.intent.duplicate(true)
	var effect := String(intent.get("effect", ""))
	if effect == "hand_burst": intent.damage = maxi(0, int(e.hp))
	var target: int = lowest_target(s) if effect in ["mind_read", "shell_game"] else s.ENEMY_RULES.single_target(s)
	if effect == "critical":
		for i in s.allies.size():
			if s._enemy_targetable(s.allies[i]) and s.allies[i].statuses.has("isolation"): target = i; break
	var targets: Array = s.ENEMY_RULES.targets(s) if String(intent.kind) == "all" else [target] if target >= 0 else []
	if effect == "countdown_burst" and target >= 0:
		targets = []
		for neighbor in [target - 1, target, target + 1]:
			if neighbor >= 0 and neighbor < s.allies.size() and s._enemy_targetable(s.allies[neighbor]): targets.append(neighbor)
	if String(intent.kind) == "bounce":
		targets.clear()
		for _hit in int(intent.get("hits", 3)):
			targets.append(-1)
	if effect == "pain_awake": e.hp = mini(int(e.max_hp), int(e.hp) * 2)
	if effect == "numb": intent.damage = maxi(1, roundi(int(e.hp) * 0.15)); e.hp = maxi(1, int(e.hp) - int(intent.damage))
	if effect == "self_harm":
		var spent := maxi(1, roundi(int(e.hp) * 0.30))
		e.hp = maxi(1, int(e.hp) - spent)
		targets.clear()
		for _hit in maxi(1, int(ceili(float(spent) / maxi(1.0, float(e.max_hp) * 0.05)))):
			targets.append(-1)
	if effect == "isolate" and target >= 0 and not s.allies[target].statuses.has("isolation"):
		var extra := maxi(1, roundi(int(s.allies[target].max_hp) * 0.30))
		s.allies[target].max_hp += extra
		s.allies[target].hp += extra
		s.allies[target].isolation_extra = extra
		add_debuff(s, target, "isolation", "隔离", "持续3回合，受到的伤害无视护盾；临时增加30%最大生命，结束时扣回。", 3, {"uncleansable":true})
		s.effect_requested.emit("isolation_gain", "ally", target, 0, 0)
	if String(intent.kind) == "single" and int(intent.get("hits", 1)) > 1:
		for _hit in range(1, int(intent.hits)):
			if target >= 0: targets.append(target)
	var weakened: Array = []
	for planned_target in targets:
		if not s._is_alive(e): break
		var hit_target := int(planned_target)
		if String(intent.kind) == "bounce":
			var available: Array = s.ENEMY_RULES.targets(s)
			if available.is_empty(): break
			hit_target = int(s.fc.random_entry(available))
		if not s._enemy_targetable(s.allies[hit_target]): continue
		if effect == "critical" or effect == "countdown_burst":
			if effect == "critical":
				for status_id in s.allies[hit_target].statuses.keys():
					if STATUS.is_buff(s.allies[hit_target].statuses[status_id]) and not bool(s.allies[hit_target].statuses[status_id].get("uncleansable", false)): s.allies[hit_target].statuses.erase(status_id)
		var result := attack(s, index, hit_target, int(intent.damage), String(intent.name), effect == "numb" or s.allies[hit_target].statuses.has("isolation")) if int(intent.damage) > 0 else {"hp":0,"guard":0}
		match effect:
			"countdown_hit": add_debuff(s, hit_target, "weakness", "虚弱", "造成的伤害降低25%。", 1, {"damage_out_mult":0.75})
			"countdown_burst": add_debuff(s, hit_target, "stun", "晕眩", "下回合无法行动。", 1, {"control":true})
			"mind_read": add_debuff(s, hit_target, "domination", "支配", "自己的牌只有在手牌首位时可打出。", 2)
			"anesthetic":
				if int(s.allies[hit_target].hp) * 2 < int(s.allies[hit_target].max_hp): add_debuff(s, hit_target, "stun", "晕眩", "下回合无法行动。", 1, {"control":true})
				else: add_debuff(s, hit_target, "weakness", "虚弱", "造成的伤害降低25%。", 1, {"damage_out_mult":0.75})
			"suffocate": add_debuff(s, hit_target, "suffocation", "窒息", "技能费用+1。", 1)
			"self_harm":
				var layers := int(s.allies[hit_target].statuses.get("pain_stacks", {}).get("stacks", 0)) + 3
				add_debuff(s, hit_target, "pain_stacks", "痛楚", "回合结束时失去等于层数的生命；净化一次清空。", -1, {"stacks":layers})
			"whip_bounce":
				if not weakened.has(hit_target):
					add_debuff(s, hit_target, "weakness", "虚弱", "造成的伤害降低25%。", 1, {"damage_out_mult":0.75})
					weakened.append(hit_target)
		if effect == "hand_burst" and int(result.guard) > 0:
			var boss_index := int(e.get("summoner", -1))
			if boss_index >= 0 and boss_index < s.enemies.size(): s.enemies[boss_index].hp = mini(int(s.enemies[boss_index].max_hp), int(s.enemies[boss_index].hp) + int(result.guard))
		# Capture each contact after its own debuff changes, including zero-damage bounces.
		if int(intent.damage) > 0 or effect == "self_harm":
			s.effect_requested.emit(String(intent.name), "ally", hit_target, result.hp, result.guard)
			s.action_resolved.emit("ally", hit_target)
		if int(intent.damage) > 0: s.fc.POISON.enemy_attacked(s.fc, index)
	if effect == "countdown_hit": e.countdown = int(e.countdown) - 1
	if effect == "countdown_burst" or effect in ["hand_burst", "shackle_lock"]: e.hp = 0
	match effect:
		"rankings": add_curse(s, "ranking", s.discard_pile, 2)
		"trojan":
			if not s.draw_pile.is_empty():
				var card: Dictionary = s.fc.random_entry(s.draw_pile)
				card.trojan = true
				s._add_log("木马已植入%s；抽到后须优先打出，原效果失效。" % FightData.skill(String(card.skill_id)).get("name", "技能"), false)
		"steal_card":
			var cards: Array = []
			if target >= 0:
				for pile in [s.hand, s.draw_pile, s.discard_pile]:
					for card in pile:
						if String(card.get("caster_id", "")) == String(s.allies[target].id): cards.append(card)
			if not cards.is_empty():
				var stolen: Dictionary = s.fc.random_entry(cards)
				for pile in [s.hand, s.draw_pile, s.discard_pile]: s.fc.remove_card(pile, stolen)
				if not e.has("stolen_cards"): e.stolen_cards = []
				e.stolen_cards.append(stolen)
				s._add_log("低调的黑客夺走了%s的%s；击败黑客后归还弃牌堆。" % [s.allies[target].name, FightData.skill(String(stolen.skill_id)).get("name", "技能")], false)
		"magic_summon":
			for _i in 2: spawn(s, index, "gaokao_countdown")
		"card_ban":
			if target >= 0: s.allies[target].ban_draw_round = s.round + 1
		"shell_game":
			s._add_guard(e, s.ENEMY_RULES.scaled(e, 13, 0.5))
			s.ENEMY_RULES.buff(e, "stage_power", "三仙归洞", 0.12, 4)
		"medicine":
			add_curse(s, "wound", s.discard_pile, 5)
			add_curse(s, "medicine", s.discard_pile)
		"phantom_summon":
			var id := String(intent.get("summon_id", "fist_phantom"))
			if id != "fist_phantom": spawn(s, index, id)
			if id == "fist_phantom":
				var pair := ["fist_phantom", "whip_phantom"]
				if living_of(s, index, "fist_phantom") > 0 and living_of(s, index, "whip_phantom") == 0: pair.reverse()
				for member in pair: spawn(s, index, member)
				for ally_index in s.allies.size(): add_debuff(s, ally_index, "tremor", "颤栗", "受到的伤害增加。", 2, {"damage_taken_mult":1.5, "stacks":2})
			if id == "shackle_phantom": add_curse(s, "shackle", s.draw_pile, 1, "deck")
			if id == "bruised_hand":
				for minion in s.enemies:
					if minion == e or int(minion.get("summoner", -1)) == index: s._add_guard(minion, s.ENEMY_RULES.scaled(e, 8, 0.3))
			e.summon_cursor = (int(intent.get("summon_slot", SUMMON_ROTATION.find(id))) + 1) % SUMMON_ROTATION.size()
			e.summon_due = false
		"disinfect":
			e.summon_due = true
			e.support_step = int(e.get("support_step", 0)) + 1
			for id in e.statuses.keys():
				if STATUS.is_debuff(e.statuses[id]): e.statuses.erase(id)
			for minion in s.enemies:
				if int(minion.get("summoner", -1)) == index and s._is_alive(minion): s.ENEMY_RULES.buff(minion, "phantom_power", "消毒水雾", 0.12, 5)
		"do_not_tell":
			e.summon_due = true
			e.support_step = int(e.get("support_step", 0)) + 1
			add_curse(s, "do_not_tell", s.draw_pile, 2, "deck")
			for minion in s.enemies:
				if int(minion.get("summoner", -1)) == index and s._is_alive(minion):
					var healed: Dictionary = e if minion.id in ["fist_phantom", "whip_phantom", "shackle_phantom"] else minion
					healed.hp = mini(int(healed.max_hp), int(healed.hp) + s.ENEMY_RULES.scaled(e, 5, 0.2))
			sync_shared_life(s, index)
		"hand_guard":
			e.statuses.hand_taunt = {"name":"求助嘲讽", "desc":"单体技能须先选中淤青之手；受到伤害降低20%。", "turns":2, "debuff":false, "damage_reduction":0.2}
		"compress":
			s.set_meta("box_compressions", int(s.get_meta("box_compressions", 0)) + 1)
			refresh_hand_limit(s)
		"suffocate": s.ENEMY_RULES.buff(e, "box_power", "窒息拥抱", 0.12, 5)
		"shackle_lock": s.set_meta("shackle_lock_round", s.round + 1)
	e.expansion_step = int(e.expansion_step) + 1
	s._add_log("%s · %s" % [e.name, intent.name], false)
	refresh_hand_limit(s)
	return true

static func incoming(s: Node, target: Dictionary, amount: int) -> int:
	if target.id == "report_card": return mini(amount, s.ENEMY_RULES.scaled(target, 16, 0.8))
	if target.id == "magician_master" and bool(s.get_meta("direct_player_attack", false)) and amount > 0:
		if s.fc.random_position(1) == 0:
			s._add_log("魔术大师闪避了这段直接攻击。", false)
			s.set_meta("magician_evaded", true)
			return 0
	return amount

static func update_summon_hits(unit: Dictionary) -> void:
	unit.statuses.summon_hits = {"name":"被攻击计数 %d" % int(unit.summon_hits), "desc":"每次受到直接攻击减少1；归零时消散。多段攻击逐段计算，护盾吸收也计入。", "turns":-1, "badge_text":str(unit.summon_hits), "debuff":false, "uncleansable":true, "category":"counter"}

static func sync_shared_life(s: Node, boss_index: int) -> void:
	if boss_index < 0 or boss_index >= s.enemies.size(): return
	var boss: Dictionary = s.enemies[boss_index]
	for minion in s.enemies:
		if int(minion.get("summoner", -1)) != boss_index or not minion.id in ["fist_phantom", "whip_phantom", "shackle_phantom"]: continue
		if int(minion.summon_hits) > 0:
			minion.max_hp = int(boss.max_hp)
			minion.hp = int(boss.hp)

static func after_damage(s: Node, target: Dictionary, result: Dictionary) -> void:
	if target.id == "bruised_hand" and target.intent.get("effect", "") == "hand_burst":
		target.intent.damage = maxi(0, int(target.hp))
	if target.id in ["fist_phantom", "whip_phantom", "shackle_phantom"] and int(target.hp) > 0 and (bool(s.get_meta("direct_player_attack", false)) or bool(s.get_meta("phantom_attack_hit", false))):
		target.summon_hits = int(target.summon_hits) - 1
		if int(target.summon_hits) <= 0:
			target.hp = 0
			s._add_log("%s 的被攻击计数归零，幻影消散。" % target.name, false)
		else:
			update_summon_hits(target)
	if target.id == "report_card" and int(target.hp) <= 0 and int(target.revivals) < 2:
		target.revivals = int(target.revivals) + 1
		target.hp = 1
		target.statuses.offstage = {"name":"无实体", "desc":"执行无实体意图后立即以部分生命复生；敌方净化可直接终结。", "turns":-1, "debuff":true}
		var index: int = s.enemies.find(target)
		if index >= 0: s._refresh_intents(index)
		s._add_log("成绩单化为灰烬，准备第%d次复生。" % int(target.revivals), false)
	if target.id == "quiet_hacker" and int(target.hp) <= 0:
		for card in target.get("stolen_cards", []):
			s.discard_pile.append(card)
			s._add_log("黑客退场：%s已归还弃牌堆。" % FightData.skill(String(card.skill_id)).get("name", "技能"), false)
		target.stolen_cards = []
	var shared_boss := int(target.get("summoner", -1))
	if target.id == "bullied_phantom": shared_boss = s.enemies.find(target)
	if shared_boss >= 0: sync_shared_life(s, shared_boss)
	if target.id in SUMMONS and int(target.hp) <= 0 and not bool(target.get("summon_counted", false)):
		target.summon_counted = true
		var boss := int(target.get("summoner", -1))
		if boss >= 0 and boss < s.enemies.size() and s._is_alive(s.enemies[boss]):
			var master: Dictionary = s.enemies[boss]
			master.assist_charge = mini(4, int(master.get("assist_charge", 0)) + 1)
			refresh(s, boss)
	if target.id == "claustrophobic_box" and int(target.hp) <= 0: refresh_hand_limit(s)

static func before_enemy(s: Node) -> void:
	for i in s.allies.size():
		var unit: Dictionary = s.allies[i]
		var pain := int(unit.statuses.get("pain_stacks", {}).get("stacks", 0))
		if pain > 0 and s._is_alive(unit): s.fc.lose_hp(i, pain)

static func after_status_tick(s: Node) -> void:
	for unit in s.allies:
		var extra := int(unit.get("isolation_extra", 0))
		if extra > 0 and not unit.statuses.has("isolation"):
			unit.max_hp = maxi(1, int(unit.max_hp) - extra)
			unit.hp = mini(int(unit.hp), int(unit.max_hp))
			unit.isolation_extra = 0

static func end_hand(s: Node) -> void:
	for card in s.hand:
		if card.skill_id == "ranking":
			for i in s.allies.size(): add_debuff(s, i, "tremor", "颤栗", "受到的伤害增加50%。", 1, {"damage_taken_mult":1.5})
		if card.skill_id == "do_not_tell":
			for e in s.enemies:
				if e.id in SUMMONS and s._is_alive(e): e.phantom_strength = int(e.get("phantom_strength", 0)) + 2

static func draw_allowed(s: Node, card: Dictionary) -> bool:
	var owner: int = s.caster_index(card)
	if owner < 0: return true
	if int(s.allies[owner].get("ban_draw_round", -1)) == s.round:
		s.discard_pile.append(card)
		return false
	return true

static func play_allowed(s: Node, card: Dictionary, index: int) -> bool:
	if s.hand.any(func(entry: Dictionary) -> bool: return bool(entry.get("trojan", false))):
		if not bool(card.get("trojan", false)): return false
	var owner: int = s.caster_index(card)
	if owner >= 0 and s.allies[owner].statuses.has("domination") and index != 0: return false
	if s.hand.any(func(entry: Dictionary) -> bool: return entry.skill_id == "shackle") and int(s.get_meta("cards_played_round", 0)) >= 4: return false
	if int(s.get_meta("shackle_lock_round", -1)) == s.round and not index in [0, int(s.hand.size() / 2), s.hand.size() - 1]: return false
	return true

static func use_medicine(s: Node, done: Callable) -> void:
	if s.hand.is_empty():
		done.call()
		return
	var options: Array = []
	for card in s.hand: options.append({"uid":int(card.uid), "label":FightData.skill(String(card.skill_id)).get("name", "技能"), "card":card})
	s.fc.ask("特效药：选择消耗的手牌", options, 1, 1, func(selected: Array) -> void:
		var card: Dictionary = selected[0].card
		var wound := String(card.skill_id) == "wound"
		s.fc.move_from_hand(card, s.fc.exhausted)
		if wound and not s.hand.is_empty():
			var second: Array = []
			for remaining in s.hand: second.append({"uid":int(remaining.uid), "label":FightData.skill(String(remaining.skill_id)).get("name", "技能"), "card":remaining})
			s.fc.ask("特效药：可再消耗一张", second, 0, 1, func(picked: Array) -> void:
				if not picked.is_empty(): s.fc.move_from_hand(picked[0].card, s.fc.exhausted)
				done.call()
			)
		else: done.call()
	)

static func can_resist(s: Node) -> bool:
	if not s.battle_active or s.phase != s.PLAYER_TURN or s.resolving_action or s.pending_turn_draw > 0 or not s.fc.choice.is_empty() or s.story_input_locked or not s.story_forced_skill.is_empty(): return false
	for enemy in s.enemies:
		if enemy.id == "bullied_phantom" and s._is_alive(enemy) and int(enemy.get("assist_charge", 0)) >= 4: return true
	return false

static func resist(s: Node) -> bool:
	if not can_resist(s) or s.phase != s.PLAYER_TURN or s.resolving_action: return false
	for boss in s.enemies:
		if boss.id == "bullied_phantom" and s._is_alive(boss): boss.assist_charge = 0
	for i in s.allies.size():
		if s._is_alive(s.allies[i]): s.allies[i].ult = s.ultimate_max(i)
	for enemy in s.enemies:
		if enemy.id in SUMMONS and s._is_alive(enemy):
			enemy.hp = 0
			enemy.summon_counted = true
	s._add_log("站出来，反抗！全队终结技充满，场上幻影消散；本体生命不变。", false)
	s._refresh_intents()
	s.state_changed.emit()
	return true
