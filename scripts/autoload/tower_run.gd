extends Node
## Standalone mode owns its persistence. No story save is read or written.
signal changed
const DATA := preload("res://scripts/data/tower_data.gd")
const REPORT_CRYPTO := preload("res://scripts/tower/report_crypto.gd")
const TRANSFER := preload("res://scripts/tower/save_transfer.gd")
const SAVE_ROOT := "user://tower"
const STATE_KEYS := ["fight_profiles", "fight_progression", "fight_accessories", "fight_equipment", "fight_health", "fight_loadouts", "fight_formation", "fight_attributes", "fight_unlocked_attributes", "inventories"]
var active := false
var data: Dictionary = {}
var error := ""
var notice := ""
var slot := 1
var save_root := SAVE_ROOT
var read_only := false
var pending: Dictionary = {}
var record: Dictionary = {}
var replay_mode := false
var replay_backup: Dictionary = {}
var lesson_backup: Dictionary = {}
var story_backup: Dictionary = {}
var old_read_only := false
var lesson_reading := false
var _started_ms := 0
var _report_integrity := "legacy"
var telemetry: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	telemetry = preload("res://scripts/tower/telemetry.gd").new()
	add_child(telemetry)
	FightSystem.player_action_started.connect(_action)
	FightSystem.battle_lost.connect(func() -> void:
		if active and not pending.is_empty(): FightSystem.last_reward = settle(false))

func enter() -> void:
	if active: return
	story_backup = GameState.to_dict().duplicate(true)
	old_read_only = SaveSystem.session_read_only
	SaveSystem.session_read_only = true
	active = true
	GameState.slot = -1
	GameState.phase = "night"
	GameState.location = "tower"
	GameState.story_flags = {}
	for id in DATA.HEROES: GameState.story_flags["fight.unlocked." + id] = true
	GameState.story_flags["fight.unlocked.red_pen"] = true
	GameState.story_flags["fight.unlocked.hang_on"] = true
	GameState.story_flags[FightSystem.FLAG_FORMATION_TUTORIAL_DONE] = true

func leave() -> void:
	if not active: return
	if FightSystem.battle_active: FightSystem.abandon_encounter()
	finish_lesson_session()
	if not data.is_empty(): save_game()
	active = false
	GameState.from_dict(story_backup)
	SaveSystem.session_read_only = old_read_only

func new_game(nickname: String, selected_slot: int = 1) -> void:
	enter()
	_report_integrity = "verified"
	slot = clampi(selected_slot, 1, 3)
	data = {"version":1, "run_id":str(Time.get_unix_time_from_system()) + "-" + str(randi()), "build":DATA.VERSION, "nickname":nickname.strip_edges().left(24), "seed":randi(), "highest":0, "shards":20, "clears":{}, "floor_checkpoints":{}, "defeated_enemies":{}, "lessons":{}, "health":{}, "shop":{}, "recovery_charges":0, "onboarding":{"status":"pending", "page":0, "tasks":{}}, "battles":[], "battle_count":0, "victories":0, "seconds":0.0}
	if String(data.nickname).is_empty(): data.nickname = "无名攀登者"
	for key in STATE_KEYS:
		if key == "fight_formation": GameState.set(key, ["", "", "", ""])
		elif key == "fight_unlocked_attributes": GameState.set(key, ["none", "math"])
		else: GameState.set(key, {})
	GameState.fight_attributes = {"zhoumingyuan":"none"}
	for id in DATA.HEROES:
		GameState.fight_profiles[id] = {"level":1, "xp":0}
		GameState.fight_loadouts[id] = FightData.default_loadout(id)
		data.health[id] = FightSystem.hero_max_hp(id)
		if id == "zhoumingyuan": data.health["zhoumingyuan@math"] = FightSystem.hero_max_hp(id)
	FightSystem.grant_consumable("battle_bandage", 3)
	pending.clear()
	record.clear()
	lesson_backup.clear()
	_remember_safe_state()
	notice = "先点一个出战位置，选好队员再出发。所有角色都从 Lv.1 开始。"
	save_game()

func cap() -> int:
	return 50 if not lesson_backup.is_empty() else DATA.cap(int(data.get("highest", 0)))

func rank() -> int:
	return mini(2, int(int(data.get("highest", 0)) / 20)) if lesson_backup.is_empty() else 2

func health(id: String, attribute: String = "") -> int:
	var key := health_key(id, attribute)
	return clampi(int(data.get("health", {}).get(key, FightSystem.hero_max_hp(id))), 0, FightSystem.hero_max_hp(id))

func _ensure_roster_health() -> void:
	# Newly added heroes/forms start healthy in older saves; recorded deaths stay dead.
	for id in DATA.HEROES:
		if not data.health.has(id): data.health[id] = FightSystem.hero_max_hp(id)
	if not data.health.has("zhoumingyuan@math"):
		data.health["zhoumingyuan@math"] = FightSystem.hero_max_hp("zhoumingyuan")

func health_key(id: String, attribute: String = "") -> String:
	if id != "zhoumingyuan": return id
	var form := attribute if not attribute.is_empty() else FightSystem.current_attribute(id)
	return "zhoumingyuan@math" if form == "math" else id

func _process(delta: float) -> void:
	if active and not data.is_empty(): data.seconds = float(data.get("seconds", 0)) + delta

func recovery_charges() -> int:
	return maxi(0, int(data.get("recovery_charges", 0)))

