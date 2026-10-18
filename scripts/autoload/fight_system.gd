extends Node
## 战斗规则与持久配置入口。卡牌始终带施术者 id；UI 不决定归属或默认目标。

signal battle_started
signal state_changed
signal anya_return_finished
signal message_added(text: String)
signal battle_won(reward: Dictionary)
signal battle_lost
signal turn_started(side: String, turn_number: int)
signal action_resolved(side: String, index: int)
signal effect_requested(effect_id: String, side: String, index: int, hp_damage: int, guard_damage: int)
signal attack_attribute_resolved(info: Dictionary)
signal enemy_action_started(index: int)
signal enemy_interrupt_started
signal enemy_interrupt_finished
signal story_event(event_id: String)
signal player_action_started(index: int, skill_id: String)
signal confused_card_played(owner: int, card: Dictionary, presentation: Dictionary)
signal card_enchanted(card: Dictionary)
signal card_piles_changed
signal enemy_cards_added(cards: Array, pile: String)
signal hand_card_exhausted(card: Dictionary, reason: String)
signal turn_guard_gained(index: int, amount: int)
signal painting_effect_resolved(kind: String, target: int, amount: int, detail: String)
signal finale_event(kind: String, data: Dictionary)
signal anya_form_changed(kind: String)
signal anya_morphed(card: Dictionary)
var finale_presentation: Callable

const PLAYER_TURN := "player"
const ENEMY_TURN := "enemy"
const HAND_LIMIT := 12
const ACTION_POINTS := 3
const INITIAL_DRAW := 5 # compatibility label; actual draw is initial_draw_count()
const TURN_DRAW := 5 # compatibility label for two allies; actual draw is turn_draw_count()
const DRAW_BASE := 3
const DRAW_PER_BREAKTHROUGH := 1
const TURN_DRAW_BASE := 4
const PARTY_LIMIT := 4
const ULT_MAX := FightData.ULT_ENERGY

const FC_RULES := preload("res://scripts/fight/fc_rules.gd")
const DAMAGE_PREVIEW := preload("res://scripts/fight/damage_preview.gd")
const EQUIPMENT := preload("res://scripts/fight/equipment_rules.gd")
const ENEMY_RULES := preload("res://scripts/fight/enemy_rules.gd")
var dark_slots: Dictionary = {}
var expansion_hand_limit := HAND_LIMIT
var preview_mode := false
var lab_invincible_allies := false
var confused_draw_resolving := false
var confused_draw_count := 0
var fc = FC_RULES.new(self)
var resolving_action := false
var ultimate_presentation: Callable
var anya_return_presentation: Callable
var pursuit_presentation: Callable
var draft_presentation: Callable
var forecast_presentation: Callable
var painting_region_presentation: Callable
var item_presentation: Callable
var pending_item_resolution: Callable
var items_used := 0
var item_used_round := -1
var rare_item_used := false

var battle_active := false
## Monotonic session identity used to keep art/music stable when a battle view reopens.
var encounter_serial := 0
var phase := PLAYER_TURN
var round := 1
var action_points := 0
var selected_enemy := -1
var selected_ally := -1
var pending_card := -1
var pending_ultimate := -1
var pending_item := ""
var hand: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
var pending_turn_draw := 0
var _animated_turn_draw := false
var allies: Array = []
var enemies: Array = []
var log_lines: Array[String] = []
var last_reward: Dictionary = {}
var last_configuration_error := ""
var shared_guard := 0
var split_reward_given := false
var story_rewards_enabled := false
var encounter_kind := "trial"
var return_location := ""
var pending_enemy_ids: Array = []
var pending_enemy_levels: Array = []
var pending_tutorial := false
var pending_story_rewards := false
var pending_story_encounter := ""
var active_story_encounter := ""
var story_input_locked := false
var story_forced_skill := ""
var _story_resume_skill := ""
var _story_events_seen: Dictionary = {}
var _story_rewards_waiting: Dictionary = {}
const FLAG_FORMATION_TUTORIAL_DONE := "fight.formation_tutorial_done"
var pending_tutorial_preparation := false
var tutorial_preparation_stage := ""
var tutorial_action_ready := true
var _tutorial_opening_state: Dictionary = {}
## -1 = 普通战斗；0..3 = 指定操作；4 = 教学完成。
var tutorial_step := -1
var _management_panel: Node
var _management_parent: Node
var _management_was_paused := false
var _dialogue_process_before := Node.PROCESS_MODE_ALWAYS
var _dialogue_visible_before := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_progress()

func _ensure_progress() -> void:
	for hero_id in FightData.HEROES:
		if not GameState.fight_profiles.has(hero_id):
			GameState.fight_profiles[hero_id] = {"level": 1, "xp": 0}
		FightProgression.normalize_profile(String(hero_id))
		# 仅初始化缺失卡组；已有配置必须通过校验，不能静默替换玩家的选择。
		if not GameState.fight_loadouts.has(hero_id):
			GameState.fight_loadouts[hero_id] = FightData.default_loadout(String(hero_id))
	if GameState.fight_unlocked_attributes.is_empty():
		GameState.fight_unlocked_attributes = [FightData.ATTR_NONE]

func roster() -> Array:
	_ensure_progress()
	return FightData.HEROES.keys().filter(func(id: String) -> bool: return id not in ["wangjiaqi", "chenmo", "xumingming", "suwanqing", "liudanya", "li_anya"] or GameFlow.has_flag("fight.unlocked." + id))

func skill_available(hero_id: String, skill_id: String) -> bool:
	var skills: Array = FightData.skills_for(hero_id, current_attribute(hero_id))
	var def := FightData.skill(skill_id)
	var unlocked := not bool(def.get("story_unlock", false)) or GameFlow.has_flag("fight.unlocked.%s" % skill_id)
	return skills.has(skill_id) and unlocked and FightProgression.hero_level(hero_id) >= FightData.unlock_level(skill_id)

func skill_point_limit(hero_id: String) -> int:
	return FightData.BASE_SKILL_POINTS + (FightProgression.hero_level(hero_id) - 1) * FightData.POINTS_PER_LEVEL + FightProgression.rank() * FightProgression.COST_PER_BREAKTHROUGH

func loadout_points(cards: Array) -> int:
	var total := 0
	for skill_id in cards:
		total += FightData.skill_points(String(skill_id))
	return total

func initial_deck_size(hero_id: String) -> int:
	return maxi(1, int(FightData.hero(hero_id).get("initial_deck_size", FightProgression.BASE_DECK_SIZE)))

func action_point_limit() -> int:
	return mini(FightProgression.MAX_ENERGY, ACTION_POINTS + FightProgression.rank() * FightProgression.ENERGY_PER_BREAKTHROUGH) + EQUIPMENT.party_bonus(self, "turn_energy")

func hero_max_hp(hero_id: String) -> int:
	return FightData.max_hp(hero_id, FightProgression.hero_level(hero_id)) + int(FightEquipmentData.bonuses(hero_id).max_hp)

func complete_breakthrough() -> bool:
	if battle_active: return false
	last_configuration_error = FightProgression.breakthrough_error()
	if not last_configuration_error.is_empty() or not FightProgression.complete_breakthrough(): return false
	state_changed.emit()
	return true

func grant_accessory(id: String, hero_id: String = "") -> bool:
	var def: Dictionary = FightEquipmentData.ACCESSORIES.get(id, {})
	if battle_active or def.is_empty() or GameState.fight_accessories.has(id): return false
	if not hero_id.is_empty() and not roster().has(hero_id): return false
	GameState.fight_accessories[id] = ""
	if not hero_id.is_empty():
		var empty := FightEquipmentData.slots(hero_id).find("")
		if empty >= 0: equip_accessory(hero_id, empty, id)
	state_changed.emit()
	return true

func equip_accessory(hero_id: String, slot: int, id: String) -> bool:
	return EQUIPMENT.equip(self, hero_id, slot, id)

func purchase_equipment(id: String) -> bool:
	return EQUIPMENT.purchase(self, id)

func grant_consumable(id: String, amount: int = 1) -> int:
	if not FightEquipmentData.CONSUMABLES.has(id): return 0
	return Inventory.add(id, amount, GameState.BAG_HIGHSCHOOL)

func can_use_items() -> bool:
	return battle_active and not resolving_action and phase == PLAYER_TURN and pending_turn_draw == 0 and not story_input_locked and story_forced_skill.is_empty() and (tutorial_step < 0 or (tutorial_step >= 4 and _tutorial_opening_state.is_empty()))

func item_error(id: String, target_index: int = -1, require_target: bool = true) -> String:
	return EQUIPMENT.item_error(self, id, target_index, require_target)

func request_item(id: String) -> bool:
	last_configuration_error = item_error(id, -1, false)
	if not last_configuration_error.is_empty(): return false
	_clear_targeting()
	if FightEquipmentData.CONSUMABLES[id].target in ["ally", "enemy"]:
		pending_item = id
		state_changed.emit()
		return true
	return use_item(id)

