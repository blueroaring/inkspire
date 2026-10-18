extends Node
## 独立练习与剧情灵境共用事务；剧情调用 enter_story_tutorial() 后回到原场景和出生点。

var run: SpiritRun
var entry_snapshot: Dictionary = {}
var entry_hp := 0
var entry_max_hp := 0
var entry_stock: Dictionary = {}
var origin_location := "main_menu"
var origin_spawn := ""
var return_to_list := true
var committed := false
var persistence_enabled := true
var keyboard_confirm := true
var _practice_loaded := false
const PRACTICE_PATH := "user://spirit_practice.json"

func open_list() -> void:
	if GameState.location not in ["spirit.list", "spirit.realm"]:
		origin_location = GameState.location if GameState.LOCATIONS.has(GameState.location) else "main_menu"
		origin_spawn = GameState.spawn_point
	if GameState.slot < 0 and not _practice_loaded:
		_practice_loaded = true
		if FileAccess.file_exists(PRACTICE_PATH):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRACTICE_PATH))
			if data is Dictionary: GameState.spirit_progress = data
	keyboard_confirm = bool(GameState.spirit_progress.get("keyboard_confirm", true))
	await SceneRouter.go_to("spirit.list")

func create_run(id: String) -> bool:
	var definition := SpiritLevels.find(id)
	if definition.is_empty(): return false
	entry_snapshot = GameState.to_dict().duplicate(true)
	entry_max_hp = FightSystem.hero_max_hp("alyina")
	entry_hp = int(GameState.fight_health.get("alyina", entry_max_hp))
	entry_stock = GameState.spirit_progress.get("bridges", {}).duplicate(true)
	committed = false
	run = load("res://scripts/spirit/clinic_coop_run.gd").new() if id == "clinic-key" else SpiritRun.new()
	run.setup(definition, entry_hp, entry_max_hp, entry_stock)
	return true

func enter_level(id: String, destination: String = "spirit.list", destination_spawn: String = "") -> void:
	return_to_list = destination == "spirit.list"
	if not return_to_list:
		origin_location = destination
		origin_spawn = destination_spawn if destination_spawn != "" else GameState.spawn_point
	if create_run(id): await SceneRouter.go_to("spirit.clinic_key" if id == "clinic-key" else "spirit.realm")

func enter_story_tutorial(destination: String = "", destination_spawn: String = "") -> void:
	var return_location := GameState.location if destination.is_empty() else destination
	if not GameState.LOCATIONS.has(return_location) or return_location.begins_with("spirit."): return
	await enter_level("story-tutorial", return_location, destination_spawn)

func reset_attempt(from_start: bool = false) -> void:
	if run == null or committed: return
	if not from_start and run.restore_checkpoint(): return
	run.setup(run.level, entry_hp, entry_max_hp, entry_stock)

func set_confirm(enabled: bool) -> void:
	keyboard_confirm = enabled
	GameState.spirit_progress["keyboard_confirm"] = enabled
	# 控制偏好不属于需要随失败回退的资源。
	if not entry_snapshot.is_empty():
		entry_snapshot["spirit_progress"]["keyboard_confirm"] = enabled

func complete() -> Dictionary:
	if run == null or run.status != "won" or committed: return {}
	committed = true
	var id := String(run.level["id"])
	var clears: Dictionary = GameState.spirit_progress.get("cleared", {}).duplicate(true)
	var first_clear := not clears.has(id)
	var best := mini(int(clears.get(id, {}).get("best_steps", 999999)), run.spent)
	clears[id] = {"best_steps": best}
	GameState.spirit_progress["cleared"] = clears
	if id == "story-tutorial" and not return_to_list: GameState.set_flag("spirit_story_tutorial_complete")
	if id == "clinic-key" and not return_to_list:
		if not Inventory.has(HighschoolMiddayData.KEY_ITEM, 1, GameState.BAG_HIGHSCHOOL):
			Inventory.add(HighschoolMiddayData.KEY_ITEM, 1, GameState.BAG_HIGHSCHOOL)
		GameFlow.set_flag(HighschoolMiddayData.FLAG_KEY, true)
		HighschoolRewindData.record_choice("clinic_key")
		HighschoolRewindData.set_stage(HighschoolMiddayData.RECOVER)
	var stock := run.bridges.duplicate(true)
	if first_clear:
		for bridge_id in run.level.get("clear_bridges", {}):
			stock[bridge_id] = int(stock.get(bridge_id, 0)) + int(run.level["clear_bridges"][bridge_id])
	GameState.spirit_progress["bridges"] = stock
	GameState.spirit_progress["keyboard_confirm"] = keyboard_confirm
	if id != "clinic-key": GameState.fight_health["alyina"] = run.hp
	var reward := run.pending_rewards.duplicate(true)
	if first_clear:
		for field in reward: reward[field] += int(run.level.get("clear_reward", {}).get(field, 0))
	FightProgression.grant_xp("alyina", int(reward["xp"]))
	if int(reward["money"]) > 0: Currency.earn(int(reward["money"]), "spirit", GameState.WALLET_NIGHT)
	if int(reward["fragments"]) > 0: Inventory.add("ink_fragment", int(reward["fragments"]), GameState.BAG_HIGHSCHOOL)
	if persistence_enabled:
		if GameState.slot > 0:
			var save_state := GameState.to_dict().duplicate(true)
			save_state["location"] = save_location()
			save_state["spawn_point"] = origin_spawn
			save_state["last_play_location"] = entry_snapshot.get("last_play_location", "")
			SaveSystem.save_to_slot(GameState.slot, save_state, false)
		else:
			var file := FileAccess.open(PRACTICE_PATH, FileAccess.WRITE)
			if file != null: file.store_string(JSON.stringify(GameState.spirit_progress))
	return reward

func rollback() -> void:
	if not committed and not entry_snapshot.is_empty(): GameState.from_dict(entry_snapshot.duplicate(true))
	run = null
	entry_snapshot = {}
	committed = false

func save_location() -> String:
	if origin_location == "main_menu":
		var anchor := String(entry_snapshot.get("last_play_location", ""))
		if anchor != "" and not anchor.begins_with("spirit.") and GameState.LOCATIONS.has(anchor): return anchor
	return origin_location

func leave_level() -> void:
	rollback()
	await SceneRouter.go_to("spirit.list" if return_to_list else origin_location, "" if return_to_list else origin_spawn)

func close_list() -> void:
	await SceneRouter.go_to(origin_location, origin_spawn)