func onboarding_pending() -> bool:
	return not data.is_empty() and data.get("onboarding", {}).get("status", "legacy") == "pending"

func tutorial_task(id: String) -> void:
	if not onboarding_pending(): return
	data.onboarding.tasks[id] = true
	save_game()

func finish_onboarding(skipped: bool = false) -> void:
	if not data.has("onboarding"): data.onboarding = {"page":0, "tasks":{}}
	data.onboarding.status = "skipped" if skipped else "completed"
	save_game()

func _has_available_hero() -> bool:
	for id in DATA.HEROES:
		if health(id) > 0: return true
	if int(data.get("health", {}).get("zhoumingyuan@math", 0)) > 0: return true
	return false

func _remember_safe_state() -> void:
	if not _has_available_hero(): return
	var checkpoint := data.duplicate(true)
	for key in ["checkpoint", "battles", "in_progress"]: checkpoint.erase(key)
	checkpoint.state = capture_state()
	data.checkpoint = checkpoint

func _rewind_if_stranded() -> bool:
	if _has_available_hero() or not data.has("checkpoint"): return false
	var checkpoint: Dictionary = data.checkpoint.duplicate(true)
	# Keep the failed encounter and elapsed time in the test journal.
	var audit := {"battles":data.battles, "battle_count":data.battle_count, "victories":data.victories, "seconds":data.seconds}
	data.merge(checkpoint, true)
	data.merge(audit, true)
	apply_state(checkpoint.state)
	notice += "\n已经没人能出战，已回溯到还有队员能战斗的存档（最高 %d 层）。生命、资源和进度也已还原。" % int(data.highest)
	return true

func formation_warning() -> String:
	if FightSystem.formation().is_empty(): return "队伍里还没有人。先点一个出战位置，至少选一名队员。"
	for id in FightSystem.formation():
		if id in ["zhoumingyuan", "xumingming", "suwanqing"]: return ""
	return "这支队伍缺少擅长攻击的角色，可能会打得比较慢。可以试着带上周明远、徐明明或苏婉青。"

func start_floor(floor_number: int, navigate: bool = true) -> bool:
	error = ""
	if data.is_empty() or FightSystem.battle_active or not pending.is_empty(): return false
	if onboarding_pending():
		error = "请先完成或跳过新手教程。"
		return false
	if floor_number < 1 or floor_number > int(data.highest) + 1:
		error = "只能挑战下一层或重打已通关层。"
		return false
	if FightSystem.formation().is_empty():
		error = formation_warning()
		return false
	if data.clears.has(str(floor_number)):
		return replay_floor(floor_number, navigate)
	for id in FightSystem.formation():
		if health(id) <= 0:
			error = "%s已阵亡。可以用一次恢复将其复活，或先换人上场。" % FightData.hero(id).name
			return false
	_remember_floor_checkpoint(floor_number)
	_remember_safe_state()
	var floor_info := DATA.floor_data(floor_number, int(data.seed))
	pending = floor_info.duplicate(true)
	pending.mode = "tower"
	pending.wave_index = 0
	pending.wave_history = []
	pending.initial_party = FightSystem.formation().duplicate()
	pending.start_health = data.health.duplicate(true)
	return _start(pending.waves[0], floor_info.level, [], navigate)

func replay_floor(floor_number: int, navigate: bool = true) -> bool:
	error = ""
	if data.is_empty() or FightSystem.battle_active or not pending.is_empty() or not data.clears.has(str(floor_number)):
		error = "只能重演已经通关的楼层。"
		return false
	if floor_number < 1 or floor_number > int(data.highest):
		error = "只能重演当前最高层以内的楼层。"
		return false
	if FightSystem.formation().is_empty():
		error = formation_warning()
		return false
	replay_mode = true
	replay_backup = {"data":data.duplicate(true), "state":capture_state()}
	# Replays are a training run: every roster member is available at full HP.
	for id in DATA.HEROES:
		data.health[id] = FightSystem.hero_max_hp(id)
		if id == "zhoumingyuan": data.health["zhoumingyuan@math"] = FightSystem.hero_max_hp(id)
	var floor_info := DATA.floor_data(floor_number, int(data.seed))
	pending = floor_info.duplicate(true)
	pending.mode = "replay"
	pending.replay = true
	pending.wave_index = 0
	pending.wave_history = []
	pending.initial_party = FightSystem.formation().duplicate()
	pending.start_health = data.health.duplicate(true)
	pending.xp = DATA.replay_xp(floor_number)
	notice = "重演第 %d 层：全员满血出战，只获得经验。层数越高，经验越多；不会增加通关进度或其他资源。" % floor_number
	return _start(pending.waves[0], floor_info.level, [], navigate)

func _remember_floor_checkpoint(floor_number: int) -> void:
	if data.clears.has(str(floor_number)): return
	var checkpoints: Dictionary = data.get("floor_checkpoints", {})
	if checkpoints.has(str(floor_number)): return
	var before := data.duplicate(true)
	before.erase("floor_checkpoints")
	before.erase("in_progress")
	checkpoints[str(floor_number)] = {"data":before, "state":capture_state()}
	data.floor_checkpoints = checkpoints

func enemy_defeated(id: String) -> bool:
	if active and not data.is_empty(): return bool(data.get("defeated_enemies", {}).get(String(id), false))
	return true