func use_item(id: String, target_index: int = -1) -> bool:
	last_configuration_error = item_error(id, target_index)
	if not last_configuration_error.is_empty():
		_add_log(last_configuration_error)
		state_changed.emit()
		return false
	_clear_targeting()
	resolving_action = true
	set_meta("active_skill_source", owner)
	var serial := encounter_serial
	var ticket := {"done":false}
	var resolve := func() -> void:
		if ticket.done: return
		ticket.done = true
		pending_item_resolution = Callable()
		if not battle_active or serial != encounter_serial: return
		EQUIPMENT.resolve_item(self, id, target_index)
		resolving_action = false
		if _all_enemies_defeated(): _finish_victory()
		elif _all_allies_defeated(): _finish_loss()
		elif ENEMY_RULES.pending_transition(self): end_player_turn()
		state_changed.emit()
	pending_item_resolution = resolve
	if item_presentation.is_valid() and not preview_mode: item_presentation.call(id, target_index, resolve)
	else: resolve.call()
	state_changed.emit()
	return true

func _legal_loadout(hero_id: String, source: Array) -> Array:
	var clean: Array = []
	for entry in source:
		var skill_id := String(entry)
		if skill_available(hero_id, skill_id) and clean.count(skill_id) < FightData.copies(skill_id):
			if loadout_points(clean) + FightData.skill_points(skill_id) <= skill_point_limit(hero_id):
				clean.append(skill_id)
	return clean

func formation_slots() -> Array:
	var slots: Array = []
	var used: Array = []
	for entry in GameState.fight_formation.slice(0, PARTY_LIMIT):
		var id := String(entry)
		if not FightData.HEROES.has(id) or used.has(id):
			id = ""
		slots.append(id)
		if not id.is_empty():
			used.append(id)
	while slots.size() < PARTY_LIMIT:
		slots.append("")
	return slots

func formation() -> Array:
	return formation_slots().filter(func(id: String) -> bool: return not id.is_empty())

func set_formation(ids: Array) -> bool:
	last_configuration_error = ""
	if battle_active:
		last_configuration_error = "战斗中不能修改编队。"
		return false
	if ids.size() > PARTY_LIMIT:
		last_configuration_error = "最多编入 4 名角色。"
		return false
	var seen: Array = []
	for entry in ids:
		var id := String(entry)
		if id.is_empty():
			continue
		if not roster().has(id) or seen.has(id):
			last_configuration_error = "不能编入未知或重复的角色。"
			return false
		seen.append(id)
	var formation_changed := formation_slots() != ids
	GameState.fight_formation = ids.duplicate()
	while GameState.fight_formation.size() < PARTY_LIMIT:
		GameState.fight_formation.append("")
	if TowerRun.active and formation_changed: TowerRun.tutorial_task("formation")
	state_changed.emit()
	return true

func set_formation_slot(slot_index: int, hero_id: String) -> bool:
	if slot_index < 0 or slot_index >= PARTY_LIMIT:
		return false
	var slots := formation_slots()
	# 已在队内的角色直接交换位置，不出现同角色两次上场。
	var previous := slots.find(hero_id) if not hero_id.is_empty() else -1
	if previous >= 0 and previous != slot_index:
		slots[previous] = slots[slot_index]
	slots[slot_index] = hero_id
	return set_formation(slots)

func current_attribute(hero_id: String) -> String:
	return String(GameState.fight_attributes.get(hero_id, FightData.hero(hero_id).get("attribute", FightData.ATTR_NONE)))

func unlocked_attributes() -> Array:
	return GameState.fight_unlocked_attributes.duplicate()

func unlock_attribute(attribute: String) -> bool:
	if battle_active or not FightData.ATTRS.has(attribute):
		return false
	if not GameState.fight_unlocked_attributes.has(attribute):
		GameState.fight_unlocked_attributes.append(attribute)
	state_changed.emit()
	return true

func set_attribute(hero_id: String, attribute: String) -> bool:
	if battle_active or hero_id != "zhoumingyuan" or not FightData.ATTRS.has(attribute) or not GameState.fight_unlocked_attributes.has(attribute):
		return false
	var previous := current_attribute(hero_id)
	if previous == attribute: return true
	GameState.fight_loadouts["%s@%s" % [hero_id, previous]] = loadout(hero_id)
	GameState.fight_attributes[hero_id] = attribute
	GameState.fight_loadouts[hero_id] = (GameState.fight_loadouts.get("%s@%s" % [hero_id, attribute], FightData.default_loadout(hero_id, attribute)) as Array).duplicate()
	var equipped := FightEquipmentData.slots(hero_id)
	for slot in equipped.size():
		var gear_id := String(equipped[slot])
		if FightEquipmentData.ACCESSORIES.has(gear_id) and FightEquipmentData.ACCESSORIES[gear_id].has("form") and String(FightEquipmentData.ACCESSORIES[gear_id].form) != attribute:
			equipped[slot] = ""
	GameState.fight_equipment[hero_id] = equipped
	state_changed.emit()
	return true

func loadout(hero_id: String) -> Array:
	_ensure_progress()
	return (GameState.fight_loadouts.get(hero_id, []) as Array).duplicate()

func loadout_error(hero_id: String, cards: Array) -> String:
	if battle_active:
		return "战斗中仅可查看角色，不能修改技能。"
	if FightData.hero(hero_id).is_empty():
		return "角色不存在。"
	var counts: Dictionary = {}
	for entry in cards:
		var skill_id := String(entry)
		if not skill_available(hero_id, skill_id):
			return "该角色尚未习得此技能。"
		counts[skill_id] = int(counts.get(skill_id, 0)) + 1
		if int(counts[skill_id]) > FightData.copies(skill_id):
			return "该技能最多装备 %d 个。" % FightData.copies(skill_id)
	var points := loadout_points(cards)
	var limit := skill_point_limit(hero_id)
	if points > limit:
		return "携带 cost 不足：需要 %d / %d。请调整卡组、升级或突破。" % [points, limit]
	if cards.size() < initial_deck_size(hero_id):
		return "卡组不足：当前 %d 张，卡组初始大小为 %d 张。" % [cards.size(), initial_deck_size(hero_id)]
	return ""

func set_loadout(hero_id: String, cards: Array) -> bool:
	last_configuration_error = loadout_error(hero_id, cards)
	if not last_configuration_error.is_empty():
		return false
	var changed_cards := loadout(hero_id) != cards
	GameState.fight_loadouts[hero_id] = cards.duplicate()
	if TowerRun.active and changed_cards: TowerRun.tutorial_task("loadout")
	state_changed.emit()
	return true

func change_skill_count(hero_id: String, skill_id: String, delta: int) -> bool:
	if delta != 1 and delta != -1:
		return false
	var cards := loadout(hero_id)
	if delta > 0:
		cards.append(skill_id)
	elif cards.has(skill_id):
		cards.erase(skill_id)
	else:
		last_configuration_error = "尚未装备此技能。"
		return false
	return set_loadout(hero_id, cards)

func toggle_loadout(hero_id: String, skill_id: String) -> bool:
	return change_skill_count(hero_id, skill_id, -1 if loadout(hero_id).has(skill_id) else 1)

func encounter_error(party_ids: Array) -> String:
	if battle_active:
		return "当前战斗尚未结束。"
	if party_ids.is_empty() or party_ids.size() > PARTY_LIMIT:
		return "请编入 1 至 4 名角色。"
	var seen: Array = []
	for entry in party_ids:
		var id := String(entry)
		if not roster().has(id) or seen.has(id):
			return "编队含有重复或未知角色。"
		seen.append(id)
		var error := loadout_error(id, loadout(id))
		if not error.is_empty():
			return "%s：%s" % [FightData.hero(id)["name"], error]
	return ""

func make_card(skill_id: String, caster_id: String) -> Dictionary:
	return fc.stamp({"skill_id": String(FightData.FC.ALIASES.get(skill_id, skill_id)), "caster_id": caster_id})

