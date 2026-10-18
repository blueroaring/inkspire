extends Node2D
## 战前编队界面：这里只选择本次出战角色，技能配置属于角色系统。

const SCREEN := Vector2(1920, 1080)
const PRESENTATION := preload("res://scripts/data/battle_presentation.gd")
const TUTORIAL_DIALOG := preload("res://scripts/ui/battle_tutorial_dialog.gd")
const TUTORIAL_SPOTLIGHT := preload("res://scripts/ui/battle_tutorial_spotlight.gd")
const T := preload("res://scripts/ui/battle_theme.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const M := preload("res://scripts/ui/battle_management_ui.gd")
const ART := preload("res://scripts/data/battle_art.gd")
const ATTRIBUTE_HINT := preload("res://scripts/ui/battle_attribute_hint.gd")
var _layer: CanvasLayer
var _ui: Control
var _content: Control
var _slot_index := 0
var _picker: Control
var _tutorial_dialog: BattleTutorialDialog
var _spotlight
var as_overlay := false

func _ready() -> void:
	if FightSystem.battle_active:
		await SceneRouter.go_to("fight", "", true)
		return
	if not as_overlay and FightSystem.can_start_tutorial_battle():
		Music.play(PRESENTATION.preview_music(), 0.8)
	_layer = CanvasLayer.new()
	_layer.layer = 70 if as_overlay else 10
	add_child(_layer)
	_ui = Control.new()
	_layer.add_child(_ui)
	_build_base()
	FightSystem.state_changed.connect(_rebuild)
	get_viewport().size_changed.connect(_relayout)
	_rebuild()
	_relayout()
	if not as_overlay and FightSystem.pending_tutorial:
		call_deferred("_show_formation_tutorial")

func _show_formation_tutorial() -> void:
	if not FightSystem.pending_tutorial_preparation or as_overlay:
		return
	if is_instance_valid(_spotlight):
		_spotlight.queue_free()
		_spotlight = null
	if is_instance_valid(_tutorial_dialog):
		_tutorial_dialog.queue_free()
	_tutorial_dialog = TUTORIAL_DIALOG.new() as BattleTutorialDialog
	add_child(_tutorial_dialog)
	var guide: Dictionary = {
		"slot_1": "点击第一个空闲位置。",
		"choose_zhou": "选择周明远。",
		"slot_2": "点击第二个空闲位置。",
		"choose_alyina": "选择艾莉娜。",
		"open_characters": "打开角色系统。",
		"begin_battle": "点击开始战斗。",
	}
	var stage := FightSystem.tutorial_preparation_stage
	if not guide.has(stage):
		return
	await _tutorial_dialog.show_step("编队 · 新手教程", String(guide[stage]))
	if is_instance_valid(_tutorial_dialog):
		_tutorial_dialog.queue_free()
		_tutorial_dialog = null
	if stage == FightSystem.tutorial_preparation_stage and is_inside_tree():
		_spotlight = TUTORIAL_SPOTLIGHT.new()
		add_child(_spotlight)
		await get_tree().process_frame
		if is_inside_tree(): _update_tutorial_focus()

func _tutorial_target() -> Control:
	var names := {"slot_1":"FormationSlot_0", "slot_2":"FormationSlot_1", "choose_zhou":"Hero_zhoumingyuan", "choose_alyina":"Hero_alyina", "open_characters":"OpenCharacters", "begin_battle":"BeginBattle"}
	return _ui.find_child(String(names.get(FightSystem.tutorial_preparation_stage, "MissingTarget")), true, false) as Control

func _update_tutorial_focus() -> void:
	if is_instance_valid(_spotlight): _spotlight.focus(M.focus_rect(_ui, _tutorial_target()))

func _advance_tutorial(stage: String) -> void:
	FightSystem.tutorial_preparation_stage = stage
	call_deferred("_show_formation_tutorial")

func _build_base() -> void:
	M.shell(_ui, "出战编队", "选择本次出战的伙伴 · 技能配置请在角色系统中调整", PRESENTATION.arena_path(PRESENTATION.preview_arena(FightSystem.return_location, FightSystem.pending_story_encounter))).name = "PreparationBackground"
	V.text(_ui, FightProgression.summary(), Rect2(1160, 61, 660, 40), 22, T.GOLD, true)
	_content = Control.new()
	_content.size = SCREEN
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_content)