func register_enemy_defeats(units: Array = []) -> void:
	if not active or data.is_empty():
		for unit in units:
			var story_id := String(unit.get("id", "")) if unit is Dictionary else String(unit)
			if not story_id.is_empty(): GameState.set_flag("bestiary.defeated." + story_id, true)
		return
	var defeated: Dictionary = data.get("defeated_enemies", {})
	for unit in units:
		var id := String(unit.get("id", "")) if unit is Dictionary else String(unit)
		if not id.is_empty(): defeated[id] = true
	data.defeated_enemies = defeated

func reset_to_floor(floor_number: int) -> bool:
	error = ""
	if data.is_empty() or FightSystem.battle_active or not pending.is_empty() or not lesson_backup.is_empty() or replay_mode:
		error = "当前无法重置爬塔进度。"
		return false
	var checkpoints: Dictionary = data.get("floor_checkpoints", {})
	var key := str(floor_number)
	if not checkpoints.has(key) or not data.clears.has(key):
		error = "该层没有可用的通关前存档。"
		return false
	var snapshot: Dictionary = checkpoints[key]
	var restored: Dictionary = snapshot.get("data", {}).duplicate(true)
	var retained: Dictionary = {}
	for checkpoint_key in checkpoints:
		if int(checkpoint_key) < floor_number: retained[checkpoint_key] = checkpoints[checkpoint_key]
	restored.floor_checkpoints = retained
	restored.clears = restored.get("clears", {}).duplicate(true)
	for clear_key in restored.clears.keys():
		if int(clear_key) >= floor_number: restored.clears.erase(clear_key)
	restored.highest = mini(int(restored.get("highest", 0)), floor_number - 1)
	data = restored
	apply_state(snapshot.get("state", {}))
	pending.clear()
	replay_mode = false
	replay_backup.clear()
	notice = "已重置到第 %d 层挑战前。之后获得的等级、经验、遗物、碎片、恢复次数和层数进度均已回退。" % floor_number
	_remember_safe_state()
	save_game()
	changed.emit()
	return true

func has_next_wave() -> bool:
	return pending.get("mode", "") in ["tower", "replay"] and int(pending.get("wave_index", 0)) + 1 < pending.get("waves", []).size()

func complete_wave() -> Dictionary:
	# Only a completed floor awards XP, currency, rest charges and a shop visit.
	for unit in FightSystem.allies:
		data.health[health_key(String(unit.id), String(unit.attribute))] = maxi(0, int(unit.hp)) if not unit.get("dead", false) else 0
	register_enemy_defeats(FightSystem.enemies)
	var entry := record.duplicate(true)
	entry.merge({"outcome":"wave_won", "rounds":FightSystem.round, "end_party":FightSystem.allies.duplicate(true), "duration_ms":Time.get_ticks_msec() - _started_ms, "log":FightSystem.log_lines.slice(-300)})
	pending.wave_history.append(entry)
	pending.wave_ready = true
	return {"tower":true, "replay":pending.mode == "replay", "wave_clear":true, "floor":pending.floor, "next_wave":int(pending.wave_index) + 2, "wave_count":pending.waves.size(), "xp":0, "item_count":0, "growth":[]}

func continue_wave(navigate: bool = true) -> bool:
	if FightSystem.battle_active or not has_next_wave() or not pending.get("wave_ready", false): return false
	var party: Array = []
	for unit in FightSystem.allies:
		if not unit.get("dead", false) and int(unit.hp) > 0:
			party.append(String(unit.id))
			# Brief intermission; fallen heroes stay out until the floor ends.
			data.health[health_key(String(unit.id), String(unit.attribute))] = mini(int(unit.max_hp), int(unit.hp) + ceili(float(unit.max_hp) * 0.2))
	if party.is_empty():
		error = "没有能继续连战的队员，请返回尖塔恢复。"
		return false
	pending.wave_index = int(pending.wave_index) + 1
	pending.wave_ready = false
	return _start(pending.waves[int(pending.wave_index)], int(pending.level), party, navigate)

func start_lesson(hero: String, final_exam: bool, navigate: bool = true) -> bool:
	error = ""
	if FightSystem.battle_active or not pending.is_empty() or not DATA.LESSONS.has(hero): return false
	var key := hero + ("_final" if final_exam else "_basic")
	if final_exam and not data.lessons.has(hero + "_basic"):
		error = "请先完成该角色的机制练习。"
		return false
	lesson_backup = capture_state()
	var lesson: Dictionary = DATA.LESSONS[hero]
	var team: Array = lesson.team.duplicate()
	GameState.fight_equipment = {}
	GameState.fight_accessories = {}
	GameState.fight_attributes = {"zhoumingyuan":"none"}
	GameState.inventories = {}
	for id in DATA.HEROES:
		GameState.fight_profiles[id] = {"level":40, "xp":0}
		GameState.fight_loadouts[id] = DATA.LESSONS[id].deck.duplicate()
	GameState.fight_formation = team
	pending = {"mode":"lesson", "hero":hero, "lesson":key, "final":final_exam, "floor":0, "xp":0, "shards":40 if final_exam else 20, "rest":false}
	var ids: Array = ["biting_book", "cupid"] if final_exam else ["paper_large"]
	return _start(ids, 12 if final_exam else 5, team, navigate)