func begin_encounter(enemy_ids: Array = ["paper_large", "paper_large"], forced_party: Array = [], enemy_levels: Array = [], tutorial: bool = false, story_rewards: bool = false, story_encounter: String = "", animated_turn_draw: bool = false) -> bool:
	if battle_active:
		return false
	_ensure_progress()
	var party_ids := forced_party.duplicate() if not forced_party.is_empty() else formation()
	if tutorial and (not party_ids.has("zhoumingyuan") or not party_ids.has("alyina")):
		last_configuration_error = "新手教程需要周明远和艾莉娜同时出战。"
		return false
	last_configuration_error = encounter_error(party_ids)
	if not last_configuration_error.is_empty() or enemy_ids.is_empty():
		return false
	for enemy_id in enemy_ids:
		if FightData.enemy(String(enemy_id)).is_empty():
			return false
	# An unfinished warehouse attempt must introduce its story skills again,
	# including saves made after leaving an older version of this encounter.
	_revoke_unwon_warehouse_rewards(story_encounter)
	_ensure_progress()
	fc.reset()
	expansion_hand_limit = HAND_LIMIT
	set_meta("box_compressions", 0)
	set_meta("cards_played_round", 0)
	set_meta("shackle_lock_round", -1)
	set_meta("active_skill_source", -1)
	dark_slots.clear()
	resolving_action = false
	pending_item_resolution = Callable()
	items_used = 0
	item_used_round = -1
	rare_item_used = false
	allies.clear()
	for hero_id in party_ids:
		var profile := FightData.hero(String(hero_id))
		var level := FightProgression.hero_level(String(hero_id))
		var max_hp := hero_max_hp(String(hero_id))
		allies.append({"id": String(hero_id), "name": profile["name"], "portrait": profile["portrait"], "attribute": current_attribute(String(hero_id)), "role": profile["role"], "damage_bonus": FightEquipmentData.bonuses(String(hero_id)).damage_bonus, "level": level, "max_hp": max_hp, "hp": max_hp, "guard": 0, "ult": 0, "downed": false, "dead": false, "downed_round": -1, "statuses": {}, "marks": {}})
		var unit: Dictionary = allies.back()
		unit.equipment = FightEquipmentData.bonuses(String(hero_id)).duplicate(true)
		unit.accessories = FightEquipmentData.slots(String(hero_id))
		unit.guard = int(unit.equipment.opening_guard)
		unit.ult = mini(FightData.ultimate_energy(String(hero_id)), int(unit.equipment.opening_ult))
		unit.guard += int(unit.equipment.round_guard)
		EQUIPMENT.opening(unit)
		if hero_id == "xumingming": fc.COMPANIONS.gain_marks(fc, allies.size() - 1, int(unit.equipment.opening_marks))
	enemies.clear()
	for enemy_index in enemy_ids.size():
		var enemy_id: String = String(enemy_ids[enemy_index])
		var profile := FightData.enemy(String(enemy_id))
		var level := maxi(1, int(enemy_levels[enemy_index])) if enemy_index < enemy_levels.size() else 1
		if TowerRun.active: level = clampi(level, 1, 70)
		else: level += FightProgression.rank() * FightProgression.LEVELS_PER_BREAKTHROUGH
		var max_hp := FightData.enemy_hp(enemy_id, level, 0 if tutorial or TowerRun.active else randi_range(0, 5))
		enemies.append({"id": enemy_id, "name": profile["name"], "portrait": profile["portrait"], "attribute": profile.get("attribute", FightData.ATTR_NONE), "level": level, "max_hp": max_hp, "hp": max_hp, "guard": 0, "statuses": {}, "marks": {}, "intent": {}, "intent_step": enemy_index, "split_used": false})
		ENEMY_RULES.setup(enemies.back())
	battle_active = true
	encounter_serial += 1
	phase = PLAYER_TURN
	round = 1
	action_points = action_point_limit()
	_clear_targeting()
	hand.clear()
	draw_pile.clear()
	discard_pile.clear()
	pending_turn_draw = 0
	_animated_turn_draw = animated_turn_draw
	log_lines.clear()
	last_reward = {}
	shared_guard = 0
	split_reward_given = false
	story_rewards_enabled = story_rewards
	active_story_encounter = story_encounter
	story_input_locked = false
	story_forced_skill = ""
	_story_resume_skill = ""
	_story_events_seen.clear()
	_story_rewards_waiting.clear()
	tutorial_step = 0 if tutorial else -1
	tutorial_action_ready = not tutorial
	for hero in allies:
		for skill_id in loadout(String(hero["id"])):
			draw_pile.append(make_card(String(skill_id), String(hero["id"])))
	if TowerRun.active and TowerRun.pending.get("mode") == "lesson": TowerRun.order_lesson_cards(draw_pile)
	else: draw_pile.shuffle()
	ENEMY_RULES.FINALE.start(self)
	ENEMY_RULES.EXPANSION.start(self)
	fc.ANYA.start_battle(fc)
	# Innate cards occupy opening-hand slots before the remaining random draw.
	for card in draw_pile.duplicate():
		if bool(FightData.skill(String(card.skill_id)).get("innate", false)) and hand.size() < HAND_LIMIT:
			fc.remove_card(draw_pile, card)
			hand.append(card)
	if _animated_turn_draw:
		pending_turn_draw = maxi(0, initial_draw_count() - hand.size())
	else:
		_draw(maxi(0, initial_draw_count() - hand.size()))
		if tutorial:
			_setup_tutorial_hand()
	_refresh_intents()
	_tutorial_opening_state = {"awaiting_initial_draw": true} if tutorial and _animated_turn_draw else {
		"allies": allies.duplicate(true), "enemies": enemies.duplicate(true),
		"hand": hand.duplicate(true), "draw_pile": draw_pile.duplicate(true),
		"discard_pile": discard_pile.duplicate(true),
	} if tutorial else {}
	_add_log("战斗开始。")
	battle_started.emit()
	state_changed.emit()
	return true

func initial_draw_count() -> int:
	# The guided practice keeps its four authored cards and action sequence.
	if tutorial_step >= 0: return 4
	return mini(HAND_LIMIT, DRAW_BASE + allies.size() + FightProgression.rank() * DRAW_PER_BREAKTHROUGH + EQUIPMENT.party_bonus(self, "turn_draw"))

func turn_draw_count() -> int:
	# Five draws for 1–2 allies, six for 3–4, independently of rank.
	# Opening options grow with rank; further throughput requires draw/tutor cards.
	return mini(HAND_LIMIT, TURN_DRAW_BASE + ceili(float(allies.size()) / 2.0) + EQUIPMENT.party_bonus(self, "turn_draw"))

func _setup_tutorial_hand() -> void:
	# Return the random opening hand before selecting the scripted cards, so
	# tutorial setup does not silently delete cards from the encounter deck.
	draw_pile.append_array(hand)
	hand.clear()
	var wanted := [make_card("basic_strike", "zhoumingyuan"), make_card("basic_strike", "zhoumingyuan"), make_card("block", "zhoumingyuan"), make_card("help_me", "alyina")]
	for card in wanted:
		var selected: Dictionary = card
		for i in range(draw_pile.size() - 1, -1, -1):
			if String(draw_pile[i].get("skill_id", "")) == String(card["skill_id"]) and String(draw_pile[i].get("caster_id", "")) == String(card["caster_id"]):
				selected = draw_pile.pop_at(i)
				break
		hand.append(selected)

func start_trial() -> void:
	await open_trial_preparation()

func prepare_encounter(enemy_ids: Array, levels: Array = [], tutorial: bool = false, story_rewards: bool = false, story_encounter: String = "", force_tutorial: bool = false) -> void:
	pending_enemy_ids = enemy_ids.duplicate()
	pending_enemy_levels = levels.duplicate()
	pending_tutorial = tutorial and (force_tutorial or not GameFlow.has_flag(FLAG_FORMATION_TUTORIAL_DONE))
	pending_tutorial_preparation = pending_tutorial
	tutorial_preparation_stage = "slot_1" if pending_tutorial else ""
	pending_story_rewards = story_rewards
	pending_story_encounter = story_encounter
	if pending_tutorial:
		GameState.fight_formation = ["", "", "", ""]
	state_changed.emit()

func skip_tutorial() -> void:
	if not pending_tutorial or battle_active:
		return
	if formation().is_empty():
		set_formation(["zhoumingyuan", "alyina"])
	pending_tutorial = false
	pending_tutorial_preparation = false
	tutorial_preparation_stage = ""
	GameFlow.set_flag(FLAG_FORMATION_TUTORIAL_DONE, true)
	state_changed.emit()

func open_trial_preparation() -> void:
	if not battle_active:
		if pending_tutorial_preparation:
			await SceneRouter.go_to("fight_prepare", "", true)
		elif _use_management_overlay():
			_show_management_panel("preparation")
		else:
			await SceneRouter.go_to("fight_prepare", "", true)

func open_character_system() -> void:
	if battle_active:
		show_character_panel(get_tree().current_scene)
	elif pending_tutorial_preparation:
		await SceneRouter.go_to("fight_characters", "", true)
	elif _use_management_overlay():
		_show_management_panel("characters")
	else:
		await SceneRouter.go_to("fight_characters", "", true)

func _use_management_overlay() -> bool:
	return is_instance_valid(_management_parent) or GameState.location.begins_with("college.") or GameState.location.begins_with("highschool.")

func _show_management_panel(scene: String) -> void:
	if not is_instance_valid(_management_parent):
		_management_parent = get_tree().current_scene
		_management_was_paused = get_tree().paused
		_dialogue_process_before = DialogueBox.process_mode
		_dialogue_visible_before = DialogueBox.visible
		DialogueBox.process_mode = Node.PROCESS_MODE_DISABLED
		DialogueBox.hide()
		get_tree().paused = true
	if is_instance_valid(_management_panel):
		_management_panel.queue_free()
	var packed: PackedScene = load("res://scenes/fight/" + scene + ".tscn")
	_management_panel = packed.instantiate()
	_management_panel.set("as_overlay", true)
	_management_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_management_parent.add_child(_management_panel)

func close_management_panel() -> void:
	if is_instance_valid(_management_panel):
		_management_panel.queue_free()
	_management_panel = null
	_management_parent = null
	DialogueBox.process_mode = _dialogue_process_before
	DialogueBox.visible = _dialogue_visible_before
	get_tree().paused = _management_was_paused

func can_start_tutorial_battle() -> bool:
	return pending_tutorial_preparation and not pending_enemy_ids.is_empty() and not is_instance_valid(_management_panel) and not battle_active

## 首次编队教学保留准备页；其余真实遇敌直接使用当前编队。
func enter_prepared_encounter() -> void:
	if pending_tutorial_preparation:
		await SceneRouter.go_to("fight_prepare", "", true)
	else:
		# 兼容旧档保存的空编队；普通配置页会保留至少一人。
		if formation().is_empty():
			set_formation(["zhoumingyuan", "alyina"])
		await _begin_pending_encounter()

## 面板覆盖在原场景上；关闭后不重建战斗、不改变地点或手牌。
func show_character_panel(parent: Node, hero_id: String = "zhoumingyuan") -> Node:
	var packed: PackedScene = load("res://scenes/fight/characters.tscn")
	var panel := packed.instantiate()
	panel.set("as_overlay", true)
	panel.set("read_only", battle_active)
	panel.set("selected_hero", hero_id)
	parent.add_child(panel)
	return panel

