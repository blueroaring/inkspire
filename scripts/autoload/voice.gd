extends Node
## 配音系统（自动加载单例 Voice）
##
## 定位：把"这一句台词该放哪段语音"从对话框里彻底剥离出来。
## 对话框只写 `"voice": "<ID>"`，解析 / 播放 / 打断 / 音量 / 缺素材兜底全在这里。
##
## 解析顺序：
##   1. `spec` 是 AudioStream                        -> 直接用
##   2. `spec` 是 Dictionary 且带 file/path          -> 用它的文件 + pitch / volume_db
##   3. `spec` 是 "res://..." 路径                   -> 直接用
##   4. `spec` 是台词 ID：先查 VoiceBank.LINES 登记，再按
##      `res://assets/audio/voice/<角色目录>/<ID>.<ogg|wav|mp3>` 约定猜
##
## **找不到素材时静默跳过**（返回 false）并把 ID 记进 `missing_log`：
## 配音还没录的现在，对话照常走、控制台不刷报错 —— 这正是"先做系统、后加素材"的关键。

signal started(id: String)
signal finished(id: String)

## 缺素材的台词（去重，最多记 200 条），供启动自检 / 走查报告用
var missing_log: Array[String] = []

var _player: AudioStreamPlayer
var _current_id := ""
var _cache: Dictionary = {}


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "VoicePlayer"
	_player.bus = AudioManager.BUS_VOICE
	add_child(_player)
	_player.finished.connect(_on_player_finished)
	AudioManager.voice_availability_changed.connect(func(enabled: bool) -> void:
		if not enabled: stop())


# ---------------------------------------------------------------- 对外 API

## 播放一条配音。返回 true 表示真的播起来了；暂停配音或没素材时返回 false。
## 新台词会打断上一句（同一时刻只播一条，符合 galgame 习惯）。
func play(spec: Variant, speaker: String = "") -> bool:
	stop()
	if not Settings.all_voice_enabled() or not bool(Settings.get_value("dialogue", "voice_enabled", true)) or not AudioManager.SPEECH_ENABLED:
		return false
	if spec == null:
		return false
	var stream := resolve(spec, speaker)
	if stream == null:
		_note_missing(spec, speaker)
		return false
	_current_id = _id_of(spec)
	_player.stream = stream
	_player.pitch_scale = _pitch_of(spec, speaker)
	_player.volume_db = _volume_of(spec, speaker)
	_player.play()
	started.emit(_current_id)
	return true


## 停止当前配音（没有在播时是空操作）
func stop() -> void:
	if _player == null:
		return
	var was_playing := _player.playing
	_player.stop()
	var finished_id := _current_id
	_current_id = ""
	if was_playing:
		finished.emit(finished_id)


func is_playing() -> bool:
	return _player != null and _player.playing


func current_id() -> String:
	return _current_id


## 等当前配音播完（没在播时立刻返回）
func wait_finished() -> void:
	while is_playing():
		await get_tree().process_frame


## 解析出可播放的音频流；没素材返回 null（不报错）
func resolve(spec: Variant, speaker: String = "") -> AudioStream:
	if spec == null:
		return null
	if spec is AudioStream:
		return spec as AudioStream
	if spec is Dictionary:
		var d: Dictionary = spec
		var f := String(d.get("file", d.get("path", "")))
		return _load(f) if f != "" else null
	var id := String(spec)
	if id == "":
		return null
	if id.begins_with("res://"):
		return _load(id)
	var mapped := VoiceBank.line_path(id)
	if mapped != "":
		var s := _load(mapped)
		if s != null:
			return s
	for candidate in VoiceBank.guess_candidates(speaker, id):
		var s2 := _load(candidate)
		if s2 != null:
			return s2
	return null


## 这条 spec 能不能播（不产生播放副作用，供调试/自检用）
func can_play(spec: Variant, speaker: String = "") -> bool:
	return resolve(spec, speaker) != null


func missing_count() -> int:
	return missing_log.size()


func clear_missing() -> void:
	missing_log.clear()


## 扫一遍配音素材目录，列出已有文件（启动自检 / 走查报告用）。
## 目录不存在时返回空数组——不是错误，只是"还没录"。
func scan_assets() -> PackedStringArray:
	var out := PackedStringArray()
	_scan_dir(VoiceBank.ROOT, out)
	return out


## 表里登记了、但文件缺失的台词（这个才是真的问题：登记了就该有）
func missing_declared() -> Array:
	var out: Array = []
	for id: String in VoiceBank.declared_ids():
		var path := VoiceBank.line_path(id)
		if path != "" and not ResourceLoader.exists(path):
			out.append("%s -> %s" % [id, path])
	return out


# ---------------------------------------------------------------- 内部

func _on_player_finished() -> void:
	var finished_id := _current_id
	_current_id = ""
	finished.emit(finished_id)


func _load(path: String) -> AudioStream:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path] as AudioStream
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	_cache[path] = stream
	return stream


func _id_of(spec: Variant) -> String:
	if spec is Dictionary:
		return String((spec as Dictionary).get("id", "voice"))
	if spec is AudioStream:
		return (spec as AudioStream).resource_path
	return String(spec)


func _pitch_of(spec: Variant, speaker: String) -> float:
	if spec is Dictionary:
		return float((spec as Dictionary).get("pitch", VoiceBank.speaker_pitch(speaker)))
	return VoiceBank.speaker_pitch(speaker)


func _volume_of(spec: Variant, speaker: String) -> float:
	if spec is Dictionary:
		return float((spec as Dictionary).get("volume_db", VoiceBank.speaker_volume_db(speaker)))
	return VoiceBank.speaker_volume_db(speaker)


func _note_missing(spec: Variant, speaker: String) -> void:
	var who := speaker if speaker != "" else "?"
	var label := "%s / %s" % [who, _id_of(spec)]
	if missing_log.size() >= 200 or missing_log.has(label):
		return
	missing_log.append(label)


func _scan_dir(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_scan_dir(full, out)
		elif not name.ends_with(".import"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