func _start(ids: Array, level: int, party: Array, navigate: bool) -> bool:
	var levels: Array = []
	for _id in ids: levels.append(level)
	FightSystem.return_location = "tower"
	# All waves belong to one floor attempt: keep the snapshot from its start.
	if not pending.has("battle_start_data"):
		var before: Dictionary = data.duplicate(true)
		before.erase("in_progress")
		before.erase("retry_encounter")
		pending.battle_start_data = before
		pending.battle_start_state = capture_state()
	# Only advancing the formal run closes the milestone shop. Lessons and
	# replays preserve its exact stock, purchases and refresh count.
	if pending.mode == "tower": data.shop_visit = false
	# Save an interruption marker BEFORE combat. Reloading never grants a win.
	data.in_progress = {"mode":pending.mode, "floor":pending.floor, "health":pending.battle_start_data.get("health", pending.get("start_health", data.health)).duplicate(true)}
	data.in_progress.battle_data = pending.battle_start_data.duplicate(true)
	data.in_progress.battle_state = pending.battle_start_state.duplicate(true)
	if pending.mode == "replay":
		data.in_progress.replay_data = replay_backup.get("data", {}).duplicate(true)
		data.in_progress.replay_state = replay_backup.get("state", {}).duplicate(true)
	save_game()
	if not FightSystem.begin_encounter(ids, party, levels, false, false, "", true):
		error = FightSystem.last_configuration_error
		_restore_battle_start_state()
		pending.clear()
		data.erase("in_progress")
		finish_lesson_session()
		save_game()
		return false
	if pending.mode in ["tower", "replay"]:
		for unit in FightSystem.allies: unit.hp = health(String(unit.id))
	_started_ms = Time.get_ticks_msec()
	record = {"run_id":data.get("run_id", "legacy"), "build":DATA.VERSION, "mode":pending.mode, "floor":pending.floor, "lesson":pending.get("lesson", ""), "started_at":Time.get_datetime_string_from_system(true), "party":FightSystem.allies.duplicate(true), "loadouts":GameState.fight_loadouts.duplicate(true), "enemies":FightSystem.enemies.duplicate(true), "actions":[], "damage":{}, "items":[], "truncated":false, "key_done":false, "follow_done":false, "partner_done":false}
	FightSystem.state_changed.emit()
	if navigate: SceneRouter.go_to("fight")
	return true

func _action(index: int, skill: String) -> void:
	if not active or record.is_empty() or index < 0 or index >= FightSystem.allies.size(): return
	var id := String(FightSystem.allies[index].id)
	if record.actions.size() < 2000:
		record.actions.append({"round":FightSystem.round, "hero":id, "skill":skill, "energy":FightSystem.action_points, "target":int(FightSystem.get_meta("tower_target", -1)), "energy_spent":int(FightSystem.get_meta("tower_spent", 0))})
	else: record.truncated = true
	if pending.get("mode") == "lesson":
		var lesson: Dictionary = DATA.LESSONS[pending.hero]
		if id == pending.hero and skill == lesson.key:
			record.key_done = true
			record.key_target = int(FightSystem.get_meta("tower_target", -1))
		elif record.key_done and skill == lesson.follow: record.follow_done = true
		if record.key_done and id != pending.hero and skill not in ["pursuit", "ultimate"]: record.partner_done = true

func damage_event(target: Dictionary, hp_damage: int, guard_damage: int) -> void:
	if record.is_empty(): return
	var side := "allies" if target.has("downed") else "enemies"
	var key := side + ":" + String(target.id)
	var total: Dictionary = record.damage.get(key, {"hp":0, "guard":0})
	total.hp += maxi(0, hp_damage)
	total.guard += maxi(0, guard_damage)
	record.damage[key] = total

func lesson_complete() -> bool:
	return bool(record.get("key_done", false)) and bool(record.get("follow_done", false)) and (not bool(pending.get("final", false)) or bool(record.get("partner_done", false)))

func lesson_stage() -> int:
	if pending.get("mode") != "lesson": return -1
	if not record.get("key_done", false): return 0
	if not record.get("follow_done", false): return 1
	if pending.get("final", false) and not record.get("partner_done", false): return 2
	return 3

func lesson_required_card(card: Dictionary) -> bool:
	var stage := lesson_stage()
	if stage < 0 or stage == 3: return true
	var lesson: Dictionary = DATA.LESSONS[pending.hero]
	if stage == 0: return card.caster_id == pending.hero and card.skill_id == lesson.key
	if stage == 1: return card.skill_id == lesson.follow
	return card.caster_id != pending.hero

func lesson_target_allowed(skill: String, target: int) -> bool:
	if pending.get("hero") == "suwanqing" and lesson_stage() == 1 and skill == "D02":
		return target == int(record.get("key_target", -1))
	return true

func order_lesson_cards(cards: Array) -> void:
	# Stable order for opening draw, subsequent draws AND discard recycling.
	# No UID/global RNG dependency; one copy of each action precedes its duplicate.
	if pending.get("mode") != "lesson": return
	var lesson: Dictionary = DATA.LESSONS[pending.hero]
	var ordered: Array = []
	var wanted := [String(lesson.key), String(lesson.follow)]
	for skill in wanted:
		for card in cards:
			if card.skill_id == skill and not ordered.has(card):
				ordered.append(card)
				break
	for hero in lesson.team:
		for skill in DATA.LESSONS[hero].deck:
			for card in cards:
				if card.caster_id == hero and card.skill_id == skill and not ordered.has(card):
					ordered.append(card)
					break
	for card in cards:
		if not ordered.has(card): ordered.append(card)
	ordered.reverse()
	cards.assign(ordered)