func begin_trial() -> void:
	if not can_start_tutorial_battle():
		return
	if tutorial_preparation_stage != "begin_battle":
		return
	if not tutorial_formation_ready():
		return
	await _begin_pending_encounter()

func tutorial_formation_ready() -> bool:
	return formation().has("zhoumingyuan") and formation().has("alyina")

func _begin_pending_encounter() -> void:
	if pending_enemy_ids.is_empty():
		return
	var enemy_ids := pending_enemy_ids
	var levels := pending_enemy_levels
	var tutorial := pending_tutorial
	var story_rewards := pending_story_rewards
	if not begin_encounter(enemy_ids, [], levels, tutorial, story_rewards, pending_story_encounter, true):
		return
	if pending_tutorial_preparation:
		GameFlow.set_flag(FLAG_FORMATION_TUTORIAL_DONE, true)
	pending_tutorial_preparation = false
	tutorial_preparation_stage = ""
	pending_enemy_ids.clear()
	pending_enemy_levels.clear()
	pending_tutorial = false
	pending_story_rewards = false
	pending_story_encounter = ""
	GameState.chapter = maxi(GameState.chapter, 1)
	GameState.phase = "night"
	await SceneRouter.go_to("fight", "", true)

func start_encounter(enemy_ids: Array, forced_party: Array = []) -> void:
	if begin_encounter(enemy_ids, forced_party, [], false, false, "", true):
		await SceneRouter.go_to("fight", "", true)

func start_finale() -> void:
	if begin_encounter([ENEMY_RULES.FINALE.BOSS], [], [], false, false, "first_cycle_finale", true):
		await SceneRouter.go_to("fight", "", true)

func _draw(amount: int) -> void:
	var drawn := 0
	var attempts := 0
	while drawn < amount and attempts < amount + draw_pile.size() + discard_pile.size() + 1:
		attempts += 1
		var confused_before := confused_draw_count
		var cards: Array = fc.take_draw(1)
		drawn += confused_draw_count - confused_before
		if cards.is_empty():
			if confused_draw_count > confused_before: continue
			break
		if not ENEMY_RULES.EXPANSION.draw_allowed(self, cards[0]): continue
		fc.to_hand(cards[0])
		drawn += 1

func caster_index(card: Dictionary) -> int:
	if String(card.get("skill_id", "")) in ENEMY_RULES.FINALE.SUPPORT: return _first_alive(allies)
	if ENEMY_RULES.is_curse(card): return _first_alive(allies)
	for i in allies.size():
		if String(allies[i]["id"]) == String(card.get("anya_actor", card.get("caster_id", ""))):
			return i
	return -1

func can_play(index: int) -> bool:
	if not fc.anya_return_pending.is_empty(): return false
	if TowerRun.active and TowerRun.lesson_reading and not preview_mode: return false
	if not battle_active or resolving_action or phase != PLAYER_TURN or pending_turn_draw > 0 or index < 0 or index >= hand.size():
		return false
	if story_input_locked or (story_forced_skill != "" and String(hand[index].get("skill_id", "")) != story_forced_skill):
		return false
	if tutorial_step == 4 and not _tutorial_opening_state.is_empty():
		return false
	if tutorial_step >= 0 and tutorial_step < 4 and not tutorial_action_ready:
		return false
	var card: Dictionary = hand[index]
	if not ENEMY_RULES.EXPANSION.play_allowed(self, card, index): return false
	if TowerRun.active and not preview_mode and not TowerRun.lesson_required_card(card): return false
	if ENEMY_RULES.slot_blocked(self, index): return false
	if tutorial_step >= 0 and tutorial_step < 3:
		var required := ["basic_strike", "block", "help_me"]
		if String(card.get("skill_id", "")) != required[tutorial_step]:
			return false
	elif tutorial_step == 3:
		return false
	var owner := caster_index(card)
	var def := FightData.skill(String(card.get("skill_id", "")))
	var cost: int = fc.cost(card)
	if ENEMY_RULES.is_curse(card): return owner >= 0 and not bool(def.get("unplayable", false)) and cost <= fc.ANYA.budget(fc)
	return owner >= 0 and _is_alive(allies[owner]) and not def.is_empty() and cost <= fc.ANYA.budget(fc) and fc.playable(card)

func card_target_type(index: int) -> String:
	if index < 0 or index >= hand.size():
		return ""
	return String(FightData.skill(String(hand[index]["skill_id"])).get("target", "enemy"))

func pending_target_type() -> String:
	if not pending_item.is_empty(): return String(FightEquipmentData.CONSUMABLES.get(pending_item, {}).get("target", ""))
	if pending_ultimate >= 0:
		var ultimate := get_ultimate(pending_ultimate)
		return String(ultimate.get("target", "enemy")) if String(ultimate.get("target", "enemy")) == "enemy" else ""
	return card_target_type(pending_card)

func request_card(index: int) -> bool:
	if not can_play(index):
		return false
	_clear_targeting()
	if card_target_type(index) in ["ally", "enemy"]:
		pending_card = index
		state_changed.emit()
		return true
	return play_card(index)

func request_ultimate(index: int) -> bool:
	if story_input_locked or story_forced_skill != "":
		return false
	if tutorial_step >= 0 and tutorial_step < 4:
		return false
	if tutorial_step == 4 and not _tutorial_opening_state.is_empty():
		return false
	if not can_ultimate(index):
		return false
	_clear_targeting()
	var ultimate := get_ultimate(index)
	if String(ultimate.get("target", "enemy")) != "enemy":
		return use_ultimate(index)
	pending_ultimate = index
	state_changed.emit()
	return true

func cancel_targeting() -> void:
	_clear_targeting()
	state_changed.emit()

func _clear_targeting() -> void:
	pending_item = ""
	pending_card = -1
	pending_ultimate = -1
	selected_ally = -1
	selected_enemy = -1

func valid_target(side: String, index: int) -> bool:
	if not battle_active or phase != PLAYER_TURN or pending_target_type() != side:
		return false
	if TowerRun.active and pending_card >= 0 and pending_card < hand.size() and not TowerRun.lesson_target_allowed(String(hand[pending_card].skill_id), index): return false
	var units: Array = allies if side == "ally" else enemies
	var ignore_taunt := pending_card >= 0 and pending_card < hand.size() and bool(FightData.skill(String(hand[pending_card].skill_id)).get("ignore_taunt", false))
	if side == "enemy" and not ENEMY_RULES.targeted_enemy(self, index, ignore_taunt): return false
	if side == "ally" and pending_card >= 0 and pending_card < hand.size() and index >= 0 and index < units.size():
		var def := FightData.skill(String(hand[pending_card].skill_id))
		if bool(def.get("not_downed", false)) and bool(units[index].downed): return false
		if bool(def.get("downed_only", false)) and not bool(units[index].downed): return false
	return index >= 0 and index < units.size() and _is_alive(units[index])

func select_enemy(index: int) -> bool:
	if not valid_target("enemy", index):
		return false
	if not pending_item.is_empty(): return use_item(pending_item, index)
	if pending_ultimate >= 0:
		return use_ultimate(pending_ultimate, index)
	return play_card(pending_card, index)

func select_ally(index: int) -> bool:
	if not valid_target("ally", index):
		return false
	if not pending_item.is_empty(): return use_item(pending_item, index)
	return play_card(pending_card, index)

func play_card(index: int, target_index: int = -1) -> bool:
	if not can_play(index):
		return false
	var card: Dictionary = hand[index]
	var skill_id := String(card["skill_id"])
	if TowerRun.active and not preview_mode and not TowerRun.lesson_target_allowed(skill_id, target_index): return false
	if tutorial_step == 0 and target_index != 0:
		return false
	if tutorial_step == 2 and target_index != 0:
		return false
	if story_forced_skill == "hang_on" and target_index != _ally_index("zhoumingyuan"):
		return false
	var def := FightData.skill(skill_id)
	var side := String(def.get("target", "enemy"))
	if side == "enemy" and not ENEMY_RULES.targeted_enemy(self, target_index, bool(def.get("ignore_taunt", false))): return false
	if side in ["enemy", "ally"]:
		var units: Array = enemies if side == "enemy" else allies
		if target_index < 0 or target_index >= units.size() or not _is_alive(units[target_index]):
			return false
		if side == "ally" and bool(def.get("downed_only", false)) and not bool(units[target_index].get("downed", false)):
			return false
		if side == "ally" and bool(def.get("not_downed", false)) and bool(units[target_index].get("downed", false)): return false
	var owner := caster_index(card)
	var spent: int = fc.cost(card)
	var count := hand.size()
	var box_refill := expansion_hand_limit < HAND_LIMIT and count == expansion_hand_limit
	hand.remove_at(index)
	fc.ANYA.spend(fc, spent)
	set_meta("cards_played_round", int(get_meta("cards_played_round", 0)) + 1)
	_clear_targeting()
	resolving_action = true
	set_meta("tower_target", target_index)
	set_meta("tower_spent", spent)
	# X-cost and curse cards do not spend the first non-X skill discount.
	if not ENEMY_RULES.is_curse(card) and int(def.get("cost", 0)) >= 0:
		allies[owner].equipment_played_round = round
	player_action_started.emit(owner, skill_id)
	if ENEMY_RULES.is_curse(card):
		fc.exhausted.append(card)
		if box_refill: _draw(1)
		if skill_id == "medicine": ENEMY_RULES.EXPANSION.use_medicine(self, _finish_card.bind(skill_id))
		else: _finish_card(skill_id)
		return true
	if bool(card.get("trojan", false)):
		card.erase("trojan")
		discard_pile.append(card)
		_add_log("木马使%s的效果失效。" % FightData.skill(skill_id).get("name", "技能"), false)
		_finish_card(skill_id)
		return true
	fc.start(owner, card, target_index, index, count, spent, _finish_card.bind(skill_id))
	if box_refill and battle_active: _draw(1)
	state_changed.emit()
	return true

