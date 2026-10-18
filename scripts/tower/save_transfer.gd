extends RefCounted
## Version-independent saves and portable transfers; no story data is accessed.
const CRYPTO := preload("res://scripts/tower/report_crypto.gd")
const MAX_FILE_BYTES := 128 * 1024 * 1024
const FORMAT := "inkspire-transfer-v1"

static func valid_save(value: Variant) -> bool:
	if not value is Dictionary or int(value.get("version", 0)) != 1: return false
	for key in ["state", "health", "lessons", "clears", "shop"]:
		if not value.get(key) is Dictionary: return false
	if not value.get("battles") is Array: return false
	for key in ["highest", "shards", "battle_count", "victories", "seed", "seconds"]:
		if not (value.get(key) is int or value.get(key) is float): return false
	if int(value.highest) < 0 or int(value.battle_count) < 0: return false
	if not value.get("nickname") is String: return false
	for key in TowerRun.STATE_KEYS:
		if not value.state.has(key): continue
		if key in ["fight_formation", "fight_unlocked_attributes"]:
			if not value.state[key] is Array: return false
		else:
			if not value.state[key] is Dictionary: return false
	return value.state.get("fight_profiles") is Dictionary and value.state.get("fight_formation") is Array

static func decode_save(raw: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(raw) != OK: return {}
	var parsed: Variant = parser.data
	var integrity := "legacy"
	if parsed is Dictionary and parsed.get("schema") == CRYPTO.SCHEMA:
		var opened := CRYPTO.open(parsed, "save")
		if opened.is_empty(): return {}
		integrity = "verified" if opened.get("integrity") == "verified" else "legacy"
		parsed = opened.get("data")
	if not valid_save(parsed): return {}
	parsed["_loaded_integrity"] = integrity
	return parsed

static func read_bounded(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES: return ""
	return file.get_as_text()

static func file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else -1

static func write_file(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(contents)
	file.flush()
	return file.get_error() == OK

static func journal_path(selected_slot: int) -> String:
	return "%s/slot_%d_battles.jsonl" % [TowerRun.save_root, selected_slot]

static func backup_slot(selected_slot: int, reason: String) -> String:
	var folder := "%s/migration_backups/%s-slot%d-%d-%d" % [TowerRun.save_root, reason, selected_slot, int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return ""
	for path in [TowerRun.path_for(selected_slot), TowerRun.path_for(selected_slot) + ".bak", journal_path(selected_slot)]:
		if FileAccess.file_exists(path) and DirAccess.copy_absolute(path, folder.path_join(path.get_file())) != OK: return ""
	return folder

static func export_bundle(path: String) -> bool:
	if TowerRun.read_only or TowerRun.data.is_empty() or not TowerRun.pending.is_empty() or not TowerRun.lesson_backup.is_empty():
		TowerRun.error = "请返回尖塔，在战斗结束后导出迁移包。"
		return false
	if not TowerRun.save_game(): return false
	var save := read_bounded(TowerRun.path_for(TowerRun.slot))
	var history_path := journal_path(TowerRun.slot)
	var history := read_bounded(history_path) if FileAccess.file_exists(history_path) else ""
	if save.is_empty() or (history.is_empty() and FileAccess.file_exists(history_path) and file_size(history_path) != 0):
		TowerRun.error = "存档或战斗记录过大，无法生成迁移包。"
		return false
	var envelope := CRYPTO.seal({"format":FORMAT, "save":save, "journal":history}, "transfer")
	if envelope.is_empty() or not write_file(path, JSON.stringify(envelope)):
		TowerRun.error = "迁移包写入失败，请选择可写入的文件夹。"
		return false
	return true

static func inspect_import(path: String) -> Dictionary:
	var raw := read_bounded(path)
	var history := ""
	var parser := JSON.new()
	if parser.parse(raw) != OK: return {}
	var parsed: Variant = parser.data
	if parsed is Dictionary and parsed.get("schema") == CRYPTO.SCHEMA and parsed.get("purpose") == "transfer":
		var bundle := CRYPTO.open(parsed, "transfer")
		if bundle.get("format") != FORMAT or not bundle.get("save") is String or not bundle.get("journal") is String: return {}
		raw = bundle.save
		history = bundle.journal
	else:
		# The original 0.1.0 slot and its adjacent journal can be imported directly.
		var history_path := path.trim_suffix(".bak").trim_suffix(".json") + "_battles.jsonl"
		if FileAccess.file_exists(history_path):
			history = read_bounded(history_path)
			if history.is_empty() and file_size(history_path) != 0: return {}
	var saved := decode_save(raw)
	if saved.is_empty(): return {}
	for line in history.split("\n", false):
		if parser.parse(line) != OK: return {}
		var entry: Variant = parser.data
		if not entry is Dictionary: return {}
		if entry.get("schema") == CRYPTO.SCHEMA and CRYPTO.open(entry, "battle").is_empty(): return {}
	return {"save":saved, "raw":raw, "journal":history}

static func import_bundle(path: String, selected_slot: int) -> bool:
	TowerRun.error = ""
	if TowerRun.read_only or selected_slot < 1 or selected_slot > 3 or FightSystem.battle_active or not TowerRun.pending.is_empty():
		TowerRun.error = "当前无法导入，请先回到尖塔存档界面。"
		return false
	var imported := inspect_import(path)
	if imported.is_empty():
		TowerRun.error = "文件不是有效的尖塔存档或迁移包，或校验未通过；原有存档未改动。"
		return false
	var backup := backup_slot(selected_slot, "before-import")
	if backup.is_empty():
		TowerRun.error = "备份原槽位失败，已取消导入。"
		return false
	var target := TowerRun.path_for(selected_slot)
	var journal := journal_path(selected_slot)
	if not write_file(target + ".importing", imported.raw) or not write_file(journal + ".importing", imported.journal):
		TowerRun.error = "迁移文件写入失败，原有存档未改动。"
		return false
	# Save is the commit point. If either rename fails, recover both original files.
	if DirAccess.rename_absolute(journal + ".importing", journal) != OK or DirAccess.rename_absolute(target + ".importing", target) != OK:
		for destination in [target, journal]:
			var original := backup.path_join(destination.get_file())
			if FileAccess.file_exists(original): DirAccess.copy_absolute(original, destination)
			elif FileAccess.file_exists(destination): DirAccess.remove_absolute(destination)
		TowerRun.error = "导入替换失败，已恢复原槽位。"
		return false
	if not TowerRun.load_game(selected_slot): return false
	TowerRun.notice = "存档已迁入第 %d 槽，角色、卡组、装备、商店和战斗记录已恢复。原槽位备份保存在 migration_backups。" % selected_slot
	return true