func shop_available() -> bool:
	return bool(data.get("shop_visit", false)) and not data.get("shop", {}).is_empty() and not FightSystem.battle_active

func lesson_hint() -> String:
	if pending.get("mode") != "lesson": return ""
	var lesson: Dictionary = DATA.LESSONS[pending.hero]
	return "%s：先用「%s」%s → 再用「%s」%s%s" % [FightData.hero(pending.hero).name, FightData.skill(lesson.key).name, " ✓" if record.get("key_done", false) else "", FightData.skill(lesson.follow).name, " ✓" if record.get("follow_done", false) else "", " → 队友行动" + (" ✓" if record.get("partner_done", false) else "") if pending.get("final", false) else ""]

func settle(won: bool, abandoned: bool = false) -> Dictionary:
	if pending.is_empty(): return {}
	var result := {"tower":true, "replay":pending.mode == "replay", "xp":0, "money":0, "item":"ink_fragment", "item_count":0, "growth":[], "floor":pending.floor}
	var lesson: bool = pending.mode == "lesson"
	var replay: bool = pending.mode == "replay"
	var qualified: bool = won and (not lesson or lesson_complete())
	if not lesson and (won or replay):
		for unit in FightSystem.allies:
			var key := health_key(String(unit.id), String(unit.attribute))
			data.health[key] = maxi(0, int(unit.hp)) if not unit.get("dead", false) else 0
	if won and not lesson:
		register_enemy_defeats(FightSystem.enemies)
	if qualified:
		var reward_allowed: bool = not lesson or not data.lessons.has(pending.lesson)
		if replay:
			result.xp = int(pending.get("xp", DATA.replay_xp(int(pending.floor))))
			var replay_defeated: Dictionary = data.get("defeated_enemies", {}).duplicate(true)
			var participants: Array = pending.get("initial_party", FightSystem.allies.map(func(unit): return unit.id))
			for id in participants:
				var before_level := FightProgression.hero_level(String(id))
				var profile := FightProgression.grant_xp(String(id), result.xp)
				result.growth.append({"id":id, "name":FightData.hero(id).name, "before_level":before_level, "level":profile.level, "xp":profile.xp, "gained":result.xp})
			var replay_profiles: Dictionary = GameState.fight_profiles.duplicate(true)
			var audit_battles: Array = data.battles.duplicate(true)
			var audit_count := int(data.battle_count)
			var audit_seconds := float(data.seconds)
			var replay_elapsed := audit_seconds - float(replay_backup.get("data", {}).get("seconds", audit_seconds))
			data = replay_backup.get("data", data).duplicate(true)
			var restored_defeated: Dictionary = data.get("defeated_enemies", {}).duplicate(true)
			for enemy_id in replay_defeated: restored_defeated[enemy_id] = true
			data.defeated_enemies = restored_defeated
			apply_state(replay_backup.get("state", {}))
			GameState.fight_profiles = replay_profiles
			data.seconds = float(data.seconds) + maxi(0.0, replay_elapsed)
			# The replay is recorded for statistics, but its only gameplay reward is XP.
			data.battles = audit_battles
			data.battle_count = audit_count
			notice = "重演第 %d 层完成，每位参战角色获得 %d 经验。重演没有其他通关奖励，当前等级上限为 Lv.%d。" % [pending.floor, result.xp, cap()]
		elif not lesson:
			var first_clear: bool = not data.clears.has(str(pending.floor))
			data.highest = maxi(int(data.highest), int(pending.floor))
			data.clears[str(pending.floor)] = int(data.clears.get(str(pending.floor), 0)) + 1
			result.xp = pending.xp
			var participants: Array = pending.get("initial_party", FightSystem.allies.map(func(unit): return unit.id))
			for id in participants:
				var before := FightProgression.hero_level(id)
				var old_max := FightSystem.hero_max_hp(id)
				var profile := FightProgression.grant_xp(id, result.xp)
				var key := health_key(String(id))
				if int(data.health.get(key, 0)) > 0:
					data.health[key] = mini(FightSystem.hero_max_hp(id), int(data.health[key]) + maxi(0, FightSystem.hero_max_hp(id) - old_max))
				result.growth.append({"id":id, "name":FightData.hero(id).name, "before_level":before, "level":profile.level, "xp":profile.xp, "gained":result.xp})
			result.recovery = DATA.recovery_reward(int(pending.floor)) if first_clear else 0
			data.recovery_charges = recovery_charges() + int(result.recovery)
			if int(pending.floor) % 5 == 0: open_shop(int(pending.floor))
		if reward_allowed and not replay:
			data.shards += int(pending.shards)
			result.item_count = pending.shards
			if lesson:
				data.lessons[pending.lesson] = true
				if pending.hero == "zhoumingyuan" and not pending.final: tutorial_task("battle")
				if pending.final:
					var weapon: String = DATA.WEAPONS[pending.hero]
					lesson_backup.fight_accessories[weapon] = ""
					result.weapon = weapon
					if pending.hero == "zhoumingyuan": lesson_backup.fight_accessories["proof_compass_math"] = ""
		if not replay: data.victories += 1
	elif replay:
		# Failed or abandoned replays never alter the formal run state.
		var audit_battles: Array = data.battles.duplicate(true)
		var replay_defeated: Dictionary = data.get("defeated_enemies", {}).duplicate(true)
		var audit_count := int(data.battle_count)
		var audit_seconds := float(data.seconds)
		var replay_elapsed := audit_seconds - float(replay_backup.get("data", {}).get("seconds", audit_seconds))
		data = replay_backup.get("data", data).duplicate(true)
		var restored_defeated: Dictionary = data.get("defeated_enemies", {}).duplicate(true)
		for enemy_id in replay_defeated: restored_defeated[enemy_id] = true
		data.defeated_enemies = restored_defeated
		apply_state(replay_backup.get("state", {}))
		data.seconds = float(data.seconds) + maxi(0.0, replay_elapsed)
		data.battles = audit_battles
		data.battle_count = audit_count
		notice = "这次重演没有打完，已恢复到重演前的状态，没有获得经验或通关奖励。"
	elif not lesson:
		_restore_battle_start_state()
		result.rewound = true
		result.chain_restarted = pending.get("waves", []).size() > 1
		notice = "战败了，已回溯到开战前，消耗的道具也已返还。本次没有奖励，可以调整后再试。" if not abandoned else "已撤退并回溯到开战前，消耗的道具也已返还。本次没有奖励。"
		if result.chain_restarted: notice = "连战没有打完，已回溯到本层第一场开战前，消耗的道具已返还。下次从第一场重打，本次没有通关奖励。"
	if won and lesson and not qualified: notice = "打赢了，但还没完成教学要求。再试一次，按提示完成操作并获胜，就能领取奖励。"
	elif qualified and lesson: notice = "教学完成！专武已获得，可以去「角色 → 专武 / 遗物」装备。" if pending.final else "机制练习完成，已解锁多人实战。"
	elif qualified and not replay: notice = "第 %d 层通关，获得 %d 墨痕碎片。%s" % [pending.floor, result.item_count, "恢复次数 +%d（已储存 %d 次）。" % [result.get("recovery", 0), recovery_charges()] if int(result.get("recovery", 0)) > 0 else ""]
	elif lesson: notice = "已记录本次撤退。" if abandoned else "本次教学结束。返回尖塔后，会恢复你原来的队伍。"
	if not record.is_empty():
		record.merge({"outcome":"abandoned" if abandoned else "won" if won else "lost", "qualified":qualified, "rounds":FightSystem.round, "duration_ms":Time.get_ticks_msec() - _started_ms, "end_party":FightSystem.allies.duplicate(true), "reward":result, "log":FightSystem.log_lines.slice(-300)})
		if not pending.get("wave_history", []).is_empty(): record.waves = pending.wave_history.duplicate(true)
		data.battles.append(record.duplicate(true))
		data.battle_count += 1
		# Keep complete history in a JSONL journal; bound the active save to 100 fights.
		append_journal(record)
		if data.battles.size() > 100: data.battles.pop_front()
	record.clear()
	pending.clear()
	replay_mode = false
	replay_backup.clear()
	data.erase("in_progress")
	if won and not lesson and not replay: _rewind_if_stranded()
	save_game()
	return result