func _rebuild() -> void:
	if not is_instance_valid(_content): return
	_close_picker()
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var slots: Array = FightSystem.formation_slots()
	V.text(_content, "队伍成员", Rect2(66, 166, 450, 32), 22, T.TEXT)
	V.text(_content, "点击卡片更换伙伴 · 配置自动保存", Rect2(1160, 166, 678, 32), 18, T.MUTED, true)
	for slot in FightSystem.PARTY_LIMIT:
		var id := String(slots[slot])
		var card := M.button("", Rect2(64 + slot * 449, 215, 432, 554), func() -> void: _open_picker(slot))
		card.name = "FormationSlot_%d" % slot
		card.clip_contents = true
		_content.add_child(card)
		V.text(card, "出战位置  %02d" % (slot + 1), Rect2(24, 18, 270, 32), 19, T.MUTED)
		if not id.is_empty():
			var profile := FightData.hero(id)
			var attribute := FightSystem.current_attribute(id)
			M.identity_button(card, id, slot == _slot_index)
			var module := ART.module({"id":id, "attribute":attribute})
			V.icon(card, ART.actor(module), Rect2(26, 60, 380, 338))
			if id == "zhoumingyuan" and TowerRun.active:
				for form_index in 2:
					var form := "none" if form_index == 0 else "math"
					var switch := M.button(FightData.attr_name(form), Rect2(30 + form_index * 194, 363, 178, 36), func() -> void:
						if FightSystem.set_attribute(id, form):
							TowerRun.save_game()
							_rebuild()
					, T.GOLD, attribute == form)
					switch.name = "FormationAttribute_" + form
					switch.disabled = not FightSystem.unlocked_attributes().has(form)
					card.add_child(switch)
			M.heading(card, String(profile.name), Rect2(24, 409, 384, 47), 33, true)
			ATTRIBUTE_HINT.badge(card, attribute, Rect2(69, 472, 100, 32))
			V.text(card, "Lv.%d · %s" % [FightProgression.hero_level(id), FightData.ROLES.get(profile.role, profile.role)], Rect2(184, 472, 220, 32), 20, T.TEXT)
			var hp_note := " · 生命 %d/%d" % [TowerRun.health(id), FightSystem.hero_max_hp(id)] if TowerRun.active else ""
			V.text(card, "携带技能 %d 张%s" % [FightSystem.loadout(id).size(), hp_note], Rect2(24, 516, 384, 25), 16, T.MUTED, true)
			var clear := M.button("×", Rect2(367, 14, 44, 38), func() -> void:
				if not FightSystem.pending_tutorial_preparation: FightSystem.set_formation_slot(slot, "")
			, T.RED)
			clear.name = "RemoveFormation_%d" % slot
			clear.tooltip_text = "移除出战角色"
			clear.disabled = FightSystem.pending_tutorial_preparation or FightSystem.formation().size() <= 1
			card.add_child(clear)
		else:
			V.glyph(card, "all", Rect2(162, 166, 108, 108), T.LINE)
			M.heading(card, "选择角色", Rect2(24, 312, 384, 46), 29, true)
			V.text(card, "空闲位置 · 点击加入伙伴", Rect2(24, 368, 384, 30), 19, T.MUTED, true)
	var summary := M.panel(Rect2(64, 793, 1780, 82), T.RECESSED)
	_content.add_child(summary)
	M.heading(summary, "已编入 %d / %d" % [FightSystem.formation().size(), FightSystem.PARTY_LIMIT], Rect2(24, 20, 450, 40), 26)
	V.text(summary, "队伍卡组 %d 张    /    战斗能量上限 %d" % [_party_card_count(), FightSystem.action_point_limit()], Rect2(580, 20, 1160, 40), 23, T.MUTED, true)
	var detail := _button("打开角色系统", Vector2(600, 924), Vector2(270, 62), _open_character_system, T.BLUE, 23)
	detail.name = "OpenCharacters"
	_content.add_child(detail)
	if not as_overlay and FightSystem.can_start_tutorial_battle():
		var begin := _button("开始战斗", Vector2(1450, 924), Vector2(300, 62), _begin_battle, T.GOLD, 26)
		begin.name = "BeginBattle"
		T.button(begin, T.GOLD, true)
		begin.disabled = not FightSystem.tutorial_formation_ready()
		if begin.disabled: begin.tooltip_text = "请先选择周明远和艾莉娜"
		_content.add_child(begin)
	var back := _button("返回地图" if as_overlay else "返回标题", Vector2(1100, 924), Vector2(300, 62), _return_from_menu, T.GOLD, 23)
	back.disabled = FightSystem.pending_tutorial_preparation
	_content.add_child(back)
	_update_tutorial_focus.call_deferred()