func _finish_card(skill_id: String) -> void:
	fc.ANYA.check_exit(fc)
	if not await _wait_for_anya_return(): return
	resolving_action = false
	set_meta("active_skill_source", -1)
	await _resolve_enemy_interrupts()
	if skill_id == story_forced_skill:
		story_forced_skill = _story_resume_skill
		_story_resume_skill = ""
		_emit_story_event("red_pen_after" if skill_id == "red_pen" else "hang_on_after")
	if tutorial_step >= 0 and tutorial_step < 3:
		tutorial_step += 1
		tutorial_action_ready = false
	if _all_enemies_defeated(): _finish_victory()
	elif _all_allies_defeated(): _finish_loss()
	elif ENEMY_RULES.pending_transition(self): end_player_turn()
	state_changed.emit()

func _apply_skill(owner: int, _def: Dictionary, target_index: int, skill_id: String) -> void:
	# Compatibility entry point for scripted encounters.
	resolving_action = true
	fc.start(owner, make_card(skill_id, String(allies[owner].id)), target_index, 0, 1, 0, _finish_card.bind(skill_id))

func get_ultimate(index: int) -> Dictionary:
	var unit: Dictionary = allies[index]
	if String(unit.id) == fc.ANYA.ID: return fc.ANYA.ultimate(fc, index)
	var result := FightData.ultimate(String(unit.id), String(unit.attribute))
	if fc.is_math(index) and not fc.noticed: result["target"] = "self"
	return result

func card_cost(card: Dictionary) -> int:
	return fc.cost(card)

func preview_card(index: int, target_index: int = -1) -> Dictionary:
	return DAMAGE_PREVIEW.calculate(self, index, target_index, false)

func preview_ultimate(index: int, target_index: int = -1) -> Dictionary:
	return DAMAGE_PREVIEW.calculate(self, index, target_index, true)

func card_keywords(card: Dictionary) -> String:
	return fc.describe(card)

func choose_cards(ids: Array) -> bool:
	return battle_active and resolving_action and fc.choose(ids)

func choose_painting(edits: Dictionary) -> bool:
	return battle_active and resolving_action and fc.PAINTING.choose(fc, edits)

func ultimate_max(index: int) -> int:
	if index < 0 or index >= allies.size():
		return ULT_MAX
	var ultimate := get_ultimate(index)
	return maxi(1, int(ultimate.get("energy", ULT_MAX)))

func can_ultimate(index: int) -> bool:
	if not fc.anya_return_pending.is_empty(): return false
	if index >= 0 and index < allies.size() and String(allies[index].id) == fc.ANYA.ID and fc.ANYA.phoenix(fc): return false
	if TowerRun.active and (TowerRun.lesson_reading or TowerRun.lesson_stage() in [0, 1, 2]) and not preview_mode: return false
	if index >= 0 and index < allies.size() and fc.POISON.absent(allies[index]): return false
	if index >= 0 and index < allies.size() and fc.COMPANIONS.is_controlled(allies[index]): return false
	return battle_active and not resolving_action and phase == PLAYER_TURN and pending_turn_draw == 0 and not story_input_locked and story_forced_skill == "" and index >= 0 and index < allies.size() and _is_alive(allies[index]) and int(allies[index]["ult"]) >= ultimate_max(index)

func present_ultimate(owner: int, resolve: Callable) -> void:
	# The scene may delay resolution for a skippable CG. Rules-only callers stay synchronous.
	if ultimate_presentation.is_valid(): ultimate_presentation.call(owner, resolve)
	else: resolve.call()

func _wait_for_anya_return() -> bool:
	if fc.anya_return_pending.is_empty(): return true
	var ticket: Dictionary = fc.anya_return_pending
	state_changed.emit()
	await anya_return_finished
	return battle_active and not bool(ticket.cancelled) and int(ticket.serial) == encounter_serial

func use_ultimate(index: int, target_index: int = -1) -> bool:
	if not can_ultimate(index): return false
	var ultimate := get_ultimate(index)
	if String(ultimate.get("target", "self")) == "enemy":
		if target_index < 0 or target_index >= enemies.size() or not _is_alive(enemies[target_index]): return false
		if not ENEMY_RULES.targeted_enemy(self, target_index): return false
	_clear_targeting()
	resolving_action = true
	set_meta("tower_target", target_index)
	set_meta("tower_spent", 0)
	player_action_started.emit(index, "ultimate")
	fc.ultimate(index, target_index, func() -> void:
		resolving_action = false
		ENEMY_RULES.skill_used(self, index)
		await _resolve_enemy_interrupts()
		if _all_enemies_defeated(): _finish_victory()
		elif _all_allies_defeated(): _finish_loss()
		elif ENEMY_RULES.pending_transition(self): end_player_turn()
		state_changed.emit()
	)
	state_changed.emit()
	return true

func _resolve_enemy_interrupts() -> void:
	if not fc.anya_return_pending.is_empty(): return
	if not battle_active or resolving_action or phase != PLAYER_TURN: return
	for i in enemies.size():
		var enemy: Dictionary = enemies[i]
		if not _is_alive(enemy) or not bool(enemy.get("sentence_pending", false)): continue
		enemy.sentence_pending = false
		enemy.intent = ENEMY_RULES.action("愚行，无处遁形", "single", ENEMY_RULES.scaled(enemy, 8), "sentence", "无视嘲讽，攻击并标记累计攻击宙斯次数最多的角色；再次标记会处决。")
		phase = ENEMY_TURN
		enemy_interrupt_started.emit()
		enemy_action_started.emit(i)
		ENEMY_RULES.resolve(self, i, true)
		enemy_interrupt_finished.emit()
		if not await _wait_for_anya_return(): return
		phase = PLAYER_TURN
		if not battle_active: return
		if _all_allies_defeated():
			_finish_loss()
			return
		_refresh_intents(i)
	state_changed.emit()

func end_player_turn() -> void:
	if not fc.anya_return_pending.is_empty(): return
	await _resolve_enemy_interrupts()
	if TowerRun.active and TowerRun.lesson_reading: return
	if not battle_active or resolving_action or phase != PLAYER_TURN or pending_turn_draw > 0:
		return
	if story_input_locked or story_forced_skill != "":
		return
	if tutorial_step == 4 and not _tutorial_opening_state.is_empty():
		return
	if tutorial_step >= 0 and tutorial_step != 3 and tutorial_step < 4:
		return
	if tutorial_step == 3 and not tutorial_action_ready:
		return
	if tutorial_step == 3:
		tutorial_step = 4
		tutorial_action_ready = true
	_clear_targeting()
	phase = ENEMY_TURN
	ENEMY_RULES.snapshot_attackers(self)
	turn_started.emit(ENEMY_TURN, round)
	fc.before_enemy_turn()
	if not await _wait_for_anya_return(): return
	if not battle_active: return
	ENEMY_RULES.EXPANSION.before_enemy(self)
	for ally in allies:
		if bool(ally.get("anya_hidden", false)): continue
		_tick_marks(ally)
		_tick_statuses(ally)
	ENEMY_RULES.EXPANSION.after_status_tick(self)
	ENEMY_RULES.thunder(self)
	ENEMY_RULES.CHALLENGES.before_enemy(self)
	if not await _wait_for_anya_return(): return
	await _resolve_enemy_turn()
	if not battle_active: return
	if _all_allies_defeated():
		_finish_loss()
		state_changed.emit()
		return
	if _all_enemies_defeated():
		_finish_victory()
		state_changed.emit()
		return
	for enemy in enemies:
		_tick_marks(enemy)
		_tick_statuses(enemy)
	ENEMY_RULES.EXPANSION.after_status_tick(self)
	fc.before_player_turn()
	fc.ANYA.check_exit(fc)
	if not await _wait_for_anya_return(): return
	round += 1
	phase = PLAYER_TURN
	fc.ANYA.mark_round(fc)
	set_meta("cards_played_round", 0)
	fc.POISON.round_started(fc)
	EQUIPMENT.round_started(self)
	if _all_allies_defeated():
		_finish_loss()
		state_changed.emit()
		return
	action_points = maxi(0, action_point_limit() + fc.painting_next_energy + fc.anya_next_energy - ENEMY_RULES.CHALLENGES.consume_penalty(self, "next_energy_penalty"))
	fc.anya_next_energy = 0
	fc.painting_next_energy = 0
	var challenge_draw_penalty := ENEMY_RULES.CHALLENGES.consume_penalty(self, "next_draw_penalty")
	if _animated_turn_draw:
		pending_turn_draw = maxi(0, turn_draw_count() + fc.next_draw - challenge_draw_penalty)
		fc.next_draw = 0
	else:
		_draw(maxi(0, turn_draw_count() + fc.next_draw - challenge_draw_penalty))
		fc.next_draw = 0
		ENEMY_RULES.FINALE.lock_hand(self)
	_refresh_intents()
	_add_log("第 %d 回合：行动点恢复为 %d。" % [round, action_points])
	turn_started.emit(PLAYER_TURN, round)
	if round == 3:
		_emit_story_event("round_three")
	state_changed.emit()

