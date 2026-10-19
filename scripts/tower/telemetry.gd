extends Node
## Private, bounded gameplay statistics. No nickname, save, narrative or free text.
const CRYPTO := preload("res://scripts/tower/report_crypto.gd")
const ENDPOINT := "https://inkspire-game.freemyip.com/api/telemetry"
const MAX_BYTES := 48000
const MAX_BATTLES := 30
var queue_path := "user://tower/telemetry_queue.json"
var endpoint := ENDPOINT
var enabled_build := false
var queue: Dictionary = {}
var request: HTTPRequest
var sending_key := ""
var sending_body := ""
var quitting := false

static func identifier(value: Variant) -> String:
	var text := String(value)
	if text.length() > 80: return ""
	for c in text:
		if not (c >= "a" and c <= "z" or c >= "A" and c <= "Z" or c >= "0" and c <= "9" or c in ["_", "-", "@", "."]): return ""
	return text

static func units(values: Array) -> Array:
	var result := []
	for unit: Dictionary in values.slice(0, 8):
		result.append({"id":identifier(unit.get("id", "")), "attribute":identifier(unit.get("attribute", "none")), "level":maxi(0, int(unit.get("level", 1))), "hp":maxi(0, int(unit.get("hp", 0))), "max_hp":maxi(0, int(unit.get("max_hp", 0)))})
	return result

static func snapshot(data: Dictionary, platform: String) -> Dictionary:
	if int(data.get("highest", 0)) < 20 or String(data.get("run_id", "")).is_empty(): return {}
	var result := {"schema":"inkspire-telemetry-v1", "build":TowerData.VERSION, "run_hash":("inkspire-anonymous-v1:" + String(data.run_id)).sha256_text(), "platform":platform, "highest":int(data.highest), "battle_count":int(data.get("battle_count", 0)), "victories":int(data.get("victories", 0)), "seconds":maxi(0, int(data.get("seconds", 0))), "battles":[]}
	for battle: Dictionary in data.get("battles", []).slice(-MAX_BATTLES):
		var skills := {}
		for action: Dictionary in battle.get("actions", []):
			var skill := identifier(action.get("skill", ""))
			if not skill.is_empty() and (skills.has(skill) or skills.size() < 48): skills[skill] = int(skills.get(skill, 0)) + 1
		result.battles.append({"build":identifier(battle.get("build", "")), "mode":identifier(battle.get("mode", "tower")), "floor":maxi(0, int(battle.get("floor", 0))), "outcome":identifier(battle.get("outcome", "interrupted")), "rounds":maxi(0, int(battle.get("rounds", 0))), "duration_ms":maxi(0, int(battle.get("duration_ms", 0))), "party":units(battle.get("party", [])), "enemies":units(battle.get("enemies", [])), "end_party":units(battle.get("end_party", [])), "skills":skills})
	return result

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled_build = enabled_build or OS.has_feature("tower_release")
	if not enabled_build: return # Editor and test runs never contact the official site.
	get_tree().auto_accept_quit = false
	request = HTTPRequest.new()
	request.timeout = 10.0
	request.use_threads = false # Nonblocking polling also makes exit cancellation bounded.
	request.request_completed.connect(_completed)
	add_child(request)
	if not OS.has_feature("web") and FileAccess.file_exists(queue_path):
		var file := FileAccess.open(queue_path, FileAccess.READ)
		if file != null and file.get_length() <= MAX_BYTES * 9:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				for key in parsed.keys().slice(0, 8):
					if parsed[key] is String and parsed[key].to_utf8_buffer().size() <= MAX_BYTES: queue[key] = parsed[key]
	Settings.setting_changed.connect(func(section: String, key: String, _value: Variant) -> void:
		if section == "privacy" and key == "anonymous_tower_data": _configure())
	_configure()
	if allowed(): flush() # Retry an earlier interrupted/offline exit without a popup.

func allowed() -> bool:
	return enabled_build and bool(Settings.get_value("privacy", "anonymous_tower_data", true))

func _web(code: String) -> void:
	if OS.has_feature("web"): JavaScriptBridge.eval("if(window.inkspireTelemetry){" + code + "}")

func _configure() -> void:
	_web("window.inkspireTelemetry.configure(" + str(allowed()).to_lower() + ");")
	if not allowed():
		queue.clear()
		if is_instance_valid(request): request.cancel_request()
		sending_key = ""
		_persist()

func capture(data: Dictionary) -> void:
	if not allowed() or TowerRun.read_only or TowerRun.save_root != TowerRun.SAVE_ROOT: return
	var payload := snapshot(data, "web" if OS.has_feature("web") else "android" if OS.has_feature("android") else "windows")
	if payload.is_empty(): return
	var body := JSON.stringify(CRYPTO.seal(payload, "telemetry"))
	while body.to_utf8_buffer().size() > MAX_BYTES and not payload.battles.is_empty():
		payload.battles.pop_front()
		body = JSON.stringify(CRYPTO.seal(payload, "telemetry"))
	if body == "{}" or body.to_utf8_buffer().size() > MAX_BYTES: return
	var key: String = payload.run_hash + ":" + payload.build
	if OS.has_feature("web"):
		_web("window.inkspireTelemetry.stage(" + JSON.stringify(key) + "," + JSON.stringify(body) + ");")
		return # Browser owns its durable queue and HTTP acknowledgements.
	if queue.size() >= 8 and not queue.has(key): queue.erase(queue.keys()[0])
	queue[key] = body
	_persist()
	_web("window.inkspireTelemetry.stage(" + JSON.stringify(key) + "," + JSON.stringify(body) + ");")

func _persist() -> void:
	DirAccess.make_dir_recursive_absolute(queue_path.get_base_dir())
	var file := FileAccess.open(queue_path + ".tmp", FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(queue))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if ok: DirAccess.rename_absolute(queue_path + ".tmp", queue_path)

func flush() -> void:
	if not allowed(): return
	if OS.has_feature("web"):
		_web("window.inkspireTelemetry.flush();")
		return
	if not sending_key.is_empty() or queue.is_empty(): return
	sending_key = String(queue.keys()[0])
	sending_body = queue[sending_key]
	var error := request.request(endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, sending_body)
	if error != OK: sending_key = "" # Durable queue retries on the next launch.

func _completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var success := result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
	if success and queue.get(sending_key) == sending_body:
		queue.erase(sending_key)
		_persist()
	sending_key = ""
	if success: flush()
	if quitting and (not success or queue.is_empty()): get_tree().quit()

func save_and_flush() -> void:
	if TowerRun.active and not TowerRun.data.is_empty(): TowerRun.save_game()
	flush()

func request_quit() -> void:
	if quitting: return
	save_and_flush()
	if OS.has_feature("web"): return
	quitting = true
	if not allowed() or queue.is_empty(): get_tree().quit(); return
	if OS.has_feature("windows") and DisplayServer.get_name() != "headless": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	# Never make quitting depend indefinitely on the network. The saved queue retries.
	await get_tree().create_timer(2.0, true, false, true).timeout
	request.cancel_request()
	get_tree().quit()

func _notification(what: int) -> void:
	if not enabled_build: return
	if what == NOTIFICATION_WM_CLOSE_REQUEST: request_quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED: save_and_flush()
	elif what == NOTIFICATION_APPLICATION_RESUMED: flush()