func finish_lesson_session() -> void:
	lesson_reading = false
	if lesson_backup.is_empty(): return
	apply_state(lesson_backup)
	lesson_backup.clear()
	save_game()

func cancel_loading_battle() -> void:
	# No combat was shown: restore the entry snapshot without awarding or recording a loss.
	_restore_battle_start_state()
	if not replay_backup.is_empty():
		data = replay_backup.get("data", data).duplicate(true)
		apply_state(replay_backup.get("state", {}))
		replay_backup.clear()
		replay_mode = false
	pending.clear()
	record.clear()
	FightSystem.abandon_encounter()
	finish_lesson_session()
	data.erase("in_progress")
	error = "战斗资源未能加载，请重新进入。"
	notice = error
	save_game()
	changed.emit()

func _restore_battle_start_state() -> void:
	var snapshot_data: Dictionary = pending.get("battle_start_data", {})
	var snapshot_state: Dictionary = pending.get("battle_start_state", {})
	if snapshot_data.is_empty(): return
	var battles: Array = data.get("battles", []).duplicate(true)
	var battle_count := int(data.get("battle_count", 0))
	var victories := int(data.get("victories", 0))
	var seconds := float(data.get("seconds", 0.0))
	data = snapshot_data.duplicate(true)
	data.battles = battles
	data.battle_count = battle_count
	data.victories = victories
	data.seconds = maxi(seconds, float(data.get("seconds", 0.0)))
	apply_state(snapshot_state)

func rest(id: String = "", attribute: String = "") -> bool:
	error = ""
	if FightSystem.battle_active or not pending.is_empty() or not lesson_backup.is_empty() or recovery_charges() <= 0 or not id in DATA.HEROES: return false
	var key := health_key(id, attribute)
	var hp := health(id, attribute)
	if hp >= FightSystem.hero_max_hp(id):
		error = "该角色已满血，无需消耗次数。"
		return false
	var revived := hp <= 0
	data.health[key] = FightSystem.hero_max_hp(id)
	data.recovery_charges = recovery_charges() - 1
	notice = "%s已%s，剩余 %d 次恢复。" % [FightData.hero(id).name, "满血复活" if revived else "回满生命", recovery_charges()]
	save_game()
	changed.emit()
	return true

