extends Control
const T := preload("res://scripts/ui/battle_theme.gd")
const DATA := preload("res://scripts/data/tower_data.gd")
const BG := preload("res://scripts/ui/tower_backdrop.gd")
const M := preload("res://scripts/ui/battle_management_ui.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const FINISH := preload("res://scripts/ui/tower_finish.gd")
const BESTIARY := preload("res://scripts/data/enemy_bestiary.gd")
const MATERIAL := preload("res://assets/shaders/battle_result_material.gdshader")
const GOLD := T.GOLD
const TEXT := T.TEXT
const MUTED := T.MUTED
var canvas: Control
var body: Control
var page := "title"
var chosen_floor := 1
var chosen_hero := "zhoumingyuan"
var status: Label
var nickname := ""
var _timer := 0.0
var tutorial: Control
var tutorial_practice := ""

func _ready() -> void:
	DisplayServer.window_set_title(DATA.GAME_TITLE)
	TowerRun.enter()
	TowerRun.finish_lesson_session()
	if not TowerRun.data.is_empty():
		page = "shop" if TowerRun.shop_available() and TowerRun.data.get("shop_arrival", false) else "lobby"
		TowerRun.data.shop_arrival = false
		chosen_floor = int(TowerRun.data.highest) + 1
	TowerRun.changed.connect(_refresh)
	canvas = Control.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	canvas.size = Vector2(1920, 1080)
	add_child(canvas)
	T.apply(canvas)
	get_viewport().size_changed.connect(_resize)
	_resize()
	Music.play("menu", 0.8)
	_refresh()

func _resize() -> void:
	if preload("res://scripts/ui/tower_mobile.gd").enabled():
		preload("res://scripts/ui/tower_mobile.gd").fit(canvas, get_viewport())
		return
	var viewport := get_viewport_rect().size
	var factor := minf(viewport.x / 1920.0, viewport.y / 1080.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (viewport - Vector2(1920, 1080) * factor) * 0.5

func _refresh() -> void:
	if not is_instance_valid(canvas): return
	if is_instance_valid(body):
		canvas.remove_child(body)
		body.queue_free()
	body = Control.new()
	body.size = Vector2(1920, 1080)
	canvas.add_child(body)
	var bg := BG.new()
	bg.size = body.size
	bg.highest = int(TowerRun.data.get("highest", 0))
	body.add_child(bg)
	text("HIGH SCHOOL CHRONICLES", Rect2(70, 50, 620, 38), 21, Color("dbc699"))
	text("高中异闻", Rect2(70, 96, 620, 80), 58, Color("ecede1"))
	text("— 尖塔 —", Rect2(76, 182, 610, 57), 34, Color("dbc699"))
	text("战斗测试版  ·  " + DATA.VERSION, Rect2(80, 1005, 600, 32), 17, Color("bdced0"))
	if page != "title":
		panel(Rect2(714, 125, 1164, 846))
	if page == "title":
		_title()
	else:
		_navigation()
		match page:
			"lobby": _lobby()
			"lessons": _lessons()
			"shop": _shop()
			"saves": _saves()
			"report": _report()
	status = text("" if page == "title" else TowerRun.notice, Rect2(740, 978, 1100, 70), 20, Color("e5c78c"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if TowerRun.onboarding_pending() and tutorial_practice.is_empty(): _open_tutorial.call_deferred()

func text(value: String, rect: Rect2, font_size: int = 22, color: Color = TEXT, parent: Node = null) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", T.HEADING if font_size >= 26 else T.BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else body).add_child(label)
	return label

func panel(rect: Rect2, parent: Node = null) -> Panel:
	var node := M.panel(rect, Color("e3dfcd"), Color("9e8251"))
	(parent if parent else body).add_child(node)
	FINISH.decorate(node)
	return node

func button(value: String, rect: Rect2, action: Callable, highlighted: bool = false, disabled: bool = false, parent: Node = null) -> Button:
	var node := M.button(value, rect, action, T.GOLD, highlighted)
	node.disabled = disabled
	node.add_theme_font_size_override("font_size", 22)
	(parent if parent else body).add_child(node)
	node.get_node("SurfaceArt").hide()
	var dark := highlighted and not value.is_empty()
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := Color("314c57") if dark else Color("c9d1cc") if disabled else Color("e4e3d5")
		if state == "hover": fill = fill.lightened(0.10)
		if state == "pressed": fill = fill.darkened(0.08)
		node.add_theme_stylebox_override(state, T.frame(fill, Color("b39760") if highlighted else Color("758a88"), 2 if highlighted else 1, 3))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		node.add_theme_color_override(state, Color("f0dfb6") if dark else T.TEXT)
	var finish := FINISH.new()
	finish.compact = true
	finish.primary = dark
	finish.size = rect.size
	node.add_child(finish)
	return node

func portrait(path: String, rect: Rect2, parent: Node = null) -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if ResourceLoader.exists(path): image.texture = load(path)
	image.position = rect.position
	image.size = rect.size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else body).add_child(image)
	return image

func _title() -> void:
	portrait("res://assets/graphics/tower/app-icon.webp", Rect2(90, 311, 260, 260))
	text("放学了。\n叫上同伴，去塔里看看吧。", Rect2(88, 639, 570, 115), 29, Color("e7dfc8"))
	text("选好队友  ·  带上技能  ·  开始爬塔", Rect2(88, 779, 590, 50), 23, Color("bdced0"))
	panel(Rect2(860, 228, 800, 704))
	text("这次能打到第几层？", Rect2(920, 270, 680, 60), 32, GOLD)
	text("%d 位角色可选 · 教学关可获得专武" % DATA.HEROES.size(), Rect2(920, 335, 680, 40), 23, MUTED)
	var entries := ["开始游戏", "教学关卡", "存档", "设置", "制作名单与许可", "退出游戏"]
	var actions: Array[Callable] = [_start_menu, func(): _ensure_game("lessons"), func(): page = "saves"; _refresh(), _settings, _credits, _quit]
	for i in entries.size():
		var entry := button(entries[i], Rect2(920, 414 + i * 76, 680, 64), actions[i], i == 0)
		if actions[i] == _credits: entry.name = "OpenTowerCredits"

func _credits() -> void:
	if canvas.has_node("TowerCredits"): return
	var credits := preload("res://scripts/ui/tower_credits.gd").new()
	canvas.add_child(credits)
	credits.closed.connect(func():
		var entry := body.find_child("OpenTowerCredits", true, false) as Button
		if is_instance_valid(entry): entry.grab_focus())

func _navigation() -> void:
	var entries := {"lobby":"攀登", "lessons":"教学", "saves":"存档", "report":"测试数据"}
	if TowerRun.shop_available(): entries["shop"] = "阿姨补给"
	var index := 0
	for key in entries:
		button(entries[key], Rect2(740 + index * 177, 58, 163, 52), func(): _ensure_game(key), page == key)
		index += 1
	button("设置", Rect2(1630, 58, 106, 52), _settings)
	button("标题", Rect2(1748, 58, 106, 52), func(): TowerRun.save_game(); page = "title"; _refresh())
	if not TowerRun.data.is_empty():
		portrait("res://assets/graphics/tower/icons/ink_fragment.webp", Rect2(1798, 127, 48, 48))
		text("%s  /  最高 %d 层  /  等级上限 %d  /  墨痕碎片 %d" % [TowerRun.data.nickname, TowerRun.data.highest, TowerRun.cap(), TowerRun.data.shards], Rect2(746, 135, 1100, 44), 23, GOLD)

func _start_menu() -> void:
	if not TowerRun.data.is_empty(): page = "lobby"; _refresh()
	else: page = "saves"; TowerRun.notice = "选一个空存档开始，或读取之前的进度。"; _refresh()

func _ensure_game(destination: String) -> void:
	if TowerRun.data.is_empty() and destination not in ["saves"]:
		page = "saves"
		TowerRun.notice = "请先创建或读取爬塔存档。"
	else: page = destination
	_refresh()

func _lobby() -> void:
	_floor_map()
	panel(Rect2(740, 208, 1114, 300))
	chosen_floor = clampi(chosen_floor, 1, int(TowerRun.data.highest) + 1)
	var floor_info := DATA.floor_data(chosen_floor, int(TowerRun.data.seed))
	text("第 %02d 层   /   %s关卡" % [chosen_floor, floor_info.kind], Rect2(770, 226, 750, 45), 32, GOLD)
	var cleared: bool = TowerRun.data.clears.has(str(chosen_floor))
	var replay_gain := DATA.replay_xp(chosen_floor)
	text(("重演经验 %d / 人  ·  当前等级上限 Lv.%d  ·  全员满血" % [replay_gain, TowerRun.cap()]) if cleared else "经验 %d / 人  ·  墨痕碎片 %d" % [floor_info.xp, floor_info.shards], Rect2(770, 276, 1020, 30), 22, MUTED)
	_floor_enemies(floor_info)
	var recommended: Array[String] = []
	for id in floor_info.enemies:
		for hero in BESTIARY.RECOMMENDATIONS.get(id, [[], ""])[0]:
			var hero_name := BESTIARY.recommended_name(String(id), String(hero))
			if hero_name not in recommended: recommended.append(hero_name)
	text("推荐：" + " / ".join(recommended), Rect2(770, 412, 730, 32), 21, GOLD).name = "TowerFloorRecommendations"
	button("查看逐怪打法", Rect2(1558, 408, 260, 40), func(): _floor_recommendations(floor_info)).name = "TowerFloorStrategy"
	var next_floor := button("前往下一层", Rect2(995, 452, 240, 42), func(): chosen_floor = int(TowerRun.data.highest) + 1; _refresh())
	next_floor.tooltip_text = "点击左侧楼层可以选关。已通关的楼层可以重演练级，只获得经验；等级仍受当前进度限制。"
	button("重演本层  →" if cleared else "进入战斗  →", Rect2(1468, 452, 350, 42), _begin, true)
	if cleared:
		button("重置到本层前", Rect2(1240, 452, 210, 42), _confirm_reset, false)
	text("出战顺序", Rect2(746, 526, 300, 40), 28)
	button("新手教程", Rect2(1195, 522, 200, 52), func(): _open_tutorial(true))
	button("角色系统与战斗百科  →", Rect2(1420, 522, 435, 52), _characters, true).name = "TowerCharacters"
	text("配技能、装遗物、查怪物与道具，出战前先来看看", Rect2(1100, 575, 750, 24), 16, MUTED)
	var team := FightSystem.formation_slots()
	for i in 4:
		var x := 740 + i * 283
		var id := String(team[i])
		var tile := button("", Rect2(x, 600, 265, 271), func(): _formation_picker(i), false)
		tile.name = "FormationSlot_%d" % i
		if id.is_empty():
			text("＋\n选择队员", Rect2(20, 80, 225, 120), 30, MUTED, tile).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			continue
		M.identity_button(tile, id, false)
		tile.get_node("SurfaceArt").show()
		portrait(FightData.hero(id).portrait, Rect2(30, 10, 205, 92 if id == "zhoumingyuan" else 120), tile)
		if id == "zhoumingyuan": _form_switch(tile, Rect2(14, 103, 237, 34))
		text(FightData.hero(id).name, Rect2(20, 134, 225, 40), 29, TEXT, tile).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text("%02d  /  Lv.%d" % [i + 1, FightProgression.hero_level(id)], Rect2(20, 178, 225, 30), 19, GOLD, tile).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_formation_health(tile, id, Rect2(16, 208, 233, 54))
		tile.tooltip_text = "点击换人 · 下方显示剩余生命"
	button("恢复 · %d 次" % TowerRun.recovery_charges(), Rect2(740, 887, 225, 57), _recovery_picker, true)
	if TowerRun.shop_available():
		button("拜访小卖铺阿姨", Rect2(982, 887, 270, 57), func(): page = "shop"; _refresh())
	text("每过5层可以找阿姨补给。\n挑战下一层才关店，教学和重演不影响。", Rect2(1280, 878, 550, 78), 20, MUTED)
	var warning := TowerRun.formation_warning()
	if not warning.is_empty(): TowerRun.notice = warning

func _floor_enemies(floor_info: Dictionary) -> void:
	var row := Control.new()
	row.name = "TowerFloorEnemies"
	row.position = Vector2(770, 312)
	row.size = Vector2(1048, 90)
	body.add_child(row)
	var enemies: Array = floor_info.enemies
	var sequential: bool = floor_info.waves.size() > 1
	var gap := 36.0 if sequential else 16.0
	var width := minf(320.0, (row.size.x - gap * (enemies.size() - 1)) / maxi(1, enemies.size()))
	for i in enemies.size():
		var enemy := FightData.enemy(String(enemies[i]))
		var tile := M.panel(Rect2(i * (width + gap), 0, width, 90), Color("d3dbd4"), Color("869589"))
		tile.name = "FloorEnemy_%d" % i
		tile.tooltip_text = "%s · Lv.%d%s" % [enemy.name, floor_info.level, " · 第 %d 战" % (i + 1) if sequential else ""]
		row.add_child(tile)
		portrait(enemy.portrait, Rect2(8, 8, 74, 74), tile).name = "EnemyIcon"
		var title := text(enemy.name, Rect2(94, 11, width - 104, 30), 22, TEXT, tile)
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text("Lv.%d%s" % [floor_info.level, "  ·  第%d战" % (i + 1) if sequential else ""], Rect2(94, 46, width - 104, 30), 21, GOLD, tile).name = "EnemyLevel"
		if sequential and i < enemies.size() - 1:
			text("→", Rect2(i * (width + gap) + width, 27, gap, 36), 24, GOLD, row).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _form_switch(parent: Control, rect: Rect2, picker_slot: int = -1) -> void:
	var current := FightSystem.current_attribute("zhoumingyuan")
	for i in 2:
		var form: String = ["none", "math"][i]
		var choice := button(("● " if form == current else "切换 ") + FightData.attr_name(form), Rect2(rect.position + Vector2(i * (rect.size.x + 6) / 2, 0), Vector2((rect.size.x - 6) / 2, rect.size.y)), func():
			if not FightSystem.set_attribute("zhoumingyuan", form): return
			TowerRun.save_game()
			TowerRun.notice = "周明远已切换为%s形态，卡组已同步；仅对应形态的专武可装备。" % FightData.attr_name(form)
			if picker_slot >= 0:
				var overlay := canvas.find_child("TowerFormationPicker", true, false)
				if is_instance_valid(overlay):
					canvas.remove_child(overlay)
					overlay.queue_free()
			_refresh()
			if picker_slot >= 0: _formation_picker(picker_slot)
		, current == form, false, parent)
		choice.name = "FormationForm_" + form
		choice.mouse_filter = Control.MOUSE_FILTER_STOP
		choice.add_theme_font_size_override("font_size", 16)
		choice.tooltip_text = "切换形态会同步独立卡组与剩余生命；不匹配的形态专武会卸下，可在角色系统重新装备。"

func _formation_health(parent: Control, id: String, rect: Rect2) -> void:
	var current := TowerRun.health(id)
	var maximum := FightSystem.hero_max_hp(id)
	var health_color := Color("ef9b8f") if current <= maximum * 0.25 else Color("f0d18b") if current <= maximum * 0.5 else Color("8ed9b5")
	var strip := M.panel(rect, Color("213d46"), health_color.darkened(0.3))
	strip.name = "FormationHealth_" + id
	parent.add_child(strip)
	var label := text("生命 %d / %d%s" % [current, maximum, " · 需复活" if current <= 0 else ""], Rect2(6, 3, rect.size.x - 12, 32), 21, health_color, strip)
	label.name = "Health_" + id
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bar := ColorRect.new()
	bar.name = "HealthBar_" + id
	bar.position = Vector2(10, 40)
	bar.size = Vector2(rect.size.x - 20, 7)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.color = Color("142a31")
	strip.add_child(bar)
	var fill := ColorRect.new()
	fill.name = "HealthFill_" + id
	fill.size = Vector2((rect.size.x - 20) * float(current) / maxf(1, maximum), 7)
	fill.color = health_color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(fill)

func _floor_recommendations(floor_info: Dictionary) -> void:
	var overlay := Control.new()
	overlay.name = "TowerFloorStrategyOverlay"
	overlay.size = Vector2(1920, 1080)
	canvas.add_child(overlay)
	var dim := ColorRect.new()
	dim.size = overlay.size
	dim.color = Color(0.01, 0.03, 0.06, 0.82)
	overlay.add_child(dim)
	var pane := panel(Rect2(224, 130, 1472, 820), overlay)
	text("第 %02d 层 / 推荐角色与打法" % int(floor_info.floor), Rect2(40, 26, 1350, 54), 34, GOLD, pane)
	text("下面按出场顺序介绍本层敌人。推荐角色仅供参考；需要的技能要先解锁，再带进卡组。", Rect2(40, 91, 1380, 40), 21, MUTED, pane)
	var scroll := ScrollContainer.new()
	scroll.name = "TowerFloorStrategyScroll"
	scroll.position = Vector2(40, 150)
	scroll.size = Vector2(1392, 554)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pane.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 20)
	scroll.add_child(rows)
	var seen: Array[String] = []
	for id in floor_info.enemies:
		if id in seen: continue
		seen.append(id)
		var title := Label.new()
		title.text = String(FightData.enemy(id).name)
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", GOLD)
		rows.add_child(title)
		var guide := Label.new()
		guide.name = "FloorStrategy_" + id
		guide.text = BESTIARY.recommendation(id)
		guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		guide.add_theme_font_size_override("font_size", 24)
		guide.add_theme_color_override("font_color", TEXT)
		rows.add_child(guide)
	button("返回编队", Rect2(1102, 736, 330, 54), overlay.queue_free, true, false, pane)

func _begin() -> void:
	if FightSystem.formation().is_empty():
		TowerRun.notice = TowerRun.formation_warning()
		_refresh()
		_formation_picker(0)
		return
	var warning := TowerRun.formation_warning()
	if not warning.is_empty():
		confirm(warning + "\n仍要进入战斗吗？", _launch)
	else: _launch()

func _floor_map() -> void:
	var frame := panel(Rect2(64, 272, 616, 696))
	text("选择楼层", Rect2(24, 17, 300, 44), 30, GOLD, frame)
	text("向上滚动查看更多楼层 · 点击选关", Rect2(24, 66, 558, 32), 19, MUTED, frame)
	var scroll := ScrollContainer.new()
	scroll.name = "TowerFloorScroll"
	scroll.position = Vector2(22, 116)
	scroll.size = Vector2(570, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 7)
	scroll.add_child(rows)
	var latest := int(TowerRun.data.highest) + 1
	var low := maxi(1, chosen_floor - 40)
	var high := mini(latest + 5, maxi(12, chosen_floor + 40))
	for floor_number in range(high, low - 1, -1):
		var unlocked := floor_number <= latest
		var kind := String(DATA.floor_data(floor_number, int(TowerRun.data.seed)).kind)
		var entry := button("", Rect2(0, 0, 546, 80), func(): chosen_floor = floor_number; _refresh(), floor_number == chosen_floor, not unlocked, rows)
		entry.custom_minimum_size = Vector2(546, 80)
		entry.name = "TowerFloor_%d" % floor_number
		for child in entry.get_children(): child.hide()
		for state in ["normal", "hover", "pressed", "disabled"]:
			entry.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var marker := preload("res://scripts/ui/tower_floor_marker.gd").new()
		marker.size = Vector2(546, 80)
		marker.selected = floor_number == chosen_floor
		marker.unlocked = unlocked
		marker.milestone = floor_number % 5 == 0
		entry.add_child(marker)
		entry.mouse_entered.connect(func(): marker.modulate = Color(1.08, 1.08, 1.08))
		entry.mouse_exited.connect(func(): marker.modulate = Color.WHITE)
		text("%02d" % floor_number, Rect2(37, 16, 68, 42), 27, Color("eee1b7") if unlocked else Color("d8e0db"), entry).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text(kind + "层", Rect2(152, 17, 150, 28), 23, TEXT if unlocked else T.FAINT, entry)
		text("战后补给" if floor_number % 5 == 0 else "战斗关卡", Rect2(152, 45, 190, 23), 16, MUTED, entry)
		V.glyph(entry, "attack" if kind == "首领" else "shield" if kind == "精英" else "retain", Rect2(338, 26, 28, 28), GOLD if unlocked else T.FAINT)
		var marker_text := "未开放" if not unlocked else "正在查看" if floor_number == chosen_floor else "新挑战" if floor_number == latest else "重演"
		text(marker_text, Rect2(393, 23, 132, 36), 20, GOLD if unlocked else T.FAINT, entry)

	scroll.set_deferred("scroll_vertical", maxi(0, (high - chosen_floor) * 87 - 205))
	button("↓ 前40层", Rect2(22, 632, 168, 45), func(): chosen_floor = maxi(1, chosen_floor - 40); _refresh(), false, chosen_floor <= 1, frame)
	button("当前进度", Rect2(201, 632, 168, 45), func(): chosen_floor = latest; _refresh(), true, false, frame)
	button("后40层 ↑", Rect2(380, 632, 212, 45), func(): chosen_floor = mini(latest, chosen_floor + 40); _refresh(), false, chosen_floor >= latest, frame)

func _formation_picker(slot_index: int) -> void:
	var overlay := Control.new()
	overlay.name = "TowerFormationPicker"
	overlay.size = Vector2(1920, 1080)
	canvas.add_child(overlay)
	var dim := ColorRect.new()
	dim.size = overlay.size
	dim.color = Color(0.01, 0.03, 0.06, 0.76)
	overlay.add_child(dim)
	var pane := panel(Rect2(224, 170, 1472, 740), overlay)
	text("编队  /  第 %d 位队员" % (slot_index + 1), Rect2(40, 28, 1100, 50), 34, GOLD, pane)
	text("点一名角色就能换人；如果对方已经在队里，两人会交换位置。", Rect2(40, 85, 1290, 36), 23, MUTED, pane)
	var team := FightSystem.formation_slots()
	for i in DATA.HEROES.size():
		var id: String = DATA.HEROES[i]
		var tile := M.hero_button(id, Rect2(40 + (i % 4) * 350, 150 + int(i / 4) * 220, 330, 200), func():
			var next := FightSystem.formation_slots()
			var other := next.find(id)
			if other >= 0: next[other] = next[slot_index]
			next[slot_index] = id
			if not FightSystem.set_formation(next): TowerRun.notice = FightSystem.last_configuration_error
			TowerRun.save_game()
			overlay.queue_free()
			_refresh()
			_resume_tutorial(), id == team[slot_index], true)
		pane.add_child(tile)
		var role := {"zhoumingyuan":"输出 / 绝境", "alyina":"治疗 / 守护", "chenmo":"防御 / 反伤", "xumingming":"输出 / 蓄势", "wangjiaqi":"辅助 / 附魔", "suwanqing":"输出 / 毒", "liudanya":"辅助 / 构图", "li_anya":"幻形 / 涅槃"}
		var team_slot := team.find(id)
		if id == "zhoumingyuan": _form_switch(tile, Rect2(20, 99, 290, 34), slot_index)
		else: text(role[id] + (" · 队中%d" % (team_slot + 1) if team_slot >= 0 else ""), Rect2(20, 99, 290, 34), 21, GOLD, tile)
		_formation_health(tile, id, Rect2(20, 138, 290, 54))
	button("移出队伍", Rect2(40, 655, 300, 52), func():
		var next := FightSystem.formation_slots()
		next[slot_index] = ""
		if not FightSystem.set_formation(next): TowerRun.notice = FightSystem.last_configuration_error
		TowerRun.save_game()
		overlay.queue_free()
		_refresh()
		_resume_tutorial(), false, false, pane)
	button("完成编队", Rect2(1102, 655, 330, 52), func(): overlay.queue_free(); _resume_tutorial(), true, false, pane)
	text("角色系统：调整卡组与装备，查阅怪物、遗物、道具图鉴及机制", Rect2(40, 599, 1380, 34), 22, GOLD, pane)
	button("进入角色系统与战斗百科  →", Rect2(570, 655, 500, 52), _characters, true, false, pane).name = "FormationCharacters"

func _launch() -> void:
	if not TowerRun.start_floor(chosen_floor): TowerRun.notice = TowerRun.error; _refresh()

func _confirm_reset() -> void:
	confirm("将回退到第 %d 层挑战前。\n之后获得的等级、经验、遗物、碎片、恢复次数和层数进度都会丢失。\n此操作不可撤销，确定继续吗？" % chosen_floor, func():
		if not TowerRun.reset_to_floor(chosen_floor): TowerRun.notice = TowerRun.error
		chosen_floor = mini(chosen_floor, int(TowerRun.data.highest) + 1)
		_refresh())

func _characters() -> void:
	TowerRun.save_game()
	SceneRouter.go_to("fight_characters")

func _lessons() -> void:
	text("先试试技能，再和队友配合", Rect2(746, 215, 1060, 54), 34, GOLD)
	text("使用教学专用 Lv.40 队伍 · 战后恢复原队伍 · 首通领奖", Rect2(746, 276, 1060, 40), 22, MUTED)
	for i in DATA.HEROES.size():
		var id: String = DATA.HEROES[i]
		button(FightData.hero(id).name, Rect2(740, 342 + i * 81, 230, 63), func(): chosen_hero = id; _refresh(), chosen_hero == id)
	var lesson: Dictionary = DATA.LESSONS[chosen_hero]
	var weapon := FightEquipmentData.definition(DATA.WEAPONS[chosen_hero])
	panel(Rect2(1000, 342, 854, 572))
	portrait(FightData.hero(chosen_hero).portrait, Rect2(1022, 365, 190, 240))
	text(lesson.title, Rect2(1240, 366, 574, 50), 32, GOLD)
	var tip := "先打出「%s」，再打出「%s」。\n%s\n多人实战中，打出第一张指定牌后，还要让队友出牌，最后赢下战斗。" % [FightData.skill(lesson.key).name, FightData.skill(lesson.follow).name, FightData.passive(chosen_hero, "none")]
	text(tip, Rect2(1240, 432, 574, 233), 21, TEXT).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text("专武 · " + String(weapon.name), Rect2(1035, 674, 590, 42), 26, GOLD)
	button("物品详情", Rect2(1650, 672, 170, 44), func(): _equipment_detail(DATA.WEAPONS[chosen_hero])).name = "LessonWeaponDetail"
	text(weapon.desc, Rect2(1035, 726, 770, 70), 21, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var basic_done: bool = TowerRun.data.lessons.has(chosen_hero + "_basic")
	var final_done: bool = TowerRun.data.lessons.has(chosen_hero + "_final")
	button("机制练习" + (" · 已领取" if basic_done else " · 首通20碎片"), Rect2(1035, 824, 360, 58), func(): _lesson(false), true)
	button("多人实战" + (" · 已领取" if final_done else " · 专武奖励"), Rect2(1420, 824, 400, 58), func(): _lesson(true), true, not basic_done)

func _lesson(final_exam: bool) -> void:
	if not TowerRun.start_lesson(chosen_hero, final_exam): TowerRun.notice = TowerRun.error; _refresh()

func _shop() -> void:
	if not TowerRun.shop_available():
		text("尚未抵达补给点", Rect2(770, 300, 1020, 65), 36, GOLD)
		text("击败第5、10、15…层的守关敌人后，阿姨会在该层等你。\n挑战下一层后，本次补给结束；教学和重演不影响。", Rect2(770, 400, 1020, 120), 25)
		button("返回攀登", Rect2(770, 620, 350, 65), func(): page = "lobby"; _refresh(), true)
		return
	portrait("res://assets/graphics/tower/merchant.webp", Rect2(40, 300, 650, 680))
	text("小卖铺阿姨  /  塔间补给", Rect2(746, 215, 1080, 54), 34, GOLD)
	text("“别着急，带好东西再往上走。”", Rect2(746, 277, 1080, 40), 23, MUTED)
	if TowerRun.data.get("shop", {}).is_empty():
		panel(Rect2(740, 350, 1114, 460))
		text("第5层通关后，阿姨会带着第一批货物等你。", Rect2(790, 475, 1010, 70), 30)
		return
	var shop: Dictionary = TowerRun.data.shop
	text("第 %d 层货架 · 楼层越高，越容易买到好东西 · 重打本层不会补货" % shop.floor, Rect2(746, 326, 1080, 36), 21, MUTED)
	for i in shop.stock.size():
		var offer: Dictionary = shop.stock[i]
		var def := FightEquipmentData.definition(offer.id)
		var card := panel(Rect2(740 + (i % 3) * 377, 391 + int(i / 3) * 241, 360, 224))
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = FightEquipmentData.texture(offer.id)
		icon.position = Vector2(15, 15)
		icon.size = Vector2(68, 68)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(icon)
		text(def.name, Rect2(96, 16, 250, 34), 24, GOLD, card)
		text(FightEquipmentData.rarity(offer.id).name, Rect2(96, 53, 250, 30), 18, MUTED, card)
		text(def.desc, Rect2(18, 92, 324, 80), 18, TEXT, card).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button("详情", Rect2(18, 177, 82, 37), func(): _equipment_detail(offer.id), false, false, card).name = "ShopDetail_" + String(offer.id)
		button("已售出" if offer.sold else "%d 碎片 · 购买" % offer.price, Rect2(110, 177, 232, 37), func():
			if TowerRun.buy(i): TowerRun.notice = "买到了「%s」。遗物去角色界面装备，道具在战斗中使用。" % def.name
			else: TowerRun.notice = TowerRun.error
			_refresh(), false, offer.sold, card)
	button("刷新全部 · %d 碎片（剩 %d 次）" % [4 + shop.refreshes * 3, 2 - shop.refreshes], Rect2(740, 893, 540, 56), func():
		if not TowerRun.refresh_shop(): TowerRun.notice = TowerRun.error
		_refresh(), true, int(shop.refreshes) >= 2)
	button("装备遗物", Rect2(1555, 893, 299, 56), _characters)

func _equipment_detail(id: String) -> void:
	var overlay := Control.new()
	overlay.name = "TowerEquipmentDetail"
	overlay.size = Vector2(1920, 1080)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(overlay)
	var shade := ColorRect.new()
	shade.size = overlay.size
	shade.color = Color(0.02, 0.03, 0.05, 0.8)
	overlay.add_child(shade)
	var pane := M.panel(Rect2(490, 190, 940, 700))
	overlay.add_child(pane)
	V.icon(pane, FightEquipmentData.texture(id), Rect2(40, 30, 156, 156))
	M.heading(pane, FightEquipmentData.definition(id).name, Rect2(230, 66, 660, 52), 34)
	M.equipment_description(pane, id, Rect2(50, 218, 840, 358))
	pane.add_child(M.button("关闭", Rect2(340, 610, 260, 56), overlay.queue_free))
	overlay.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("ui_cancel"):
			overlay.accept_event()
			overlay.queue_free())
	overlay.focus_mode = Control.FOCUS_ALL
	overlay.grab_focus()

func _saves() -> void:
	text("攀登记录", Rect2(746, 215, 1080, 54), 34, GOLD)
	text("更新后直接点继续：同一电脑覆盖或重命名 EXE 均会接续旧档。\n换电脑可导入 0.1.0 的 slot_*.json，或新版导出的迁移包。", Rect2(746, 277, 1080, 63), 21, MUTED)
	for i in 3:
		var selected_slot := i + 1
		var saved := TowerRun.read_save(selected_slot)
		var y := 350 + i * 170
		panel(Rect2(740, y, 1114, 145))
		text("%02d  /  %s" % [selected_slot, saved.get("nickname", "空存档")], Rect2(770, y + 18, 630, 42), 28, GOLD)
		text("尚未开始" if saved.is_empty() else "最高 %d 层  ·  %d 场战斗  ·  %s UTC" % [saved.highest, saved.battle_count, saved.get("saved_at", "")], Rect2(770, y + 73, 700, 37), 20, MUTED)
		button("继续", Rect2(1435, y + 24, 115, 48), func():
			if TowerRun.load_game(selected_slot): page = "lobby"; chosen_floor = int(TowerRun.data.highest) + 1
			else: TowerRun.notice = TowerRun.error
			_refresh(), true, saved.is_empty())
		button("导入", Rect2(1565, y + 24, 110, 48), func(): _import_save(selected_slot)).name = "ImportSlot_%d" % selected_slot
		button("新建存档", Rect2(1690, y + 24, 140, 48), func(): _new_dialog(selected_slot, not saved.is_empty()))
	text("迁移会保留战斗记录并备份原槽位。旧版请连同同目录的 *_battles.jsonl 一起复制。", Rect2(746, 842, 1090, 35), 19, MUTED)
	button("保存当前记录", Rect2(740, 891, 340, 56), func():
		TowerRun.notice = "存档已保存。" if TowerRun.save_game() else TowerRun.error
		_refresh(), true, TowerRun.data.is_empty())
	button("导出迁移包", Rect2(1100, 891, 320, 56), _export_save, false, TowerRun.data.is_empty()).name = "ExportSaveTransfer"
	button("打开存档文件夹", Rect2(1440, 891, 414, 56), func():
		DirAccess.make_dir_recursive_absolute(TowerRun.save_root)
		OS.shell_open(ProjectSettings.globalize_path(TowerRun.save_root)))

func _export_save() -> void:
	var dialog := FileDialog.new()
	dialog.title = "导出可迁移的尖塔存档"
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.inksave ; 尖塔迁移包"])
	dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	dialog.current_file = "InkSpire-slot%d.inksave" % TowerRun.slot
	dialog.file_selected.connect(func(path: String):
		TowerRun.notice = "迁移包已导出，包含当前存档与完整战斗记录。" if TowerRun.TRANSFER.export_bundle(path) else TowerRun.error
		dialog.queue_free()
		_refresh())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(960, 640))

func _import_save(selected_slot: int) -> void:
	var dialog := FileDialog.new()
	dialog.title = "导入到第 %d 槽：旧版存档或迁移包" % selected_slot
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.inksave,*.json,*.bak ; 尖塔存档或迁移包"])
	dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	dialog.file_selected.connect(func(path: String):
		dialog.queue_free()
		var imported := TowerRun.TRANSFER.inspect_import(path)
		if imported.is_empty():
			TowerRun.notice = "无法读取此文件：请选择尖塔存档或迁移包；原有记录未改动。"
			_refresh()
			return
		var saved: Dictionary = imported.save
		confirm("将「%s」的最高 %d 层进度导入第 %d 槽。\n该槽原有记录会先备份，再替换；其他槽位不受影响。\n来源版本：%s" % [saved.nickname, saved.highest, selected_slot, saved.get("last_played_build", saved.get("build", "旧版"))], func():
			if TowerRun.TRANSFER.import_bundle(path, selected_slot): chosen_floor = int(TowerRun.data.highest) + 1
			else: TowerRun.notice = TowerRun.error
			_refresh()))
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(960, 640))

