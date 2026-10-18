extends Node2D
## 角色系统：查看永久成长，并在战斗外编辑当前角色的技能槽。

const SCREEN := Vector2(1920, 1080)
const PRESENTATION := preload("res://scripts/data/battle_presentation.gd")
const TUTORIAL_DIALOG := preload("res://scripts/ui/battle_tutorial_dialog.gd")
const TUTORIAL_SPOTLIGHT := preload("res://scripts/ui/battle_tutorial_spotlight.gd")
const ATTRIBUTE_HINT := preload("res://scripts/ui/battle_attribute_hint.gd")
const T := preload("res://scripts/ui/battle_theme.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const M := preload("res://scripts/ui/battle_management_ui.gd")
const REFERENCE := preload("res://scripts/ui/battle_reference.gd")
const EQUIPMENT_PANEL := preload("res://scripts/ui/battle_equipment_panel.gd")
var _page := "loadout"
var _tabs: Dictionary = {}
var _layer: CanvasLayer
var _ui: Control
var _content: Control
var _selected := "zhoumingyuan"
var _skill_popup: PanelContainer
var as_overlay := false
var read_only := false
var selected_hero := ""
var _error_label: Label
var _tutorial_dialog: BattleTutorialDialog
var _spotlight
var _drafts: Dictionary = {}
var _system_guide: Control

func _ready() -> void:
	if selected_hero != "":
		_selected = selected_hero
	if FightSystem.battle_active and not as_overlay:
		await SceneRouter.go_to("fight", "", true)
		return
	read_only = read_only or FightSystem.battle_active
	if not as_overlay:
		Music.play("menu", 0.8)
	_layer = CanvasLayer.new()
	_layer.layer = 70 if as_overlay else 10
	add_child(_layer)
	_ui = Control.new()
	_layer.add_child(_ui)
	_build_base()
	_rebuild()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	if _in_tutorial():
		call_deferred("_show_character_tutorial")
	elif TowerRun.active and not as_overlay and not read_only and not TowerRun.data.get("character_guide", {}).get("completed", false):
		call_deferred("_show_system_guide")

func _show_system_guide(replay: bool = false) -> void:
	if is_instance_valid(_system_guide): return
	_system_guide = preload("res://scripts/ui/character_system_guide.gd").new()
	_system_guide.replay = replay
	_system_guide.page_requested.connect(_show_page)
	_system_guide.completed.connect(func(): _system_guide = null)
	_ui.add_child(_system_guide)

func _in_tutorial() -> bool:
	return not as_overlay and FightSystem.pending_tutorial_preparation

func _show_character_tutorial() -> void:
	if not _in_tutorial():
		return
	if is_instance_valid(_spotlight):
		_spotlight.queue_free()
		_spotlight = null
	if is_instance_valid(_tutorial_dialog):
		_tutorial_dialog.queue_free()
	_tutorial_dialog = TUTORIAL_DIALOG.new() as BattleTutorialDialog
	add_child(_tutorial_dialog)
	var stage := FightSystem.tutorial_preparation_stage
	if stage == "character_intro":
		var lines := [
			"每位角色有对应的等级，属性和职业，以及拥有的技能。",
			"战斗与灵境都能获得经验。达到剧情阶段的等级上限后，经验会储存；以后需完成夜间突破任务才能继续成长。",
			"角色和敌人都有各自的属性，角色会造成其所属属性的伤害。",
			"游戏内有六种属性：语文，数学，外语，理综，文综，无极。",
			"不同属性的技能伤害可能会产生不同的克制与被克制效果。",
			"每个属性相对其他属性，会有三种可能：克制，被克制，无克制关系。",
			"无极属性是特殊的属性，不会被任何属性克制或被克制。",
			"角色的职业代表了该角色的技能特色。",
		]
		for line in lines:
			await _tutorial_dialog.show_step("角色系统", line)
		FightSystem.tutorial_preparation_stage = "switch_character"
		stage = "switch_character"
	if stage == "switch_character":
		await _tutorial_dialog.show_step("角色系统", "可以通过该部分切换你想要看的角色。请点击左侧艾莉娜。")
	elif stage == "switch_back":
		await _tutorial_dialog.show_step("角色系统", "已切换到艾莉娜。现在点击周明远，查看他的普通攻击。")
	elif stage == "skill_intro":
		for line in [
			"每个角色的技能携带都需要消耗相应的携带 cost，且同名技能最多只能装备三个。少数强力技能可能最大装备数会更少。",
			"技能分为稀有（金色）、中等（蓝色）、普通（白色）。稀有度与携带 cost、战斗能量消耗分别显示。",
			"每名角色的卡组数量必须大于等于卡组初始大小。目前为 %d 张，同时携带 cost 不得超过上限。换牌时可先减后加，满足限制后自动保存。" % FightSystem.initial_deck_size(_selected),
			"点击技能框中加减号以外的区域，或右键点击技能，都能查看详细介绍。请查看普通攻击。",
		]:
			await _tutorial_dialog.show_step("技能与卡组", line)
		FightSystem.tutorial_preparation_stage = "inspect_basic"
		stage = "inspect_basic"
	elif stage == "open_formation":
		await _tutorial_dialog.show_step("角色系统", "点击打开编队。")
	if is_instance_valid(_tutorial_dialog):
		_tutorial_dialog.queue_free()
		_tutorial_dialog = null
	if not is_inside_tree() or stage != FightSystem.tutorial_preparation_stage:
		return
	await get_tree().process_frame
	if not is_inside_tree(): return
	_spotlight = TUTORIAL_SPOTLIGHT.new()
	add_child(_spotlight)
	_update_tutorial_focus()

func _tutorial_target() -> Control:
	var names := {"switch_character":"Hero_alyina", "switch_back":"Hero_zhoumingyuan", "inspect_basic":"Skill_basic_strike", "open_formation":"OpenFormation"}
	return _content.find_child(String(names.get(FightSystem.tutorial_preparation_stage, "MissingTarget")), true, false) as Control

func _update_tutorial_focus() -> void:
	if not is_instance_valid(_spotlight): return
	_spotlight.focus(M.focus_rect(_ui, _tutorial_target()))

func _advance_tutorial(stage: String) -> void:
	FightSystem.tutorial_preparation_stage = stage
	call_deferred("_show_character_tutorial")

func _select_hero(hero_id: String) -> void:
	if _in_tutorial():
		var expected := "alyina" if FightSystem.tutorial_preparation_stage == "switch_character" else "zhoumingyuan"
		if FightSystem.tutorial_preparation_stage not in ["switch_character", "switch_back"] or hero_id != expected:
			return
	_selected = hero_id
	_rebuild()
	if _in_tutorial():
		_advance_tutorial("switch_back" if hero_id == "alyina" else "skill_intro")

func _build_base() -> void:
	var arena := String(PRESENTATION.for_encounter(FightSystem.encounter_serial, FightSystem.return_location, FightSystem.active_story_encounter).arena) if FightSystem.battle_active else PRESENTATION.preview_arena(FightSystem.return_location, FightSystem.pending_story_encounter)
	M.shell(_ui, "角色系统", "查看角色成长、调整携带技能，或查阅战斗指南", PRESENTATION.arena_path(arena)).name = "CharacterBackground"
	if TowerRun.active and not read_only:
		var guide := M.button("功能教程", Rect2(596, 58, 170, 48), func(): _show_system_guide(true))
		guide.name = "CharacterGuideReplay"
		_ui.add_child(guide)
	var pages := {"loadout":"角色与卡组", "equipment":"专武 / 遗物", "attributes":"属性克制", "bestiary":"怪物图鉴", "items":"战斗道具", "effects":"机制说明"}
	var i := 0
	for key in pages:
		var tab := M.button(pages[key], Rect2(790 + i * 176, 58, 164, 48), func() -> void: _show_page(key))
		tab.name = "CharacterTab_" + key
		tab.disabled = _in_tutorial() and key != "loadout"
		_ui.add_child(tab)
		_tabs[key] = tab
		i += 1
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size = SCREEN
	_ui.add_child(_content)

func _show_page(key: String) -> void:
	if _content.find_child("EquipmentMotion", true, false) != null: return
	if _in_tutorial() and key != "loadout": return
	_page = key
	_rebuild()

func _rebuild() -> void:
	if not is_instance_valid(_content): return
	if is_instance_valid(_skill_popup):
		_skill_popup.queue_free()
		_skill_popup = null
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_error_label = null
	for key in _tabs: T.button(_tabs[key], T.GOLD, key == _page)
	if _page == "loadout":
		var roster: Array = FightSystem.roster()
		if read_only:
			roster.clear()
			for ally in FightSystem.allies: roster.append(String(ally.id))
		if roster.is_empty(): return
		if not roster.has(_selected): _selected = String(roster[0])
		V.text(_content, "角色档案  /  %02d" % roster.size(), Rect2(68, 169, 280, 28), 18, T.MUTED)
		var scroll := ScrollContainer.new()
		scroll.name = "CharacterRoster"
		_place(scroll, Rect2(64, 211, 290, 690))
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_content.add_child(scroll)
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 10)
		scroll.add_child(rows)
		for id in roster:
			var tile := M.hero_button(id, Rect2(0, 0, 270, 90), func() -> void: _select_hero(id), id == _selected, true)
			tile.custom_minimum_size = Vector2(270, 90)
			rows.add_child(tile)
		_draw_detail(FightData.hero(_selected))
	elif _page == "equipment":
		var equipment := EQUIPMENT_PANEL.new()
		equipment.hero_id = _selected
		equipment.selected = "proof_compass_math" if _selected == "zhoumingyuan" and FightSystem.current_attribute(_selected) == "math" else String(TowerData.WEAPONS.get(_selected, ""))
		if TowerRun.active: equipment._category = "weapons"
		equipment.read_only = read_only
		equipment.position = Vector2(64, 180)
		equipment.hero_changed.connect(func(id: String) -> void: _selected = id)
		_content.add_child(equipment)
	else:
		var reference := REFERENCE.new()
		reference.page = _page
		reference.hero_id = _selected
		reference.read_only = read_only
		reference.position = Vector2(64, 180)
		_content.add_child(reference)
	V.text(_content, "点击技能查看效果 · 战斗中仅查看资料" if read_only else "合法卡组会自动保存 · 点击技能框查看效果，＋／−调整数量 · 也支持右键", Rect2(68, 958, 1080, 32), 18, T.MUTED)
	if read_only:
		_content.add_child(_button("关闭", Vector2(1670, 942), Vector2(180, 60), _close_overlay, T.GOLD, 21))
	else:
		var formation := _button("打开编队", Vector2(1435, 942), Vector2(240, 60), _open_formation, T.BLUE, 23)
		formation.name = "OpenFormation"
		_content.add_child(formation)
		var back := _button("返回尖塔" if TowerRun.active else "返回地图" if as_overlay else ("返回教学" if FightSystem.can_start_tutorial_battle() else "返回标题"), Vector2(1694, 942), Vector2(156, 60), _return_from_menu, T.GOLD, 20)
		back.disabled = _in_tutorial()
		_content.add_child(back)
	_update_tutorial_focus.call_deferred()