func open_shop(floor_number: int) -> void:
	# Revisiting a milestone never resets its purchases or refresh allowance.
	var shops: Dictionary = data.get("shops", {})
	var key := str(floor_number)
	if not shops.has(key): shops[key] = {"floor":floor_number, "refreshes":0, "stock":roll_stock(floor_number, 0)}
	data.shops = shops
	data.shop = shops[key]
	data.shop_visit = true
	data.shop_arrival = true

func roll_stock(floor_number: int, refresh_count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.seed) + floor_number * 997 + refresh_count * 7919
	var weights := DATA.rarity_weights(floor_number)
	var stock: Array = []
	var chosen: Array = []
	for i in 6:
		var roll := rng.randf()
		var quality := "common" if roll < weights[0] else "uncommon" if roll < weights[0] + weights[1] else "rare"
		var catalog: Dictionary = FightEquipmentData.ACCESSORIES if i < 3 else FightEquipmentData.CONSUMABLES
		var pool: Array = []
		for id in catalog:
			if catalog[id].get("exclusive", "") != "" or chosen.has(id): continue
			if i < 3 and GameState.fight_accessories.has(id): continue
			if catalog[id].rarity == quality: pool.append(id)
		if pool.is_empty():
			for id in FightEquipmentData.CONSUMABLES:
				if not chosen.has(id) and FightEquipmentData.CONSUMABLES[id].rarity == quality: pool.append(id)
		if pool.is_empty(): continue
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		chosen.append(id)
		stock.append({"id":id, "price":DATA.price(id), "sold":false})
	return stock

func refresh_shop() -> bool:
	error = ""
	if not shop_available(): error = "每过5层，阿姨才会开店。挑战下一层后商店才会关闭，教学和重演不影响。"; return false
	var shop: Dictionary = data.shop
	var cost := 4 + int(shop.refreshes) * 3
	if int(shop.refreshes) >= 2: error = "本层商店的两次刷新机会已用完。"; return false
	if int(data.shards) < cost: error = "墨痕碎片不足。"; return false
	data.shards -= cost
	shop.refreshes += 1
	shop.stock = roll_stock(shop.floor, shop.refreshes)
	data.shops[str(shop.floor)] = shop
	save_game()
	return true

func buy(index: int) -> bool:
	error = ""
	if not shop_available(): error = "每过5层，阿姨才会开店。挑战下一层后商店才会关闭，教学和重演不影响。"; return false
	var stock: Array = data.shop.stock
	if index < 0 or index >= stock.size() or stock[index].sold: return false
	var offer: Dictionary = stock[index]
	if int(data.shards) < int(offer.price): error = "墨痕碎片不足。"; return false
	var id := String(offer.id)
	if FightEquipmentData.ACCESSORIES.has(id):
		if GameState.fight_accessories.has(id): error = "已经拥有这件遗物。"; return false
		GameState.fight_accessories[id] = ""
	elif FightSystem.grant_consumable(id, 1) != 1:
		error = "补给背包已满。"; return false
	data.shards -= int(offer.price)
	offer.sold = true
	data.shops[str(data.shop.floor)] = data.shop
	save_game()
	return true

func capture_state() -> Dictionary:
	var result: Dictionary = {}
	for key in STATE_KEYS: result[key] = GameState.get(key).duplicate(true)
	return result

func apply_state(state: Dictionary) -> void:
	for key in STATE_KEYS:
		if state.has(key): GameState.set(key, state[key].duplicate(true))

func path_for(selected_slot: int) -> String:
	return "%s/slot_%d.json" % [save_root, selected_slot]

func save_game() -> bool:
	if read_only or data.is_empty(): return false
	# Creation build and per-battle build retain their original provenance.
	data.last_played_build = DATA.VERSION
	data.state = capture_state() if lesson_backup.is_empty() else lesson_backup.duplicate(true)
	data.saved_at = Time.get_datetime_string_from_system(true)
	var sealed := REPORT_CRYPTO.seal({"data":data, "integrity":_report_integrity}, "save")
	if sealed.is_empty(): error = "存档校验密钥未配置，无法保存。"; return false
	DirAccess.make_dir_recursive_absolute(save_root)
	var path := path_for(slot)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: error = "存档写入失败：" + error_string(FileAccess.get_open_error()); return false
	file.store_string(JSON.stringify(sealed))
	file.flush()
	if file.get_error() != OK: file.close(); error = "存档写入失败。"; return false
	file.close()
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK: error = "存档备份失败。"; return false
	var code := DirAccess.rename_absolute(path + ".tmp", path)
	if code != OK: error = "存档替换失败：" + error_string(code); return false
	if is_instance_valid(telemetry): telemetry.capture(data)
	return true

func read_save(selected_slot: int) -> Dictionary:
	for suffix in ["", ".bak"]:
		var path: String = path_for(selected_slot) + suffix
		if not FileAccess.file_exists(path): continue
		var parsed := TRANSFER.decode_save(TRANSFER.read_bounded(path))
		if not parsed.is_empty(): return parsed
	return {}

