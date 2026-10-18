extends Node
## 存档系统（自动加载单例 SaveSystem）
##
## 职责：5 个存档槽的读写 / 删除 / 元数据列举。只做"存"，不管 UI。
## 存储布局：
##   user://saves/slot_1/save.json    进度数据（GameState 序列化）
##   user://saves/slot_1/shot.png     存档截图
## 存档格式带 version 字段，将来加字段时在 _migrate() 里做兼容。

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 1
const MAX_SLOTS := 5

## 临时剧情测试会话禁止所有存档写入，包括剧情内部的自动保存。
var session_read_only := false

## 截图尺寸（小图足够存档槽界面显示，也省磁盘）
const SHOT_WIDTH := 480
const SHOT_HEIGHT := 270

signal saved(slot: int)
signal loaded(slot: int)
signal deleted(slot: int)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func slot_dir(slot: int) -> String:
	return "%s/slot_%d" % [SAVE_DIR, slot]


func save_path(slot: int) -> String:
	return "%s/save.json" % slot_dir(slot)


func shot_path(slot: int) -> String:
	return "%s/shot.png" % slot_dir(slot)


func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= MAX_SLOTS


func has_save(slot: int) -> bool:
	if not is_valid_slot(slot):
		return false
	return FileAccess.file_exists(save_path(slot))


## 列出全部槽位状态，供"读取存档"界面直接绑定。
## 返回 [{ index, empty, meta: {...} }, ...]
func list_slots() -> Array:
	var out: Array = []
	for slot in range(1, MAX_SLOTS + 1):
		var meta := read_meta(slot)
		out.append({
			"index": slot,
			"empty": meta.is_empty(),
			"meta": meta,
		})
	return out