func _draw_detail(profile: Dictionary) -> void:
	var attribute := FightSystem.current_attribute(_selected)
	var identity := T.identity(_selected, attribute)
	var panel := M.panel(Rect2(378, 178, 542, 724), identity.fill, identity.edge)
	panel.name = "CharacterIdentity"
	T.material_identity(panel, identity)
	_content.add_child(panel)
	M.heading(panel, "角色档案", Rect2(26, 17, 350, 34), 22)
	V.text(panel, "Lv.%02d" % FightProgression.hero_level(_selected), Rect2(380, 17, 136, 34), 24, T.GOLD, true)
	V.hero_icon(panel, _selected, Rect2(60, 64, 422, 192), attribute).name = "CharacterPortrait"
	var portrait_style := preload("res://scripts/ui/battle_portrait_style.gd").new()
	portrait_style.hero_id = _selected
	portrait_style.position = Vector2(26, 266)
	portrait_style.style_selected.connect(_rebuild)
	panel.add_child(portrait_style)
	M.heading(panel, String(profile.name), Rect2(26, 340, 490, 48), 34, true)
	ATTRIBUTE_HINT.badge(panel, attribute, Rect2(96, 396, 100, 32)).name = "CharacterAttribute"
	V.text(panel, String(FightData.ROLES.get(profile.role, profile.role)), Rect2(214, 396, 240, 32), 22, T.TEXT)
	var growth: Dictionary = GameState.fight_profiles.get(_selected, {"level":1, "xp":0})
	V.text(panel, "生命上限 %d   ·   经验 %d / %d" % [FightSystem.hero_max_hp(_selected), int(growth.get("xp", 0)), TowerData.xp_needed(int(growth.get("level", 1))) if TowerRun.active else int(growth.get("level", 1)) * 100], Rect2(26, 444, 490, 31), 20, T.MUTED, true)
	var scroll := ScrollContainer.new()
	scroll.name = "CharacterMechanics"
	scroll.position = Vector2(26, 492)
	scroll.size = Vector2(490, 123 if _selected == "zhoumingyuan" else 144 if _selected == "li_anya" else 202)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 9)
	scroll.add_child(words)
	_detail_paragraph(words, "角色被动", FightData.passive(_selected, attribute))
	var ultimate := FightData.ultimate(_selected, attribute)
	var unit := {"id":_selected, "attribute":attribute}
	M.ultimate_illustration(words, unit, 112, func():
		var detail := preload("res://scripts/ui/battle_ultimate_reference.gd").new()
		detail.unit = unit
		detail.ultimate = ultimate
		_ui.add_child(detail))
	_detail_paragraph(words, "终结技 · %s / %s %d" % [ultimate.name, "涅槃充能" if _selected == "li_anya" else "能量", ultimate.energy], ultimate.desc)
	if _selected == "li_anya":
		var forms := _button("查看双形态技能", Vector2(26, 646), Vector2(490, 48), func() -> void: _ui.add_child(preload("res://scripts/ui/anya_form_reference.gd").new()), T.GOLD, 19)
		forms.name = "AnyaFormReference"
		panel.add_child(forms)
	if _selected == "zhoumingyuan":
		V.text(panel, "切换属性 · 每场战斗装备一种", Rect2(26, 625, 490, 28), 17, T.MUTED)
		var unlocked: Array = FightSystem.unlocked_attributes()
		for index in unlocked.size():
			var attr := String(unlocked[index])
			var choice := _button(FightData.attr_name(attr), Vector2(26 + index % 3 * 164, 656 + int(index / 3) * 36), Vector2(154, 30), func() -> void:
				if _drafts.has(_selected):
					_show_error("请先完成或撤销当前卡组调整，再切换形态。")
					return
				FightSystem.set_attribute(_selected, attr)
				_rebuild()
			, T.BLUE, 17)
			choice.disabled = read_only
			choice.set_meta("attribute", attr)
			T.button(choice, identity.accent, attr == attribute)
			panel.add_child(choice)
	_content.add_child(M.panel(Rect2(944, 178, 908, 724)))
	var loadout := _working_loadout()
	var points := FightSystem.loadout_points(loadout)
	var limit := FightSystem.skill_point_limit(_selected)
	M.heading(_content, "携带技能", Rect2(972, 194, 420, 44), 30)
	V.text(_content, "携带 cost  %d / %d" % [points, limit], Rect2(1410, 201, 404, 34), 24, T.RED if points > limit else T.GOLD, true)
	V.text(_content, "卡组 %d 张 / 至少 %d 张 · 同名最多 %d 张" % [loadout.size(), FightSystem.initial_deck_size(_selected), FightData.MAX_SKILL_COPIES], Rect2(974, 246, 620, 29), 18, T.MUTED)
	_draw_skills(FightData.skills_for(_selected, attribute), points, limit)
	_draw_growth_and_accessories()
	if _drafts.has(_selected):
		_show_error("调整中，尚未保存：" + FightSystem.loadout_error(_selected, _working_loadout()))
		_content.add_child(_button("撤销调整", Vector2(1662, 245), Vector2(154, 32), func() -> void:
			_drafts.erase(_selected)
			_rebuild()
		, T.RED, 17))