func finish_player_turn_intro(expected_round: int) -> void:
	if not battle_active or phase != PLAYER_TURN or round != expected_round or pending_turn_draw <= 0:
		return
	var amount := pending_turn_draw
	pending_turn_draw = 0
	_draw(amount)
	ENEMY_RULES.FINALE.lock_hand(self)
	if tutorial_step == 0 and _tutorial_opening_state.has("awaiting_initial_draw"):
		_setup_tutorial_hand()
		_tutorial_opening_state = {
			"allies": allies.duplicate(true), "enemies": enemies.duplicate(true),
			"hand": hand.duplicate(true), "draw_pile": draw_pile.duplicate(true),
			"discard_pile": discard_pile.duplicate(true),
		}
	state_changed.emit()

func complete_tutorial_reset() -> void:
	if tutorial_step != 4 or _tutorial_opening_state.is_empty():
		return
	allies = (_tutorial_opening_state["allies"] as Array).duplicate(true)
	enemies = (_tutorial_opening_state["enemies"] as Array).duplicate(true)
	hand = (_tutorial_opening_state["hand"] as Array).duplicate(true)
	draw_pile = (_tutorial_opening_state["draw_pile"] as Array).duplicate(true)
	discard_pile = (_tutorial_opening_state["discard_pile"] as Array).duplicate(true)
	action_points = action_point_limit()
	shared_guard = 0
	fc.reset()
	split_reward_given = false
	_clear_targeting()
	_tutorial_opening_state.clear()
	_add_log("教学结束：除了回合数，战斗已恢复至开局状态。")
	start_story_battle_intro()
	state_changed.emit()

func start_story_battle_intro() -> void:
	_emit_story_event("battle_opening")

func _resolve_enemy_turn(only_index: int = -1) -> void:
	# Resume the next enemy only after the phoenix has actually returned.
	var enemy_count_this_turn := enemies.size()
	for enemy_index in enemy_count_this_turn:
		if only_index >= 0 and enemy_index != only_index: continue
		if not battle_active: return
		_resolve_enemy_action(enemy_index)
		if not await _wait_for_anya_return(): return