func load_game(selected_slot: int) -> bool:
	var loaded := read_save(selected_slot)
	if loaded.is_empty(): error = "这里没有可读取的存档，备份也无法读取。"; return false
	var prior_build := String(loaded.get("last_played_build", loaded.get("build", "")))
	if not read_only and prior_build != DATA.VERSION:
		if TRANSFER.backup_slot(selected_slot, "before-upgrade").is_empty():
			error = "升级前备份失败，旧存档保持不变，请检查保存目录权限。"
			return false
		loaded.upgraded_from = prior_build
		notice = "已自动接续旧版存档；升级前的存档与战斗记录已备份。覆盖或重命名程序都不会改变存档位置。"
	enter()
	slot = selected_slot
	data = loaded
	_report_integrity = String(data.get("_loaded_integrity", "legacy"))
	data.erase("_loaded_integrity")
	# Old saves keep one unused rest as one charge; cleared floors cannot be farmed.
	if not data.has("recovery_charges"): data.recovery_charges = 1 if data.get("rest_available", false) else 0
	if not data.has("defeated_enemies"): data.defeated_enemies = {}
	if not data.has("floor_checkpoints"): data.floor_checkpoints = {}
	data.erase("rest_available")
	data.erase("recover_at")
	data.erase("retry_encounter")
	pending.clear()
	record.clear()
	lesson_backup.clear()
	replay_mode = false
	replay_backup.clear()
	apply_state(data.state)
	if data.has("in_progress"):
		var interrupted: Dictionary = data.in_progress.duplicate(true)
		var was_replay := String(interrupted.get("mode", "")) == "replay"
		var interrupted_data: Dictionary = interrupted.get("battle_data", {}).duplicate(true)
		var interrupted_state: Dictionary = interrupted.get("battle_state", {}).duplicate(true)
		if was_replay and interrupted.get("replay_data") is Dictionary:
			var restored_replay: Dictionary = interrupted.replay_data.duplicate(true)
			var restored_replay_state: Dictionary = interrupted.get("replay_state", {}).duplicate(true)
			data = restored_replay
			apply_state(restored_replay_state)
			notice = "上次重演没有打完，已恢复到重演前的状态，没有获得经验或通关奖励。"
		if not was_replay:
			if String(interrupted.get("mode", "")) == "tower" and not interrupted_data.is_empty():
				var audit_battles: Array = data.battles.duplicate(true)
				var audit_count := int(data.battle_count)
				var audit_victories := int(data.victories)
				var audit_seconds := float(data.seconds)
				data = interrupted_data
				data.battles = audit_battles
				data.battle_count = audit_count
				data.victories = audit_victories
				data.seconds = maxi(audit_seconds, float(data.get("seconds", 0.0)))
				apply_state(interrupted_state)
				data.erase("retry_encounter")
			if interrupted.has("health"): data.health = interrupted.health.duplicate(true)
			notice = "上次战斗中断，已回到战前状态；没有结算奖励。"
		var interrupted_entry := {"run_id":data.get("run_id", "legacy"), "outcome":"interrupted", "mode":interrupted.get("mode", "tower"), "floor":interrupted.get("floor", 0), "build":DATA.VERSION}
		data.battles.append(interrupted_entry)
		append_journal(interrupted_entry)
		data.battle_count += 1
		data.erase("in_progress")
	_ensure_roster_health()
	return true if read_only else save_game()

func append_journal(entry: Dictionary) -> void:
	if read_only: return
	var sealed := REPORT_CRYPTO.seal(entry, "battle")
	if sealed.is_empty(): error = "战斗记录校验密钥未配置。"; return
	var path := "%s/slot_%d_battles.jsonl" % [save_root, slot]
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(JSON.stringify(sealed))
		file.flush()
		if file.get_error() != OK: error = "战斗记录写入失败。"
	else: error = "战斗记录无法写入。"

func export_report(path: String) -> bool:
	error = ""
	if data.is_empty(): error = "还没有可导出的存档。"; return false
	var snapshot := data.duplicate(true)
	snapshot.state = capture_state() if lesson_backup.is_empty() else lesson_backup.duplicate(true)
	var payload := {"schema":"school-tower-report-v2", "integrity":_report_integrity, "build":DATA.VERSION, "nickname":data.nickname, "highest_floor":data.highest, "battle_count":data.battle_count, "play_seconds":data.seconds, "save":snapshot, "history":[]}
	var journal := "%s/slot_%d_battles.jsonl" % [save_root, slot]
	if FileAccess.file_exists(journal):
		var reader := FileAccess.open(journal, FileAccess.READ)
		if reader == null: error = "战斗记录无法读取，未导出。"; return false
		while not reader.eof_reached():
			var line := reader.get_line().strip_edges()
			if line.is_empty(): continue
			var entry: Variant = JSON.parse_string(line)
			if not entry is Dictionary: error = "战斗记录已损坏，未导出。"; return false
			var authenticated: bool = entry.get("schema") == REPORT_CRYPTO.SCHEMA
			if authenticated:
				entry = REPORT_CRYPTO.open(entry, "battle")
				if entry.is_empty(): error = "战斗记录校验失败，可能已被修改，未导出。"; return false
			if entry.get("run_id", "legacy") == data.get("run_id", "legacy"):
				if not authenticated: payload.integrity = "legacy"
				payload.history.append(entry)
	if payload.integrity == "verified" and payload.history.size() != int(data.battle_count):
		# Backup recovery / floor reset can rewind counters without rewinding the journal.
		# Keep the report useful for analysis, but never certify incomplete history.
		payload.integrity = "legacy"
	var sealed := REPORT_CRYPTO.seal(payload, "report")
	if sealed.is_empty(): error = "报告加密密钥未配置，无法导出。"; return false
	var content := JSON.stringify(sealed)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: error = "导出失败：" + error_string(FileAccess.get_open_error()); return false
	file.store_string(content)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: error = "报告写入失败。"; return false
	return true
