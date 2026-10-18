extends Node
## Only autoloaded by the Android tower build; desktop can opt in for UI tests.
const SCREEN := Vector2(1920, 1080)

static func enabled() -> bool:
	return OS.has_feature("android") or bool(Engine.get_meta("tower_mobile_preview", false))

static func content_rect(viewport: Viewport) -> Rect2:
	var whole := viewport.get_visible_rect()
	if not enabled() or not OS.has_feature("android"): return whole
	var physical := Vector2(DisplayServer.window_get_size())
	if physical.x <= 0 or physical.y <= 0: return whole
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0: return whole
	var ratio := whole.size / physical
	return Rect2(Vector2(safe.position) * ratio, Vector2(safe.size) * ratio).intersection(whole)

static func fit(root: Control, viewport: Viewport) -> void:
	var area := content_rect(viewport)
	var factor := minf(area.size.x / SCREEN.x, area.size.y / SCREEN.y)
	root.scale = Vector2.ONE * factor
	root.position = area.position + (area.size - SCREEN * factor) * 0.5

func _ready() -> void:
	if not enabled(): return
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().quit_on_go_back = false
	Input.emulate_mouse_from_touch = true
	if OS.has_feature("android"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		var tower := get_node_or_null("/root/TowerRun")
		if tower != null and tower.active and not tower.data.is_empty(): tower.save_game()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Forward to existing cancel handlers; Android Back must never kill a run.
		var event := InputEventAction.new()
		event.action = "ui_cancel"
		event.pressed = true
		Input.parse_input_event(event)
		var release := InputEventAction.new()
		release.action = "ui_cancel"
		Input.parse_input_event(release)
