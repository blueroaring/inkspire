extends Control
## Visible before resource work begins; lives outside the scene being replaced.
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const LIVING := preload("res://scripts/ui/battle_living_portrait.gd")
var canvas: Control
var stage: Label
var progress_bar: ProgressBar
var progress := 0.0
var elapsed := 0.0
var retained: Array[Resource] = []
var spinner: Line2D

func _ready() -> void:
	name = "TowerBattleLoading"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var black := ColorRect.new()
	black.color = Color("070c19")
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	canvas = Control.new()
	canvas.size = Vector2(1920, 1080)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	var cg := V.icon(canvas, load("res://assets/graphics/tower/loading_cg.webp"), Rect2(0, 0, 1920, 1080))
	cg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	V.text(canvas, "高中异闻  /  尖塔", Rect2(122, 104, 900, 46), 25, Color("dfc596"))
	var floor_number := int(TowerRun.pending.get("floor", 0))
	var title := "正在准备战斗"
	if floor_number > 0: title = "第 %d 层  ·  准备开战" % floor_number
	elif TowerRun.pending.get("mode") == "lesson": title = "角色教学  ·  准备开始"
	V.text(canvas, title, Rect2(120, 704, 950, 66), 43, Color("fff0d3"))
	stage = V.text(canvas, "正在加载战场…", Rect2(123, 798, 880, 40), 23, Color("d7dfeb"))
	V.text(canvas, "先看看敌人要攻击谁，再决定这回合怎么出牌。", Rect2(124, 941, 1020, 38), 21, Color("b5c3d3"))
	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(124, 866)
	progress_bar.size = Vector2(720, 4)
	progress_bar.show_percentage = false
	for part in ["background", "fill"]:
		var paint := StyleBoxFlat.new()
		paint.bg_color = Color("26364b") if part == "background" else Color("e6c48b")
		progress_bar.add_theme_stylebox_override(part, paint)
	canvas.add_child(progress_bar)
	spinner = Line2D.new()
	spinner.name = "LoadingIndicator"
	spinner.position = Vector2(878, 868)
	spinner.width = 2
	spinner.default_color = Color("e6c48b")
	spinner.antialiased = true
	for i in 27: spinner.add_point(Vector2.from_angle(float(i) / 26.0 * 4.6) * 12)
	canvas.add_child(spinner)
	get_viewport().size_changed.connect(_resize)
	_resize()

func _resize() -> void:
	size = get_viewport_rect().size
	var factor := minf(size.x / 1920.0, size.y / 1080.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - Vector2(1920, 1080) * factor) * 0.5

func _process(delta: float) -> void:
	elapsed += delta
	progress_bar.value = lerpf(progress_bar.value, progress * 100, 1 - exp(-delta * 12))
	spinner.rotation = elapsed * 2.5

func _input(event: InputEvent) -> void:
	# Prevent a key or click intended for the old screen reaching the new battle.
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()

func shown_frame() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func prepare(scene_path: String) -> PackedScene:
	await shown_frame()
	var paths: Array[String] = [scene_path]
	for unit: Dictionary in FightSystem.allies:
		var path := String(unit.get("portrait", ""))
		if not path.is_empty() and path not in paths: paths.append(path)
		var profile := LIVING.profile(LIVING.key_for(String(unit.id), String(unit.attribute)))
		if not profile.is_empty() and not path.contains("pixel_portraits"):
			var blink := String(profile.blink)
			if blink not in paths: paths.append(blink)
	for unit: Dictionary in FightSystem.enemies:
		var path := String(unit.get("portrait", ""))
		if not path.is_empty() and path not in paths: paths.append(path)
	for path in paths:
		if ResourceLoader.load_threaded_request(path) != OK: return null
	var loaded: Dictionary = {}
	while loaded.size() < paths.size():
		var total := 0.0
		for path in paths:
			if loaded.has(path):
				total += 1
				continue
			var detail: Array = []
			var status := ResourceLoader.load_threaded_get_status(path, detail)
			if status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]: return null
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				var resource := ResourceLoader.load_threaded_get(path)
				loaded[path] = resource
				retained.append(resource)
				total += 1
			elif not detail.is_empty(): total += float(detail[0])
		progress = total / paths.size() * 0.9
		await get_tree().process_frame
	stage.text = "正在准备队伍…"
	await shown_frame()
	return loaded.get(scene_path) as PackedScene

func dismiss() -> void:
	progress = 1
	stage.text = "准备就绪"
	await shown_frame()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.22)
	await fade.finished
	queue_free()