func _detail_paragraph(parent: Node, title: String, description: String) -> void:
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_override("font", T.HEADING)
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", T.GOLD)
	parent.add_child(heading)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = description
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 17)
	parent.add_child(body)

func _draw_skills(skills: Array, points: int, limit: int) -> void:
	var loadout := _working_loadout()
	var scroll := ScrollContainer.new()
	scroll.name = "SkillCatalog"
	scroll.position = Vector2(968, 290)
	scroll.size = Vector2(864, 333)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var groups := VBoxContainer.new()
	groups.add_theme_constant_override("separation", 14)
	scroll.add_child(groups)
	var grid: GridContainer
	var group := ""
	var split_forms := _selected == "zhoumingyuan" and FightSystem.current_attribute(_selected) == "math"
	for skill in skills:
		var id := String(skill)
		if _in_tutorial() and id == "red_pen": continue
		var next_group := ("数学技能" if id.begins_with("M") else "通用无极技能") if split_forms else "全部技能"
		if next_group != group:
			group = next_group
			if split_forms:
				var heading := Label.new()
				heading.text = group
				heading.add_theme_font_size_override("font_size", 23)
				heading.add_theme_color_override("font_color", T.GOLD)
				groups.add_child(heading)
			grid = GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 14)
			grid.add_theme_constant_override("v_separation", 14)
			groups.add_child(grid)
		var def := FightData.skill(id)
		var count := loadout.count(id)
		var unlocked := FightSystem.skill_available(_selected, id)
		var tile := _button("", Vector2.ZERO, Vector2(414, 136), func() -> void: _inspect_skill(id), T.GOLD, 20)
		tile.custom_minimum_size = Vector2(414, 136)
		tile.name = "Skill_" + id
		tile.set_meta("skill_id", id)
		M.identity_button(tile, _selected, count > 0)
		grid.add_child(tile)
		V.icon(tile, FightData.skill_icon(id), Rect2(14, 24, 74, 74))
		M.heading(tile, String(def.name), Rect2(102, 10, 294, 34), 21)
		V.text(tile, "%s · 携带 %d · 能量 %s" % [FightData.rarity_name(id), FightData.skill_points(id), "X" if int(def.get("cost", 0)) < 0 else str(def.get("cost", 0))], Rect2(104, 47, 292, 25), 15, T.MUTED)
		var minus := _button("−", Vector2(104, 86), Vector2(44, 34), func() -> void: _change_count(id, -1), T.RED, 22)
		minus.name = "RemoveCopy"
		minus.mouse_filter = Control.MOUSE_FILTER_STOP
		minus.disabled = read_only or not unlocked or count <= 0 or _in_tutorial()
		tile.add_child(minus)
		V.text(tile, "%d / %d" % [count, FightData.copies(id)], Rect2(155, 86, 75, 34), 20, T.GOLD, true)
		var plus := _button("+", Vector2(238, 86), Vector2(44, 34), func() -> void: _change_count(id, 1), T.GREEN, 22)
		plus.name = "AddCopy"
		plus.mouse_filter = Control.MOUSE_FILTER_STOP
		plus.disabled = read_only or not unlocked or count >= FightData.copies(id) or _in_tutorial()
		tile.add_child(plus)
		V.text(tile, "点击详情" if unlocked else "剧情习得" if def.get("story_unlock", false) else "Lv.%d 解锁" % FightData.unlock_level(id), Rect2(293, 88, 106, 30), 14, T.MUTED if unlocked else T.RED, true)
		if preload("res://scripts/ui/tower_mobile.gd").enabled():
			var detail := M.button("详情", Rect2(292, 82, 108, 48), func(): _inspect_skill(id))
			detail.name = "MobileSkillDetail"
			tile.add_child(detail)
			minus.position.y = 80
			minus.size = Vector2(52, 52)
			plus.position.y = 80
			plus.size = Vector2(52, 52)
		tile.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				_inspect_skill(id)
				get_viewport().set_input_as_handled()
		)
	if points > limit: _show_error("携带 cost 超上限：请调整技能后保存。")

