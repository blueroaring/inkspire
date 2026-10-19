extends Node
## A touch commits its mouse click on release; scrolling never presses a child.
const SCREEN := Vector2(1920, 1080)
const POINTER_DEVICE := 8721
var _finger := -1
var _origin := Vector2.ZERO
var _last := Vector2.ZERO
var _dragged := false
var _slider_drag := false
var _target: Control
var _scrolls: Array[Control] = []
var _held := 0.0
var _explained := false
var _paused_by_app := false
var _previous_paused := false
var _previous_mute := false
var _previous_mouse_emulation := true
var _back_stack: Array[Dictionary] = []
var _input_focus: Control
var _focus_position := Vector2.ZERO
static var _browser_touch := -1

static func enabled() -> bool:
	if bool(Engine.get_meta("tower_mobile_preview", false)): return true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null: return false
	var tower := tree.root.get_node_or_null("TowerRun")
	var in_tower: bool = OS.has_feature("tower_release") or (tower != null and tower.active)
	if not in_tower: return false
	if OS.has_feature("android"): return true
	if OS.has_feature("web"):
		if _browser_touch < 0: _browser_touch = 1 if DisplayServer.is_touchscreen_available() or bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0 || matchMedia('(pointer: coarse)').matches")) else 0
		return _browser_touch == 1
	return false

static func touch_extent(control: Control) -> float:
	# Convert 48 Android dp / browser CSS px into this control's local units.
	var density := maxf(DisplayServer.screen_get_dpi() / 160.0, 1.0)
	if OS.has_feature("web"): density = float(JavaScriptBridge.eval("window.devicePixelRatio || 1"))
	var scale := maxf(absf(control.get_screen_transform().get_scale().y), 0.01)
	return maxf(144.0, 48.0 * density / scale)

static func ensure(tree: SceneTree) -> void:
	if tree.root.has_node("TowerMobile"): return
	var router := load("res://scripts/ui/tower_mobile.gd").new() as Node
	router.name = "TowerMobile"
	tree.root.add_child.call_deferred(router)

static func instance() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("TowerMobile") if tree != null else null

static func words(value: String) -> String:
	if not enabled(): return value
	var replacements := {
		"右键取消":"点「取消选取」取消", "右键卡牌查看详情":"点按卡牌查看详情",
		"右键查看详情":"点「详情」查看说明", "右键详情":"点按详情",
		"右键查看效果":"开启「详情」后点按查看", "左键选牌":"点按选牌",
		"左键点击":"点按", "左键":"点按", "滚轮":"滑动",
		"悬停目标":"选牌后", "悬停":"选取后", "（也支持右键）":"",
		" · 也支持右键":"", "，或右键点击技能":"", "或右键":"",
		"ESC / 点击外侧返回":"点关闭返回", "ESC / 关闭返回":"点关闭返回",
		"或按 Esc 关闭":"或点关闭", " · Esc 返回":" · 点关闭返回",
		"点击 / Esc 跳过":"点按跳过", "点击 / 空格":"点按",
		"Enter 确认执行    ·    Esc 取消":"点「确认执行」继续 · 点「取消」返回",
	}
	for before in replacements: value = value.replace(before, replacements[before])
	return value

static func content_rect(viewport: Viewport) -> Rect2:
	var whole := viewport.get_visible_rect()
	if bool(Engine.get_meta("tower_mobile_preview", false)) and Engine.has_meta("tower_mobile_safe_area"):
		return (Engine.get_meta("tower_mobile_safe_area") as Rect2).intersection(whole)
	if enabled() and OS.has_feature("web"):
		var insets = JSON.parse_string(String(JavaScriptBridge.eval("(function(){let e=document.getElementById('safe-insets');if(!e)return '[0,0,0,0]';let s=getComputedStyle(e);return JSON.stringify([parseFloat(s.paddingLeft),parseFloat(s.paddingTop),parseFloat(s.paddingRight),parseFloat(s.paddingBottom)]);})()")))
		var width := float(JavaScriptBridge.eval("window.innerWidth"))
		var height := float(JavaScriptBridge.eval("window.innerHeight"))
		if insets is Array and width > 0 and height > 0:
			var top_left := Vector2(insets[0], insets[1]) * whole.size / Vector2(width, height)
			var bottom_right := Vector2(insets[2], insets[3]) * whole.size / Vector2(width, height)
			return Rect2(whole.position + top_left, whole.size - top_left - bottom_right)
	if not enabled() or not OS.has_feature("android"): return whole
	var physical := Vector2(DisplayServer.window_get_size())
	if physical.x <= 0 or physical.y <= 0: return whole
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0: return whole
	return Rect2(Vector2(safe.position) * whole.size / physical, Vector2(safe.size) * whole.size / physical).intersection(whole)

static func fit(root: Control, viewport: Viewport) -> void:
	var area := content_rect(viewport)
	var factor := minf(area.size.x / SCREEN.x, area.size.y / SCREEN.y)
	root.scale = Vector2.ONE * factor
	root.position = area.position + (area.size - SCREEN * factor) * 0.5