func _open_picker(slot: int) -> void:
	if FightSystem.pending_tutorial_preparation:
		if (FightSystem.tutorial_preparation_stage == "slot_1" and slot != 0) or (FightSystem.tutorial_preparation_stage == "slot_2" and slot != 1): return
		if FightSystem.tutorial_preparation_stage not in ["slot_1", "slot_2"]: return
	_slot_index = slot
	_close_picker()
	_picker = Control.new()
	_picker.name = "FormationPicker"
	_picker.z_index = 30
	_picker.size = SCREEN
	_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(_picker)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.48)
	shade.size = SCREEN
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_picker.add_child(shade)
	_picker.add_child(M.panel(Rect2(190, 135, 1540, 790), T.INK, T.LINE))
	M.heading(_picker, "选择第 %d 个出战位置" % (slot + 1), Rect2(245, 176, 1000, 54), 34)
	V.text(_picker, "选择后自动关闭 · 已上阵角色会与该位置交换", Rect2(248, 242, 1000, 30), 19, T.MUTED)
	var close := _button("关闭", Vector2(1510, 175), Vector2(150, 52), _close_picker, T.GOLD, 21)
	close.disabled = FightSystem.pending_tutorial_preparation
	_picker.add_child(close)
	var roster: Array = ["zhoumingyuan", "alyina"] if FightSystem.pending_tutorial_preparation else FightSystem.roster()
	for index in roster.size():
		var id := String(roster[index])
		var chosen := FightSystem.formation_slots().has(id)
		var tile := M.hero_button(id, Rect2(245 + index % 4 * 350, 302 + int(index / 4) * 282, 300, 258), func() -> void: _choose_hero(id), chosen)
		_picker.add_child(tile)
		if chosen: V.text(tile, "已在编队 · 点击交换", Rect2(14, 229, 272, 24), 15, T.GOLD, true)
	if FightSystem.pending_tutorial_preparation: _advance_tutorial("choose_zhou" if slot == 0 else "choose_alyina")

func _choose_hero(hero_id: String) -> void:
	if FightSystem.pending_tutorial_preparation:
		var expected := "zhoumingyuan" if FightSystem.tutorial_preparation_stage == "choose_zhou" else "alyina"
		if hero_id != expected or FightSystem.tutorial_preparation_stage not in ["choose_zhou", "choose_alyina"]:
			return
		FightSystem.tutorial_preparation_stage = "slot_2" if hero_id == "zhoumingyuan" else "open_characters"
	FightSystem.set_formation_slot(_slot_index, hero_id)
	_close_picker()
	if FightSystem.pending_tutorial_preparation:
		call_deferred("_show_formation_tutorial")

func _close_picker() -> void:
	if is_instance_valid(_picker):
		_picker.queue_free()
	_picker = null

func _begin_battle() -> void:
	if as_overlay or not FightSystem.can_start_tutorial_battle():
		return
	if FightSystem.tutorial_preparation_stage != "begin_battle":
		return
	await FightSystem.begin_trial()

func _back_to_title() -> void:
	if FightSystem.battle_active:
		return
	await GameFlow.back_to_title(GameState.slot > 0)

func _open_character_system() -> void:
	if FightSystem.battle_active:
		return
	if FightSystem.pending_tutorial_preparation:
		if FightSystem.tutorial_preparation_stage != "open_characters":
			return
		FightSystem.tutorial_preparation_stage = "character_intro"
	await FightSystem.open_character_system()

func _return_from_menu() -> void:
	if as_overlay:
		FightSystem.close_management_panel()
	else:
		await _back_to_title()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if FightSystem.pending_tutorial_preparation:
			return
		if is_instance_valid(_picker):
			_close_picker()
		else:
			_return_from_menu()

func _label_in_content(text: String, pos: Vector2, size: Vector2, font: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := _label(text, pos, size, font, color, align)
	_content.add_child(label)
	return label

func _label(text: String, pos: Vector2, size: Vector2, font: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
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

func _add_button_icon(button: Button, icon_name: String) -> void:
	var icon := TextureRect.new()
	icon.texture = load("res://assets/graphics/battle/icons/%s.webp" % icon_name) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	_place(icon, Rect2(Vector2(8, 8), button.size - Vector2(16, 16)))

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
	var viewport := get_viewport_rect().size
	_ui.size = SCREEN
	var scale: float = minf(viewport.x / SCREEN.x, viewport.y / SCREEN.y)
	_ui.scale = Vector2(scale, scale)
	_ui.position = (viewport - SCREEN * scale) * 0.5

func _party_card_count() -> int:
	var count := 0
	for id in FightSystem.formation(): count += FightSystem.loadout(id).size()
	return count