func _inspect_skill(id: String) -> void:
	if _in_tutorial() and (FightSystem.tutorial_preparation_stage != "inspect_basic" or id != "basic_strike"): return
	_show_skill_popup(FightData.skill(id).merged({"desc":FightData.description(id, FightProgression.hero_level(_selected))}, true))
	if _in_tutorial(): _advance_tutorial("open_formation")

func _show_skill_popup(def: Dictionary) -> void:
	if is_instance_valid(_skill_popup):
		_skill_popup.queue_free()
	_skill_popup = PanelContainer.new()
	_skill_popup.z_index = 40
	_skill_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := T.frame(T.SURFACE, T.GOLD, 2, 6)
	style.set_content_margin_all(20)
	_skill_popup.add_theme_stylebox_override("panel", style)
	_ui.add_child(_skill_popup)
	_place(_skill_popup, Rect2(Vector2(970, 642), Vector2(860, 238)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_skill_popup.add_child(box)
	var title := Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text = "%s · %s · 能量 %s / 携带 cost %d" % [def.get("name", "技能"), FightData.RARITIES[def.get("rarity", "common")].name, "X" if int(def.get("cost", 0)) < 0 else str(def.get("cost", 0)), int(def.get("skill_points", 1))]
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", T.GOLD)
	box.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "%s\n属性：%s　目标：%s" % [def.get("desc", ""), FightData.attr_name(String(def.get("attribute", FightData.ATTR_NONE))), FightData.target_name(String(def.get("target", "enemy")))]
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", T.TEXT)
	box.add_child(body)

func _add_button_icon(button: Button, icon_name: String) -> void:
	var icon := TextureRect.new()
	icon.texture = load("res://assets/graphics/battle/icons/%s.webp" % icon_name) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	_place(icon, Rect2(Vector2(4, 2), button.size - Vector2(8, 4)))

func _input(event: InputEvent) -> void:
	if is_instance_valid(_system_guide):
		for action in ["pause", "ui_cancel", "ui_focus_next", "ui_focus_prev", "ui_up", "ui_down", "ui_left", "ui_right"]:
			if event.is_action_pressed(action): get_viewport().set_input_as_handled()
		return
	if _content.find_child("EquipmentMotion", true, false) != null:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"): get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and is_instance_valid(_skill_popup):
		_skill_popup.queue_free()
		_skill_popup = null
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _in_tutorial():
			return
		if read_only:
			_close_overlay()
		else:
			_return_from_menu()

func _show_error(message: String) -> void:
	if message.is_empty():
		return
	if _error_label != null and is_instance_valid(_error_label):
		_error_label.queue_free()
	_error_label = _label(message, Vector2(980, 900), Vector2(700, 42), 18, T.RED)
	_content.add_child(_error_label)

func _close_overlay() -> void:
	queue_free()

func _open_formation() -> void:
	if _has_pending_draft(): return
	if TowerRun.active:
		TowerRun.save_game()
		await SceneRouter.go_to("tower")
		return
	if _in_tutorial():
		if FightSystem.tutorial_preparation_stage != "open_formation":
			return
		FightSystem.tutorial_preparation_stage = "begin_battle"
	await FightSystem.open_trial_preparation()

func _return_from_menu() -> void:
	if _has_pending_draft(): return
	if TowerRun.active and not as_overlay:
		TowerRun.save_game()
		await SceneRouter.go_to("tower")
		return
	if as_overlay:
		FightSystem.close_management_panel()
	elif FightSystem.can_start_tutorial_battle():
		await SceneRouter.go_to("fight_prepare", "", true)
	else:
		await _back_to_title()

func _back_to_title() -> void:
	await GameFlow.back_to_title(GameState.slot > 0)

func _label(text: String, pos: Vector2, size: Vector2, font: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", T.BODY)
	label.add_theme_font_size_override("font_size", font)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(label, Rect2(pos, size))
	return label

func _button(text: String, pos: Vector2, size: Vector2, handler: Callable, accent: Color, font: int) -> Button:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	T.button(button, accent)
	button.add_theme_font_size_override("font_size", font)
	button.pressed.connect(handler)
	_place(button, Rect2(pos, size))
	return button

func _panel(pos: Vector2, size: Vector2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", T.frame(color, border, 1, 6))
	_place(panel, Rect2(pos, size))
	return panel

func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size

func _relayout() -> void:
	if not is_instance_valid(_ui):
		return
	if preload("res://scripts/ui/tower_mobile.gd").enabled():
		_ui.size = SCREEN
		preload("res://scripts/ui/tower_mobile.gd").fit(_ui, get_viewport())
		return
	var viewport := get_viewport_rect().size
	_ui.size = SCREEN
	var scale: float = minf(viewport.x / SCREEN.x, viewport.y / SCREEN.y)
	_ui.scale = Vector2(scale, scale)
	_ui.position = (viewport - SCREEN * scale) * 0.5

func _draw_growth_and_accessories() -> void:
	var panel := M.panel(Rect2(968, 646, 858, 228), T.RECESSED, T.LINE)
	_content.add_child(panel)
	M.heading(panel, "爬塔成长" if TowerRun.active else "成长与突破", Rect2(20, 12, 390, 35), 23)
	V.text(panel, FightProgression.summary(), Rect2(20, 51, 404, 31), 18, T.GOLD)
	M.paragraph(panel, ("每通关5层，等级上限+5，最高50级。\n技能在1/10/20/30/40级开放。\n20层与40层提高被动阶位及基础能量。" if TowerRun.active else "战斗能量上限 %d（最高 %d）\n下次突破：等级 +%d / cost +%d / 能量 +%d\n%s" % [FightSystem.action_point_limit(), FightProgression.MAX_ENERGY, FightProgression.LEVELS_PER_BREAKTHROUGH, FightProgression.COST_PER_BREAKTHROUGH, FightProgression.ENERGY_PER_BREAKTHROUGH, FightProgression.breakthrough_error()]), Rect2(20, 92, 404, 118), 16, T.MUTED)
	M.heading(panel, "专武 / 遗物", Rect2(448, 12, 390, 35), 23)
	var bonus := FightEquipmentData.bonuses(_selected)
	V.text(panel, "生命 +%d / 伤害 +%d%%" % [bonus.max_hp, roundi(float(bonus.damage_bonus) * 100)], Rect2(448, 51, 388, 31), 18, T.GREEN)
	var slots := FightEquipmentData.slots(_selected)
	for i in slots.size():
		var id := String(slots[i])
		var slot := M.button("", Rect2(448 + i * 196, 94, 184, 108), func() -> void: _show_page("equipment"), T.GOLD)
		slot.name = "CharacterAccessorySlot_%d" % i
		slot.disabled = _in_tutorial()
		panel.add_child(slot)
		if not id.is_empty(): V.icon(slot, FightEquipmentData.texture(id), Rect2(8, 16, 68, 68))
		else: V.glyph(slot, "innate", Rect2(22, 28, 42, 42), T.LINE)
		M.paragraph(slot, "槽 %d\n%s" % [i + 1, FightEquipmentData.definition(id).get("name", "点击安装")], Rect2(82, 12, 94, 84), 16)

func _working_loadout() -> Array:
	return (_drafts[_selected] as Array).duplicate() if _drafts.has(_selected) else FightSystem.loadout(_selected)

func _change_count(skill_id: String, delta: int) -> void:
	if read_only: return
	var cards := _working_loadout()
	if delta > 0:
		if cards.count(skill_id) >= FightData.copies(skill_id):
			_show_error("同名技能最多携带 %d 张。" % FightData.copies(skill_id))
			return
		cards.append(skill_id)
	else: cards.erase(skill_id)
	# 允许先减后加以替换满 cost 卡组；只有完整合法的草稿才写入存档。
	if FightSystem.set_loadout(_selected, cards): _drafts.erase(_selected)
	else: _drafts[_selected] = cards
	_rebuild()

func _has_pending_draft() -> bool:
	if _drafts.is_empty(): return false
	_selected = String(_drafts.keys()[0])
	_rebuild()
	_show_error("请补齐卡组并满足携带 cost，或点击「撤销调整」后离开。")
	return true