## 只读存档头部信息，不恢复游戏状态
func read_meta(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var data := _read_json(save_path(slot))
	if data.is_empty():
		return {}
	return data.get("meta", {})


func delete_slot(slot: int) -> void:
	if not is_valid_slot(slot):
		return
	var dir := slot_dir(slot)
	_remove_if_exists(save_path(slot))
	_remove_if_exists(shot_path(slot))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	deleted.emit(slot)


## 保存当前 GameState 到槽位。
## 调用后 game 会切到新槽位（GameState.slot = slot）。
##
## ⚠️ **对话回顾（backlog）跟着存档走**（用户 2026-09-20 实报："从 A 存档退出、进入 B 存档，
##    会保存上个存档的对话内容，应该是每个存档的回顾是独立的"）。
##    所以这里把 `DialogueBox` 的回顾一起写进 `history` 键，读档时再还回去 ——
##    回顾的**真身**始终是 `DialogueBox`（它是跨场景常驻的单例），
##    存档只是它的一份快照；这样"新游戏 / 读档"两条入口都不会串味。
##    ⚠️ 它**不在** `GameState` 里：那是"进度数据"，而回顾是 UI 状态
##    （主菜单、开场 CG 阶段都还没有它）。
func save_to_slot(slot: int, state: Dictionary = {}, capture_screenshot: bool = true) -> bool:
	if session_read_only:
		return false
	if not is_valid_slot(slot):
		push_warning("SaveSystem: 非法槽位 %d" % slot)
		return false

	DirAccess.make_dir_recursive_absolute(slot_dir(slot))

	var payload_state := state if not state.is_empty() else GameState.to_dict()
	if state.is_empty() and SpiritSystem.run != null and not SpiritSystem.committed:
		payload_state = SpiritSystem.entry_snapshot.duplicate(true)
		payload_state["location"] = SpiritSystem.save_location()
		payload_state["spawn_point"] = SpiritSystem.origin_spawn
	payload_state["slot"] = slot
	GameState.slot = slot

	var data := {
		"version": SAVE_VERSION,
		"meta": build_meta(slot, payload_state),
		"state": payload_state,
		"history": _history_snapshot(),
	}

	var f := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: 无法写入 %s（错误码 %d）" % [save_path(slot), FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(data, "\t", false))
	f.close()

	if capture_screenshot:
		_capture_screenshot.call_deferred(slot)

	saved.emit(slot)
	return true


## 读取槽位并恢复到 GameState。返回是否成功。
func load_from_slot(slot: int) -> bool:
	if not has_save(slot):
		push_warning("SaveSystem: 槽位 %d 没有存档" % slot)
		return false
	var data := _read_json(save_path(slot))
	if data.is_empty():
		return false
	data = _migrate(data)
	var state: Dictionary = data.get("state", {})
	if state.is_empty():
		return false
	GameState.from_dict(state)
	GameState.slot = slot
	# 回顾一起还回去：**先清空再还原**，这样"这个槽没有 history 键"（旧存档）
	# 或"读档失败"都不会把上一个槽的台词留在面板里。
	DialogueBox.restore_history(data.get("history", []))
	loaded.emit(slot)
	return true


## 当前回顾的快照（写成 JSON 友好的纯数据）。
## 只留"人看得见"的三样：说话人 / 正文 / 情绪。
func _history_snapshot() -> Array:
	var out: Array = []
	for entry_variant in DialogueBox.history_entries():
		var entry: Dictionary = entry_variant
		out.append({
			"speaker": String(entry.get("speaker", "")),
			"text": String(entry.get("text", "")),
			"emotion": String(entry.get("emotion", "")),
		})
	return out


## 生成存档元数据：章节 / 地点 / 游戏内时间 / 游玩时长 / 真实时间
func build_meta(slot: int, state: Dictionary) -> Dictionary:
	var location := String(state.get("location", ""))
	return {
		"slot": slot,
		"chapter": int(state.get("chapter", 0)),
		"chapter_name": chapter_name(int(state.get("chapter", 0))),
		"phase": String(state.get("phase", "day")),
		"location": location,
		"location_name": GameState.LOCATION_NAMES.get(location, location),
		"in_game_time": _format_minutes(int(state.get("in_game_minutes", 0))),
		"played_seconds": float(state.get("played_seconds", 0.0)),
		"played_text": format_played(float(state.get("played_seconds", 0.0))),
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"has_screenshot": FileAccess.file_exists(shot_path(slot)),
	}


func chapter_name(chapter: int) -> String:
	match chapter:
		GameState.CHAPTER_COLLEGE:
			return "序章 · 大学"
		_:
			return "第 %d 章" % chapter


## 秒数 -> "3小时42分"
func format_played(seconds: float) -> String:
	var total := int(seconds)
	var h := int(total / 3600.0)
	var m := int((total % 3600) / 60.0)
	if h > 0:
		return "%d小时%d分" % [h, m]
	return "%d分" % m


func _format_minutes(minutes: int) -> String:
	return "%02d:%02d" % [int(minutes / 60) % 24, minutes % 60]


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveSystem: %s 解析失败" % path)
		return {}
	return parsed


## 旧版本存档兼容入口（当前无历史版本，先把口子留好）
func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version == SAVE_VERSION:
		return data
	# 未来：if version < 2: ...
	data["version"] = SAVE_VERSION
	return data


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 抓取当前画面存成存档截图（延迟到帧渲染后执行，避免读不到纹理）。
## 注意：此时机晚于存档写盘，所以元数据里的 has_screenshot 只代表"上次保存时"的状态；
## 界面判断有没有截图请直接看 shot_path() 是否存在（见 has_screenshot()）。
func _capture_screenshot(slot: int) -> void:
	await RenderingServer.frame_post_draw
	if session_read_only: return
	var vp := get_viewport()
	if vp == null:
		return
	var tex := vp.get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	img.resize(SHOT_WIDTH, SHOT_HEIGHT, Image.INTERPOLATE_BILINEAR)
	DirAccess.make_dir_recursive_absolute(slot_dir(slot))
	var err := img.save_png(shot_path(slot))
	if err != OK:
		push_warning("SaveSystem: 存档截图写入失败（错误码 %d）" % err)


## 该槽位当前是否真的有截图文件（UI 用这个，而不是元数据字段）
func has_screenshot(slot: int) -> bool:
	return is_valid_slot(slot) and FileAccess.file_exists(shot_path(slot))


## 载入存档槽的截图（没有则返回 null，UI 显示占位）
func load_screenshot(slot: int) -> Texture2D:
	var path := shot_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)