func _resolve_enemy_action(enemy_index: int) -> void:
	var enemy: Dictionary = enemies[enemy_index]
	if not _is_alive(enemy):
		return
	if fc.POISON.STATUS.skip_action(enemy):
		_add_log("%s 处于眩晕，本回合无法行动。" % enemy.name, false)
		return
	enemy_action_started.emit(enemy_index)
	if ENEMY_RULES.resolve(self, enemy_index): return
	var intent: Dictionary = enemy.get("intent", {})
	if String(intent.get("kind", "")) == "split":
		enemy["split_used"] = true
		enemy["dead"] = true
		enemy["hp"] = 0
		enemy["intent"] = {}
		var level := int(enemy.get("level", 1))
		enemies.append({"id":"paper_small", "name":"试卷兽（小）", "portrait":FightData.enemy("paper_small")["portrait"], "attribute":FightData.ATTR_NONE, "level":level, "max_hp":FightData.enemy_hp("paper_small", level), "hp":FightData.enemy_hp("paper_small", level), "guard":0, "statuses":{}, "marks":{}, "intent":{}, "intent_step":0, "split_used":true})
		enemies.append({"id":"paper_small", "name":"试卷兽（小）", "portrait":FightData.enemy("paper_small")["portrait"], "attribute":FightData.ATTR_NONE, "level":level, "max_hp":FightData.enemy_hp("paper_small", level), "hp":FightData.enemy_hp("paper_small", level), "guard":0, "statuses":{}, "marks":{}, "intent":{}, "intent_step":0, "split_used":true})
		_add_log("%s 撕裂成两只试卷兽（小）。" % enemy["name"])
		if story_rewards_enabled and not split_reward_given and not GameFlow.has_flag("fight.unlocked.red_pen"):
			split_reward_given = true
			if _story_ready():
				_story_rewards_waiting["red_pen"] = true
				_emit_story_event("first_split")
			else:
				_grant_story_reward("red_pen")
		elif story_rewards_enabled:
			_add_log("本场已领取红笔批注奖励。")
		return
	var targets: Array = []
	if String(intent.get("kind", "single")) == "bounce":
		var previous := -1
		for hit in 3:
			if not _is_alive(enemy): break
			var candidates: Array[int] = []
			for candidate_index in allies.size():
				if _enemy_targetable(allies[candidate_index]):
					candidates.append(candidate_index)
			var bounce_target := candidates[randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else -1
			if bounce_target < 0:
				break
			var bounce_damage := int(intent.get("damage", 4))
			if bounce_target == previous:
				bounce_damage = maxi(1, bounce_damage / 2)
			bounce_damage = fc.damage_amount(enemy, allies[bounce_target], float(bounce_damage), false)
			var damage_result := _take_damage(allies[bounce_target], bounce_damage, false, enemy_index)
			effect_requested.emit("enemy_bounce", "ally", bounce_target, damage_result["hp"], damage_result["guard"])
			previous = bounce_target
			selected_ally = bounce_target
			action_resolved.emit("ally", bounce_target)
			fc.POISON.enemy_attacked(fc, enemy_index)
		_add_log("%s 施放%s，三段弹射攻击结算。" % [enemy["name"], intent.get("name", "交头接耳")])
		return
	if String(intent.get("kind", "single")) == "all":
		for i in allies.size():
			if _enemy_targetable(allies[i]):
				targets.append(i)
	else:
		var index: int = ENEMY_RULES.single_target(self)
		if index >= 0:
			targets.append(index)
	for index in targets:
		if not _is_alive(enemy): break
		var enemy_damage: int = fc.damage_amount(enemy, allies[index], float(intent.get("damage", 6)), false)
		var damage_result := _take_damage(allies[index], enemy_damage, false, enemy_index)
		effect_requested.emit(String(intent.get("name", "enemy_attack")), "ally", index, damage_result["hp"], damage_result["guard"])
		if fc.POISON.STATUS.canonical(String(intent.get("status", ""))) == "weakness" and _is_alive(allies[index]):
			fc.POISON.debuff(allies[index], "weakness", {"turns":1})
		if String(intent.get("status", "")) == "sleep_bad" and _is_alive(allies[index]):
			var stacks := int((allies[index]["statuses"] as Dictionary).get("sleep_bad", {}).get("stacks", 0)) + 1
			stacks = mini(stacks, 4)
			fc.POISON.debuff(allies[index], "sleep_bad", {"name":"睡眠不佳", "desc":"受到的治疗效果降低 25%。", "turns":9999, "stacks":stacks, "heal_taken_mult":maxf(0.0, 1.0 - 0.25 * stacks), "debuff":true})
		selected_ally = int(index)
		action_resolved.emit("ally", int(index))
	if not targets.is_empty() and int(intent.get("damage", 0)) > 0: fc.POISON.enemy_attacked(fc, enemy_index)
	_add_log("%s 施放%s，%s受到 %d 点伤害。" % [enemy["name"], intent.get("name", "攻击"), "我方全体" if intent.get("kind", "") == "all" else "目标队友", int(intent.get("damage", 6))])

func _refresh_intents(only_index: int = -1) -> void:
	for i in enemies.size():
		if only_index >= 0 and i != only_index: continue
		var enemy: Dictionary = enemies[i]
		if not _is_alive(enemy):
			continue
		if ENEMY_RULES.refresh(self, i): continue
		var id := String(enemy["id"])
		var skills: Array
		if id == "paper_large" and not bool(enemy.get("split_used", false)) and int(enemy["hp"]) <= int(enemy["max_hp"]) / 2:
			enemy["intent"] = {"name":"撕卷！", "damage":0, "kind":"split"}
			continue
		match id:
			"paper_large": skills = [{"name":"分发试卷", "damage":6 + enemy["level"] - 1, "kind":"all"}, {"name":"试卷压迫", "damage":8 + enemy["level"] - 1, "kind":"single", "status":"weakness"}]
			"paper_small": skills = [{"name":"分发试卷", "damage":roundi(4.0 + 0.5 * (enemy["level"] - 1)), "kind":"all"}, {"name":"试卷压迫", "damage":roundi(4.0 + 0.5 * (enemy["level"] - 1)), "kind":"single", "random_target":true}]
			"noise": skills = [{"name":"不！许！睡！", "damage":0, "kind":"single", "status":"sleep_bad", "random_target":true}, {"name":"交头接耳", "damage":4 + floori(float(enemy["level"]) / 5.0) * 2, "kind":"bounce"}]
			_: skills = [{"name":"攻击", "damage":6, "kind":"single"}]
		var skill_index := (round + i - 1) % skills.size()
		if id == "noise" and round == 1:
			skill_index = 0 if randf() < 0.8 else 1
		enemy["intent"] = (skills[skill_index] as Dictionary).duplicate()

func _tick_marks(target: Dictionary) -> void:
	var marks: Dictionary = target.get("marks", {})
	for attribute in marks.keys():
		marks[attribute] = int(marks[attribute]) - 1
		if int(marks[attribute]) <= 0:
			marks.erase(attribute)

func _tick_statuses(target: Dictionary) -> void:
	var statuses: Dictionary = target.get("statuses", {})
	for id in statuses.keys():
		if bool(statuses[id].get("fc_after_enemy", false)) or bool(statuses[id].get("tick_on_action", false)): continue
		if int(statuses[id].get("turns", 1)) < 0:
			continue
		statuses[id]["turns"] = int(statuses[id].get("turns", 1)) - 1
		if int(statuses[id]["turns"]) <= 0:
			statuses.erase(id)

func _take_damage(target: Dictionary, amount: int, true_damage: bool = false, enemy_source: int = -1, share_allowed: bool = true, skip_shared: bool = false) -> Dictionary:
	amount = ENEMY_RULES.CHALLENGES.incoming(self, target, amount)
	amount = ENEMY_RULES.EXPANSION.incoming(self, target, amount)
	if String(target.get("id", "")) == ENEMY_RULES.FINALE.BOSS and amount > 0: amount = 1
	var result := _take_damage_raw(target, amount, true_damage, enemy_source, share_allowed, skip_shared)
	if TowerRun.active and not preview_mode: TowerRun.damage_event(target, int(result.hp), int(result.guard))
	ENEMY_RULES.CHALLENGES.after_damage(self, target, result)
	ENEMY_RULES.after_damage(self, target, result)
	fc.COMPANIONS.after_damage(fc, target, result, enemy_source)
	return result

func _take_damage_raw(target: Dictionary, amount: int, true_damage: bool, enemy_source: int, share_allowed: bool, skip_shared: bool) -> Dictionary:
	var result := {"hp": 0, "guard": 0}
	if amount > 0 and fc.anya_damage_block_round == round and _is_ally_unit(target):
		# Cancel only damage for the rest of this round; enemy actions still resolve.
		result.anya_suppressed = true
		return result
	if lab_invincible_allies and _is_ally_unit(target): return result
	if bool(target.get("phase_pending", false)): return result
	if amount <= 0 or not _is_alive(target) or fc.POISON.absent(target):
		return result
	if not true_damage and not skip_shared and _is_ally_unit(target) and fc.temporary_guard > 0:
		var absorbed_temp: int = mini(fc.temporary_guard, amount)
		fc.temporary_guard -= absorbed_temp
		amount -= absorbed_temp
		result.guard += absorbed_temp
		if amount <= 0: return result
	if not true_damage and not skip_shared and _is_ally_unit(target) and shared_guard > 0:
		var shared_absorbed := mini(shared_guard, amount)
		shared_guard -= shared_absorbed
		amount -= shared_absorbed
		result["guard"] += shared_absorbed
		if amount <= 0:
			return result
	if not true_damage and target.statuses.has("poison_guard"):
		var absorbed_temp := mini(int(target.statuses.poison_guard.stacks), amount)
		target.statuses.poison_guard.stacks -= absorbed_temp
		amount -= absorbed_temp
		result.guard += absorbed_temp
		if int(target.statuses.poison_guard.stacks) <= 0: target.statuses.erase("poison_guard")
		if amount <= 0: return result
	var guard := int(target.get("guard", 0))
	var absorbed := 0 if true_damage or _is_ally_unit(target) and target.statuses.has("isolation") else mini(guard, amount)
	target["guard"] = guard - absorbed
	result["guard"] += absorbed
	var hp_damage := amount - absorbed
	if _is_ally_unit(target): hp_damage = fc.ANYA.buffer_damage(fc, target, hp_damage, enemy_source)
	hp_damage = ENEMY_RULES.clamp_boss_damage(target, hp_damage)
	if hp_damage > 0 and share_allowed and enemy_source >= 0 and _is_ally_unit(target):
		var protector: int = fc.COMPANIONS.share_owner(fc, target)
		if protector >= 0:
			var transferred := roundi(hp_damage * [0.3, 0.4, 0.5][mini(2, FightProgression.rank())])
			hp_damage -= transferred
			var shared_result := _take_damage(allies[protector], transferred, true_damage, enemy_source, false, true)
			effect_requested.emit("C_share", "ally", protector, shared_result.hp, shared_result.guard)
	if hp_damage <= 0:
		return result
	if String(target.get("id", "")) in ["fist_phantom", "whip_phantom", "shackle_phantom"]:
		var shared_boss := int(target.get("summoner", -1))
		if shared_boss >= 0 and shared_boss < enemies.size() and _is_alive(enemies[shared_boss]):
			var master: Dictionary = enemies[shared_boss]
			var before_shared := int(master.hp)
			master.hp = maxi(0, before_shared - hp_damage)
			fc.hp_lost(master, before_shared)
			result.hp = mini(before_shared, hp_damage)
			return result
	var target_statuses: Dictionary = target.get("statuses", {})
	if bool(target.get("anya_phoenix", false)):
		var previous := int(target.hp)
		target.hp = maxi(1 if target_statuses.has("anya_unbroken") else 0, previous - hp_damage)
		result.hp = previous - int(target.hp)
		fc.hp_lost(target, previous)
		if int(target.hp) <= 0: fc.ANYA.forced_exit(fc, target)
		return result
	if hp_damage >= maxi(1, int(target.get("hp", 0))) and target_statuses.has("resilience"):
		var stacks := int(target_statuses.resilience.get("stacks", 1)) - 1
		if stacks <= 0: target_statuses.erase("resilience")
		else: target_statuses.resilience.stacks = stacks
		_add_log("%s 的坚毅抵挡了致命伤害。" % target["name"])
		return result
	var wuji := String(target.get("id", "")) == "zhoumingyuan" and String(target.get("attribute", "none")) == "none"
	var may_exit := phase == ENEMY_TURN and bool(target.get("downed_at_enemy_start", false)) if wuji else bool(target.get("downed", false)) and int(target.get("downed_round", round)) < round
	if may_exit:
		target["dead"] = true
		target["downed"] = false
		var before_death := int(target.hp)
		target["hp"] = 0
		fc.hp_lost(target, before_death + hp_damage)
		_remove_caster_cards(String(target.get("id", "")))
		_add_log("%s 再次受创，退场。" % target["name"])
		result["hp"] = hp_damage
		return result
	var previous_hp := int(target["hp"])
	target["hp"] = previous_hp - hp_damage
	fc.hp_lost(target, previous_hp)
	result["hp"] = hp_damage if _is_ally_unit(target) else mini(maxi(0, previous_hp), hp_damage)
	if String(target.get("id", "")) == "zhoumingyuan" and previous_hp > int(target.get("max_hp", 0)) / 2 and int(target["hp"]) <= int(target.get("max_hp", 0)) / 2:
		_emit_story_event("zhou_half_hp")
	if String(target.get("id", "")) == "paper_large" and not bool(target.get("split_used", false)) and int(target["hp"]) <= int(target["max_hp"]) / 2:
		target["intent"] = {"name":"撕卷！", "damage":0, "kind":"split"}
	if target.has("downed") and int(target["hp"]) <= 0:
		target["downed"] = true
		target["downed_round"] = round
		_add_log("%s 陷入濒死，可以通过治疗拉回。" % target["name"])
		if String(target.get("id", "")) == "zhoumingyuan" and _first_alive(allies) >= 0 and story_rewards_enabled and not GameFlow.has_flag("fight.unlocked.hang_on"):
			GameFlow.set_flag("fight.unlocked.hang_on", true)
			if _story_ready():
				_story_rewards_waiting["hang_on"] = true
				_emit_story_event("zhou_downed")
			else:
				_grant_story_reward("hang_on")
	return result

func _story_ready() -> bool:
	return story_rewards_enabled and active_story_encounter == HighschoolData.WAREHOUSE_ENCOUNTER and _tutorial_opening_state.is_empty()

func _emit_story_event(event_id: String) -> void:
	if not _story_ready() or _story_events_seen.has(event_id):
		return
	_story_events_seen[event_id] = true
	story_input_locked = true
	story_event.emit(event_id)

func finish_story_dialogue() -> void:
	story_input_locked = false
	state_changed.emit()

func grant_story_reward(skill_id: String) -> void:
	if not _story_rewards_waiting.has(skill_id):
		return
	_story_rewards_waiting.erase(skill_id)
	_grant_story_reward(skill_id)
	state_changed.emit()

func _grant_story_reward(skill_id: String) -> void:
	if skill_id == "red_pen":
		GameFlow.set_flag("fight.unlocked.red_pen", true)
		var red_card := make_card("red_pen", "zhoumingyuan")
		red_card["free"] = true
		_grant_story_card(red_card)
		draw_pile.append(make_card("red_pen", "zhoumingyuan"))
		draw_pile.append(make_card("red_pen", "zhoumingyuan"))
		if _story_ready():
			_force_story_skill("red_pen")
		_add_log("获得红笔批注：本场首次分裂奖励，本回合可直接使用。")
	elif skill_id == "hang_on":
		var rescue_card := make_card("hang_on", "alyina")
		rescue_card["free"] = true
		if not hand.any(func(card: Dictionary) -> bool: return String(card.get("skill_id", "")) == "hang_on"):
			_grant_story_card(rescue_card)
			if _story_ready():
				_force_story_skill("hang_on")
			_add_log("艾莉娜将撑住！加入手牌，本次使用不消耗能量。")

func _force_story_skill(skill_id: String) -> void:
	if story_forced_skill == "":
		story_forced_skill = skill_id
	elif skill_id == "hang_on" and story_forced_skill != "hang_on":
		_story_resume_skill = story_forced_skill
		story_forced_skill = "hang_on"
	elif skill_id == "red_pen" and story_forced_skill == "hang_on":
		_story_resume_skill = "red_pen"

func _grant_story_card(card: Dictionary) -> void:
	if hand.size() >= expansion_hand_limit:
		discard_pile.append(hand.pop_back())
	hand.append(card)

func _ally_index(hero_id: String) -> int:
	for i in allies.size():
		if String(allies[i].get("id", "")) == hero_id:
			return i
	return -1

func healing_ceiling(target: Dictionary) -> int:
	return mini(int(target.max_hp), int(target.get("finale_heal_cap", target.max_hp)))

func _heal(target: Dictionary, amount: float) -> void:
	var active_source: Variant = get_meta("active_skill_source", -1)
	var source := int(active_source) if active_source != null else -1
	if source >= 0 and _is_ally_unit(target) and target.statuses.has("isolation") and allies.find(target) != source: return
	if fc.COMPANIONS.healing_blocked(target): return
	if amount <= 0 or bool(target.get("dead", false)):
		return
	var healing_mult := 1.0
	for status in (target.get("statuses", {}) as Dictionary).values():
		healing_mult *= float(status.get("heal_taken_mult", 1.0))
	amount = roundi(float(amount) * healing_mult)
	if amount <= 0:
		return
	var hp := int(target.get("hp", 0)) + amount
	# A transferred pool can sit one point above the seal after integer rounding.
	# Healing must not remove existing health; stage changes enforce the seal.
	target["hp"] = maxi(int(target.get("hp", 0)), mini(healing_ceiling(target), roundi(hp)))
	if bool(target.get("downed", false)):
		if int(target["hp"]) > 0:
			target["downed"] = false
			_add_log("%s 脱离濒死。" % target["name"])
	else:
		target["downed"] = false
		target["downed_round"] = -1

func _remove_caster_cards(caster_id: String) -> void:
	if caster_id.is_empty():
		return
	var pending_from_dead := pending_card >= 0 and pending_card < hand.size() and String(hand[pending_card].get("caster_id", "")) == caster_id
	for pile in [hand, draw_pile, discard_pile, fc.calculation, fc.exhausted]:
		for i in range(pile.size() - 1, -1, -1):
			if String(pile[i].get("caster_id", "")) == caster_id or String(pile[i].get("anya_actor", "")) == caster_id:
				pile.remove_at(i)
	if pending_from_dead:
		_clear_targeting()

func _add_guard(target: Dictionary, amount: int) -> void:
	var active_source: Variant = get_meta("active_skill_source", -1)
	var source := int(active_source) if active_source != null else -1
	if source >= 0 and _is_ally_unit(target) and target.statuses.has("isolation") and allies.find(target) != source: return
	if amount > 0 and _is_alive(target) and not (target.get("statuses", {}) as Dictionary).has("no_guard") and not target.statuses.has("athlete_burst"):
		target["guard"] = int(target.get("guard", 0)) + fc.PAINTING.shield_amount(target, amount)

func _damage_output_multiplier(unit: Dictionary) -> float:
	var multiplier := 1.0 + float(unit.get("damage_bonus", 0.0))
	var final_damage_bonus := 1.0
	for status in (unit.get("statuses", {}) as Dictionary).values():
		var status_multiplier := float(status.get("damage_out_mult", 1.0))
		if status_multiplier > 1.0:
			final_damage_bonus = maxf(final_damage_bonus, status_multiplier)
		else:
			multiplier *= status_multiplier
	return multiplier * final_damage_bonus

func _is_ally_unit(unit: Dictionary) -> bool:
	return unit.has("role")

func _taunt_target() -> int:
	for i in allies.size():
		if _enemy_targetable(allies[i]) and (allies[i].get("statuses", {}) as Dictionary).has("taunt"):
			return i
	return -1

func _enemy_targetable(unit: Dictionary) -> bool:
	return _is_alive(unit) and not fc.POISON.absent(unit)

func _is_alive(unit: Dictionary) -> bool:
	if bool(unit.get("anya_hidden", false)): return false
	if bool(unit.get("dead", false)):
		return false
	if bool(unit.get("downed", false)):
		return true
	if bool(unit.get("phase_pending", false)):
		return true
	return int(unit.get("hp", 0)) > 0

func _first_alive(units: Array) -> int:
	for i in units.size():
		if _is_alive(units[i]):
			return i
	return -1

func _all_enemies_defeated() -> bool:
	return _first_alive(enemies) < 0

func _all_allies_defeated() -> bool:
	return _first_alive(allies) < 0

func _finish_victory() -> void:
	if not battle_active:
		return
	if fc.ANYA.phoenix(fc): fc.ANYA.leave(fc)
	if not await _wait_for_anya_return(): return
	battle_active = false
	resolving_action = false
	fc.choice.clear()
	fc.choice_callback = Callable()
	pending_turn_draw = 0
	if active_story_encounter == HighschoolData.WAREHOUSE_ENCOUNTER:
		GameFlow.set_flag(HighschoolData.STORY_WAREHOUSE_CLEARED, true)
	active_story_encounter = ""
	var defeated_ids: Array = []
	for enemy in enemies:
		if not defeated_ids.has(String(enemy.get("id", ""))): defeated_ids.append(String(enemy.get("id", "")))
	TowerRun.register_enemy_defeats(defeated_ids)
	_clear_targeting()
	if TowerRun.active and not TowerRun.pending.is_empty():
		last_reward = TowerRun.complete_wave() if TowerRun.has_next_wave() else TowerRun.settle(true)
		battle_won.emit(last_reward)
		state_changed.emit()
		return
	var xp := 30
	var growth_rows: Array = []
	for ally in allies:
		var id := String(ally["id"])
		var before := FightProgression.hero_level(id)
		var growth := FightProgression.grant_xp(id, xp)
		growth_rows.append({"id":id, "name":ally.name, "before_level":before, "level":int(growth.level), "xp":int(growth.xp), "gained":xp})
		if int(growth.level) > before: _add_log("%s 提升到 Lv.%d，携带 cost 上限增加。" % [ally.name, growth.level])
		if int(growth.level) >= FightProgression.level_cap(): _add_log("%s 已达等级上限；经验已储存，等待夜间突破。" % ally.name)
	var money := 125
	Currency.earn(money, "battle", GameState.WALLET_NIGHT)
	Inventory.add("ink_fragment", 1, GameState.BAG_HIGHSCHOOL)
	last_reward = {"xp": xp, "money": money, "item": "ink_fragment", "item_count":1, "growth":growth_rows}
	_add_log("战斗胜利！获得经验、金钱与墨痕碎片。")
	battle_won.emit(last_reward)
	state_changed.emit()

func _finish_loss(reason: String = "队伍全员退场。战斗失败。") -> void:
	if lab_invincible_allies:
		for ally in allies:
			ally.dead = false
			ally.downed = false
			ally.hp = maxi(1, int(ally.hp))
		state_changed.emit()
		return
	if fc.ANYA.phoenix(fc): fc.ANYA.leave(fc, true, false)
	_revoke_unwon_warehouse_rewards(active_story_encounter)
	battle_active = false
	resolving_action = false
	fc.choice.clear()
	fc.choice_callback = Callable()
	pending_turn_draw = 0
	active_story_encounter = ""
	_clear_targeting()
	_add_log(reason)
	battle_lost.emit()
	state_changed.emit()

func abandon_encounter() -> void:
	if not battle_active:
		return
	if fc.ANYA.phoenix(fc): fc.ANYA.leave(fc, true, false)
	if TowerRun.active and not TowerRun.pending.is_empty(): TowerRun.settle(false, true)
	_revoke_unwon_warehouse_rewards(active_story_encounter)
	battle_active = false
	resolving_action = false
	fc.choice.clear()
	fc.choice_callback = Callable()
	pending_turn_draw = 0
	active_story_encounter = ""
	story_input_locked = false
	_clear_targeting()
	state_changed.emit()

func _revoke_unwon_warehouse_rewards(encounter: String) -> void:
	if encounter != HighschoolData.WAREHOUSE_ENCOUNTER or GameFlow.has_flag(HighschoolData.STORY_WAREHOUSE_CLEARED):
		return
	GameFlow.set_flag("fight.unlocked.red_pen", false)
	GameFlow.set_flag("fight.unlocked.hang_on", false)
	# A retry cannot start with rewards that only exist inside the unfinished attempt.
	for key in GameState.fight_loadouts.keys():
		var original: Array = GameState.fight_loadouts[key]
		if not original.has("red_pen") and not original.has("hang_on"): continue
		var cards: Array = original.filter(func(id: String) -> bool: return id not in ["red_pen", "hang_on"])
		var hero_id := String(key).split("@")[0]
		for id in FightData.default_loadout(hero_id):
			if cards.size() >= initial_deck_size(hero_id): break
			if cards.count(id) < FightData.copies(id) and loadout_points(cards) + FightData.skill_points(id) <= skill_point_limit(hero_id): cards.append(id)
		GameState.fight_loadouts[key] = cards

func _add_log(text: String, notify_ui: bool = true) -> void:
	log_lines.append(text)
	if notify_ui: message_added.emit(text)

func get_allies() -> Array: return allies
func get_enemies() -> Array: return enemies
func get_hand() -> Array: return hand.duplicate(true)
func get_draw_count() -> int: return draw_pile.size()
func get_discard_count() -> int: return discard_pile.size()
func get_log() -> Array: return log_lines.duplicate()
func get_phase_label() -> String: return "我方回合" if phase == PLAYER_TURN else "敌方回合"