static func register_back(owner: Node, action: Callable) -> void:
	var router := instance()
	if enabled() and router != null: router.push_back(owner, action)

func push_back(owner: Node, action: Callable) -> void:
	_back_stack = _back_stack.filter(func(entry: Dictionary): return is_instance_valid(entry.owner))
	# A base page redraw must not move it above the modal already on screen.
	for entry in _back_stack:
		if entry.owner == owner:
			entry.action = action
			return
	_back_stack.append({"owner":owner, "action":action})

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_mouse_emulation = Input.emulate_mouse_from_touch
	get_tree().node_added.connect(func(node: Node):
		if node.get_parent() == get_tree().root: _raise_router.call_deferred()
		if node is Control: _prepare_control.call_deferred(node.get_instance_id()))
	_raise_router.call_deferred()
	if enabled():
		get_tree().quit_on_go_back = false
		Input.emulate_mouse_from_touch = false
		if OS.has_feature("android"): DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)

func _raise_router() -> void:
	if is_inside_tree(): get_parent().move_child(self, -1)

func _prepare_control(instance_id: int) -> void:
	var control := instance_from_id(instance_id) as Control
	if not is_instance_valid(control) or not control.is_inside_tree(): return
	if not enabled() and not (OS.has_feature("web") and OS.has_feature("tower_release")): return
	if enabled() and (control is BaseButton or control is LineEdit or control is HSlider) and control.get_parent() is Container:
		control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, touch_extent(control))
	if control is LineEdit:
		if OS.has_feature("web"):
			control.virtual_keyboard_enabled = false
			control.focus_entered.connect(func():
				var browser := get_tree().root.get_node_or_null("TowerWeb")
				if browser != null: browser.edit(control))
		control.text_submitted.connect(func(_value: String):
			control.release_focus()
			if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide())

func _process(delta: float) -> void:
	if not enabled():
		Input.emulate_mouse_from_touch = _previous_mouse_emulation
		return
	Input.emulate_mouse_from_touch = false
	if _finger >= 0 and not _dragged and not _explained:
		_held += delta
		if _held > 0.6 and is_instance_valid(_target):
			var control := _target
			while control != null and control.tooltip_text.is_empty(): control = control.get_parent_control()
			if control != null and not control.tooltip_text.is_empty():
				_explained = true
				show_help("操作说明", words(control.tooltip_text))
	_avoid_keyboard()

func _input(event: InputEvent) -> void:
	if not enabled(): return
	if event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		if event.pressed:
			if _finger != -1: return
			_finger = event.index
			_origin = event.position
			_last = _origin
			_dragged = false
			_slider_drag = false
			_held = 0.0
			_explained = false
			_motion(_origin, Vector2.ZERO)
			_target = get_viewport().gui_get_hovered_control()
			_scrolls.clear()
			var ancestor: Node = _target
			while ancestor != null:
				if ancestor is ScrollContainer or ancestor is RichTextLabel: _scrolls.append(ancestor)
				ancestor = ancestor.get_parent()
		elif event.index == _finger:
			if _slider_drag: _mouse_button(event.position, false)
			elif not _dragged and not _explained and not event.canceled:
				var option := _target as OptionButton
				if option != null and not option.disabled:
					show_options(option)
				else:
					_mouse_button(event.position, true)
					_mouse_button(event.position, false)
			_reset_touch()
		# push_input above has its own handled flag; consume the original touch too.
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _finger:
		get_viewport().set_input_as_handled()
		var movement: Vector2 = event.position - _last
		_last = event.position
		if not _dragged and _origin.distance_to(_last) > _drag_threshold():
			_dragged = true
			if is_instance_valid(_target) and _target is HSlider and absf(_last.x - _origin.x) > absf(_last.y - _origin.y):
				_slider_drag = true
				_mouse_button(_origin, true)
		if _slider_drag: _motion(_last, movement, true)
		elif _dragged and not _explained: _scroll(movement)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and event.device != POINTER_DEVICE:
		get_viewport().set_input_as_handled()
		go_back()

func _drag_threshold() -> float:
	var physical := Vector2(DisplayServer.window_get_size())
	if physical.x <= 0: physical = get_viewport().get_visible_rect().size
	var ratio := get_viewport().get_visible_rect().size.x / maxf(physical.x, 1)
	return maxf(10, 8 * maxf(DisplayServer.screen_get_dpi(), 160) / 160.0 * ratio)