func _new_dialog(selected_slot: int, overwrite: bool) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "新建爬塔存档"
	dialog.dialog_text = ("此槽已有记录，创建后将覆盖。\n" if overwrite else "") + "给自己起个昵称吧（最多24字）。如果之后选择公开成绩，榜单会显示这个名字。"
	dialog.min_size = Vector2i(650, 230)
	var input := LineEdit.new()
	input.max_length = 24
	input.placeholder_text = "无名攀登者"
	input.position = Vector2(25, 100)
	input.size = Vector2(590, 42)
	dialog.add_child(input)
	dialog.confirmed.connect(func(): TowerRun.new_game(input.text, selected_slot); page = "lobby"; chosen_floor = 1; dialog.queue_free(); _refresh())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()
	input.grab_focus()

func _report() -> void:
	panel(Rect2(740, 208, 1114, 714))
	text("愿意分享这次的战斗记录吗？", Rect2(780, 244, 1020, 60), 34, GOLD)
	var stats := "最高楼层   %d\n战斗场数   %d    /    胜利   %d\n游玩时间   %d 分钟\n已完成教学   %d / %d" % [TowerRun.data.highest, TowerRun.data.battle_count, TowerRun.data.victories, int(float(TowerRun.data.seconds) / 60), TowerRun.data.lessons.size(), DATA.HEROES.size() * 2]
	text(stats, Rect2(780, 344, 1000, 210), 28)
	text("报告包含昵称、版本、楼层、阵容、卡组装备、出牌、伤害和胜负。\n导出的报告已加密，修改后将无法通过校验；旧存档仅用于测试分析，不计入榜单。\n导出后可以自己上传到测试网站，游戏不会自动上传。成绩是否公开，由你选择。", Rect2(780, 585, 1000, 150), 23, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button("导出存档与战斗数据  →", Rect2(780, 790, 600, 68), _export, true)
	button("打开测试网站  ↗", Rect2(1410, 790, 385, 68), func(): OS.shell_open("https://inkspire-game.freemyip.com"))

func _export() -> void:
	TowerRun.save_game()
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	if OS.has_feature("android"): dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.json ; 加密测试报告"])
	dialog.current_file = "ink-spire-report.json"
	dialog.file_selected.connect(func(path: String):
		TowerRun.notice = "数据已导出：" + path if TowerRun.export_report(path) else TowerRun.error
		dialog.queue_free()
		_refresh())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_ratio(0.75)

func confirm(message: String, action: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = message
	dialog.min_size = Vector2i(720, 210)
	dialog.confirmed.connect(func(): dialog.queue_free(); action.call())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _settings() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var settings := SettingsPanel.new()
	layer.add_child(settings)
	settings.closed.connect(layer.queue_free)

func _quit() -> void:
	if not TowerRun.data.is_empty():
		if not TowerRun.save_game(): TowerRun.notice = TowerRun.error; _refresh(); return
	get_tree().quit()

func _open_tutorial(replay: bool = false) -> void:
	if is_instance_valid(tutorial): return
	if not replay and not TowerRun.onboarding_pending(): return
	tutorial = preload("res://scripts/ui/tower_onboarding.gd").new()
	tutorial.replay = replay and not TowerRun.onboarding_pending()
	tutorial.practice_requested.connect(_tutorial_practice)
	tutorial.closed.connect(func(): tutorial = null; _refresh.call_deferred())
	canvas.add_child(tutorial)

func _tutorial_practice(task: String) -> void:
	tutorial_practice = task
	if is_instance_valid(tutorial):
		tutorial.queue_free()
		tutorial = null
	match task:
		"formation": _formation_picker(0)
		"loadout": _characters()
		"battle":
			if not TowerRun.start_lesson("zhoumingyuan", false):
				TowerRun.notice = TowerRun.error
				_resume_tutorial()

func _resume_tutorial() -> void:
	tutorial_practice = ""
	if TowerRun.onboarding_pending(): _open_tutorial.call_deferred()

func _recovery_picker() -> void:
	var overlay := Control.new()
	overlay.name = "TowerRecoveryPicker"
	overlay.size = Vector2(1920, 1080)
	canvas.add_child(overlay)
	var shade := ColorRect.new()
	shade.size = overlay.size
	shade.color = Color(0.01, 0.03, 0.06, 0.82)
	overlay.add_child(shade)
	var box := panel(Rect2(224, 155, 1472, 770), overlay)
	box.name = "RecoveryPanel"
	text("恢复 / 已储存 %d 次" % TowerRun.recovery_charges(), Rect2(40, 24, 1200, 50), 34, GOLD, box)
	text(DATA.RECOVERY_DESCRIPTION + "每次使一人满血或复活，可积攒。", Rect2(40, 84, 1380, 42), 21, MUTED, box)
	var ids: Array = DATA.HEROES.duplicate()
	ids.insert(1, "zhoumingyuan@math")
	for i in ids.size():
		var key: String = ids[i]
		var hero := "zhoumingyuan" if key == "zhoumingyuan@math" else key
		var attribute := ("math" if key.ends_with("@math") else "none") if hero == "zhoumingyuan" else FightSystem.current_attribute(hero)
		var hp := TowerRun.health(hero, attribute)
		var maximum := FightSystem.hero_max_hp(hero)
		var tile := M.hero_button(hero, Rect2(40 + (i % 3) * 472, 150 + int(i / 3) * 180, 448, 166), func(): _confirm_recovery(hero, attribute, overlay), false, true, attribute)
		tile.name = "Recovery_" + key.replace("@", "_")
		tile.disabled = hp >= maximum or TowerRun.recovery_charges() <= 0
		box.add_child(tile)
		text("生命 %d / %d%s" % [hp, maximum, " · 已阵亡" if hp <= 0 else ""], Rect2(18, 88, 412, 30), 21, Color("a34438") if hp <= 0 else TEXT, tile).name = "RecoveryHealth"
		text("已满血" if hp >= maximum else "满血复活 · 消耗1次" if hp <= 0 else "回满生命 · 消耗1次", Rect2(18, 124, 412, 30), 21, GOLD, tile)
	button("返回", Rect2(1102, 704, 330, 44), overlay.queue_free, true, false, box).name = "RecoveryBack"

func _confirm_recovery(hero: String, attribute: String, picker: Control) -> void:
	if canvas.has_node("TowerRecoveryConfirm"): return
	var hp := TowerRun.health(hero, attribute)
	var maximum := FightSystem.hero_max_hp(hero)
	if hp >= maximum or TowerRun.recovery_charges() <= 0: return
	var overlay := Control.new()
	overlay.name = "TowerRecoveryConfirm"
	overlay.size = Vector2(1920, 1080)
	canvas.add_child(overlay)
	var shade := ColorRect.new()
	shade.size = overlay.size
	shade.color = Color(0.01, 0.03, 0.06, 0.82)
	overlay.add_child(shade)
	var box := panel(Rect2(500, 300, 920, 480), overlay)
	text("确认复活" if hp <= 0 else "确认恢复", Rect2(40, 28, 840, 50), 34, GOLD, box)
	V.hero_icon(box, hero, Rect2(40, 100, 130, 140), attribute)
	var hero_name := String(FightData.hero(hero, attribute).name)
	if hero == "zhoumingyuan": hero_name += " · %s形态" % FightData.attr_name(attribute)
	text(hero_name, Rect2(200, 107, 660, 44), 29, TEXT, box).name = "RecoveryConfirmHero"
	text("生命 %d / %d → %d / %d" % [hp, maximum, maximum, maximum], Rect2(200, 166, 660, 40), 24, TEXT, box)
	text("消耗 1 次恢复，剩余次数：%d → %d。" % [TowerRun.recovery_charges(), TowerRun.recovery_charges() - 1], Rect2(40, 268, 840, 42), 24, GOLD, box)
	text("该角色将满血复活。" if hp <= 0 else "该角色将恢复全部生命。", Rect2(40, 320, 840, 36), 21, MUTED, box)
	button("取消", Rect2(40, 394, 390, 54), overlay.queue_free, false, false, box).name = "RecoveryCancel"
	var accept := button("确认复活" if hp <= 0 else "确认恢复", Rect2(490, 394, 390, 54), func():
		box.get_node("RecoveryAccept").disabled = true
		if not TowerRun.rest(hero, attribute):
			TowerRun.notice = TowerRun.error if not TowerRun.error.is_empty() else "当前无法恢复，请检查剩余次数和角色状态。"
			_refresh()
		overlay.queue_free()
		canvas.remove_child(picker)
		picker.queue_free()
		_recovery_picker.call_deferred(), true, false, box)
	accept.name = "RecoveryAccept"