func _scroll(delta: Vector2) -> void:
	for scroll in _scrolls:
		if not is_instance_valid(scroll): continue
		var local := scroll.get_global_transform_with_canvas().basis_xform_inv(delta)
		var vertical: VScrollBar = scroll.get_v_scroll_bar()
		if scroll is RichTextLabel:
			if vertical.max_value > vertical.page:
				var before := vertical.value
				vertical.value -= local.y
				if vertical.value != before: return
			continue
		var horizontal: HScrollBar = scroll.get_h_scroll_bar()
		if absf(delta.y) >= absf(delta.x) and vertical.max_value > vertical.page:
			var before: int = scroll.scroll_vertical
			scroll.scroll_vertical = clampi(scroll.scroll_vertical - roundi(local.y), 0, maxi(0, roundi(vertical.max_value - vertical.page)))
			if scroll.scroll_vertical != before: return
		if horizontal.max_value > horizontal.page:
			var before: int = scroll.scroll_horizontal
			scroll.scroll_horizontal = clampi(scroll.scroll_horizontal - roundi(local.x), 0, maxi(0, roundi(horizontal.max_value - horizontal.page)))
			if scroll.scroll_horizontal != before: return

func _motion(point: Vector2, relative: Vector2, down: bool = false) -> void:
	var mouse := InputEventMouseMotion.new()
	mouse.device = POINTER_DEVICE
	mouse.position = point
	mouse.global_position = point
	mouse.relative = relative
	mouse.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	get_viewport().push_input(mouse, true)

func _mouse_button(point: Vector2, down: bool) -> void:
	var mouse := InputEventMouseButton.new()
	mouse.device = POINTER_DEVICE
	mouse.position = point
	mouse.global_position = point
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	mouse.pressed = down
	get_viewport().push_input(mouse, true)

func _reset_touch() -> void:
	_finger = -1
	_target = null
	_scrolls.clear()
	_slider_drag = false
	_dragged = false
	_motion(Vector2(-100, -100), Vector2.ZERO)

func go_back() -> void:
	if _slider_drag: _mouse_button(_last, false)
	_reset_touch()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) and DisplayServer.virtual_keyboard_get_height() > 0:
		DisplayServer.virtual_keyboard_hide()
		get_viewport().gui_release_focus()
		return
	while not _back_stack.is_empty():
		var entry: Dictionary = _back_stack.back()
		if not is_instance_valid(entry.owner) or entry.owner.is_queued_for_deletion() or (entry.owner is CanvasItem and not entry.owner.is_visible_in_tree()):
			_back_stack.pop_back()
			continue
		entry.action.call()
		return
	var cancel := InputEventAction.new()
	cancel.device = POINTER_DEVICE
	cancel.action = "ui_cancel"
	cancel.pressed = true
	get_viewport().push_input(cancel, true)

func show_help(title: String, description: String, action_text: String = "", action: Callable = Callable(), prompt_input: bool = false, choices: Array[Dictionary] = []) -> Control:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var panel := load("res://scripts/ui/tower_mobile_help.gd").new() as Control
	panel.heading = title
	panel.description = description
	panel.action_text = action_text
	panel.action = action
	panel.prompt_input = prompt_input
	panel.choices = choices
	layer.add_child(panel)
	panel.dismissed.connect(layer.queue_free)
	push_back(panel, panel.dismiss)
	return panel

func show_options(option: OptionButton) -> void:
	var choices: Array[Dictionary] = []
	for index in option.item_count:
		if option.is_item_separator(index): continue
		choices.append({"text": ("✓ " if option.selected == index else "") + option.get_item_text(index), "disabled": option.is_item_disabled(index), "action":func():
			if is_instance_valid(option): option.select(index); option.item_selected.emit(index)})
	show_help("请选择", "", "", Callable(), false, choices)

func _avoid_keyboard() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): return
	var focus := get_viewport().gui_get_focus_owner()
	var height := DisplayServer.virtual_keyboard_get_height()
	if height <= 0 or not (focus is LineEdit or focus is TextEdit):
		if is_instance_valid(_input_focus): _input_focus.position = _focus_position
		_input_focus = null
		return
	var root := focus
	while root.get_parent_control() != null: root = root.get_parent_control()
	if _input_focus != root:
		if is_instance_valid(_input_focus): _input_focus.position = _focus_position
		_input_focus = root
		_focus_position = root.position
	root.position = _focus_position
	var viewport := get_viewport().get_visible_rect().size
	var available := viewport.y * (1.0 - float(height) / maxf(DisplayServer.window_get_size().y, 1))
	var bottom := (focus.get_global_transform_with_canvas() * Vector2(0, focus.size.y)).y
	if bottom > available - 24: root.position.y -= bottom - available + 24

func _notification(what: int) -> void:
	if not enabled(): return
	if what == NOTIFICATION_APPLICATION_PAUSED: suspend_application(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED: suspend_application(false)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST: go_back()

func suspend_application(paused: bool) -> void:
	# Desktop Web also pauses when the tab is hidden.
	if not enabled() and not (OS.has_feature("web") and OS.has_feature("tower_release")): return
	if paused:
		if _paused_by_app: return
		if _slider_drag: _mouse_button(_last, false)
		_reset_touch()
		_previous_paused = get_tree().paused
		_previous_mute = AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
		_paused_by_app = true
		var tower := get_node_or_null("/root/TowerRun")
		if tower != null and tower.active and not tower.data.is_empty(): tower.save_game()
		get_tree().paused = true
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	elif _paused_by_app:
		_paused_by_app = false
		get_tree().paused = _previous_paused
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), _previous_mute)
