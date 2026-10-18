extends Node2D
## 战斗场景表现层：所有规则调用 FightSystem，场景本身可被地图战斗入口复用。

var _fc_choices: Control
var _painting_popup: Control
var _painting_sequence: Control
var _calculation_popup: Control
var _fc_card_detail: Control
var _mobile_inspect := false
var _mobile_inspect_button: Button
var _mobile_cancel_button: Button
const FC_VISUALS := preload("res://scripts/ui/fc_card_visuals.gd")
const CHROME := preload("res://scripts/ui/battle_chrome.gd")
const DISPLAY_FONT := preload("res://assets/fonts/noto_serif_sc/battle_ui.tres")
var _round_label: Label
var _energy_skin: Control
const BATTLE_THEME := preload("res://scripts/ui/battle_theme.gd")
const ATTRIBUTE_HINT := preload("res://scripts/ui/battle_attribute_hint.gd")
const PERSONAL_GUARD := preload("res://scripts/ui/battle_personal_guard.gd")
var _status_list: Control
const BATTLE_ART := preload("res://scripts/data/battle_art.gd")
const GENERATED_AUDIO := preload("res://scripts/ui/battle_generated_audio.gd")
var _audio: Node
var _audio_painting: Array = []
var _ultimate_cutin: Control
var _anya_return_queue: Array[Dictionary] = []
var _anya_resolution_fx: Control
var _anya_active_return: Dictionary = {}
var _anya_saved_arena := "rooftop"
var _energy_caption: Label
var _anya_rebirth: Control
var _anya_ambient: Control
var _pursuit_cutin: Control
var _draft_reveal: Control
var _forecast_reveal: Control
var _vfx: Node2D
var _enchant_feedback: Control
var _card_motion: Control
var _pending_player_effects: Array[Dictionary] = []
var _pending_attack_attribute: Dictionary = {}
var _player_effect_queue: Array[Dictionary] = []
var _player_effects_busy := false
const HIT_INTERVAL := 0.34
var _painting_effects_waiting := false
var _layer: CanvasLayer
var _ui: Control
var _dynamic: Array[Node] = []
var _result_panel: Control
var _header_ap: Label
var _turn_queue: Array[Dictionary] = []
var _banner_busy := false
var _enemy_damage_staged := false
var _enemy_presentation_round := 1
var _enemy_display_allies: Array[Dictionary] = []
var _enemy_display_shared_guard := 0
var _enemy_display_temporary_guard := 0
var _enemy_display_hand_limit := FightSystem.HAND_LIMIT
var _enemy_effect_queue: Array[Dictionary] = []
var _enemy_interrupt_staged := false
var _enemy_interrupt_busy := false
var _enemy_display_enemies: Array = []
var _enemy_display_dark_slots: Dictionary = {}
var _enemy_attack: Node
const ENEMY_ACTOR := preload("res://scripts/ui/battle_enemy_actor.gd")
const ENEMY_RULE := preload("res://scripts/ui/battle_enemy_rule.gd")
var _current_enemy_actor := -1
var _current_player_actor := -1
var _round_start_damage: Array = []
var _turn_guard_gains: Array[Dictionary] = []
var _item_motion: Control
var _player_cast_played := false
var _player_skill_id := ""
var _active_player_casts := 0
var _enemy_portraits: Dictionary = {}
var _player_display_enemies: Array = []
var _status_seen_allies: Array = []
var _status_seen_enemies: Array = []
var _status_feedback_ready := false
var _confused_actions: Array[Dictionary] = []
var _confusion_display_allies: Array[Dictionary] = []
var _confusion_display_shared_guard := 0
var _confusion_display_temporary_guard := 0
var _confusion_busy := false
var _story_dialogue: Dictionary = {}
var _story_queue: Array[String] = []
var _story_busy := false
var _pending_victory := false
var _victory_sequence_started := false
var _defeat_sequence_started := false
var _effect_layer: Control
var _log_button: Button
var _end_button: Button
var _leave_button: Button
var _character_button: Button
var _item_button: Button
var _item_popup: Control
var _settings_button: Button
var _battle_settings: SettingsPanel
var _tutorial_dialog: BattleTutorialDialog
var _spotlight
var _waiting_tutorial_intent := false
var _last_tutorial_step := -1
var _skill_popup: PanelContainer
var _log_popup: Control
var _pile_popup: Control
var _pile_popup_key := ""
var _archive: Control
const ARCHIVE := preload("res://scripts/ui/battle_archive.gd")
var _status_popup: PanelContainer
var _target_rects: Dictionary = {}
var _intent_rects: Dictionary = {}
var _math_portrait_rect := Rect2()
var _dragging := false
var _drag_origin := Vector2.ZERO
var _drag_visual: Node2D
var _pointer := Vector2.ZERO
var _press_pointer := Vector2.ZERO
var _drag_distance := 0.0
var _impact_until := 0
var _presentation_serial := 0
var _ultimate_audio_token := -1
var _impact_tweens: Dictionary = {}
var _hovered_skill := -1
var _hovered_ultimate := -1
var _tower_hint: Label
var _damage_preview: Control
var _preview_revision := 0
var _preview_key := ""
# Keep one deliberate next action across presentation locks, using physical card IDs.
var _buffered_action: Dictionary = {}
var _commands: Node

const PRESENTATION := preload("res://scripts/data/battle_presentation.gd")
var _arena_id := "rooftop"
var _tower_arena_owner := -1
var _tower_arena_stage := 1
var _tower_music_id := ""
var _tower_floor_info: Dictionary = {}
var _background_fade: TextureRect
var _background_tween: Tween
var play_encounter_music := true
var _finale_ui: Control
var _phantom_assist: Control
var _ally_dead_shown: Dictionary = {}
var _ally_exits: Dictionary = {}
const ICON_DIR := "res://assets/graphics/battle/icons/"
const TUTORIAL_DIALOG := preload("res://scripts/ui/battle_tutorial_dialog.gd")
const TUTORIAL_SPOTLIGHT := preload("res://scripts/ui/battle_tutorial_spotlight.gd")
const SCREEN := Vector2(1920, 1080)
const ALLY_Y := 868.0
const ALLY_WIDTH := 356.0
const ALLY_STEP := 380.0
const ALLY_LEFT := 524.0

func _ready() -> void:
	if not FightSystem.battle_active:
		FightSystem.begin_encounter(["paper_large", "paper_large"], [], [], false, false, "", true)
	var presentation := PRESENTATION.for_encounter(FightSystem.encounter_serial, FightSystem.return_location, FightSystem.active_story_encounter)
	_arena_id = presentation.arena
	if PRESENTATION.context_arena(FightSystem.return_location, FightSystem.active_story_encounter) == "tower":
		_tower_floor_info = {"ambience":TowerRun.pending.get("ambience", -1)}
		_tower_arena_owner = PRESENTATION.tower_owner(FightSystem.enemies)
		if _tower_arena_owner >= 0:
			var owner: Dictionary = FightSystem.enemies[_tower_arena_owner]
			_tower_arena_stage = int(owner.get("boss_phase", 1))
			_arena_id = PRESENTATION.tower_arena(owner, _tower_arena_stage, _tower_floor_info)
	var finale := not FightSystem.ENEMY_RULES.FINALE.boss(FightSystem).is_empty()
	if finale: _arena_id = "finale"
	if play_encounter_music and not finale:
		if _tower_arena_owner >= 0: _tower_music_id = PRESENTATION.tower_music(FightSystem.enemies[_tower_arena_owner], _tower_arena_stage, _tower_floor_info)
		Music.play(_tower_music_id if not _tower_music_id.is_empty() else presentation.music, 0.8)
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	_ui = Control.new()
	BATTLE_THEME.apply(_ui)
	_ui.mouse_filter = Control.MOUSE_FILTER_PASS
	_layer.add_child(_ui)
	_build_base()
	_commands = preload("res://scripts/ui/battle_command_confirm.gd").new()
	_commands.battle = self
	add_child(_commands)
	_audio = GENERATED_AUDIO.new()
	_audio.name = "GeneratedBattleAudio"
	_effect_layer.add_child(_audio)
	_effect_layer.set_meta("generated_battle_audio", _audio)
	_ui.set_meta("generated_battle_audio", _audio)
	if TowerRun.active and TowerRun.pending.get("mode") == "lesson":
		_ui.add_child(preload("res://scripts/ui/tower_lesson_guide.gd").new())
	if finale:
		_finale_ui = preload("res://scripts/ui/battle_finale.gd").new()
		_finale_ui.battle = self
		_ui.add_child(_finale_ui)
	if FightSystem.enemies.any(func(unit: Dictionary) -> bool: return String(unit.id) == "bullied_phantom"):
		_phantom_assist = preload("res://scripts/ui/battle_phantom_assist.gd").new()
		_phantom_assist.battle = self
		_ui.add_child(_phantom_assist)
	_damage_preview = preload("res://scripts/ui/battle_damage_preview.gd").new()
	_ui.add_child(_damage_preview)
	FightSystem.ultimate_presentation = _present_ultimate
	FightSystem.anya_return_presentation = _queue_anya_return
	Settings.setting_changed.connect(_on_presentation_setting_changed)
	FightSystem.anya_form_changed.connect(_on_anya_form_changed)
	FightSystem.anya_morphed.connect(func(_card: Dictionary) -> void: _audio.play_sfx("sfx_anya_morph"))
	_anya_ambient = preload("res://scripts/ui/anya_battle_aura.gd").new()
	_ui.add_child(_anya_ambient)
	FightSystem.pursuit_presentation = _present_pursuit
	FightSystem.draft_presentation = _present_draft
	FightSystem.forecast_presentation = _present_forecast
	FightSystem.painting_region_presentation = _present_painting_region
	FightSystem.item_presentation = _present_item
	FightSystem.painting_effect_resolved.connect(_on_painting_effect)
	if not TowerRun.active and FileAccess.file_exists("res://data/warehouse_dialogue.json"):
		var warehouse_story: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/warehouse_dialogue.json"))
		if warehouse_story is Dictionary:
			_story_dialogue = (warehouse_story as Dictionary).get("battle", {})
	FightSystem.state_changed.connect(_refresh)
	FightSystem.message_added.connect(_on_message)
	FightSystem.battle_won.connect(_on_won)
	FightSystem.battle_lost.connect(_on_lost)
	FightSystem.turn_started.connect(_on_turn_started)
	FightSystem.effect_requested.connect(_on_effect_requested)
	FightSystem.attack_attribute_resolved.connect(func(info: Dictionary) -> void: _pending_attack_attribute = info.duplicate(true))
	FightSystem.card_enchanted.connect(_enchant_feedback.queue_card)
	FightSystem.enemy_cards_added.connect(_on_enemy_cards_added)
	FightSystem.card_piles_changed.connect(_card_motion.observe_piles)
	FightSystem.hand_card_exhausted.connect(_on_hand_card_exhausted)
	FightSystem.turn_guard_gained.connect(func(index: int, amount: int) -> void:
		_turn_guard_gains.append({"index":index, "amount":amount})
	)
	FightSystem.enemy_action_started.connect(_on_enemy_action_started)
	FightSystem.enemy_interrupt_started.connect(_on_enemy_interrupt_started)
	FightSystem.enemy_interrupt_finished.connect(_on_enemy_interrupt_finished)
	FightSystem.action_resolved.connect(_on_enemy_contact_resolved)
	FightSystem.player_action_started.connect(_on_player_action_started)
	FightSystem.confused_card_played.connect(_on_confused_card_played)
	FightSystem.story_event.connect(_on_story_event)
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	_on_turn_started(FightSystem.PLAYER_TURN, FightSystem.round)
	_refresh()
	_show_opening_phantom_summons.call_deferred()
	FightSystem.start_story_battle_intro()

func _build_base() -> void:
	var bg := TextureRect.new()
	bg.name = "BattleBackground"
	bg.texture = load(PRESENTATION.arena_path(_arena_id))
	bg.set_meta("arena", _arena_id)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(bg)
	_place(bg, Rect2(Vector2.ZERO, SCREEN))
	var tint := ColorRect.new()
	tint.name = "BattleBackgroundTint"
	tint.color = Color(0.025, 0.035, 0.09, PRESENTATION.arena_shade(_arena_id))
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(tint)
	_place(tint, Rect2(Vector2.ZERO, SCREEN))
	_chrome(_ui, "stage", Rect2(Vector2.ZERO, SCREEN), Color("d5ba84"))
	_effect_layer = Control.new()
	_effect_layer.name = "BattleEffectLayer"
	_effect_layer.z_index = 80
	_effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_effect_layer)
	_place(_effect_layer, Rect2(Vector2.ZERO, SCREEN))
	_vfx = preload("res://scripts/ui/battle_vfx.gd").new()
	_effect_layer.add_child(_vfx)
	_enchant_feedback = preload("res://scripts/ui/battle_enchantment_feedback.gd").new()
	_ui.add_child(_enchant_feedback)
	_card_motion = preload("res://scripts/ui/battle_card_motion.gd").new()
	_card_motion.make_ticket = _make_hand_ticket
	_card_motion.settled.connect(func() -> void: _refresh.call_deferred())
	_ui.add_child(_card_motion)
	_enemy_attack = preload("res://scripts/ui/battle_enemy_attack.gd").new()
	_enemy_attack.name = "EnemyAttackDirector"
	add_child(_enemy_attack)
	_build_action_points()
	_drag_visual = preload("res://scripts/ui/battle_aim.gd").new()
	_drag_visual.z_index = 65
	_drag_visual.visible = false
	_ui.add_child(_drag_visual)
	_chrome(_ui, "header", Rect2(42, 102, 420, 60), Color("d5ba84"))
	var hand_title := _label("战斗手札", Vector2(42, 109), Vector2(190, 36), 26, BATTLE_THEME.ON_STAGE)
	hand_title.add_theme_font_override("font", DISPLAY_FONT)
	_label("点牌后点目标 · 详情模式查看" if preload("res://scripts/ui/tower_mobile.gd").enabled() else "拖向目标 · 右键详情", Vector2(236, 116), Vector2(225, 26), 15, Color("a6b6c4"), HORIZONTAL_ALIGNMENT_RIGHT)
	_round_label = _label("", Vector2(846, 26), Vector2(228, 46), 22, BATTLE_THEME.ON_STAGE, HORIZONTAL_ALIGNMENT_CENTER)
	_round_label.add_theme_font_override("font", DISPLAY_FONT)
	_settings_button = _compact_button("设置", Rect2(1358, 27, 98, 44), _open_battle_settings, BATTLE_THEME.GOLD)
	_settings_button.name = "BattleSettingsButton"
	_settings_button.tooltip_text = "打开战斗手札 · 设置"
	_log_button = _compact_button("记录", Rect2(1468, 30, 84, 38), _toggle_log_popup)
	_log_button.name = "BattleLogButton"
	_character_button = _compact_button("角色", Rect2(1564, 30, 84, 38), _open_read_only_characters)
	_item_button = _compact_button("道具", Rect2(1660, 30, 84, 38), _toggle_items)
	_leave_button = _compact_button("撤退回塔" if TowerRun.active else "退出试炼", Rect2(1756, 30, 120, 38), _leave_battle)
	# Fixed below the hand/painting area, clear of the ally row at every party size.
	_end_button = _compact_button("结束回合", Rect2(226, 1010, 236, 52), _on_end_turn, Color("dfc795"))
	_end_button.name = "EndTurnButton"
	_end_button.get_node("BattleChrome").kind = "turn"
	_end_button.add_theme_font_size_override("font_size", 23)
	if preload("res://scripts/ui/tower_mobile.gd").enabled():
		_mobile_inspect_button = _compact_button("详情：关", Rect2(42, 928, 198, 64), func():
			_mobile_inspect = not _mobile_inspect
			_mobile_inspect_button.text = "详情：开" if _mobile_inspect else "详情：关"
			_clear_drag_visual()
			FightSystem.cancel_targeting())
		_mobile_inspect_button.name = "MobileInspectButton"
		_mobile_cancel_button = _compact_button("取消选取", Rect2(252, 928, 210, 64), func():
			_clear_drag_visual()
			FightSystem.cancel_targeting())
		_mobile_cancel_button.name = "MobileCancelTarget"
		for top_button in [_settings_button, _log_button, _character_button, _item_button, _leave_button]:
			top_button.size.y = 58

func _open_battle_settings() -> void:
	_clear_drag_visual()
	_buffered_action.clear()
	_open_archive("settings")

func set_background(arena_id: String, transition: bool = false) -> void:
	if FightSystem.fc.ANYA.phoenix(FightSystem.fc) and arena_id != "anya_phoenix":
		_anya_saved_arena = arena_id
		return
	if not PRESENTATION.ARENAS.has(arena_id): return
	if _arena_id == arena_id: return
	if is_instance_valid(_background_tween): _background_tween.kill()
	if is_instance_valid(_background_fade):
		_background_fade.get_parent().remove_child(_background_fade)
		_background_fade.queue_free()
		_background_fade = null
	_arena_id = arena_id
	var background: TextureRect = _ui.get_node("BattleBackground")
	if transition:
		_background_fade = TextureRect.new()
		_background_fade.name = "BattleBackgroundCrossfade"
		_background_fade.texture = background.texture
		_background_fade.expand_mode = background.expand_mode
		_background_fade.stretch_mode = background.stretch_mode
		_background_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(_background_fade)
		_ui.move_child(_background_fade, background.get_index() + 1)
		_place(_background_fade, Rect2(Vector2.ZERO, SCREEN))
	background.texture = load(PRESENTATION.arena_path(arena_id))
	background.set_meta("arena", arena_id)
	var tint: ColorRect = _ui.get_node("BattleBackgroundTint")
	if transition:
		_background_tween = Settings.battle_tween(self).set_parallel(true)
		_background_tween.tween_property(_background_fade, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_background_tween.tween_property(tint, "color:a", PRESENTATION.arena_shade(arena_id), 0.9)
		_background_tween.chain().tween_callback(func() -> void:
			if is_instance_valid(_background_fade): _background_fade.queue_free()
			_background_fade = null
		)
	else:
		tint.color.a = PRESENTATION.arena_shade(arena_id)

func _sync_tower_background() -> void:
	_sync_anya_background()
	if _tower_arena_owner < 0 or _tower_arena_owner >= FightSystem.enemies.size(): return
	# Rules advance immediately; visuals advance only at the corresponding rebirth.
	set_background(PRESENTATION.tower_arena(FightSystem.enemies[_tower_arena_owner], _tower_arena_stage, _tower_floor_info), true)
	if play_encounter_music and FightSystem.battle_active:
		var track := PRESENTATION.tower_music(FightSystem.enemies[_tower_arena_owner], _tower_arena_stage, _tower_floor_info)
		if not track.is_empty() and track != _tower_music_id:
			_tower_music_id = track
			Music.play(track, 1.8)

func _chrome(parent: Node, kind: String, rect: Rect2, accent: Color, active: bool = false) -> Control:
	var art := CHROME.new()
	art.name = "BattleChrome"
	art.kind = kind
	art.accent = accent
	art.active = active
	art.show_behind_parent = parent is BaseButton
	parent.add_child(art)
	_place(art, rect)
	return art

func _compact_button(words: String, rect: Rect2, action: Callable, accent: Color = Color("94aac1")) -> Button:
	var button := _button(words, rect.position, rect.size, action, accent, 17)
	button.get_node("SurfaceArt").hide()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_color_override("font_color", CHROME.INK)
	button.add_theme_color_override("font_hover_color", BATTLE_THEME.TEXT)
	button.add_theme_color_override("font_pressed_color", BATTLE_THEME.TEXT)
	button.add_theme_color_override("font_disabled_color", BATTLE_THEME.FAINT)
	_chrome(button, "utility", Rect2(Vector2.ZERO, rect.size), accent)
	return button

func _refresh() -> void:
	if _painting_effects_waiting and FightSystem.fc.choice.is_empty():
		_flush_player_effects.call_deferred()
	_preview_revision += 1
	_hovered_skill = -1
	_hovered_ultimate = -1
	if is_instance_valid(_archive) and _archive.page != "settings":
		_archive.queue_free()
		_clear_archive_references()
	_hide_calculation()
	if is_instance_valid(_painting_popup): _painting_popup.queue_free()
	if not is_instance_valid(_fc_choices) and is_instance_valid(_ui):
		_fc_choices = preload("res://scripts/ui/fc_choice_panel.gd").new()
		_ui.add_child(_fc_choices)
	if is_instance_valid(_fc_choices): _fc_choices.refresh()
	if not is_instance_valid(_ui):
		return
	_sync_tower_background()
	if is_instance_valid(_skill_popup):
		_skill_popup.queue_free()
		_skill_popup = null
	if is_instance_valid(_status_popup):
		_status_popup.queue_free()
		_status_popup = null
	for node in _dynamic.duplicate():
		if is_instance_valid(node):
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.queue_free()
	_dynamic.clear()
	_target_rects.clear()
	_intent_rects.clear()
	_math_portrait_rect = Rect2()
	_draw_resource("抽牌", "deck", Vector2(42, 30), Color("#6d9ed0"))
	_draw_resource("弃牌", "discard", Vector2(148, 30), Color("#8b7698"))
	_draw_resource("手牌", "hand", Vector2(254, 30), Color("#719e7f"))
	_draw_enemies()
	_draw_allies()
	_show_status_feedback()
	_draw_hand()
	_draw_dark_slots()
	_draw_hand_limit()
	_draw_painting()
	var exhaust := _compact_button("消耗 %d" % FightSystem.fc.exhausted.size(), Rect2(572, 30, 104, 38), func() -> void: _show_fc_pile("exhausted"), Color("bb9cb8"))
	exhaust.name = "ExhaustedPile"
	exhaust.tooltip_text = "点击查看消耗区"
	_dynamic.append(exhaust)
	if _header_ap:
		var phoenix: bool = FightSystem.fc.ANYA.phoenix(FightSystem.fc)
		var amount: int = FightSystem.fc.ANYA.budget(FightSystem.fc)
		var limit: int = int(FightSystem.allies[FightSystem.fc.ANYA.owner(FightSystem.fc)].get("rebirth_max", 12)) if phoenix else FightSystem.action_point_limit()
		_header_ap.text = "%d / %d" % [amount, limit]
		_energy_skin.amount = clampf(float(amount) / maxi(1, limit), 0, 1)
		_energy_caption.text = "重生计数" if phoenix else "能量"
		_energy_skin.visible = not phoenix
		_energy_caption.visible = not phoenix
		_header_ap.visible = not phoenix
		_anya_rebirth.visible = phoenix
		if phoenix: _anya_rebirth.update_count(amount, limit)
	if _round_label:
		_round_label.text = "第 %02d 回合 · %s" % [_enemy_presentation_round if _enemy_damage_staged else FightSystem.round, "插入行动" if _enemy_interrupt_staged else "敌方" if _enemy_damage_staged or FightSystem.phase == FightSystem.ENEMY_TURN else "我方"]
	_log_button.disabled = _turn_interaction_locked()
	_item_button.disabled = not FightSystem.can_use_items() or _turn_interaction_locked()
	if not FightSystem.pending_item.is_empty():
		_dynamic.append(_label("%s：请选择目标；右键取消" % FightEquipmentData.CONSUMABLES[FightSystem.pending_item].name, Vector2(530, 802), Vector2(890, 38), 23, Color("#b1eddd")))
	_end_button.disabled = not FightSystem.battle_active or FightSystem.phase != FightSystem.PLAYER_TURN or (FightSystem.tutorial_step >= 0 and FightSystem.tutorial_step < 3) or FightSystem.story_input_locked or FightSystem.story_forced_skill != "" or _turn_interaction_locked()
	if is_instance_valid(_mobile_inspect_button):
		_mobile_inspect_button.disabled = _turn_interaction_locked()
		_mobile_cancel_button.disabled = _turn_interaction_locked() or FightSystem.pending_target_type() == ""
	_leave_button.disabled = (FightSystem.tutorial_step >= 0 and FightSystem.tutorial_step < 4) or _turn_interaction_locked()
	_character_button.disabled = (FightSystem.tutorial_step >= 0 and FightSystem.tutorial_step < 4) or _turn_interaction_locked()
	if FightSystem.tutorial_step >= 0 and FightSystem.tutorial_step != _last_tutorial_step:
		_last_tutorial_step = FightSystem.tutorial_step
		call_deferred("_show_tutorial_step", _last_tutorial_step)
	elif is_instance_valid(_spotlight) and FightSystem.tutorial_step >= 0 and FightSystem.tutorial_step < 4 and not _waiting_tutorial_intent:
		_spotlight.focus(_tutorial_action_rect())
	elif is_instance_valid(_spotlight) and FightSystem.story_forced_skill != "" and not FightSystem.story_input_locked:
		_spotlight.focus(_story_action_rect())
	_relayout()
	if is_instance_valid(_fc_choices):
		_ui.move_child(_fc_choices, _ui.get_child_count() - 1)
	# A pending confirmation must stay above every control this refresh rebuilt
	# (target boxes, status chips, rule buttons): GUI picking uses tree order, not z_index.
	if is_instance_valid(_commands) and _commands.pending():
		_commands.raise_modal()

func _use_phantom_resistance() -> void:
	if is_instance_valid(_phantom_assist): _phantom_assist.present()

func _show_tutorial_step(step: int) -> void:
	if not is_inside_tree() or step != FightSystem.tutorial_step:
		return
	if is_instance_valid(_spotlight):
		_spotlight.queue_free()
		_spotlight = null
	while _banner_busy or not _turn_queue.is_empty() or _card_motion.busy():
		await get_tree().process_frame
		if not is_inside_tree(): return
	if is_instance_valid(_tutorial_dialog):
		_tutorial_dialog.queue_free()
	_tutorial_dialog = TUTORIAL_DIALOG.new() as BattleTutorialDialog
	add_child(_tutorial_dialog)
	if step == 0:
		_tutorial_dialog.highlight(Rect2(36, 10, 646, 80))
		await _tutorial_dialog.show_step("战斗教程", "在角色系统界面选择的技能，会以手牌的形式展示，具有相应的抽牌堆，弃牌堆，手牌数。")
		await _tutorial_dialog.show_step("战斗教程", "每个技能释放需要对应的能量值，当前回合的能量值和能量上限也会在这里展示。")
		_tutorial_dialog.highlight(Rect2(42, 185, 420, 300))
		await _tutorial_dialog.show_step("技能手牌", "该部分为你本回合抽到的技能手牌。数字表示其需要消耗的能量值，右侧头像表示该技能属于哪位角色的技能。技能造成的伤害属性取决于角色的属性。边框与文字的金、蓝、白色分别表示稀有、中等、普通。")
		_tutorial_dialog.highlight(_target_rects.get("enemy_0", Rect2()))
		await _tutorial_dialog.show_step("敌人", "这是你要使用技能攻击的怪物。可以看到它剩余的血量；血量下方是意图，点击可查看详细信息。")
		_tutorial_dialog.highlight(_intent_rect())
		await _tutorial_dialog.show_step("敌人意图", "点击左侧怪物的意图框。")
		_tutorial_dialog.queue_free()
		_tutorial_dialog = null
		_waiting_tutorial_intent = true
		_spotlight = TUTORIAL_SPOTLIGHT.new()
		add_child(_spotlight)
		_spotlight.focus(_intent_rect())
		return
	elif step == 1:
		_tutorial_dialog.highlight(_target_rects.get("ally_0", Rect2()))
		await _tutorial_dialog.show_step("以血换血", "点击即可对自己释放：失去25%最大生命值的生命，再获得本次失去生命一半的护盾；若扣血后处于濒死，则获得等量护盾。")
		await _tutorial_dialog.show_step("以血换血", "护盾可以抵挡敌人的伤害。主动失去生命不会令周明远退场。现在尝试释放一下该技能吧！")
	elif step == 2:
		_tutorial_dialog.highlight(Rect2(42, 242, 420, 50))
		await _tutorial_dialog.show_step("我来帮你！", "先点击艾莉娜的我来帮你！，再选定一名角色，使其获得10点个人护盾。")
		await _tutorial_dialog.show_step("保留与保护", "艾莉娜的牌会保留至下回合。队友打出带保留的牌时，还会获得一份优先消耗的共享临时护盾。现在选择周明远试试吧！")
	elif step == 3:
		_tutorial_dialog.highlight(_end_button.get_rect())
		await _tutorial_dialog.show_step("结束回合", "该回合可用能量耗尽，点击结束回合。")
	else:
		await _tutorial_dialog.show_step("新手教程结束", "现在尝试击败眼前的怪物吧！接下来会把角色、怪物和手牌恢复至开局状态，只保留当前回合数。")
		FightSystem.complete_tutorial_reset()
	if is_instance_valid(_tutorial_dialog):
		_tutorial_dialog.queue_free()
		_tutorial_dialog = null
	if step < 4 and step == FightSystem.tutorial_step and is_inside_tree():
		FightSystem.tutorial_action_ready = true
		_spotlight = TUTORIAL_SPOTLIGHT.new()
		add_child(_spotlight)
		_spotlight.focus(_tutorial_action_rect())
		FightSystem.state_changed.emit()

func _continue_after_intent() -> void:
	if not _waiting_tutorial_intent:
		return
	_waiting_tutorial_intent = false
	if is_instance_valid(_spotlight):
		_spotlight.queue_free()
		_spotlight = null
	_tutorial_dialog = TUTORIAL_DIALOG.new() as BattleTutorialDialog
	add_child(_tutorial_dialog)
	_tutorial_dialog.highlight(Rect2(ALLY_LEFT, ALLY_Y, maxf(_ally_width(), (FightSystem.allies.size() - 1) * _ally_step() + _ally_width()), 168))
	for line in [
		"这是你的编队角色。你可以在这里看到角色当前所有战斗状态信息。",
		"角色框右侧为终结技。终结技能量充满后，即可释放该角色的终结技。",
		"终结技充能值可通过释放本角色的技能获得，或通过某些特殊充能技能。",
	]:
		await _tutorial_dialog.show_step("编队角色", line)
	_tutorial_dialog.highlight(Rect2(42, 185, 420, 50))
	for line in [
		"周明远的普通攻击是指向性技能，需要选择一名敌人释放，能造成6点无极属性伤害。",
		"指向性技能可以拖拽释放，也可以先点击技能，再点击目标敌人。",
		"现在尝试释放一下该技能吧！",
	]:
		await _tutorial_dialog.show_step("普通攻击", line)
	_tutorial_dialog.queue_free()
	_tutorial_dialog = null
	FightSystem.tutorial_action_ready = true
	_spotlight = TUTORIAL_SPOTLIGHT.new()
	add_child(_spotlight)
	_spotlight.focus(_tutorial_action_rect())
	FightSystem.state_changed.emit()

func _intent_rect() -> Rect2:
	return _intent_rects.get(0, Rect2())

func _tutorial_action_rect() -> Rect2:
	if FightSystem.tutorial_step == 3:
		return _end_button.get_rect()
	if FightSystem.pending_card >= 0:
		return _target_rects.get("enemy_0", Rect2()) if FightSystem.tutorial_step == 0 else _target_rects.get("ally_0", Rect2())
	var skill := "basic_strike" if FightSystem.tutorial_step == 0 else "block" if FightSystem.tutorial_step == 1 else "help_me"
	for i in FightSystem.hand.size():
		if String(FightSystem.hand[i].get("skill_id", "")) == skill:
			return Rect2(42, 185 + i * 57, 420, 50)
	return Rect2()

func _draw_enemies() -> void:
	if is_instance_valid(_finale_ui) and _finale_ui.victory_started: return
	var list: Array = _player_display_enemies if not _player_display_enemies.is_empty() else FightSystem.get_enemies()
	if _enemy_damage_staged: list = _enemy_display_enemies
	# Actor nodes survive HP/status rebuilds, so neither idle nor attacks restart.
	for key in _enemy_portraits.keys():
		if int(key) >= list.size() or not _alive(list[int(key)]):
			var old_actor: TextureRect = _enemy_portraits[key]
			if is_instance_valid(old_actor):
				if old_actor.visible and old_actor.modulate.a > 0.01 and not old_actor.has_meta("death_audio"):
					old_actor.set_meta("death_audio", true)
					var dead_stage := int(list[int(key)].get("boss_phase", 1)) if int(key) < list.size() else 1
					preload("res://scripts/ui/battle_enemy_audio.gd").emit(_effect_layer, old_actor.enemy_id, "death", "", dead_stage)
				if old_actor.enemy_id == "perfect_score" and old_actor.visible:
					_retire_perfect_score(old_actor)
				elif old_actor.enemy_id == "panic_throat": _retire_panic(old_actor)
				else: old_actor.queue_free()
			_enemy_portraits.erase(key)
	var count := 0
	for unit in list:
		if _alive(unit): count += 1
	if count == 0: return
	var compact := count > 3
	var columns := count if not compact else (2 if count == 4 else 3)
	var gap := 44.0 if not compact else 34.0
	var width := minf(530.0, (1330.0 - gap * (columns - 1)) / columns)
	var left := 524.0 + (1330.0 - columns * width - (columns - 1) * gap) * 0.5
	var visible_index := 0
	var boss_index := -1
	for i in list.size():
		if _alive(list[i]) and bool(FightData.enemy(String(list[i].id)).get("boss", false)):
			boss_index = i
			break
	if boss_index < 0:
		for i in list.size():
			if not _alive(list[i]): continue
			for minion in list:
				if _alive(minion) and int(minion.get("summoner", -1)) == i:
					boss_index = i
					break
			if boss_index >= 0: break
	var escort_index := 0
	var regular_width := width
	for i in list.size():
		var enemy: Dictionary = list[i]
		if not _alive(enemy): continue
		width = regular_width
		var x := left + (visible_index % columns) * (width + gap)
		var y := (104.0 + int(visible_index / columns) * 350.0) if compact else 160.0
		visible_index += 1
		var portrait_top := y + (90.0 if compact else 95.0)
		var portrait_height := 180.0 if compact else 390.0
		if boss_index >= 0:
			if i == boss_index:
				x = 862.0
				width = 654.0
				y = 105.0
				portrait_top = 207.0
				portrait_height = 470.0
			else:
				if enemy.has("finale_slot"): escort_index = int(enemy.finale_slot)
				x = 538.0 if escort_index % 2 == 0 else 1540.0
				width = 300.0
				portrait_top = 416.0 - (escort_index / 2) * 260.0
				portrait_height = 210.0
				y = portrait_top - 90.0
				if String(list[boss_index].id) == "terminal_echo":
					portrait_height = 170.0
					portrait_top = 480.0 if escort_index < 2 else 200.0
					y = portrait_top - 65.0
				escort_index += 1
		var portrait: TextureRect = _enemy_portraits.get(i)
		if not is_instance_valid(portrait):
			portrait = ENEMY_ACTOR.new()
			portrait.name = "EnemyActor_%d" % i
			portrait.texture = load(String(enemy.portrait))
			portrait.enemy_id = String(enemy.id)
			portrait.phase_index = i
			_ui.add_child(portrait)
			_enemy_portraits[i] = portrait
		portrait.place(Rect2(x + 15, portrait_top, width - 30, portrait_height))
		if String(enemy.id) == "perfect_score": portrait.call("set_score", int(enemy.get("score", 0)))
		if String(enemy.id) == "gaokao_countdown": portrait.call("set_countdown", int(enemy.get("countdown", 3)))
		if String(enemy.id) == "report_card": portrait.modulate.a = 0.32 if enemy.statuses.has("offstage") else 1.0
		if enemy.has("finale_wave") and is_instance_valid(_finale_ui) and not _finale_ui.revealed_waves.has(int(enemy.finale_wave)):
			portrait.modulate.a = 0.0
		if i == boss_index and bool(FightData.enemy(String(enemy.id)).get("boss", false)):
			var stage := clampi(int(enemy.get("boss_phase", 1)), 1, 3)
			portrait.modulate = [Color.WHITE, Color("d8c6ef"), Color("acdef1")][stage - 1]
			var phase_names := ["阴雨低压·状态迷航", "旧伤回响·痛觉牢笼", "破限镜像·自我对决"] if enemy.id == "inverse_limit" else ["无声扼喉", "百舌嘲心", "孤影囚笼"]
			if enemy.id == "terminal_echo": phase_names = ["低语 · 夜空无声", "合唱 · 我仍在这里", "黎明 · 拒绝终末"]
			var phase_label := FC_VISUALS.text(_ui, "阶段 %s · %s" % [["Ⅰ", "Ⅱ", "Ⅲ"][stage - 1], phase_names[stage - 1]], Rect2(x, 69, width, 34), 25, Color("e8c2bd"), true)
			phase_label.name = "BossPhaseLabel"
			_dynamic.append(phase_label)
		var target := Rect2(x, portrait_top, width, portrait_height + 68)
		_target_rects["enemy_%d" % i] = target
		if FightSystem._enemy_targetable(enemy):
			var button := _button("", target.position, target.size, _select_enemy.bind(i), Color("725d98"), 20)
			button.name = "EnemyTarget_%d" % i
			button.flat = true
			button.modulate = Color(1, 1, 1, 0.01)
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			_dynamic.append(button)
		var bar_y := portrait_top + portrait_height + 12
		var attribute_badge := ATTRIBUTE_HINT.badge(_ui, String(enemy.attribute), Rect2(x + 12, bar_y - 33, 84, 30))
		attribute_badge.name = "EnemyAttribute_%d" % i
		attribute_badge.z_index = 22
		_dynamic.append(attribute_badge)
		var name_label := FC_VISUALS.text(_ui, String(enemy.name), Rect2(x + 104, bar_y - 28, width - 116, 25), 19, Color("f1e4d2"), true)
		name_label.name = "EnemyName_%d" % i
		name_label.add_theme_color_override("font_outline_color", Color("080d18"))
		name_label.add_theme_constant_override("outline_size", 6)
		name_label.z_index = 22
		_dynamic.append(name_label)
		var poison: int = maxi(0, int(enemy.get("statuses", {}).get("poison", {}).get("stacks", 0)))
		var infinite_hp := String(enemy.id) == "terminal_echo"
		var shared_life := String(enemy.id) in ["fist_phantom", "whip_phantom", "shackle_phantom"] and int(enemy.get("summoner", -1)) >= 0
		if shared_life:
			var shared_label := FC_VISUALS.text(_ui, "与本体共享生命", Rect2(x + 12, bar_y - 2, width - 24 - (94 if int(enemy.guard) > 0 else 0), 26), 17, Color("e8bfe1"), true)
			shared_label.name = "EnemySharedLife_%d" % i
			shared_label.z_index = 20
			_dynamic.append(shared_label)
		else:
			var hp_bar := _progress_bar(Vector2(x + 12, bar_y), Vector2(width - 24 - (94 if int(enemy.guard) > 0 else 0), 22), 1 if infinite_hp else int(enemy.hp), 1 if infinite_hp else int(enemy.max_hp), Color("a36776"), "∞/∞" if infinite_hp else "%d / %d" % [enemy.hp, enemy.max_hp], false, false, 0 if infinite_hp else poison)
			hp_bar.name = "EnemyHP_%d" % i
			hp_bar.z_index = 20
			_dynamic.append(hp_bar)
		if int(enemy.guard) > 0:
			var shield := preload("res://scripts/ui/battle_enemy_guard.gd").new()
			shield.position = Vector2(x + 7, bar_y - 5)
			shield.size = Vector2(width - 14, 32)
			shield.amount = int(enemy.guard)
			_ui.add_child(shield)
			shield.name = "EnemyGuard_%d" % i
			shield.z_index = 22
			_dynamic.append(shield)
		if FightSystem.fc.locked_enemy == i:
			var math_owner: int = FightSystem._ally_index("zhoumingyuan")
			if FightSystem.fc.is_math(math_owner) and _alive(FightSystem.allies[math_owner]):
				_draw_math_lock(i, Rect2(x + 8, portrait_top, width - 16, portrait_height))
		var rule_count := _draw_enemy_rules(enemy, i, Vector2(x + 12, bar_y + 34), width - 24)
		_draw_statuses(enemy, Vector2(x + 12, bar_y + 34 + rule_count * 44), false, width - 24)
		_draw_intent(enemy.get("intent", {}), Vector2(x + width * 0.5 - 74, y), i)

func _retire_panic(actor: TextureRect) -> void:
	# A final collapse has no next phase and must not play the resurrection beam.
	var fx := preload("res://scripts/ui/battle_panic_effect.gd").new()
	_effect_layer.add_child(fx)
	fx.center = actor.rest_position + actor.size * Vector2(0.5, 0.45)
	fx.mode = "collapse"
	actor.animating = true
	var collapse := Settings.battle_tween(self).set_parallel(true)
	collapse.tween_property(actor, "modulate:a", 0.0, 0.5)
	collapse.tween_property(fx, "progress", 1.0, 0.6)
	await collapse.finished
	fx.queue_free()
	if is_instance_valid(actor): actor.queue_free()

func _retire_perfect_score(actor: TextureRect) -> void:
	_impact_until = maxi(_impact_until, Time.get_ticks_msec() + Settings.battle_msec(3300))
	await actor.dissolve()
	if is_instance_valid(actor): actor.queue_free()

func _show_opening_phantom_summons() -> void:
	if not is_instance_valid(_effect_layer): return
	while _banner_busy or not _turn_queue.is_empty():
		await get_tree().process_frame
	if not is_instance_valid(_effect_layer): return
	for i in FightSystem.enemies.size():
		var enemy: Dictionary = FightSystem.enemies[i]
		if String(enemy.get("id", "")) == "bullied_phantom":
			_audio.play_voice("enemy_bullied_phantom_opening", 1, "bullied_phantom")
		if String(enemy.get("id", "")) in FightSystem.ENEMY_RULES.EXPANSION.SUMMONS and int(enemy.get("summoner", -1)) >= 0:
			_play_phantom_summon(i, "opening")

func _play_phantom_summon(index: int, source: String = "arrival") -> void:
	var actor: TextureRect = _enemy_portraits.get(index) as TextureRect
	var area: Rect2 = _target_rects.get("enemy_%d" % index, Rect2())
	if Settings.simple_battle_effects():
		if area.has_area(): _vfx.play_simple_contact(area.get_center())
		_reveal_phantom_actor(index)
		return
	var center := area.get_center()
	if is_instance_valid(actor):
		center = actor.rest_position + actor.size * Vector2(0.5, 0.72)
	elif not area.has_area():
		var escort := 0
		for i in index:
			if i != int(_enemy_display_enemies[index].get("summoner", -1)) and _alive(_enemy_display_enemies[i]): escort += 1
		center = Vector2((538.0 if escort % 2 == 0 else 1540.0) + 150.0, 416.0 - int(escort / 2) * 260.0 + 105.0)
	var portal := preload("res://scripts/ui/battle_phantom_summon.gd").new()
	portal.set_meta("source", source)
	_effect_layer.add_child(portal)
	portal.burst(center)
	_reveal_phantom_actor(index)

func _reveal_phantom_actor(index: int) -> void:
	var actor: TextureRect = _enemy_portraits.get(index) as TextureRect
	for attempt in 12:
		if is_instance_valid(actor): break
		await Settings.battle_timer(0.04).timeout
		actor = _enemy_portraits.get(index) as TextureRect
	if not is_instance_valid(actor): return
	if Settings.simple_battle_effects():
		actor.modulate.a = 1.0
		actor.scale = Vector2.ONE
		return
	actor.modulate.a = 0.0
	actor.scale = Vector2(0.72, 0.82)
	var reveal := Settings.battle_tween(self).set_parallel(true)
	reveal.tween_property(actor, "modulate:a", 1.0, 0.48).set_delay(0.13)
	reveal.tween_property(actor, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _draw_enemy_rules(enemy: Dictionary, index: int, pos: Vector2, available_width: float) -> int:
	var rules: Array[Dictionary] = ENEMY_RULE.extra(enemy)
	for status: Dictionary in FightData.statuses(enemy):
		if ENEMY_RULE.has(String(status.get("icon", ""))): rules.append(status)
	for i in rules.size():
		var status: Dictionary = rules[i]
		var key := String(status.icon)
		var style: Dictionary = ENEMY_RULE.style(key)
		var accent := Color(String(style.color))
		var rect := Rect2(pos + Vector2(0, i * 44), Vector2(available_width, 39))
		var button := _button("", rect.position, rect.size, _show_status_list.bind(rules, String(enemy.name) + " · 特殊规则"), accent, 17)
		button.name = "EnemyRule_%d_%s" % [index, key]
		button.get_node("SurfaceArt").hide()
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.z_index = 26
		for state in ["normal", "hover", "pressed", "focus"]:
			var fill := BATTLE_THEME.SURFACE if state == "normal" else BATTLE_THEME.HOVER
			button.add_theme_stylebox_override(state, BATTLE_THEME.frame(fill, accent if state != "normal" else Color(accent, 0.7), 1 if state == "normal" else 2, 5))
		var art := FC_VISUALS.icon(button, _status_icon_texture(status), Rect2(5, 3, 33, 33))
		art.name = "FieldRuleArt" if String(style.kind) == "场地" else "EnemyRuleArt"
		var heading := FC_VISUALS.text(button, String(style.kind), Rect2(41, 3, 47, 32), 15, BATTLE_THEME.quiet(accent), true)
		heading.name = "RuleKind"
		var caption := FC_VISUALS.text(button, ENEMY_RULE.title(key, enemy, status), Rect2(93, 3, available_width - 122, 32), 17, BATTLE_THEME.TEXT)
		caption.name = "RuleTitle"
		caption.clip_text = true
		FC_VISUALS.glyph(button, "target", Rect2(available_width - 27, 10, 19, 19), accent)
		button.tooltip_text = "点击查看" + String(status.name) + "详情"
		_dynamic.append(button)
	return rules.size()

func _draw_math_lock(index: int, rect: Rect2) -> void:
	var marker := Control.new()
	marker.name = "MathLockMarker"
	marker.z_index = 23
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(marker)
	_place(marker, rect)
	_dynamic.append(marker)
	marker.set_meta("enemy_index", index)
	var accent := Color("80deef")
	for corner in [Vector2.ZERO, Vector2(rect.size.x, 0), rect.size, Vector2(0, rect.size.y)]:
		var inward := Vector2(1 if corner.x == 0 else -1, 1 if corner.y == 0 else -1)
		var bracket := Line2D.new()
		bracket.points = PackedVector2Array([corner + Vector2(0, inward.y * 22), corner, corner + Vector2(inward.x * 22, 0)])
		bracket.width = 3.0
		bracket.default_color = accent
		marker.add_child(bracket)
	var badge := FC_VISUALS.panel(marker, Rect2((rect.size.x - 242) * 0.5, -16, 242, 40), Color("0a2636"), accent, 7)
	FC_VISUALS.icon(badge, BATTLE_ART.icon("pursuit"), Rect2(10, 6, 28, 28))
	var caption := FC_VISUALS.text(badge, "追击锁定 · 敌人 %d" % (index + 1), Rect2(44, 2, 192, 36), 21, Color("e2faff"), true)
	caption.name = "MathLockLabel"

func _ally_width() -> float:
	return 314.0 if FightSystem.allies.size() == 4 else ALLY_WIDTH

func _ally_step() -> float:
	return 338.0 if FightSystem.allies.size() == 4 else ALLY_STEP

func _draw_allies() -> void:
	var list: Array = _confusion_display_allies if not _confusion_display_allies.is_empty() else _enemy_display_allies if _enemy_damage_staged else FightSystem.get_allies()
	for i in list.size():
		if bool(list[i].get("anya_phoenix", false)):
			_draw_phoenix_ally(list[i], i)
			return
	var shared := _confusion_display_shared_guard if not _confusion_display_allies.is_empty() else _enemy_display_shared_guard if _enemy_damage_staged else FightSystem.shared_guard
	var temporary: int = _confusion_display_temporary_guard if not _confusion_display_allies.is_empty() else _enemy_display_temporary_guard if _enemy_damage_staged else FightSystem.fc.temporary_guard
	var width := _ally_step()
	var card_width := _ally_width()
	var compact := list.size() == 4
	var stat_offset := 94.0 if compact else 118.0
	var stat_width := 126.0 if compact else 144.0
	var bounds := Rect2(ALLY_LEFT, ALLY_Y, maxf(card_width, (list.size() - 1) * width + card_width), 168)
	if shared > 0: _draw_party_guard(bounds.grow(8), shared, false, 0)
	if temporary > 0: _draw_party_guard(bounds.grow(8), temporary, true, 212 if shared > 0 else 0)
	for i in list.size():
		var ally: Dictionary = list[i]
		if bool(ally.get("anya_hidden", false)): continue
		var x := ALLY_LEFT + i * width
		_target_rects["ally_%d" % i] = Rect2(x + 6, ALLY_Y + 6, card_width - 12, 156)
		var dead := bool(ally.get("dead", false))
		var downed := bool(ally.get("downed", false))
		var palette: Array = [Color("183b72"), Color("62beff")]
		if String(ally.id) == "alyina": palette = [Color("1c4c64"), Color("71ebdc")]
		elif String(ally.id) == "wangjiaqi": palette = [Color("452b72"), Color("c895ff")]
		elif FightSystem.fc.is_math(i): palette = [Color("174968"), Color("65dfff")]
		var border := Color("596079") if dead else Color("fc91ce") if downed else Color("ffe08b") if i == FightSystem.selected_ally else palette[1] as Color
		var bg := Color("202637") if dead else Color("65315f") if downed else palette[0] as Color
		var panel := _rect(Vector2(x, ALLY_Y), Vector2(card_width, 168), bg, border, 1)
		panel.name = "AllyCard_%d" % i
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var identity := BATTLE_THEME.identity(String(ally.id), String(ally.get("attribute", "none")))
		var ally_skin := _chrome(panel, "ally", Rect2(Vector2.ZERO, panel.size), identity.accent, FightSystem.pending_target_type() == "ally")
		ally_skin.identity = identity
		ally_skin.disabled = dead
		ally_skin.downed = downed
		_dynamic.append(panel)
		var portrait_rect := Rect2(x + 6, ALLY_Y + 39, 82 if compact else 106, 114)
		var portrait := FC_VISUALS.hero_icon(_ui, String(ally.id), portrait_rect, String(ally.attribute))
		portrait.interactive_motion = true
		portrait.living_portrait.resting = dead or downed
		if String(ally.id) == "li_anya":
			portrait.form_portrait = String(ally.portrait)
			portrait.texture = load(String(ally.portrait))
		portrait.name = "AllyPortrait_%d" % i
		var ally_id := String(ally.id)
		var just_exited := dead and _ally_dead_shown.has(ally_id) and not bool(_ally_dead_shown[ally_id])
		_ally_dead_shown[ally_id] = dead
		if just_exited: _play_ally_exit(ally_id, portrait.texture, portrait_rect)
		portrait.visible = not _ally_exits.has(ally_id)
		portrait.modulate = Color(0.10, 0.10, 0.13, 1) if dead else Color(1.0, 0.58, 0.82, 1) if downed else Color.WHITE
		if FightSystem.fc.POISON.absent(ally): portrait.modulate = Color(0.65, 0.86, 0.75, 0.42)
		if bool(ally.get("anya_hidden", false)):
			portrait.modulate = Color(0.7, 0.73, 0.85, 0.22)
			var sheltered := FC_VISUALS.text(_ui, "羽翼庇护 · 暂离", Rect2(x + 8, ALLY_Y + 141, card_width - 16, 24), 17, Color("d6b98c"), true)
			_dynamic.append(sheltered)
		_dynamic.append(portrait)
		_draw_ally_condition_fx(ally, i, Rect2(x, ALLY_Y, card_width, 168))
		var hitbox := _button("", _target_rects["ally_%d" % i].position, _target_rects["ally_%d" % i].size, _select_ally.bind(i), border, 18)
		hitbox.flat = true
		hitbox.modulate = Color(1, 1, 1, 0.01)
		hitbox.mouse_entered.connect(func() -> void: ally_skin.hovered = true; ally_skin.set_process(true))
		hitbox.mouse_exited.connect(func() -> void: ally_skin.hovered = false; ally_skin.set_process(true))
		_dynamic.append(hitbox)
		var hero_name := _label(String(ally.name), Vector2(x + 20, ALLY_Y + 8), Vector2(card_width - (204 if dead or downed else 144), 26), 20, BATTLE_THEME.FAINT if dead else CHROME.INK)
		hero_name.add_theme_font_override("font", DISPLAY_FONT)
		_dynamic.append(hero_name)
		var attribute_badge := ATTRIBUTE_HINT.badge(_ui, String(ally.attribute), Rect2(x + card_width - 116, ALLY_Y + 8, 70, 26))
		attribute_badge.name = "AllyAttribute_%d" % i
		attribute_badge.modulate.a = 0.5 if dead else 1.0
		_dynamic.append(attribute_badge)
		if dead or downed:
			_dynamic.append(_label("已退场" if dead else "濒死", Vector2(x + card_width - 180, ALLY_Y + 8), Vector2(60, 26), 16, BATTLE_THEME.FAINT if dead else BATTLE_THEME.RED, HORIZONTAL_ALIGNMENT_RIGHT))
		var personal_guard := int(ally.guard)
		var personal_temporary := int(ally.statuses.get("poison_guard", {}).get("stacks", 0))
		var both_guards := personal_guard > 0 and personal_temporary > 0
		_draw_statuses(ally, Vector2(x + stat_offset, ALLY_Y + (132 if both_guards else 116)), true, stat_width)
		var hp_color := BATTLE_THEME.RECESSED if dead else Color("916a88") if downed else BATTLE_THEME.HEALTH
		var hp_bar := _progress_bar(Vector2(x + stat_offset, ALLY_Y + 53), Vector2(stat_width, 20), int(ally.hp), int(ally.max_hp), hp_color, "%d / %d" % [ally.hp, ally.max_hp], downed and not dead, true)
		_dynamic.append(hp_bar)
		if ally.has("finale_original_max"):
			var empty_style := StyleBoxFlat.new()
			empty_style.bg_color = Color("242235")
			empty_style.set_corner_radius_all(10)
			(hp_bar.get_child(0) as Panel).add_theme_stylebox_override("panel",empty_style)
			var cap := FightSystem.healing_ceiling(ally)
			var ratio := float(cap) / float(ally.max_hp)
			var sealed := ColorRect.new()
			sealed.name = "FinaleSealedHP_%d" % i
			sealed.color = Color("8b9099")
			sealed.position = Vector2(stat_width * ratio, 0)
			sealed.size = Vector2(stat_width * (1.0 - ratio), 20)
			sealed.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sealed.tooltip_text = "最大生命%d不变；最高可回复至%d。灰色区不可回复，深色区为失去的生命。" % [ally.max_hp, cap]
			hp_bar.add_child(sealed)
			hp_bar.move_child(sealed, 2)
			for caption in hp_bar.get_children():
				if caption is Label:
					caption.add_theme_color_override("font_color", Color.WHITE)
					caption.add_theme_constant_override("outline_size", 2)
		if personal_guard > 0:
			_draw_personal_guard(i, ally, Rect2(x + stat_offset, ALLY_Y + (78 if both_guards else 81), stat_width, 24 if both_guards else 30), false)
		if personal_temporary > 0:
			_draw_personal_guard(i, ally, Rect2(x + stat_offset, ALLY_Y + (105 if both_guards else 81), stat_width, 24 if both_guards else 30), true)
		_dynamic.append(_ultimate_card(i, x))
		if FightSystem.fc.is_math(i):
			_math_portrait_rect = portrait_rect
			var math_hitbox := Control.new()
			math_hitbox.name = "MathPortraitInspect"
			math_hitbox.mouse_filter = Control.MOUSE_FILTER_STOP
			math_hitbox.tooltip_text = "右键查看演算区与战斗计数"
			_ui.add_child(math_hitbox)
			_place(math_hitbox, portrait_rect)
			math_hitbox.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed:
					if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and _mobile_inspect): _toggle_calculation()
					elif event.button_index == MOUSE_BUTTON_LEFT: _select_ally(i)
					math_hitbox.accept_event()
			)
			_dynamic.append(math_hitbox)

func _draw_phoenix_ally(ally: Dictionary, index: int) -> void:
	var rect := Rect2(592, ALLY_Y, 1240, 196)
	var frame := preload("res://scripts/ui/anya_phoenix_frame.gd").new()
	frame.unit = ally
	frame.position = rect.position
	frame.selected.connect(_select_ally.bind(index))
	frame.inspect_ultimate.connect(_show_ultimate_popup.bind(index, 1000.0))
	_ui.add_child(frame)
	_dynamic.append(frame)
	_target_rects["ally_%d" % index] = rect
	_draw_personal_guard(index, ally, Rect2(rect.position + Vector2(278, 130), Vector2(205, 30)), false)
	var temporary := int(ally.statuses.get("poison_guard", {}).get("stacks", 0))
	if temporary > 0: _draw_personal_guard(index, ally, Rect2(rect.position + Vector2(500, 130), Vector2(205, 30)), true)
	_draw_statuses(ally, rect.position + Vector2(720 if temporary > 0 else 500, 129), true, 220 if temporary > 0 else 440)
	_draw_ally_condition_fx(ally, index, rect)

func _draw_ally_condition_fx(ally: Dictionary, index: int, rect: Rect2) -> void:
	var isolated: bool = ally.statuses.has("isolation")
	var controlled: bool = FightSystem.fc.COMPANIONS.is_controlled(ally) or ally.statuses.has("domination")
	if not isolated and not controlled: return
	var fx := Control.new()
	fx.name = "AllyConditionFX_%d" % index
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.z_index = 19
	_ui.add_child(fx)
	_place(fx, rect)
	_dynamic.append(fx)
	if isolated:
		var curtain := preload("res://scripts/ui/battle_isolation_frame.gd").new()
		curtain.name = "IsolationCurtain"
		curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		curtain.size = rect.size
		fx.add_child(curtain)
	if controlled:
		var violet := Color("f4a5e0", 0.95)
		for edge in [0.0, rect.size.x]:
			var inward := 1.0 if edge == 0.0 else -1.0
			for top in [0.0, rect.size.y]:
				var vertical := 1.0 if top == 0.0 else -1.0
				var corner := Line2D.new()
				corner.points = PackedVector2Array([Vector2(edge, top + vertical * 27), Vector2(edge, top), Vector2(edge + inward * 27, top)])
				corner.width = 4.0
				corner.default_color = violet
				fx.add_child(corner)
	if controlled:
		var pulse := Settings.battle_tween(fx).set_loops()
		pulse.tween_property(fx, "modulate:a", 0.55, 0.7)
		pulse.tween_property(fx, "modulate:a", 1.0, 0.7)

func _play_ally_exit(ally_id: String, texture: Texture2D, rect: Rect2) -> void:
	if _ally_exits.has(ally_id): return
	var effect := preload("res://scripts/ui/battle_ally_shatter.gd").new()
	effect.name = "AllyExit_" + ally_id
	effect.configure(texture, rect, ally_id.hash())
	_ally_exits[ally_id] = effect
	effect.finished.connect(func() -> void:
		_ally_exits.erase(ally_id)
		_refresh.call_deferred()
	, CONNECT_ONE_SHOT)
	_effect_layer.add_child(effect)

func _draw_personal_guard(index: int, ally: Dictionary, rect: Rect2, temporary: bool) -> void:
	var amount := int(ally.statuses.get("poison_guard", {}).get("stacks", 0)) if temporary else int(ally.guard)
	var badge := PERSONAL_GUARD.badge(_ui, rect, amount, temporary, int(ally.max_hp))
	badge.name = ("PersonalTemporaryGuard_%d" if temporary else "PersonalGuard_%d") % index
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	# Reading a shield must not block selecting its owner as a skill target.
	badge.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: _select_ally(index)
	)
	_dynamic.append(badge)

func _draw_painting() -> void:
	var owner := FightSystem._ally_index("liudanya")
	if owner < 0: return
	if bool(FightSystem.allies[owner].get("anya_hidden", false)): return
	var p = FightSystem.fc.PAINTING
	var g: Dictionary = p.groups(FightSystem.fc.painting)
	var button := _compact_button("", Rect2(42, 880, 420, 116), _show_painting, Color("b75f4e"))
	button.name = "PaintingInspect"
	button.tooltip_text = FightData.passive("liudanya")
	button.disabled = _turn_interaction_locked()
	button.add_theme_stylebox_override("normal", BATTLE_THEME.frame(Color("ded3ba"), Color("a98b60"), 1, 4))
	button.add_theme_stylebox_override("hover", BATTLE_THEME.frame(Color("eee3cd"), Color("ac6c45"), 2, 4))
	_dynamic.append(button)
	var miniature := preload("res://scripts/ui/painting_canvas.gd").new()
	miniature.name = "PaintingMiniature"
	miniature.compact = true
	miniature.position = Vector2(12, 10)
	miniature.size = Vector2(144, 96)
	miniature.colors = FightSystem.fc.painting.duplicate()
	button.add_child(miniature)
	FC_VISUALS.text(button, "未完的画作", Rect2(176, 8, 232, 30), 23, Color("3f5549")).add_theme_font_override("font", BATTLE_THEME.HEADING)
	FC_VISUALS.text(button, "水墨 %d 组  ·  三色 %d 组" % [g.ink.size(), g.tri.size()], Rect2(176, 42, 232, 28), 17, Color("7c5a42"))
	FC_VISUALS.text(button, "下回合能量 +%d" % FightSystem.fc.painting_next_energy if FightSystem.fc.painting_next_energy > 0 else "展开画卷  ›", Rect2(176, 78, 232, 26), 18, Color("8d503b"))

func _show_painting() -> void:
	if _turn_interaction_locked(): return
	if is_instance_valid(_painting_popup):
		_painting_popup.queue_free()
		return
	_painting_popup = preload("res://scripts/ui/fc_painting_panel.gd").new()
	_painting_popup.inspect_only = true
	_ui.add_child(_painting_popup)

func _draw_party_guard(rect: Rect2, amount: int, temporary: bool, badge_offset: float) -> void:
	var tint := Color("afd3c1") if temporary else Color("8abbdc")
	var frame := Control.new()
	_ui.add_child(frame)
	_place(frame, rect)
	frame.name = "TemporarySharedGuardFrame" if temporary else "SharedGuardFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rail := _chrome(frame, "guard_frame", Rect2(Vector2.ZERO, rect.size), tint)
	rail.temporary = temporary
	frame.z_index = 3
	_dynamic.append(frame)
	var badge := Control.new()
	frame.add_child(badge)
	# Attach readouts to the lower party rail, clear of the finale meters above.
	_place(badge, Rect2(rect.size.x - 204 - badge_offset, rect.size.y - 4, 200, 36))
	badge.name = "TemporaryGuardBadge" if temporary else "SharedGuardBadge"
	badge.z_index = 1
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.tooltip_text = "临时共享护盾：优先抵挡伤害，下个我方回合开始消失。" if temporary else "共享护盾：全队共用，先于个人护盾抵挡伤害。"
	var crest := _chrome(badge, "guard_badge", Rect2(Vector2.ZERO, badge.size), tint)
	crest.temporary = temporary
	FC_VISUALS.text(badge, "临时" if temporary else "共享", Rect2(48, 1, 40, 34), 16, tint.lerp(CHROME.INK, 0.6))
	FC_VISUALS.text(badge, str(amount), Rect2(90, 1, 98, 34), 22, CHROME.INK, true)

func _make_hand_ticket(data: Dictionary, index: int = -1) -> Button:
	var id := String(data.skill_id)
	var card := _button("", Vector2.ZERO, Vector2(420, 50), func() -> void: pass, FightData.rarity_color(id), 17)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		card.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	card.get_node("SurfaceArt").hide()
	card.pivot_offset = Vector2(0, 25)
	var identity := FC_VISUALS.card_identity(data)
	var skin := _chrome(card, "ticket", Rect2(Vector2.ZERO, card.size), identity.accent, index >= 0 and FightSystem.pending_card == index)
	skin.identity = identity
	skin.disabled = index >= 0 and not FightSystem.can_play(index)
	var energy_badge := FC_VISUALS.energy_badge(card, data, Rect2(3, 1, 48, 48))
	energy_badge.paper_style = true
	var energy_value := energy_badge.get_child(0) as Label
	energy_value.add_theme_color_override("font_color", BATTLE_THEME.FAINT if skin.disabled else CHROME.INK)
	if id.begins_with("LP"): energy_value.add_theme_color_override("font_color", Color("c1ac91") if skin.disabled else Color("fff0c8"))
	energy_value.add_theme_constant_override("outline_size", 0)
	FC_VISUALS.icon(card, FightData.skill_icon(id), Rect2(55, 3, 44, 44))
	var effects: Array[String] = FightSystem.fc.effect_keys(data)
	var name_color := BATTLE_THEME.GOLD if FightData.rarity_color(id).r > 0.9 and FightData.rarity_color(id).b < 0.75 else BATTLE_THEME.TEXT
	if skin.disabled: name_color = BATTLE_THEME.FAINT
	var skill_name := FC_VISUALS.text(card, FightData.skill(id).get("name", id), Rect2(109, 0 if not effects.is_empty() else 8, 224, 27), 21, name_color)
	skill_name.add_theme_font_override("font", DISPLAY_FONT)
	if not effects.is_empty(): FC_VISUALS.effect_icons(card, data, Vector2(110, 27), 21, true)
	if bool(data.get("trojan", false)) and effects.size() == 1:
		var warning := FC_VISUALS.text(card, "先打此牌 · 原效果失效", Rect2(177, 27, 193, 21), 15, Color("ffb4bb"))
		warning.name = "TrojanWarning"
	FC_VISUALS.owner_icon(card, data, Rect2(374, 3, 34, 44))
	return card

func _draw_hand() -> void:
	var cards: Array = FightSystem.get_hand()
	var card_views: Array[Control] = []
	if cards.any(func(entry: Dictionary) -> bool: return bool(entry.get("trojan", false))):
		var notice := FC_VISUALS.panel(_ui, Rect2(42, 149, 420, 29), Color("442633"), Color("e48791"), 4)
		notice.name = "TrojanHandNotice"
		FC_VISUALS.glyph(notice, "debuff", Rect2(4, 3, 23, 23), Color("ff9eaa"))
		FC_VISUALS.text(notice, "木马牌优先 · 打出后原效果失效", Rect2(33, 2, 380, 25), 17, Color("ffd5d8"))
		_dynamic.append(notice)
	for i in cards.size():
		var data: Dictionary = cards[i]
		var id := String(data.skill_id)
		var caster := FightData.card_owner(data)
		var card := _make_hand_ticket(data, i)
		card.position = Vector2(42, 185 + i * 57)
		card.name = "HandCard_%d" % int(data.uid)
		card.tooltip_text = "%s · 施术者：%s\n悬停预览最终扣血；左键施放，右键详情" % [FightData.rarity_name(id), caster.get("name", "")]
		if bool(data.get("trojan", false)): card.tooltip_text += "\n木马感染：必须先打出此牌，消耗能量，但原技能效果失效。"
		elif cards.any(func(entry: Dictionary) -> bool: return bool(entry.get("trojan", false))): card.tooltip_text += "\n需先打出带木马标记的手牌。"
		if FightSystem.ENEMY_RULES.slot_blocked(FightSystem, i): card.tooltip_text += "\n黑暗遮蔽：第%d位无法直接出牌，可交换、弃置或消耗。" % (i + 1)
		card.mouse_entered.connect(func() -> void: _hovered_skill = i)
		card.mouse_exited.connect(func() -> void:
			if _hovered_skill == i: _hovered_skill = -1
		)
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					if _mobile_inspect:
						if not _turn_interaction_locked(): _show_fc_card_detail(data)
						card.accept_event()
						return
					if _turn_interaction_locked():
						_request_card(i)
						return
					if not FightSystem.can_play(i): return
					_drag_origin = Vector2(250, 210 + i * 57)
					_pointer = _ui.get_global_transform_with_canvas().affine_inverse() * (card.get_global_transform_with_canvas() * event.position)
					_press_pointer = _pointer
					_drag_distance = 0.0
					_drag_visual.set_skill(data)
					_request_card(i)
					_dragging = FightSystem.pending_card == i and FightSystem.pending_target_type() != ""
					_update_drag_visual(_pointer)
				elif event.button_index == MOUSE_BUTTON_RIGHT: _show_fc_card_detail(data)
				get_viewport().set_input_as_handled()
		)
		if not FightSystem.can_play(i) or _turn_interaction_locked(): card.modulate = Color(0.83, 0.86, 0.89, 0.93)
		_dynamic.append(card)
		card_views.append(card)
	_enchant_feedback.sync_hand(cards, card_views)
	_card_motion.sync_hand(cards, card_views)

func _draw_dark_slots() -> void:
	var slots: Dictionary = _enemy_display_dark_slots if _enemy_damage_staged else FightSystem.dark_slots
	for key in slots.keys():
		var index := int(key)
		if index < 0 or index >= FightSystem.expansion_hand_limit or int(slots[key]) < FightSystem.round: continue
		var fog := preload("res://scripts/ui/battle_dark_slot.gd").new()
		fog.name = "DarkSlotFog_%d" % index
		fog.position = Vector2(42, 185 + index * 57)
		_ui.add_child(fog)
		_dynamic.append(fog)

func _on_hand_card_exhausted(card: Dictionary, reason: String) -> void:
	if not is_instance_valid(_card_motion): return
	_card_motion.mark_burn(int(card.uid), reason)
	_card_motion.observe_piles()

func _request_card(index: int) -> bool:
	if _turn_interaction_locked():
		if _can_buffer_action() and index >= 0 and index < FightSystem.hand.size():
			_buffer_action("card", int(FightSystem.hand[index].uid))
			AudioManager.play_card_select()
		return false
	_buffered_action.clear()
	var accepted: bool = _commands.request_card(index)
	if accepted: AudioManager.play_card_select()
	return accepted

func _request_ultimate(index: int) -> bool:
	if _turn_interaction_locked():
		if _can_buffer_action() and index >= 0 and index < FightSystem.allies.size():
			_buffer_action("ultimate", index)
		return false
	_buffered_action.clear()
	_drag_origin = (_target_rects.get("ally_%d" % index, Rect2()) as Rect2).get_center()
	return _commands.request_ultimate(index)

func _select_enemy(index: int) -> void:
	if _turn_interaction_locked(): return
	_commands.select_target("enemy", index)

func _select_ally(index: int) -> void:
	if _turn_interaction_locked(): return
	_commands.select_target("ally", index)

func _can_buffer_action() -> bool:
	if is_instance_valid(_commands) and _commands.pending(): return false
	# Enemy turns, tutorials and modal choices must never become queued attacks.
	if not FightSystem.battle_active or FightSystem.phase != FightSystem.PLAYER_TURN or FightSystem.pending_turn_draw > 0: return false
	if FightSystem.story_input_locked or _story_busy or _enemy_damage_staged or _enemy_interrupt_staged or _enemy_interrupt_busy: return false
	if _banner_busy or not _turn_queue.is_empty() or _confusion_busy or not _confused_actions.is_empty() or not _ally_exits.is_empty(): return false
	for modal in [_ultimate_cutin, _pursuit_cutin, _draft_reveal, _forecast_reveal, _painting_sequence, _painting_popup, _result_panel, _tutorial_dialog, _fc_card_detail, _status_list, _archive, _log_popup, _pile_popup, _calculation_popup, _item_popup]:
		if is_instance_valid(modal): return false
	return FightSystem.fc.choice.is_empty() and not (is_instance_valid(_finale_ui) and _finale_ui.busy) and not (is_instance_valid(_phantom_assist) and _phantom_assist.busy)

func _buffer_action(kind: String, identity: int) -> void:
	_buffered_action = {"kind":kind, "identity":identity, "round":FightSystem.round, "encounter":FightSystem.encounter_serial}

func _buffered_card_index() -> int:
	for i in FightSystem.hand.size():
		if int(FightSystem.hand[i].uid) == int(_buffered_action.identity): return i
	return -1

func _buffered_target_side() -> String:
	if _buffered_action.is_empty(): return FightSystem.pending_target_type()
	if _buffered_action.kind == "ultimate":
		var owner := int(_buffered_action.identity)
		if owner >= 0 and owner < FightSystem.allies.size(): return String(FightSystem.get_ultimate(owner).get("target", ""))
	else:
		return FightSystem.card_target_type(_buffered_card_index())
	return ""

func _capture_buffered_input(event: InputEvent) -> void:
	if not _can_buffer_action(): return
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		_buffered_action.clear()
		_clear_drag_visual()
		FightSystem.cancel_targeting()
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT: return
	var point: Vector2 = _ui.get_global_transform_with_canvas().affine_inverse() * event.position
	if event.pressed:
		for i in FightSystem.allies.size():
			var button := _ui.find_child("UltimateButton_%d" % i, true, false) as Control
			if is_instance_valid(button) and Rect2(Vector2.ZERO, button.size).has_point(button.get_global_transform_with_canvas().affine_inverse() * event.position):
				_request_ultimate(i)
				return
		for node in _dynamic:
			if not is_instance_valid(node) or not String(node.name).begins_with("HandCard_"): continue
			var card := node as Control
			if card.get_rect().has_point(point):
				_buffer_action("card", int(String(card.name).trim_prefix("HandCard_")))
				AudioManager.play_card_select()
				_buffered_action["held"] = true
				_press_pointer = point
				return
	# Both click-to-target and a drag released during recovery retain their target.
	if _buffered_action.is_empty():
		if FightSystem.pending_card >= 0 and FightSystem.pending_card < FightSystem.hand.size():
			_buffer_action("card", int(FightSystem.hand[FightSystem.pending_card].uid))
		elif FightSystem.pending_ultimate >= 0:
			_buffer_action("ultimate", FightSystem.pending_ultimate)
	if not event.pressed and not _buffered_action.is_empty(): _buffered_action["held"] = false
	var side := _buffered_target_side()
	if side not in ["enemy", "ally"]: return
	var units: Array = FightSystem.enemies if side == "enemy" else FightSystem.allies
	for i in units.size():
		if (_target_rects.get("%s_%d" % [side, i], Rect2()) as Rect2).has_point(point):
			if not _buffered_action.is_empty(): _buffered_action["target"] = i
			return

func _flush_buffered_action() -> void:
	if _buffered_action.is_empty(): return
	if not _can_buffer_action() or int(_buffered_action.round) != FightSystem.round or int(_buffered_action.encounter) != FightSystem.encounter_serial:
		_buffered_action.clear()
		return
	if _turn_interaction_locked(): return
	var action := _buffered_action.duplicate()
	var index := _buffered_card_index() if action.kind == "card" else int(action.identity)
	_buffered_action.clear() # Clear before rules emit signals or start another animation.
	_clear_drag_visual()
	if index < 0: return
	var accepted: bool = _request_card(index) if action.kind == "card" else _request_ultimate(index)
	if accepted and action.kind == "card" and bool(action.get("held", false)) and FightSystem.pending_target_type() != "":
		_drag_origin = Vector2(250, 210 + index * 57)
		_drag_visual.set_skill(FightSystem.hand[index])
		_dragging = true
	if not accepted or not action.has("target"): return
	var side := FightSystem.pending_target_type()
	if side == "enemy": _select_enemy(int(action.target))
	elif side == "ally": _select_ally(int(action.target))

func _turn_interaction_locked() -> bool:
	if is_instance_valid(_commands) and _commands.pending(): return true
	if not _anya_return_queue.is_empty(): return true
	if is_instance_valid(_anya_resolution_fx): return true
	if is_instance_valid(_phantom_assist) and _phantom_assist.busy: return true
	if _enemy_interrupt_staged or _enemy_interrupt_busy: return true
	if _confusion_busy or not _confused_actions.is_empty(): return true
	if not _ally_exits.is_empty(): return true
	if is_instance_valid(_finale_ui) and _finale_ui.busy: return true
	if is_instance_valid(_item_motion): return true
	return (is_instance_valid(_card_motion) and _card_motion.busy()) or _active_player_casts > 0 or _player_effects_busy or Time.get_ticks_msec() < _impact_until or is_instance_valid(_ultimate_cutin) or is_instance_valid(_pursuit_cutin) or is_instance_valid(_draft_reveal) or is_instance_valid(_forecast_reveal) or _banner_busy or not _turn_queue.is_empty() or FightSystem.resolving_action

func _input(event: InputEvent) -> void:
	if is_instance_valid(_commands) and _commands.pending():
		# Modal rule: the pending command exposes exactly two choices, 确认 or 不确认.
		# Left clicks reach the modal's own buttons through the full-screen shade; any
		# other event is swallowed so no hand card, HUD button, status chip, shortcut
		# or unhandled handler can act on another interface while the modal is up.
		if event is InputEventMouseButton:
			var click := event as InputEventMouseButton
			if click.button_index == MOUSE_BUTTON_LEFT:
				return
			get_viewport().set_input_as_handled()
			if click.pressed and click.button_index == MOUSE_BUTTON_RIGHT: _commands.cancel()
			return
		if event is InputEventMouseMotion:
			return # Hovering never reaches controls behind the shade.
		if event.is_action_pressed("ui_cancel"):
			_commands.cancel()
		elif event.is_action_pressed("ui_accept") and not (event is InputEventKey and (event as InputEventKey).echo):
			_commands.accept()
		get_viewport().set_input_as_handled()
		return
	# Settings stays available even while the director consumes normal battle input.
	if not is_instance_valid(_archive) and not is_instance_valid(_result_panel) and not is_instance_valid(_fc_card_detail) and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var settings_point: Vector2 = _ui.get_global_transform_with_canvas().affine_inverse() * event.position
		var hovered := get_viewport().gui_get_hovered_control()
		# A higher canvas (such as the FC lab toolbar) owns its own clicks.
		if _settings_button.get_rect().has_point(settings_point) and (hovered == null or _ui.is_ancestor_of(hovered)):
			_open_battle_settings()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause") and FightSystem.pending_target_type().is_empty() and not is_instance_valid(_archive) and not is_instance_valid(_calculation_popup) and not is_instance_valid(_fc_card_detail) and not is_instance_valid(_painting_popup) and not is_instance_valid(_result_panel):
		_open_battle_settings()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_archive) and _archive.page == "settings": return
	if is_instance_valid(_phantom_assist) and _phantom_assist.busy:
		_phantom_assist.accept_skip(event)
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_painting_popup): return
	if is_instance_valid(_result_panel): return
	if is_instance_valid(_ultimate_cutin): return
	if is_instance_valid(_status_list): return
	if is_instance_valid(_fc_card_detail): return
	if is_instance_valid(_archive):
		_clear_drag_visual()
		return
	if is_instance_valid(_calculation_popup):
		var outside_click := false
		if event is InputEventMouseButton and event.pressed:
			var point: Vector2 = _ui.get_global_transform_with_canvas().affine_inverse() * event.position
			outside_click = not _calculation_popup.get_rect().has_point(point)
		if event.is_action_pressed("ui_cancel") or outside_click:
			_hide_calculation()
			get_viewport().set_input_as_handled()
			return
	if not FightSystem.fc.choice.is_empty():
		# The modal needs GUI events while normal battle controls remain locked.
		_clear_drag_visual()
		return
	if _turn_interaction_locked():
		_capture_buffered_input(event)
		if event is InputEventMouse or event is InputEventKey:
			get_viewport().set_input_as_handled()
		return
	if FightSystem.pending_target_type() != "" and ((event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT) or event.is_action_pressed("ui_cancel")):
		_clear_drag_visual()
		FightSystem.cancel_targeting()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_pointer = _ui.get_global_transform_with_canvas().affine_inverse() * event.position
		if _dragging: _drag_distance = maxf(_drag_distance, _pointer.distance_to(_press_pointer))
		_update_drag_visual(_pointer)
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed and _dragging:
		_clear_drag_visual()
		var local: Vector2 = _ui.get_global_transform_with_canvas().affine_inverse() * event.position
		var target := _target_at(local)
		if target >= 0:
			if FightSystem.pending_target_type() == "enemy": _select_enemy(target)
			elif FightSystem.pending_target_type() == "ally": _select_ally(target)
		elif maxf(_drag_distance, local.distance_to(_press_pointer)) > 28:
			FightSystem.cancel_targeting()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and is_instance_valid(_skill_popup):
		_skill_popup.queue_free()
		_skill_popup = null

func _process(_delta: float) -> void:
	_try_anya_return()
	_flush_buffered_action()
	_update_damage_preview()
	if is_instance_valid(_card_motion):
		_card_motion.hold_draws = _banner_busy or not _turn_queue.is_empty()
	if is_instance_valid(_drag_visual): _update_drag_visual(_pointer)
	if is_instance_valid(_enchant_feedback):
		_enchant_feedback.blocked = _turn_interaction_locked() or not FightSystem.fc.choice.is_empty() or is_instance_valid(_fc_card_detail) or is_instance_valid(_archive)

func _update_damage_preview() -> void:
	if not is_instance_valid(_damage_preview): return
	var blocked: bool = not FightSystem.battle_active or _turn_interaction_locked() or FightSystem.story_input_locked or is_instance_valid(_result_panel) or is_instance_valid(_fc_card_detail) or is_instance_valid(_status_list) or is_instance_valid(_archive) or is_instance_valid(_log_popup) or is_instance_valid(_pile_popup) or is_instance_valid(_calculation_popup) or is_instance_valid(_item_popup) or not FightSystem.fc.choice.is_empty() or not FightSystem.pending_item.is_empty()
	var ultimate := FightSystem.pending_ultimate if FightSystem.pending_ultimate >= 0 else _hovered_ultimate
	var card := FightSystem.pending_card if FightSystem.pending_card >= 0 else _hovered_skill
	if FightSystem.pending_card >= 0: ultimate = -1
	if blocked or (ultimate < 0 and (card < 0 or card >= FightSystem.hand.size())):
		if _preview_key != "": _damage_preview.clear()
		_preview_key = ""
		return
	var definition: Dictionary = FightSystem.get_ultimate(ultimate) if ultimate >= 0 else FightData.skill(String(FightSystem.hand[card].skill_id))
	var side := String(definition.get("target", "enemy"))
	var target := -1
	if side in ["enemy", "ally"]:
		var units: Array = FightSystem.enemies if side == "enemy" else FightSystem.allies
		for i in units.size():
			# Use the same transformed event position as the aiming arrow.
			if _target_rects.get("%s_%d" % [side, i], Rect2()).has_point(_pointer) and _alive(units[i]): target = i
	var key := "%d:%d:%d:%d" % [_preview_revision, card, ultimate, target]
	if key == _preview_key: return
	_preview_key = key
	var previews: Array = []
	var compare := side in ["enemy", "ally"] and target < 0
	var targets: Array = [target]
	if compare:
		targets.clear()
		for i in (FightSystem.enemies.size() if side == "enemy" else FightSystem.allies.size()): targets.append(i)
	for i in targets:
		var preview := FightSystem.preview_ultimate(ultimate, int(i)) if ultimate >= 0 else FightSystem.preview_card(card, int(i))
		if preview.is_empty(): continue
		preview.compare_side = side
		preview.compare_target = i
		previews.append(preview)
	var owner := ultimate if ultimate >= 0 else FightSystem.caster_index(FightSystem.hand[card])
	var context := {"unit":FightSystem.allies[owner] if owner >= 0 else {}, "kind":"终结技" if ultimate >= 0 else "技能"}
	context.finale = is_instance_valid(_finale_ui)
	if ultimate >= 0:
		context.icon = load(String(definition.icon)) if definition.has("icon") else null
	else:
		context.icon = FightData.skill_icon(String(FightSystem.hand[card].skill_id))
	_damage_preview.present(previews, _target_rects, compare, FightSystem.can_ultimate(ultimate) if ultimate >= 0 else FightSystem.can_play(card), context)

func _clear_drag_visual() -> void:
	_dragging = false
	if is_instance_valid(_drag_visual): _drag_visual.hide()

func _update_drag_visual(end: Vector2) -> void:
	if not is_instance_valid(_drag_visual): return
	var side := FightSystem.pending_target_type()
	_drag_visual.visible = side != "" and not _turn_interaction_locked() and not is_instance_valid(_fc_card_detail) and not is_instance_valid(_status_list) and not is_instance_valid(_archive) and not is_instance_valid(_log_popup) and not is_instance_valid(_pile_popup) and not is_instance_valid(_calculation_popup) and not is_instance_valid(_item_popup) and FightSystem.fc.choice.is_empty()
	if not _drag_visual.visible: return
	_drag_visual.origin = _drag_origin
	_drag_visual.pointer = end
	_drag_visual.held = _dragging and _drag_distance > 18
	_drag_visual.targets.clear()
	var count := FightSystem.enemies.size() if side == "enemy" else FightSystem.allies.size()
	for i in count:
		if _valid_visual_target(side, i):
			_drag_visual.targets.append(_target_rects.get("%s_%d" % [side, i], Rect2()))
	var target := _target_at(end)
	_drag_visual.target = _target_rects.get("%s_%d" % [side, target], Rect2()) if target >= 0 else Rect2()

func _valid_visual_target(side: String, index: int) -> bool:
	if not FightSystem.valid_target(side, index): return false
	if FightSystem.tutorial_step == 0 and side == "enemy" and index != 0: return false
	if FightSystem.tutorial_step == 2 and side == "ally" and index != 0: return false
	if FightSystem.story_forced_skill == "hang_on" and side == "ally" and String(FightSystem.allies[index].id) != "zhoumingyuan": return false
	if side == "ally" and FightSystem.pending_card >= 0:
		var def := FightData.skill(String(FightSystem.hand[FightSystem.pending_card].skill_id))
		if def.get("downed_only", false) and not FightSystem.allies[index].get("downed", false): return false
	return true

func _target_at(local: Vector2) -> int:
	var side := FightSystem.pending_target_type()
	var count := FightSystem.enemies.size() if side == "enemy" else FightSystem.allies.size()
	for i in count:
		var key := ("enemy_" if side == "enemy" else "ally_") + str(i)
		if _valid_visual_target(side, i) and _target_rects.get(key, Rect2()).has_point(local):
			return i
	return -1

func _on_effect_requested(effect_id: String, side: String, index: int, hp_damage: int, guard_damage: int) -> void:
	if FightSystem.confused_draw_resolving: return
	if effect_id == "report_rebirth" and side == "enemy":
		if _enemy_damage_staged: return # Reveal with the queued absent action's contact.
		preload("res://scripts/ui/battle_enemy_audio.gd").emit(_effect_layer, "report_card", "rebirth")
		var rebirth_rect: Rect2 = _target_rects.get("enemy_%d" % index, Rect2())
		if rebirth_rect.size != Vector2.ZERO: _enemy_attack._play_expansion_fx(_effect_layer, effect_id, rebirth_rect.get_center())
		return
	var attack_attribute := _pending_attack_attribute
	_pending_attack_attribute = {}
	if effect_id == "self_loss" and FightSystem.phase == FightSystem.PLAYER_TURN and _enemy_damage_staged:
		_round_start_damage.append({"index":index, "hp":hp_damage})
		return
	if FightSystem.phase == FightSystem.ENEMY_TURN and effect_id == "poison_apply":
		if not _enemy_effect_queue.is_empty() and not _enemy_effect_queue[-1].effects.is_empty():
			var last: Dictionary = _enemy_effect_queue[-1].effects[-1]
			if not last.has("reactions"): last.reactions = []
			last.reactions.append({"id":effect_id, "side":side, "target":index, "hp":0, "guard":0, "after":FightSystem.enemies[index].duplicate(true)})
		return
	if FightSystem.phase == FightSystem.ENEMY_TURN and effect_id in ["C_reflect", "C_share"]:
		if _enemy_effect_queue.is_empty(): return
		var action: Dictionary = _enemy_effect_queue[-1]
		if not action.has("reactions"): action.reactions = []
		var unit: Dictionary = FightSystem.enemies[index] if side == "enemy" else FightSystem.allies[index]
		action.reactions.append({"side":side, "target":index, "hp":hp_damage, "guard":guard_damage, "after":unit.duplicate(true)})
		return
	if FightSystem.phase == FightSystem.ENEMY_TURN and side == "ally":
		if _enemy_effect_queue.is_empty(): return
		_enemy_effect_queue[-1].effects.append({
			"actor": _current_enemy_actor, "effect": effect_id, "target": index,
			"hp_damage": hp_damage, "guard_damage": guard_damage,
			"ally_after": FightSystem.allies[index].duplicate(true),
			"shared_guard_after": FightSystem.shared_guard,
			"temporary_guard_after": FightSystem.fc.temporary_guard,
			"reactions":_enemy_effect_queue[-1].get("reactions", []),
		})
		_enemy_effect_queue[-1]["reactions"] = []
		return
	if not _player_display_enemies.is_empty():
		_impact_until = maxi(_impact_until, Time.get_ticks_msec() + Settings.battle_msec(330))
	var rect: Rect2 = _target_rects.get(("enemy_" if side == "enemy" else "ally_") + str(index), Rect2())
	var code := String(FightData.skill(effect_id).get("code", effect_id))
	var hit_count := 0 if code == "poison_apply" else 1
	var origin_rect: Rect2 = _target_rects.get("ally_%d" % _current_player_actor, rect)
	var first := _pending_player_effects.is_empty()
	var units: Array = FightSystem.enemies if side == "enemy" else FightSystem.allies
	# Preserve each individual contact and its exact intermediate HP/shield state.
	_pending_player_effects.append({"id":code, "side":side, "rect":rect, "origin":origin_rect.get_center(), "hp":hp_damage, "guard":guard_damage, "hits":hit_count, "index":index, "attribute":attack_attribute, "after":units[index].duplicate(true), "enemies_after":FightSystem.get_enemies().duplicate(true) if side == "enemy" else [], "audio_token":_presentation_serial, "audio_ultimate":_ultimate_audio_token == _presentation_serial and FightSystem.phase == FightSystem.PLAYER_TURN, "audio_module":BATTLE_ART.module(FightSystem.allies[_current_player_actor]) if _current_player_actor >= 0 and _current_player_actor < FightSystem.allies.size() else ""})
	if first: _flush_player_effects.call_deferred()

func _flush_player_effects() -> void:
	if FightSystem.fc.choice.get("kind", "") == "painting":
		_painting_effects_waiting = true
		return
	_painting_effects_waiting = false
	if _pending_player_effects.is_empty(): return
	var effects := _pending_player_effects.duplicate()
	_pending_player_effects.clear()
	if not _player_cast_played and _current_player_actor >= 0 and _current_player_actor < FightSystem.allies.size() and _player_skill_id != "ultimate":
		_start_player_cast(effects)
	else:
		_release_player_effects(effects)

func _start_player_cast(effects: Array) -> void:
	_player_cast_played = true
	var audio_skill := _player_skill_id
	var audio_token := _presentation_serial
	_audio.player_start(audio_skill, FightSystem.allies[_current_player_actor])
	var actor_unit: Dictionary = FightSystem.allies[_current_player_actor].duplicate(true)
	if audio_skill.begins_with("LP"): actor_unit.anya_phoenix = true
	var actor := preload("res://scripts/ui/battle_player_cast.gd").new()
	actor.name = "PlayerCast_%d" % _presentation_serial
	actor.configure(actor_unit, effects, _target_rects.get("ally_%d" % _current_player_actor, Rect2()))
	_active_player_casts += 1
	actor.released.connect(func(origin: Vector2, travel: float) -> void:
		_audio.player_release(audio_skill, audio_token)
		_release_player_effects(effects, origin, travel)
	, CONNECT_ONE_SHOT)
	actor.finished.connect(func() -> void: _active_player_casts = maxi(0, _active_player_casts - 1), CONNECT_ONE_SHOT)
	_ui.add_child(actor)

func _release_player_effects(effects: Array, actor_origin: Vector2 = Vector2.INF, travel_override: float = -1.0) -> void:
	var previous_bounce := -1
	for effect: Dictionary in effects:
		var queued := effect.duplicate()
		queued.origin = effect.origin if actor_origin == Vector2.INF else actor_origin
		queued.travel = travel_override
		if String(effect.id) in ["M07", "D05", "X09"] and String(effect.side) == "enemy":
			queued["bounce_from"] = previous_bounce
			previous_bounce = int(effect.index)
		_player_effect_queue.append(queued)
	if not _player_effects_busy: _play_player_effect_queue()

func _play_player_effect_queue() -> void:
	_player_effects_busy = true
	while not _player_effect_queue.is_empty():
		var effect: Dictionary = _player_effect_queue.pop_front()
		# A previous segment may have defeated an enemy and shifted the surviving targets.
		var rect: Rect2 = _target_rects.get(("enemy_" if effect.side == "enemy" else "ally_") + str(effect.index), effect.rect)
		if rect.size == Vector2.ZERO: continue
		if String(effect.id) == "magician_dodge":
			if not _player_display_enemies.is_empty():
				_player_display_enemies = effect.enemies_after.duplicate(true)
				_refresh()
			var actor: TextureRect = _enemy_portraits.get(int(effect.index))
			if is_instance_valid(actor):
				var base_x := actor.position.x
				var dodge := Settings.battle_tween(self)
				dodge.tween_property(actor, "position:x", base_x + 46.0, 0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				dodge.tween_property(actor, "position:x", base_x, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_spawn_damage_number("闪避！", rect.get_center() + Vector2(0, -55), Color("ffe0a1"), "enemy", "dodge", 43)
				await Settings.battle_timer(0.35).timeout
			continue
		var origin: Vector2 = effect.origin
		if int(effect.get("bounce_from", -1)) >= 0:
			origin = (_target_rects.get("enemy_%d" % int(effect.bounce_from), Rect2(origin, Vector2.ZERO)) as Rect2).get_center()
		var delay: float = _vfx.impact_delay(BATTLE_ART.family(effect.id, effect.side), rect.get_center(), origin, float(effect.travel))
		_impact_until = maxi(_impact_until, Time.get_ticks_msec() + Settings.battle_msec((delay + HIT_INTERVAL) * 1000))
		var ultimate_sound := bool(effect.get("audio_ultimate", false))
		var contact_sound := GENERATED_AUDIO.DATA.contact(String(effect.id), String(effect.side), int(effect.hp) + int(effect.guard) > 0, String(effect.get("audio_module", "")))
		_vfx.play_effect(BATTLE_ART.family(effect.id, effect.side), rect.get_center(), origin, String(effect.id).begins_with("ultimate"), int(effect.hits), effect.id, float(effect.travel), not ultimate_sound and contact_sound.is_empty())
		if delay > 0: await Settings.battle_timer(delay).timeout
		_audio.contact(String(effect.id), String(effect.side), int(effect.hp) + int(effect.guard) > 0, String(effect.get("audio_module", "")), int(effect.get("audio_token", -1)), ultimate_sound)
		if effect.side == "enemy" and not _player_display_enemies.is_empty():
			_player_display_enemies = effect.enemies_after.duplicate(true)
			_refresh()
		if effect.hp > 0 or effect.guard > 0:
			_impact_feedback(effect.side, int(effect.index), 1)
			_show_damage_numbers(rect, effect.side, effect.hp, effect.guard, effect.get("attribute", {}))
			await Settings.battle_timer(HIT_INTERVAL).timeout
		else:
			await Settings.battle_timer(0.08).timeout
	_player_effects_busy = false

func _present_item(id: String, target: int, resolve: Callable) -> void:
	var motion := preload("res://scripts/ui/equipment_motion.gd").new()
	_item_motion = motion
	motion.item_id = id
	motion.battle_use = true
	var def: Dictionary = FightEquipmentData.CONSUMABLES[id]
	var target_name := "战斗能量" if def.has("energy") else "我方全体"
	if def.target in ["ally", "enemy"]:
		var units: Array = FightSystem.allies if def.target == "ally" else FightSystem.enemies
		target_name = String(units[target].name)
		var area: Rect2 = _target_rects.get("%s_%d" % [def.target, target], Rect2(860, 700, 200, 120))
		motion.destination = area.get_center()
	elif def.has("energy"):
		motion.destination = Vector2(465, 52)
	elif def.has("draw") or def.has("retain_hand"):
		target_name = "当前手牌"
		motion.destination = Vector2(250, 440)
	else:
		motion.destination = Vector2(1130, 835)
		for i in FightSystem.allies.size():
			if FightSystem._is_alive(FightSystem.allies[i]) and FightSystem.EQUIPMENT.can_guard(FightSystem.allies[i]):
				var area: Rect2 = _target_rects.get("ally_%d" % i, Rect2())
				motion.targets.append(area.get_center())
	motion.caption = "%s → %s" % [def.name, target_name]
	motion.contacted.connect(func() -> void:
		var before_hp: int = int(FightSystem.allies[target].hp) if def.target == "ally" else 0
		resolve.call()
		var restored: int = maxi(0, int(FightSystem.allies[target].hp) - before_hp) if def.target == "ally" else 0
		var words := "能量 +1" if def.has("energy") else "负面状态净化" if def.has("cleanse") else "脱离濒死" if def.has("rescue") else "生命 +%d" % restored if def.has("heal") else "护盾 +8" if def.has("guard") or def.has("party_guard") else ""
		if def.has("cleanse_ids"): words = "疲劳与困倦清除"
		if def.has("ward"): words = "可净化负面免疫 ×1"
		if def.has("enemy_status"): words = "虚弱 · 1回合" if String(def.enemy_status) == "weakness" else "受到伤害 +15%"
		if def.has("draw"): words = "抽牌 +1 · 下回合 +1"
		if def.has("retain_hand"): words = "当前手牌保留"
		if def.has("dispel"): words = "正面状态驱散"
		if not words.is_empty():
			var centers: Array = motion.targets if not motion.targets.is_empty() else [motion.destination]
			for center in centers: _spawn_damage_number(words, center + Vector2(0, -60), Color("e9ba8a") if def.target == "enemy" else Color("9adfcf"), String(def.target), "item_gain", 34)
	)
	motion.finished.connect(func() -> void: _item_motion = null; _refresh())
	_ui.add_child(motion)

func _present_ultimate(owner: int, resolve: Callable) -> void:
	if not Settings.ultimate_presentation_enabled():
		resolve.call()
		_refresh()
		return
	if String(FightSystem.allies[owner].id) == "li_anya":
		_present_anya_entry(owner, resolve)
		return
	_ultimate_cutin = preload("res://scripts/ui/battle_ultimate_cutin.gd").new()
	_ultimate_cutin.module = BATTLE_ART.module(FightSystem.allies[owner])
	var audio_module: String = _ultimate_cutin.module
	_ultimate_cutin.minimum_seconds = _audio.ultimate_start(audio_module)
	_ultimate_cutin.title = String(FightSystem.get_ultimate(owner).get("name", ""))
	_ultimate_cutin.finished.connect(func() -> void:
		var voice_keys: Array[String] = [String(GENERATED_AUDIO.DATA.ULTIMATES[audio_module][1])]
		_audio.stop_cues(voice_keys)
		_ultimate_cutin = null
		_audio.ultimate_release(audio_module)
		resolve.call()
		_refresh()
	, CONNECT_ONE_SHOT)
	_ui.add_child(_ultimate_cutin)
	_refresh()

func _on_presentation_setting_changed(section: String, key: String, value: Variant) -> void:
	if section != "battle": return
	if key == "ultimate_presentation" and not bool(value) and is_instance_valid(_ultimate_cutin):
		if _ultimate_cutin.has_method("complete"): _ultimate_cutin.complete()
		else: _ultimate_cutin._finish()
	if key == "ultimate_presentation" and not bool(value) and is_instance_valid(_anya_resolution_fx):
		_anya_resolution_fx.complete()
	if key == "simple_effects" and bool(value):
		_audio.stop_sfx()
	if key == "show_damage_number" and not bool(value):
		for node in _effect_layer.get_children():
			if node.get_meta("damage_kind", "") in ["hp", "guard"]:
				node.hide()
				node.queue_free()

func _present_pursuit(_owner: int, target: int, sequence: int, consume: bool, resolve: Callable) -> void:
	# Flush the triggering hit and let its damage land before introducing the next hit.
	_refresh()
	await get_tree().process_frame
	while _active_player_casts > 0 or _player_effects_busy or not _pending_player_effects.is_empty() or Time.get_ticks_msec() < _impact_until:
		await get_tree().process_frame
	if Settings.simple_battle_effects():
		resolve.call()
		_refresh()
		return
	_pursuit_cutin = preload("res://scripts/ui/battle_pursuit_cutin.gd").new()
	_audio.play_sfx("sfx_math_lock")
	_audio.play_voice("hero_zhoumingyuan_math_pursuit", 0, "zhoumingyuan")
	_pursuit_cutin.target_name = "敌人 %d · %s" % [target + 1, FightSystem.enemies[target].name]
	_pursuit_cutin.target_attribute = String(FightSystem.enemies[target].attribute)
	_pursuit_cutin.sequence = sequence
	_pursuit_cutin.ammo_name = "释放一次追击"
	if consume and not FightSystem.fc.calculation.is_empty():
		var ammo: Dictionary = FightSystem.fc.calculation[0]
		_pursuit_cutin.ammo_name = "释放弹药 · " + String(FightData.skill(String(ammo.skill_id)).get("name", "演算牌"))
	_pursuit_cutin.finished.connect(func() -> void:
		_pursuit_cutin = null
		_audio.play_sfx("sfx_math_pursuit_release")
		resolve.call()
		_refresh()
	, CONNECT_ONE_SHOT)
	_ui.add_child(_pursuit_cutin)

func _present_draft(owner: int, cards: Array, resolve: Callable) -> void:
	_player_cast_played = true
	_audio.play_sfx("sfx_math_calculation")
	_draft_reveal = preload("res://scripts/ui/battle_draft_reveal.gd").new()
	_draft_reveal.cards = cards.duplicate(true)
	_draft_reveal.owner_id = String(FightSystem.allies[owner].id)
	_draft_reveal.calculation_anchor = Vector2(_math_portrait_rect.get_center().x, 835)
	_draft_reveal.finished.connect(func() -> void:
		_draft_reveal = null
		resolve.call()
		_refresh()
	, CONNECT_ONE_SHOT)
	_ui.add_child(_draft_reveal)
	_refresh()

func _present_forecast(cards: Array, fresh_uids: Array, skill_id: String, resolve: Callable) -> void:
	_audio.play_sfx("sfx_wang_reveal")
	_forecast_reveal = preload("res://scripts/ui/battle_forecast_reveal.gd").new()
	_forecast_reveal.cards = cards.duplicate(true)
	_forecast_reveal.fresh_uids = fresh_uids.duplicate()
	_forecast_reveal.skill_name = String(FightData.skill(skill_id).name)
	_forecast_reveal.finished.connect(func() -> void:
		_forecast_reveal = null
		resolve.call()
		_refresh()
	, CONNECT_ONE_SHOT)
	_ui.add_child(_forecast_reveal)
	_refresh()

func _present_painting_region(owner: int, colors: Array, index: int, resolve: Callable) -> void:
	if not _player_cast_played and _current_player_actor >= 0:
		_start_player_cast([])
	# Includes the preceding region's attacks, poison bursts and math pursuits.
	await get_tree().process_frame
	while _active_player_casts > 0 or _player_effects_busy or not _pending_player_effects.is_empty() or is_instance_valid(_pursuit_cutin) or Time.get_ticks_msec() < _impact_until:
		await get_tree().process_frame
	if Settings.simple_battle_effects():
		if is_instance_valid(_painting_sequence):
			_painting_sequence.queue_free()
			_painting_sequence = null
		_current_player_actor = owner
		_player_skill_id = "Y16"
		_player_cast_played = true
		resolve.call()
		_refresh()
		return
	if index >= colors.size():
		if is_instance_valid(_painting_sequence):
			await Settings.battle_timer(0.3).timeout
			_painting_sequence.queue_free()
			_painting_sequence = null
		resolve.call()
		_refresh()
		return
	if not is_instance_valid(_painting_sequence):
		_painting_sequence = preload("res://scripts/ui/battle_painting_sequence.gd").new()
		_ui.add_child(_painting_sequence)
	_painting_sequence.show_region(colors, index)
	await Settings.battle_timer(0.28).timeout
	_current_player_actor = owner
	_player_skill_id = "Y16"
	_player_cast_played = true
	_painting_sequence.applied = true
	_impact_until = maxi(_impact_until, Time.get_ticks_msec() + Settings.battle_msec(560))
	resolve.call()
	_refresh()

func _on_painting_effect(kind: String, target: int, amount: int, detail: String) -> void:
	if is_instance_valid(_painting_sequence): _painting_sequence.add_result(detail)
	_refresh()
	if target < 0: return
	var rect: Rect2 = _target_rects.get("ally_%d" % target, Rect2())
	if not rect.has_area(): return
	var family := "barrier" if kind == "guard" else "blessing"
	_audio.play_sfx("sfx_liu_guard" if kind == "guard" else "sfx_liu_cleanse")
	_vfx.play_effect(family, rect.get_center(), rect.get_center(), false, 1, "mix_" + kind, 0.0)
	_spawn_damage_number("共享盾 +%d" % amount if kind == "guard" else "净化", rect.get_center() + Vector2(0, -75), Color("83d8ff") if kind == "guard" else Color("abe2be"), "ally", "mix_" + kind, 32)
	_impact_until = maxi(_impact_until, Time.get_ticks_msec() + Settings.battle_msec(560))

func _exit_tree() -> void:
	if FightSystem.item_presentation == Callable(self, "_present_item"):
		FightSystem.item_presentation = Callable()
		if FightSystem.pending_item_resolution.is_valid(): FightSystem.pending_item_resolution.call()
	if FightSystem.painting_region_presentation == Callable(self, "_present_painting_region"):
		FightSystem.painting_region_presentation = Callable()
	if FightSystem.ultimate_presentation == Callable(self, "_present_ultimate"):
		FightSystem.ultimate_presentation = Callable()
	if FightSystem.anya_return_presentation == Callable(self, "_queue_anya_return"):
		FightSystem.anya_return_presentation = Callable()
		# A removed view cannot strand a live battle behind its presentation callback.
		for pending in _anya_return_queue: pending.complete.call()
		_anya_return_queue.clear()
		if not _anya_active_return.is_empty(): _anya_active_return.complete.call()
	if FightSystem.pursuit_presentation == Callable(self, "_present_pursuit"):
		FightSystem.pursuit_presentation = Callable()
	if FightSystem.draft_presentation == Callable(self, "_present_draft"):
		FightSystem.draft_presentation = Callable()
	if FightSystem.forecast_presentation == Callable(self, "_present_forecast"):
		FightSystem.forecast_presentation = Callable()

func _on_enemy_action_started(index: int) -> void:
	_capture_enemy_action_end()
	_current_enemy_actor = index
	_enemy_effect_queue.append({
		"actor": index, "unit": FightSystem.enemies[index].duplicate(true),
		"intent": FightSystem.enemies[index].get("intent", {}).duplicate(true), "effects": [],
		"enemy_count_before": FightSystem.enemies.size(),
		"hand_limit_before":FightSystem.expansion_hand_limit,
	})

func _on_enemy_cards_added(cards: Array, pile: String) -> void:
	var batch := {"cards":cards.duplicate(true), "pile":pile}
	if _enemy_damage_staged and not _enemy_effect_queue.is_empty():
		var action: Dictionary = _enemy_effect_queue[-1]
		if not action.has("inserted_cards"): action.inserted_cards = []
		action.inserted_cards.append(batch)
	else:
		_present_inserted_cards({"inserted_cards":[batch]})

func _present_inserted_cards(action: Dictionary) -> void:
	if action.get("inserted_cards", []).is_empty(): return
	var reveal := preload("res://scripts/ui/battle_inserted_cards.gd").new()
	reveal.entries = action.inserted_cards
	reveal.source = String(action.get("unit", {}).get("name", "敌方干扰"))
	_effect_layer.add_child(reveal)
	await reveal.play()

func _on_enemy_interrupt_started() -> void:
	if _enemy_interrupt_staged: return
	_enemy_interrupt_staged = true
	_enemy_damage_staged = true
	_enemy_presentation_round = FightSystem.round
	_enemy_effect_queue.clear()
	_enemy_display_allies.clear()
	for ally in FightSystem.allies: _enemy_display_allies.append((ally as Dictionary).duplicate(true))
	_enemy_display_enemies = FightSystem.get_enemies().duplicate(true)
	_enemy_display_dark_slots = FightSystem.dark_slots.duplicate()
	_enemy_display_shared_guard = FightSystem.shared_guard
	_enemy_display_temporary_guard = FightSystem.fc.temporary_guard
	_enemy_display_hand_limit = FightSystem.expansion_hand_limit

func _on_enemy_interrupt_finished() -> void:
	_capture_enemy_action_end()
	if not _enemy_interrupt_busy: _play_enemy_interrupt.call_deferred()

func _play_enemy_interrupt() -> void:
	if _enemy_interrupt_busy or not _enemy_interrupt_staged: return
	_enemy_interrupt_busy = true
	while _banner_busy or not _turn_queue.is_empty() or _card_motion.busy() or _active_player_casts > 0 or _player_effects_busy or not _pending_player_effects.is_empty() or _confusion_busy or not _confused_actions.is_empty() or Time.get_ticks_msec() < _impact_until:
		await get_tree().process_frame
	var action_cursor := 0
	while action_cursor < _enemy_effect_queue.size():
		var action: Dictionary = _enemy_effect_queue[action_cursor]
		action_cursor += 1
		if not action.has("allies_after"): _capture_enemy_action_end()
		var portrait: TextureRect = _enemy_portraits.get(int(action.actor)) as TextureRect
		await _present_boss_rebirth(action, portrait)
		await _enemy_attack.play(portrait, action, _target_rects.duplicate(), _effect_layer, _apply_enemy_contacts.bind(action), _vfx)
		_enemy_display_allies.assign(action.allies_after.duplicate(true))
		_enemy_display_enemies = action.enemies_after.duplicate(true)
		_enemy_display_dark_slots = action.dark_slots_after.duplicate()
		_enemy_display_shared_guard = int(action.shared_guard_after)
		_enemy_display_temporary_guard = int(action.temporary_guard_after)
		_refresh()
		_show_enemy_buff_feedback(action)
		await _present_inserted_cards(action)
		if bool(action.get("anya_return", false)):
			await _play_anya_return()
	_enemy_effect_queue.clear()
	_enemy_damage_staged = false
	_enemy_interrupt_staged = false
	_enemy_interrupt_busy = false
	_enemy_display_allies.clear()
	_enemy_display_enemies.clear()
	_enemy_display_dark_slots.clear()
	_refresh()

func _present_boss_rebirth(action: Dictionary, portrait: TextureRect) -> void:
	var unit: Dictionary = action.unit
	if not bool(unit.get("phase_rebirth", false)): return
	var index := int(action.actor)
	if index >= _enemy_display_enemies.size(): return
	if index == _tower_arena_owner:
		_tower_arena_stage = int(unit.boss_phase)
		_sync_tower_background()
	_enemy_display_enemies[index].hp = 0
	_enemy_display_enemies[index].max_hp = int(unit.max_hp)
	_refresh()
	if String(unit.id) == "panic_throat" and is_instance_valid(portrait):
		var effect := preload("res://scripts/ui/battle_panic_effect.gd").new()
		_effect_layer.add_child(effect)
		await effect.rebirth(portrait, int(unit.boss_phase))
	elif String(unit.id) == "inverse_limit" and is_instance_valid(portrait):
		var effect := preload("res://scripts/ui/battle_boss_signature_effect.gd").new()
		_effect_layer.add_child(effect)
		await effect.rebirth(portrait, int(unit.boss_phase))
	else:
		await Settings.battle_timer(0.45).timeout
	_enemy_display_enemies[index].max_hp = int(unit.phase_health[int(unit.boss_phase) - 1])
	_enemy_display_enemies[index].hp = int(_enemy_display_enemies[index].max_hp)
	_refresh()

func _capture_enemy_action_end() -> void:
	if _enemy_effect_queue.is_empty(): return
	var action: Dictionary = _enemy_effect_queue[-1]
	action["allies_after"] = FightSystem.get_allies().duplicate(true)
	# Round-start gains are presented after the player-turn ribbon, not as part of
	# the final enemy's attack or before the matching positive shield number.
	for gain in _turn_guard_gains:
		action.allies_after[int(gain.index)].guard -= int(gain.amount)
	action["enemies_after"] = FightSystem.get_enemies().duplicate(true)
	action["dark_slots_after"] = FightSystem.dark_slots.duplicate()
	action["shared_guard_after"] = FightSystem.shared_guard
	action["temporary_guard_after"] = FightSystem.fc.temporary_guard
	action["hand_limit_after"] = FightSystem.expansion_hand_limit

func _on_enemy_contact_resolved(side: String, index: int) -> void:
	# effect_requested precedes debuff application in the rules; this signal follows it.
	if FightSystem.phase != FightSystem.ENEMY_TURN or side != "ally" or _enemy_effect_queue.is_empty(): return
	var effects: Array = _enemy_effect_queue[-1].effects
	if not effects.is_empty() and int(effects[-1].target) == index:
		effects[-1].ally_after = FightSystem.allies[index].duplicate(true)

func _apply_enemy_contacts(effects: Array, action: Dictionary) -> void:
	if String(action.intent.get("effect", "")) == "compress" and not bool(action.get("hand_limit_shown", false)):
		action["hand_limit_shown"] = true
		var before := int(action.get("hand_limit_before", _enemy_display_hand_limit))
		var after := int(action.get("hand_limit_after", FightSystem.expansion_hand_limit))
		_enemy_display_hand_limit = after
		_enemy_display_enemies = action.enemies_after.duplicate(true)
		var feedback := preload("res://scripts/ui/battle_hand_limit_feedback.gd").new()
		feedback.previous_limit = before
		feedback.current_limit = after
		_effect_layer.add_child(feedback)
	var summoned: Array[int] = []
	if String(action.intent.get("kind", "")) == "split" or String(action.intent.get("effect", "")) in ["report_absent", "score_dissolve"]:
		_enemy_display_enemies = action.enemies_after.duplicate(true)
	elif String(action.intent.get("effect", "")) in ["phantom_summon", "summon", "magic_summon"]:
		var old_count := int(action.get("enemy_count_before", _enemy_display_enemies.size()))
		_enemy_display_enemies = action.enemies_after.duplicate(true)
		for i in range(old_count, _enemy_display_enemies.size()):
			if _alive(_enemy_display_enemies[i]): summoned.append(i)
	for effect: Dictionary in effects:
		if int(effect.target) < _enemy_display_allies.size():
			_enemy_display_allies[int(effect.target)] = effect.ally_after.duplicate(true)
		for reaction: Dictionary in effect.get("reactions", []):
			var units: Array = _enemy_display_enemies if reaction.side == "enemy" else _enemy_display_allies
			if int(reaction.target) < units.size(): units[int(reaction.target)] = reaction.after.duplicate(true)
		_enemy_display_shared_guard = int(effect.shared_guard_after)
		_enemy_display_temporary_guard = int(effect.temporary_guard_after)
	var before_rects := _target_rects.duplicate()
	_refresh()
	for index in summoned:
		if Settings.simple_battle_effects():
			_play_phantom_summon(index)
			continue
		var id := String(_enemy_display_enemies[index].get("id", ""))
		if id == "snicker_shadow":
			var summoned_actor: TextureRect = _enemy_portraits.get(index) as TextureRect
			var at: Vector2 = summoned_actor.rest_position + summoned_actor.size * Vector2(0.5, 0.72) if is_instance_valid(summoned_actor) else (_target_rects.get("enemy_%d" % index, Rect2()) as Rect2).get_center()
			preload("res://scripts/ui/battle_panic_effect.gd").summon_at(_effect_layer, at, index % 2 == 0)
			_reveal_phantom_actor(index)
		elif String(action.intent.get("effect", "")) == "magic_summon":
			_enemy_attack._play_expansion_fx(_effect_layer, "magic_summon", (_target_rects.get("enemy_%d" % index, Rect2()) as Rect2).get_center(), 340.0)
			_reveal_phantom_actor(index)
		else: _play_phantom_summon(index)
	for effect: Dictionary in effects:
		var rect: Rect2 = _target_rects.get("ally_%d" % int(effect.target), Rect2())
		if String(effect.get("effect", "")) == "isolation_gain":
			var extra := int(effect.ally_after.get("isolation_extra", 0))
			_enemy_attack._play_expansion_fx(_effect_layer, "isolation_gain", rect.get_center() - Vector2(0, 14), 240.0)
			_spawn_damage_number("生命上限 +%d\n生命 +%d" % [extra, extra], rect.get_center() + Vector2(0, -105), Color("a9f0cf"), "ally", "isolation_gain", 28)
			continue
		_show_damage_numbers(rect, "ally", int(effect.hp_damage), int(effect.guard_damage))
		if int(effect.hp_damage) > 0 or int(effect.guard_damage) > 0:
			_ally_hit_reaction(int(effect.target), int(effect.hp_damage) == 0)
		for reaction: Dictionary in effect.get("reactions", []):
			var area: Rect2 = before_rects.get("%s_%d" % [reaction.side, int(reaction.target)], Rect2())
			_show_damage_numbers(area, String(reaction.side), int(reaction.hp), int(reaction.guard))
			var reaction_id := String(reaction.get("id", "C_reflect" if reaction.side == "enemy" else "C_share"))
			_audio.contact(reaction_id, String(reaction.side), true, "chen", _presentation_serial)
			_vfx.play_effect(BATTLE_ART.family(reaction_id, reaction.side), area.get_center(), rect.get_center(), false, 1, reaction_id, 0.0)

func _ally_hit_reaction(index: int, guarded: bool) -> void:
	var rect: Rect2 = (_target_rects.get("ally_%d" % index, Rect2()) as Rect2).grow(6)
	var phoenix := _ui.get_node_or_null("AnyaPhoenixFrame")
	if phoenix != null and rect.has_point(phoenix.position): phoenix.react(guarded)
	var portrait := _ui.get_node_or_null("AllyPortrait_%d" % index)
	if portrait != null and is_instance_valid(portrait.living_portrait): portrait.living_portrait.react(guarded)
	# Animate the existing card's parts together, without moving its targeting rect.
	for node in _dynamic:
		if not is_instance_valid(node) or not node is Control or node.get_parent() != _ui: continue
		var part := node as Control
		if not rect.has_point(part.position): continue
		var home := part.position
		var tint := part.modulate
		part.position += Vector2(0, 4 if guarded else 10)
		part.modulate = Color("9fdfff") if guarded else Color("ffc1c7")
		var recoil := Settings.battle_tween(part)
		recoil.tween_interval(0.055)
		recoil.tween_property(part, "position", home - Vector2(0, 3), 0.055)
		recoil.parallel().tween_property(part, "modulate", tint, 0.14)
		recoil.tween_property(part, "position", home, 0.10)

func _on_player_action_started(index: int, skill_id: String) -> void:
	_current_player_actor = index
	_player_skill_id = skill_id
	# The pursuit ribbon already provides its character performance.
	_player_cast_played = skill_id == "pursuit"
	_clear_drag_visual()
	_player_display_enemies = FightSystem.get_enemies().duplicate(true)
	_impact_until = Time.get_ticks_msec() + Settings.battle_msec(800)
	_presentation_serial += 1
	_ultimate_audio_token = _presentation_serial if skill_id == "ultimate" else -1
	_finish_attack_presentation(_presentation_serial)
	_cast_without_effects.call_deferred(_presentation_serial)

func _on_confused_card_played(owner: int, card: Dictionary, presentation: Dictionary) -> void:
	_card_motion.mark_confused(int(card.uid))
	_confused_actions.append({"owner":owner, "card":card.duplicate(true), "presentation":presentation.duplicate(true)})
	if not _confusion_busy: _play_confused_actions.call_deferred()

func _play_confused_actions() -> void:
	if _confusion_busy: return
	_confusion_busy = true
	while not _confused_actions.is_empty() and is_inside_tree():
		while _banner_busy or not _turn_queue.is_empty() or _card_motion.busy() or _active_player_casts > 0 or _player_effects_busy or not _pending_player_effects.is_empty():
			await get_tree().process_frame
		var action: Dictionary = _confused_actions.pop_front()
		var card: Dictionary = action.card
		var owner := int(action.owner)
		var presentation: Dictionary = action.presentation
		_confusion_display_allies.assign(presentation.before.duplicate(true))
		_confusion_display_shared_guard = int(presentation.shared_before)
		_confusion_display_temporary_guard = int(presentation.temporary_before)
		_refresh()
		var owner_rect: Rect2 = _target_rects.get("ally_%d" % owner, Rect2())
		var ticket := _make_hand_ticket(card)
		ticket.name = "ConfusedCard_%d" % int(card.uid)
		ticket.pivot_offset = ticket.size * 0.5
		_card_motion._ignore_input(ticket)
		if ticket.get_parent() != null: ticket.get_parent().remove_child(ticket)
		_effect_layer.add_child(ticket)
		ticket.position = Vector2(90, 49) - ticket.size * 0.5
		ticket.scale = Vector2(0.18, 0.46)
		ticket.rotation = -0.16
		var card_goal := Vector2(clampf(owner_rect.get_center().x, 690, 1430), 690)
		var draw := Settings.battle_tween(ticket).set_parallel(true)
		draw.tween_property(ticket, "position", card_goal - ticket.size * 0.5, 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		draw.tween_property(ticket, "scale", Vector2.ONE, 0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		draw.tween_property(ticket, "rotation", 0.0, 0.40)
		await draw.finished
		var title := preload("res://scripts/ui/battle_enemy_title.gd").new()
		title.skill = "迷魂 · " + String(FightData.skill(String(card.skill_id)).get("name", "攻击"))
		title.caption = "失控出牌 · 攻击队友"
		title.rank = 1
		title.tint = Color("f2a5d6")
		title.position = Vector2(650, 92)
		title.size = Vector2(620, 125)
		_effect_layer.add_child(title)
		var release_card := Settings.battle_tween(ticket).set_parallel(true)
		release_card.tween_property(ticket, "position", owner_rect.get_center() - ticket.size * 0.5, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		release_card.tween_property(ticket, "scale", Vector2(0.28, 0.32), 0.22)
		release_card.tween_property(ticket, "modulate:a", 0.0, 0.22)
		await release_card.finished
		ticket.queue_free()
		var actor := preload("res://scripts/ui/battle_player_cast.gd").new()
		var effects: Array = []
		for hit: Dictionary in presentation.contacts:
			effects.append({"side":"ally", "rect":_target_rects.get("ally_%d" % int(hit.target), Rect2())})
		actor.configure(FightSystem.allies[owner], effects, owner_rect)
		var cue := {"released":false, "finished":false, "origin":owner_rect.get_center(), "travel":0.0}
		actor.released.connect(func(origin: Vector2, travel: float) -> void:
			cue.origin = origin
			cue.travel = travel
			cue.released = true
		, CONNECT_ONE_SHOT)
		actor.finished.connect(func() -> void: cue.finished = true, CONNECT_ONE_SHOT)
		_ui.add_child(actor)
		while not bool(cue.released): await get_tree().process_frame
		var skill_code := String(FightData.skill(String(card.skill_id)).get("code", card.skill_id))
		_audio.player_release(String(card.skill_id), -int(card.uid) - 100)
		var family := BATTLE_ART.family(skill_code, "enemy")
		for hit: Dictionary in presentation.contacts:
			var target := int(hit.target)
			var rect: Rect2 = _target_rects.get("ally_%d" % target, Rect2())
			if rect.has_area():
				var delay: float = _vfx.impact_delay(family, rect.get_center(), cue.origin, float(cue.travel))
				_vfx.play_effect(family, rect.get_center(), cue.origin, false, 1, skill_code, float(cue.travel))
				if delay > 0: await Settings.battle_timer(delay).timeout
			_confusion_display_allies[target] = hit.after.duplicate(true)
			_confusion_display_shared_guard = int(hit.shared)
			_confusion_display_temporary_guard = int(hit.temporary)
			_refresh()
			if rect.has_area():
				_audio.contact(skill_code, "ally", int(hit.hp) + int(hit.guard) > 0, BATTLE_ART.module(FightSystem.allies[owner]), -int(card.uid) - 100)
				_show_damage_numbers(rect, "ally", int(hit.hp), int(hit.guard))
				if int(hit.hp) + int(hit.guard) > 0: _ally_hit_reaction(target, int(hit.hp) == 0)
			await Settings.battle_timer(HIT_INTERVAL).timeout
		while not bool(cue.finished): await get_tree().process_frame
		title.queue_free()
		_confusion_display_allies.clear()
		_card_motion.finish_confused(int(card.uid))
		_refresh()
	_confusion_busy = false
	_refresh()

func _cast_without_effects(serial: int) -> void:
	await get_tree().process_frame
	if serial != _presentation_serial or _player_cast_played or _player_skill_id == "ultimate" or FightSystem.resolving_action: return
	_start_player_cast([])

func _finish_attack_presentation(serial: int) -> void:
	while _active_player_casts > 0 or _player_effects_busy or not _pending_player_effects.is_empty() or Time.get_ticks_msec() < _impact_until or FightSystem.resolving_action:
		await get_tree().process_frame
		if serial != _presentation_serial: return
	_player_display_enemies.clear()
	_ultimate_audio_token = -1
	_refresh()

func _impact_feedback(side: String, index: int, hits: int = 1) -> void:
	var portrait: TextureRect = _enemy_portraits.get(index) if side == "enemy" else null
	if not is_instance_valid(portrait): return
	var previous: Tween = _impact_tweens.get(index)
	if previous != null and previous.is_valid(): previous.kill()
	var base_x := float(portrait.get_meta("rest_x", portrait.position.x))
	portrait.set_meta("rest_x", base_x)
	var material := portrait.material as ShaderMaterial
	if portrait.enemy_id == "terminal_echo":
		# The immovable finale body should not strobe white on multihit cards.
		material.set_shader_parameter("hit_flash", 0.0)
		portrait.position.x = base_x
		return
	material.set_shader_parameter("hit_flash", 0.35)
	portrait.position.x = base_x + minf(8, 4 + log(float(maxi(1, hits))))
	var kick := Settings.battle_tween(portrait)
	_impact_tweens[index] = kick
	# A 45 ms pose hold accents the impact without pausing input or the rule engine.
	kick.tween_property(portrait, "position:x", base_x - 2, 0.08).set_trans(Tween.TRANS_SINE)
	kick.parallel().tween_property(material, "shader_parameter/hit_flash", 0.0, 0.18)
	kick.tween_property(portrait, "position:x", base_x, 0.14).set_trans(Tween.TRANS_SINE)


func _on_story_event(event_id: String) -> void:
	_story_queue.append(event_id)
	call_deferred("_play_story_queue")

func _play_story_queue() -> void:
	if _story_busy or _story_queue.is_empty() or not is_inside_tree():
		return
	_story_busy = true
	if is_instance_valid(_spotlight):
		_spotlight.queue_free()
		_spotlight = null
	while not _story_queue.is_empty():
		while _banner_busy or not _turn_queue.is_empty() or _card_motion.busy():
			await get_tree().process_frame
			if not is_inside_tree():
				return
		var event_id: String = _story_queue.pop_front()
		var lines: Array = _story_dialogue.get(event_id, [])
		if event_id == "first_split" and lines.size() >= 5:
			await DialogueBox.play_script(lines.slice(0, 5))
			if not is_inside_tree(): return
			FightSystem.grant_story_reward("red_pen")
			await DialogueBox.play_script(lines.slice(5))
		elif event_id == "zhou_downed" and lines.size() >= 2:
			await DialogueBox.play_script(lines.slice(0, 2))
			if not is_inside_tree(): return
			FightSystem.grant_story_reward("hang_on")
			await DialogueBox.play_script(lines.slice(2))
		elif not lines.is_empty():
			await DialogueBox.play_script(lines)
		if not is_inside_tree(): return
	_story_busy = false
	FightSystem.finish_story_dialogue()
	if FightSystem.story_forced_skill != "" and FightSystem.battle_active:
		_spotlight = TUTORIAL_SPOTLIGHT.new()
		add_child(_spotlight)
		_spotlight.focus(_story_action_rect())
	if _pending_victory:
		_pending_victory = false
		_show_victory_after_last_hit.call_deferred()

func _story_action_rect() -> Rect2:
	if FightSystem.pending_card >= 0 and FightSystem.story_forced_skill == "hang_on":
		return _target_rects.get("ally_%d" % FightSystem._ally_index("zhoumingyuan"), Rect2())
	for i in FightSystem.hand.size():
		if String(FightSystem.hand[i].get("skill_id", "")) == FightSystem.story_forced_skill:
			return Rect2(42, 185 + i * 57, 420, 50)
	return Rect2()

func _show_effect(effect_id: String, side: String, index: int, source_side: String = "", source_index: int = -1) -> void:
	if not is_instance_valid(_vfx): return
	var rect: Rect2 = _target_rects.get(("enemy_" if side == "enemy" else "ally_") + str(index), Rect2())
	if rect.size == Vector2.ZERO: return
	var origin := rect.get_center()
	if source_index >= 0:
		var source_rect: Rect2 = _target_rects.get(("enemy_" if source_side == "enemy" else "ally_") + str(source_index), Rect2())
		if source_rect.size != Vector2.ZERO: origin = source_rect.get_center()
	var code := String(FightData.skill(effect_id).get("code", effect_id))
	var family := BATTLE_ART.family(code, side)
	if source_side == "enemy": family = "math" if effect_id == "enemy_bounce" else "magic" if effect_id == "不！许！睡！" else "slash"
	_vfx.play_effect(family, rect.get_center(), origin, effect_id.begins_with("ultimate_"), 1, code)

func _show_damage_numbers(rect: Rect2, side: String, hp_damage: int, guard_damage: int, attack_attribute: Dictionary = {}) -> void:
	if not is_instance_valid(_effect_layer) or rect.size == Vector2.ZERO:
		return
	var anchor := rect.get_center() + Vector2(0, -65 if side == "ally" else -95)
	var hit_color := Color("#ffe28b") if side == "enemy" else Color("#ff7d92")
	if not attack_attribute.is_empty():
		var relation := ATTRIBUTE_HINT.relation(String(attack_attribute.attribute), String(attack_attribute.target_attribute))
		if relation.kind != "neutral":
			hit_color = relation.color
			var notice := ATTRIBUTE_HINT.matchup(_effect_layer, [attack_attribute], Rect2(anchor+Vector2(-190, -94), Vector2(380, 44)))
			notice.name = "AttributeImpact_" + String(relation.kind)
			notice.z_index = 19
			var fade := Settings.battle_tween(notice).set_parallel(true)
			fade.tween_property(notice, "position:y", notice.position.y - 58, 0.95)
			fade.tween_property(notice, "modulate:a", 0.0, 0.3).set_delay(0.65)
			fade.chain().tween_callback(notice.queue_free)
	if hp_damage > 0:
		_spawn_damage_number("-%d" % hp_damage, anchor + Vector2(42 if guard_damage > 0 else 0, 0), hit_color, side, "hp", 60)
	if guard_damage > 0:
		_spawn_damage_number("护盾 -%d" % guard_damage, anchor + Vector2(-77 if hp_damage > 0 else 0, -38 if hp_damage > 0 else 0), Color("#83d8ff"), side, "guard", 36)

func _show_enemy_buff_feedback(action: Dictionary) -> void:
	var index := int(action.actor)
	if index < 0 or index >= action.enemies_after.size(): return
	var before: Dictionary = action.unit.get("statuses", {})
	var after: Dictionary = action.enemies_after[index].get("statuses", {})
	var anchor: Rect2 = _target_rects.get("enemy_%d" % index, Rect2())
	if not anchor.has_area(): return
	var guard_gain := int(action.enemies_after[index].get("guard", 0)) - int(action.unit.get("guard", 0))
	if guard_gain > 0:
		_spawn_damage_number("护盾 +%d" % guard_gain, anchor.get_center() + Vector2(0, -230), Color("83d8ff"), "enemy", "guard_gain", 36)
		_vfx.play_effect("barrier", anchor.get_center(), anchor.get_center(), false, 1, "enemy_guard")
	for id in after.keys():
		var status: Dictionary = after[id]
		var previous: Dictionary = before.get(id, {})
		var percent := roundi((float(status.get("damage_bonus", 0.0)) - float(previous.get("damage_bonus", 0.0))) * 100.0)
		var base := int(status.get("base_damage_bonus", 0)) - int(previous.get("base_damage_bonus", 0))
		if percent <= 0 and base <= 0: continue
		var words := "伤害 +%d%%" % percent if percent > 0 else "基础伤害 +%d" % base
		_spawn_damage_number(words, anchor.get_center() + Vector2(0, -175), Color("efb5f1"), "enemy", "damage_gain", 32)
		_vfx.play_effect("magic", anchor.get_center(), anchor.get_center(), false, 1, String(id))

func _show_status_feedback() -> void:
	_sync_painting_audio()
	var shown_allies: Array = _confusion_display_allies if not _confusion_display_allies.is_empty() else _enemy_display_allies if _enemy_damage_staged else FightSystem.get_allies()
	var shown_enemies: Array = _player_display_enemies if not _player_display_enemies.is_empty() else _enemy_display_enemies if _enemy_damage_staged else FightSystem.get_enemies()
	if _status_feedback_ready and not (is_instance_valid(_finale_ui) and _finale_ui.busy):
		for i in shown_allies.size():
			if i < _status_seen_allies.size(): _show_unit_status_gains(_status_seen_allies[i], shown_allies[i], "ally", i)
		for i in shown_enemies.size():
			if i < _status_seen_enemies.size(): _show_unit_status_gains(_status_seen_enemies[i], shown_enemies[i], "enemy", i)
	_status_seen_allies = shown_allies.duplicate(true)
	_status_seen_enemies = shown_enemies.duplicate(true)
	_status_feedback_ready = true

func _sync_painting_audio() -> void:
	var colors: Array = FightSystem.fc.painting
	if is_instance_valid(_audio) and not _audio_painting.is_empty() and not is_instance_valid(_painting_sequence):
		var changed: Dictionary = {}
		for i in mini(colors.size(), _audio_painting.size()):
			if colors[i] != _audio_painting[i]:
				changed["liu_wash" if colors[i] == "white" else "liu_ink" if colors[i] == "ink" else "liu_color"] = true
		for key in changed: _audio.play_sfx("sfx_" + String(key), 140)
		var painter := preload("res://scripts/fight/fc_painting.gd")
		var before: Dictionary = painter.groups(_audio_painting)
		var after: Dictionary = painter.groups(colors)
		for kind in ["ink", "tri"]:
			if after[kind].size() > before[kind].size(): _audio.play_sfx("sfx_liu_ink_group" if kind == "ink" else "sfx_liu_color_group", 200)
	_audio_painting = colors.duplicate()

func _show_unit_status_gains(before: Dictionary, after: Dictionary, side: String, index: int) -> void:
	var area: Rect2 = _target_rects.get("%s_%d" % [side, index], Rect2())
	if not area.has_area(): return
	var old: Dictionary = before.get("statuses", {})
	var current: Dictionary = after.get("statuses", {})
	if side == "ally" and is_instance_valid(_audio):
		var old_marks := int(old.get("latent_marks", {}).get("stacks", 0))
		var marks := int(current.get("latent_marks", {}).get("stacks", 0))
		if marks != old_marks: _audio.play_sfx("sfx_xu_mark_gain" if marks > old_marks else "sfx_xu_mark_consume", 180)
		if FightSystem.phase == FightSystem.PLAYER_TURN and FightSystem.resolving_action:
			for id in old:
				if bool(old[id].get("debuff", false)) and not current.has(id):
					_audio.play_sfx("sfx_alyina_cleanse", 180)
					break
	if side == "enemy" and is_instance_valid(_audio):
		var old_count := int(old.get("poison", {}).get("counter", 0))
		if int(current.get("poison", {}).get("counter", 0)) > old_count: _audio.play_sfx("sfx_su_poison_counter", 120)
	var shown := 0
	for id in current.keys():
		if side == "ally" and id == "isolation": continue # Dedicated gain cue and persistent curtain.
		var status: Dictionary = current[id]
		var previous: Dictionary = old.get(id, {})
		var added_layers: int = int(status.get("stacks", 0)) - int(previous.get("stacks", 0))
		var refreshed: bool = int(status.get("turns", -1)) > int(previous.get("turns", -1))
		if not previous.is_empty() and added_layers <= 0 and not refreshed: continue
		var name := String(status.get("name", id))
		var words := "%s +%d层" % [name, added_layers] if added_layers > 0 else name
		var debuff := bool(status.get("debuff", false))
		var center := area.get_center() + Vector2(0, -95 if side == "enemy" else -82)
		_spawn_damage_number(words, center + Vector2(0, -38 * shown), Color("ff9ca8") if debuff else Color("a8e7c9"), side, "debuff" if debuff else "buff", 30)
		shown += 1

func _spawn_damage_number(words: String, center: Vector2, color: Color, side: String, kind: String, font_size: int) -> void:
	if kind in ["hp", "guard"] and not bool(Settings.get_value("battle", "show_damage_number", true)): return
	var number := Label.new()
	number.name = "DamageNumber_%s_%s" % [side, kind]
	number.set_meta("damage_side", side)
	number.set_meta("damage_kind", kind)
	number.text = words
	number.size = Vector2(320 if kind in ["buff", "debuff"] else 230, 72)
	number.pivot_offset = number.size * 0.5
	number.position = center - number.pivot_offset
	number.scale = Vector2(0.70, 0.70)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.z_index = 18
	number.add_theme_font_size_override("font_size", font_size)
	number.add_theme_color_override("font_color", color)
	number.add_theme_color_override("font_outline_color", Color("#111827"))
	number.add_theme_constant_override("outline_size", 7)
	_effect_layer.add_child(number)
	var motion := Settings.battle_tween(number).set_parallel(true)
	motion.tween_property(number, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.tween_property(number, "position:y", number.position.y - 84.0, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(number, "modulate:a", 0.0, 0.48).set_delay(0.37)
	motion.chain().tween_callback(number.queue_free)

func _on_turn_started(side: String, turn_number: int) -> void:
	_buffered_action.clear()
	if side == FightSystem.ENEMY_TURN:
		_enemy_effect_queue.clear()
		_enemy_presentation_round = turn_number
		_enemy_display_enemies = FightSystem.get_enemies().duplicate(true)
		_enemy_display_dark_slots = FightSystem.dark_slots.duplicate()
		_enemy_damage_staged = true
		_enemy_display_allies.clear()
		for ally in FightSystem.allies:
			_enemy_display_allies.append((ally as Dictionary).duplicate(true))
		_enemy_display_shared_guard = FightSystem.shared_guard
		_enemy_display_temporary_guard = FightSystem.fc.temporary_guard
		_enemy_display_hand_limit = FightSystem.expansion_hand_limit
	elif _enemy_damage_staged:
		_capture_enemy_action_end()
	_clear_drag_visual()
	_turn_queue.append({"side": side, "round": turn_number})
	if not _banner_busy:
		call_deferred("_play_next_turn_banner")

func _play_next_turn_banner() -> void:
	if _banner_busy or _turn_queue.is_empty() or not is_inside_tree():
		return
	_banner_busy = true
	# Let the previous hand reach its piles before covering it with a turn ribbon.
	while _card_motion.outgoing_busy():
		await get_tree().process_frame
	var entry: Dictionary = _turn_queue.pop_front()
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.06, 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.z_index = 90
	_ui.add_child(shade)
	_place(shade, Rect2(Vector2.ZERO, SCREEN))
	var words := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
	var number := int(entry["round"])
	var round_text: String = String(words[number]) if number >= 0 and number < words.size() else str(number)
	var player_turn: bool = entry["side"] == FightSystem.PLAYER_TURN
	var accent := Color("#49caff") if player_turn else Color("#ff648c")
	var ribbon := _build_turn_ribbon(player_turn, round_text, number, accent)
	var enter := Settings.battle_tween(self)
	enter.tween_property(ribbon, "position:x", 0.0, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	enter.parallel().tween_property(shade, "color:a", 0.30, 0.25)
	await enter.finished
	var glint := _turn_polygon(ribbon, PackedVector2Array([Vector2(0, 76), Vector2(28, 75), Vector2(174, 238), Vector2(146, 239)]), Color(accent, 0.46))
	glint.position.x = -260.0
	var glint_tween := Settings.battle_tween(self)
	glint_tween.tween_property(glint, "position:x", 2100.0, 0.86).set_trans(Tween.TRANS_SINE)
	await Settings.battle_timer(0.82).timeout
	var leave := Settings.battle_tween(self)
	leave.tween_property(ribbon, "position:x", 2050.0, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	leave.parallel().tween_property(shade, "color:a", 0.0, 0.30)
	await leave.finished
	ribbon.queue_free()
	if entry["side"] == FightSystem.ENEMY_TURN:
		# Defeat has no following player-turn signal, so close the last action here too.
		if not _enemy_effect_queue.is_empty() and not _enemy_effect_queue[-1].has("allies_after"):
			_capture_enemy_action_end()
		if _enemy_effect_queue.is_empty() and not _anya_return_queue.is_empty():
			await _play_anya_return()
		var action_cursor := 0
		while action_cursor < _enemy_effect_queue.size():
			var action: Dictionary = _enemy_effect_queue[action_cursor]
			action_cursor += 1
			if not action.has("allies_after"): _capture_enemy_action_end()
			var portrait: TextureRect = _enemy_portraits.get(int(action.actor)) as TextureRect
			await _present_boss_rebirth(action, portrait)
			await _enemy_attack.play(portrait, action, _target_rects.duplicate(), _effect_layer, _apply_enemy_contacts.bind(action), _vfx)
			_enemy_display_allies.assign(action.allies_after.duplicate(true))
			_enemy_display_enemies = action.enemies_after.duplicate(true)
			_enemy_display_dark_slots = action.dark_slots_after.duplicate()
			_enemy_display_shared_guard = int(action.shared_guard_after)
			_enemy_display_temporary_guard = int(action.temporary_guard_after)
			_refresh()
			_show_enemy_buff_feedback(action)
			await _present_inserted_cards(action)
			if bool(action.get("anya_return", false)):
				await _play_anya_return()
		if not _enemy_effect_queue.is_empty():
			await Settings.battle_timer(0.18).timeout
		_enemy_effect_queue.clear()
		_enemy_damage_staged = false
		_enemy_display_allies.clear()
		_enemy_display_enemies.clear()
		_enemy_display_dark_slots.clear()
		for cost in _round_start_damage:
			var area: Rect2 = _target_rects.get("ally_%d" % int(cost.index), Rect2())
			_show_damage_numbers(area, "ally", int(cost.hp), 0)
			_vfx.play_effect("poison", area.get_center(), area.get_center(), false, 1, "poison_backlash", 0.0)
		_round_start_damage.clear()
	shade.queue_free()
	if player_turn and not _turn_guard_gains.is_empty():
		_refresh()
		for gain in _turn_guard_gains:
			var area: Rect2 = _target_rects.get("ally_%d" % int(gain.index), Rect2())
			if area.size == Vector2.ZERO: continue
			_vfx.play_effect("barrier", area.get_center(), area.get_center(), false, 1, "C04", 0.0)
			_spawn_damage_number("护盾 +%d" % int(gain.amount), area.get_center()+Vector2(0, -65), Color("83d8ff"), "ally", "guard_gain", 36)
		_turn_guard_gains.clear()
		await Settings.battle_timer(0.65).timeout
	_banner_busy = false
	if player_turn:
		FightSystem.finish_player_turn_intro(number)
	if not _turn_queue.is_empty():
		call_deferred("_play_next_turn_banner")
	else:
		_refresh()
		call_deferred("_play_story_queue")

func _build_turn_ribbon(player_turn: bool, round_text: String, number: int, accent: Color) -> Control:
	var ribbon := Control.new()
	ribbon.name = "TurnChangeRibbon"
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.clip_contents = true
	ribbon.z_index = 91
	_ui.add_child(ribbon)
	_place(ribbon, Rect2(Vector2(-2050, 390), Vector2(1920, 300)))
	_turn_polygon(ribbon, PackedVector2Array([Vector2(0, 86), Vector2(1920, 32), Vector2(1920, 242), Vector2(0, 296)]), Color(accent, 0.10))
	_turn_polygon(ribbon, PackedVector2Array([Vector2(0, 100), Vector2(1920, 46), Vector2(1920, 222), Vector2(0, 276)]), Color("#07111f") if player_turn else Color("#1f0b18"))
	_turn_polygon(ribbon, PackedVector2Array([Vector2(0, 116), Vector2(1920, 62), Vector2(1920, 206), Vector2(0, 260)]), Color(0.07, 0.21, 0.34, 0.87) if player_turn else Color(0.30, 0.08, 0.19, 0.87))
	_turn_polygon(ribbon, PackedVector2Array([Vector2(0, 98), Vector2(1920, 44), Vector2(1920, 50), Vector2(0, 104)]), Color(accent, 0.78))
	_turn_polygon(ribbon, PackedVector2Array([Vector2(0, 260), Vector2(1920, 206), Vector2(1920, 211), Vector2(0, 265)]), Color(accent, 0.65))
	for i in 5:
		var left := 165.0 + i * 75.0
		_turn_polygon(ribbon, PackedVector2Array([Vector2(left, 111), Vector2(left + 18, 110), Vector2(left + 118, 248), Vector2(left + 100, 249)]), Color(accent, 0.13 + float(i) * 0.035))
		var right := 1460.0 + i * 75.0
		_turn_polygon(ribbon, PackedVector2Array([Vector2(right, 70), Vector2(right + 18, 69), Vector2(right + 118, 207), Vector2(right + 100, 208)]), Color(accent, 0.20))
	_turn_text(ribbon, "TURN CHANGE", Rect2(0, 94, 1920, 112), 94, Color(accent, 0.14))
	_turn_text(ribbon, "TURN %02d  /  %s" % [number, "YOUR TURN" if player_turn else "ENEMY TURN"], Rect2(0, 103, 1920, 34), 21, Color(accent, 0.92))
	var heading := "%s回合 · 回合%s" % ["我方" if player_turn else "敌方", round_text]
	_turn_text(ribbon, heading, Rect2(3, 136, 1920, 90), 63, Color(accent, 0.35))
	_turn_text(ribbon, heading, Rect2(0, 132, 1920, 90), 63, Color("#f6fbff"))
	return ribbon

func _turn_polygon(parent: Node, points: PackedVector2Array, color: Color) -> Polygon2D:
	var shape := Polygon2D.new()
	shape.polygon = points
	shape.color = color
	parent.add_child(shape)
	return shape

func _turn_text(parent: Control, words: String, rect: Rect2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = words
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	_place(label, rect)

func _open_read_only_characters() -> void:
	_open_archive("characters")

func _build_action_points() -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)
	_place(holder, Rect2(372, 17, 184, 66))
	_energy_skin = _chrome(holder, "energy", Rect2(Vector2.ZERO, holder.size), Color("d5ba84"), true)
	_energy_caption = FC_VISUALS.text(holder, "能量", Rect2(60, 8, 120, 22), 14, CHROME.BRASS)
	_header_ap = FC_VISUALS.text(holder, "%d / %d" % [FightSystem.action_points, FightSystem.action_point_limit()], Rect2(68, 27, 108, 32), 27, CHROME.INK)
	_anya_rebirth = preload("res://scripts/ui/anya_rebirth_meter.gd").new()
	holder.add_child(_anya_rebirth)
	_anya_rebirth.hide()

func _display_hand_limit() -> int:
	return _enemy_display_hand_limit if _enemy_damage_staged else FightSystem.expansion_hand_limit

func _draw_hand_limit() -> void:
	var limit := _display_hand_limit()
	var constrained := limit < FightSystem.HAND_LIMIT
	var tint := Color("edbc85") if constrained else Color("a4b5c8")
	var pane := FC_VISUALS.panel(_ui, Rect2(42, 74, 318, 26), Color("17222e"), Color(tint, 0.55), 5)
	pane.name = "HandLimitHUD"
	FC_VISUALS.glyph(pane, "sealed" if constrained else "retain", Rect2(7, 3, 20, 20), tint)
	var label := FC_VISUALS.text(pane, "手牌上限 %d 张%s" % [limit, " · 空间受限" if constrained else ""], Rect2(34, 0, 276, 26), 18, tint)
	label.name = "CurrentHandLimit"
	_dynamic.append(pane)

func _draw_resource(title: String, key: String, pos: Vector2, color: Color) -> void:
	var value := FightSystem.get_draw_count() if key == "deck" else FightSystem.get_discard_count() if key == "discard" else FightSystem.hand.size()
	var button := _compact_button("%s %d" % [title, value], Rect2(pos, Vector2(96, 38)), func() -> void: _toggle_pile_popup(key) if key != "hand" else _show_fc_pile("hand"), color)
	button.name = "Pile_" + key
	button.tooltip_text = "当前手牌上限 %d 张，超出时进入弃牌堆 · 点击查看" % _display_hand_limit() if key == "hand" else title + " · 点击查看"
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if key == "hand": _show_fc_pile("hand")
			else: _toggle_pile_popup(key)
			button.accept_event()
	)
	_dynamic.append(button)

func _toggle_pile_popup(key: String) -> void:
	if key in ["deck", "discard"]: _open_archive(key)

func _draw_statuses(unit: Dictionary, pos: Vector2, ally: bool, available_width: float = 270) -> void:
	var statuses: Array = FightData.statuses(unit)
	if not ally: statuses = statuses.filter(func(status: Dictionary) -> bool: return not ENEMY_RULE.has(String(status.get("icon", ""))))
	# Taunt changes who will be attacked; never bury it behind the overflow button.
	for i in statuses.size():
		if String(statuses[i].get("icon", "")) == "taunt":
			var taunt: Dictionary = statuses.pop_at(i)
			statuses.push_front(taunt)
			break
	var step := 36.0
	var slots := maxi(1, int((available_width + 4.0) / step))
	var visible_count := mini(statuses.size(), slots - 1) if statuses.size() > slots else statuses.size()
	for i in visible_count:
		var status: Dictionary = statuses[i]
		var status_for_icon := status.duplicate(true)
		var icon_pos := pos + Vector2(i * step, 0)
		var is_dead := String(status.get("icon", "")) == "dead"
		var icon := _button("", icon_pos, Vector2(32, 32), _show_status_list.bind(statuses, String(unit.get("name", ""))), Color("#252830") if is_dead else Color("#ba87bd") if status.get("debuff", false) else Color("#76cbbd"), 15)
		icon.set_meta("status_chip", true)
		icon.set_meta("status_key", String(status.get("icon", "")))
		icon.set_meta("unit_id", String(unit.get("id", "")))
		if ally: _paper_status_button(icon, Color("b77d92") if status.get("debuff", false) else Color("76a698"))
		var status_texture := _status_icon_texture(status)
		if status_texture != null:
			# Button.icon 在当前主题下会被内容边距压缩成空白按钮；用真实子节点
			# 保证 buff/debuff 图片按 26x26 绘制，同时保留按钮的悬停和点击区域。
			var image := TextureRect.new()
			image.texture = status_texture
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.add_child(image)
			_place(image, Rect2(Vector2(3, 3), Vector2(26, 26)))
		icon.z_index = 30 if ally else 25
		icon.modulate = Color(0.35, 0.35, 0.4, 1) if is_dead else Color.WHITE
		# The custom detail card is the sole hover surface, including long hovers.
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		var count := int(status.get("stacks", 0))
		if count <= 0: count = int(status.get("turns", 0))
		if count > 0 or status.has("badge_text"):
			var badge_text := String(status.get("badge_text", "99+" if count > 99 else str(count)))
			var counter := FC_VISUALS.text(icon, badge_text, Rect2(5 if status.has("badge_text") else 10, 17, 27 if status.has("badge_text") else 22, 14), 10 if count > 99 or status.has("badge_text") else 11, Color("fff1c7"), true)
			counter.add_theme_constant_override("outline_size", 4)
			counter.add_theme_color_override("font_outline_color", Color("08121d"))
		icon.mouse_entered.connect(func() -> void: _show_status_popup(status_for_icon, icon_pos + Vector2(0, 34)))
		icon.mouse_exited.connect(_hide_status_popup)
		_dynamic.append(icon)
	if statuses.size() > visible_count:
		var remaining := statuses.size() - visible_count
		var more := _button("", pos + Vector2(visible_count * step, 0), Vector2(32, 32), _show_status_list.bind(statuses, String(unit.get("name", ""))), Color("d7bc8c"), 12)
		FC_VISUALS.text(more, "更多", Rect2(0, 0, 32, 32), 12, CHROME.INK if ally else BATTLE_THEME.ON_STAGE, true)
		more.name = "StatusOverflow_%s_%s" % ["ally" if ally else "enemy", str(int(pos.x))]
		if ally: _paper_status_button(more, CHROME.BRASS)
		more.set_meta("hidden_count", remaining)
		more.tooltip_text = "还有 %d 项状态 · 点击查看全部" % remaining
		more.z_index = 30 if ally else 25
		_dynamic.append(more)

func _show_status_list(statuses: Array, unit_name: String) -> void:
	if is_instance_valid(_status_list): _status_list.queue_free()
	_hide_status_popup()
	_status_list = preload("res://scripts/ui/battle_status_list.gd").new()
	_status_list.statuses = statuses.duplicate(true)
	_status_list.title = unit_name + " · 全部状态"
	_ui.add_child(_status_list)

func _draw_intent(intent: Dictionary, pos: Vector2, index: int) -> void:
	# Show the effective next action without overwriting the enemy's AI plan.
	if FightSystem.enemies[index].statuses.has("stun"):
		intent = {"name":"眩晕", "kind":"stun", "damage":0, "desc":"眩晕中，跳过下一次行动；每次跳过行动消耗1回合眩晕。"}
	var kind := String(intent.get("kind", "single"))
	var damage := int(intent.get("damage", 0))
	var absent := String(intent.get("effect", "")) == "report_absent"
	var harmful := not absent and not String(intent.get("status", "")).is_empty()
	var tint := Color("ff8d83") if damage > 0 else Color("cc9dff") if harmful or kind == "split" else Color("a6bed6")
	var glyph := "stun" if kind == "stun" else "attack" if damage > 0 else "split" if kind == "split" else "debuff" if harmful else "wait"
	var button := _button("", pos, Vector2(148, 88), func() -> void:
		if index == 0 and _waiting_tutorial_intent: call_deferred("_continue_after_intent")
	, tint, 20)
	button.name = "EnemyIntent_%d" % index
	button.set_meta("intent_kind", kind)
	button.get_node("SurfaceArt").hide()
	button.z_index = 25
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", FC_VISUALS.style(Color(tint, 0.08), Color(tint, 0.35), 1, 20))
	button.add_theme_stylebox_override("pressed", FC_VISUALS.style(Color(tint, 0.15), tint, 1, 20))
	_intent_rects[index] = Rect2(pos, button.size)
	FC_VISUALS.glyph(button, glyph, Rect2(45, 0, 60,60), tint)
	if damage > 0:
		var damage_text := _intent_damage_text(intent)
		var value := FC_VISUALS.text(button, damage_text, Rect2(0, 53, 148, 34), 26 if damage_text.length() > 7 else 30, Color("fff2e4"), true)
		value.name = "IntentDamage"
		value.add_theme_color_override("font_outline_color", Color("34121e"))
		value.add_theme_constant_override("outline_size", 8)
		FC_VISUALS.glyph(button, "all" if kind == "all" else "bounce" if kind == "bounce" else "target", Rect2(10, 17, 30,30), tint)
		if harmful: FC_VISUALS.glyph(button, "debuff", Rect2(109, 17, 30, 30), Color("cc9dff"))
	elif kind == "stun":
		FC_VISUALS.text(button, "眩晕 · 跳过行动", Rect2(-16, 54, 180, 30), 21, tint, true)
	elif kind == "split":
		FC_VISUALS.text(button, "×2", Rect2(0, 54, 148, 30), 25, tint, true)
	elif absent:
		var state := FC_VISUALS.text(button, "无实体", Rect2(0, 54, 148, 30), 23, tint, true)
		state.name = "IntentState"
	var description := "分裂为两只小型敌人，本回合不造成攻击伤害。" if kind == "split" else "施加负面状态，本回合不造成攻击伤害。" if damage == 0 and harmful else "本回合不攻击。" if damage == 0 else "攻击全体队友。" if kind == "all" else "随机弹射3次；连续命中同一人时，该段基础伤害减半。" if kind == "bounce" else "优先攻击嘲讽目标，否则随机攻击一名队友。"
	if harmful: description += "\n附加：" + ("睡眠不佳" if intent.status == "sleep_bad" else "虚弱")
	if intent.has("desc"): description = String(intent.desc)
	if String(FightSystem.enemies[index].id) == "cupid": description += "\nlove达到100：1回合迷魂；抽到自己的攻击牌自动伤害队友。"
	if damage > 0: description += "\n\n基础伤害：" + _intent_damage_text(intent) + "\n" + _intent_damage_detail(intent, index)
	var detail := {"name":"敌人意图：" + String(intent.get("name", "等待")), "desc":description}
	# Use one custom popup; a native tooltip would cover it after a longer hover.
	button.mouse_entered.connect(func() -> void: _show_intent_popup(detail, Rect2(pos, button.size), tint))
	button.mouse_exited.connect(_hide_status_popup)
	_dynamic.append(button)

func _intent_damage_text(intent: Dictionary) -> String:
	var hits := int(intent.get("hits", 3 if String(intent.get("kind", "")) == "bounce" else 1))
	var number := str(int(intent.get("damage", 0)))
	return number + "×%d" % hits if hits > 1 else number

func _intent_damage_detail(intent: Dictionary, index: int) -> String:
	var targets: Array = []
	var kind := String(intent.get("kind", "single"))
	var effect := String(intent.get("effect", ""))
	var taunt_target: int = FightSystem._taunt_target()
	if kind in ["all", "bounce"] or (taunt_target < 0 and effect not in ["sentence", "zeus_admonition", "lowest_hp", "mind_read", "shell_game", "pressure"]):
		for unit in FightSystem.allies:
			if FightSystem._enemy_targetable(unit): targets.append(unit)
	else:
		var target: int = taunt_target
		if effect == "sentence":
			target = FightSystem.ENEMY_RULES.sentence_target(FightSystem, FightSystem.enemies[index])
		elif effect == "zeus_admonition":
			target = -1
			var highest := 0
			for candidate in FightSystem.ENEMY_RULES.targets(FightSystem):
				var count: int = int(FightSystem.enemies[index].get("last_attacker_counts", {}).get(String(FightSystem.allies[candidate].id), 0))
				if count > highest:
					highest = count
					target = candidate
			if target < 0:
				target = taunt_target
				if target < 0:
					for unit in FightSystem.allies:
						if FightSystem._enemy_targetable(unit): targets.append(unit)
		elif effect in ["lowest_hp", "mind_read", "shell_game"]:
			target = FightSystem.ENEMY_RULES.EXPANSION.lowest_target(FightSystem)
		elif effect == "pressure":
			target = FightSystem.ENEMY_RULES.CHALLENGES.mirror_owner(FightSystem, FightSystem.enemies[index])
			if target < 0:
				target = taunt_target
				if target < 0:
					for unit in FightSystem.allies:
						if FightSystem._enemy_targetable(unit): targets.append(unit)
		if target >= 0: targets.append(FightSystem.allies[target])
	var lines: PackedStringArray = ["预计承伤（每段命中时，护盾抵扣前）："]
	for unit in targets:
		# Player-side timed buffs tick before the enemy actually attacks.
		var next_state: Dictionary = unit.duplicate(true)
		FightSystem._tick_statuses(next_state)
		var amount := FightSystem.fc.damage_amount(FightSystem.enemies[index], next_state, float(intent.get("damage", 0)), false)
		lines.append("%s：%d" % [String(unit.get("name", "")), amount])
	if targets.is_empty(): lines.append("暂无可攻击目标")
	if kind == "bounce": lines.append("弹射连续命中同一人时，该段按基础伤害减半重新计算。")
	lines.append("按当前属性与状态预估；后续状态变化会影响承伤。")
	return "\n".join(lines)

func _ultimate_card(index: int, x: float) -> Control:
	var holder := Control.new()
	_ui.add_child(holder)
	_place(holder, Rect2(Vector2(x + _ally_width() - 87, ALLY_Y + 39), Vector2(80, 116)))
	var hero_id := String(FightSystem.allies[index].get("id", ""))
	var ultimate := FightSystem.get_ultimate(index)
	var automatic := bool(ultimate.get("locked", false))
	var ready := FightSystem.can_ultimate(index) and (FightSystem.tutorial_step < 0 or FightSystem.tutorial_step >= 4)
	var selected := FightSystem.pending_ultimate == index
	var crest := _chrome(holder, "ultimate", Rect2(0, 0, 80, 86), Color("bca9dc"), ready)
	crest.amount = clampf(float(FightSystem.allies[index].get("ult", 0)) / maxi(1, FightSystem.ultimate_max(index)), 0, 1)
	# Keep the dedicated skill icon; CG artwork belongs only to the release cut-in.
	var ultimate_art := TextureRect.new()
	var ultimate_path := String(ultimate.get("icon", ""))
	ultimate_art.texture = load(ultimate_path) as Texture2D if not ultimate_path.is_empty() and ResourceLoader.exists(ultimate_path) else null
	ultimate_art.name = "UltimateSkillIcon_%d" % index
	if ultimate_art.texture == null:
		ultimate_art.texture = _icon_texture("ultimate")
	ultimate_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ultimate_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ultimate_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ultimate_art.modulate = Color("#fff2a8") if selected else Color.WHITE if ready else Color(0.78, 0.8, 0.88, 1)
	ultimate_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ultimate_art)
	_place(ultimate_art, Rect2(Vector2(12, 12), Vector2(56, 56)))
	var button := _button_in(holder, "", Vector2(0, 0), Vector2(80, 80), func() -> void:
		if _mobile_inspect: _show_ultimate_popup(index, x)
		else: _request_ultimate(index), Color("#805aa2"), 28)
	button.name = "UltimateButton_%d" % index
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.flat = true
	button.get_node("SurfaceArt").hide()
	for state in ["normal", "hover", "pressed", "focus"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.disabled = false
	button.mouse_entered.connect(func() -> void: _hovered_ultimate = index)
	button.mouse_exited.connect(func() -> void:
		if _hovered_ultimate == index: _hovered_ultimate = -1
	)
	button.tooltip_text = ("左键选择后点击敌人；右键查看效果" if String(ultimate.get("target", "enemy")) == "enemy" else "左键立即释放；右键查看效果") if ready else "终结技能量未满；右键查看效果"
	if automatic: button.tooltip_text = "锁定 · 退场时自动释放；右键查看回场规则"
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT and (event as InputEventMouseButton).pressed:
			_show_ultimate_popup(index, x)
			get_viewport().set_input_as_handled()
	)
	var charge_label := _label_in(holder, "%d / %d" % [int(FightSystem.allies[index].get("ult", 0)), FightSystem.ultimate_max(index)], Vector2(0, 88), Vector2(80, 24), 15, CHROME.BRASS if selected or ready else CHROME.INK, HORIZONTAL_ALIGNMENT_CENTER)
	charge_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if automatic:
		charge_label.text = "锁定 · 自动"
		ultimate_art.modulate = Color(0.82, 0.73, 0.6, 1)
	charge_label.clip_text = true
	_place(charge_label, Rect2(Vector2(0, 88), Vector2(80, 24)))
	return holder

func _show_skill_popup(index: int) -> void:
	if index < 0 or index >= FightSystem.hand.size():
		return
	if is_instance_valid(_skill_popup):
		_skill_popup.queue_free()
	_skill_popup = PanelContainer.new()
	_skill_popup.z_index = 45
	_skill_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_skill_popup.add_theme_stylebox_override("panel", UiKit.panel_style(BATTLE_THEME.INK, BATTLE_THEME.LINE, 1, 8))
	_ui.add_child(_skill_popup)
	_place(_skill_popup, Rect2(Vector2(485, 190), Vector2(440, 260)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_skill_popup.add_child(box)
	var card_data: Dictionary = FightSystem.hand[index]
	var def := FightData.skill(String(card_data.get("skill_id", "")))
	var title := Label.new()
	title.text = "%s · %s　%s %d" % [def.get("name", "技能"), FightData.RARITIES[def.get("rarity", "common")].name, "重生计数" if String(card_data.skill_id).begins_with("LP") else "能量", FightSystem.card_cost(card_data)]
	title.add_theme_font_override("font", DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", BATTLE_THEME.TEXT)
	box.add_child(title)
	var body := Label.new()
	body.text = "%s\n\n属性：%s\n目标：%s\n\n点击目标或拖动箭头释放。" % [FightData.description(String(card_data.skill_id), FightData.card_level(card_data)) + "\n" + FightSystem.card_keywords(card_data), FightData.attr_name(String(def.get("attribute", FightData.ATTR_NONE))), FightData.target_name(String(def.get("target", "enemy")))]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 19)
	body.add_theme_color_override("font_color", BATTLE_THEME.TEXT)
	box.add_child(body)

func _show_ultimate_popup(index: int, x: float) -> void:
	if index < 0 or index >= FightSystem.allies.size():
		return
	_hide_skill_popup()
	var hero_id := String(FightSystem.allies[index].get("id", ""))
	var ultimate := FightSystem.get_ultimate(index)
	_skill_popup = PanelContainer.new()
	_skill_popup.z_index = 80
	_skill_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_skill_popup.add_theme_stylebox_override("panel", UiKit.panel_style(BATTLE_THEME.INK, BATTLE_THEME.LINE, 1, 8))
	_ui.add_child(_skill_popup)
	_place(_skill_popup, Rect2(Vector2(minf(x + 36, 1550), 655), Vector2(320, 170)))
	if hero_id == "li_anya": _place(_skill_popup, Rect2(minf(x + 36, 1260), 420, 620, 390))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_skill_popup.add_child(box)
	var title := Label.new()
	title.text = "%s　%s" % [ultimate.get("name", "终结技"), "锁定 · 自动" if ultimate.get("locked", false) else "已充能" if FightSystem.can_ultimate(index) else "未充能"]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", BATTLE_THEME.TEXT)
	box.add_child(title)
	var body := Label.new()
	var target_name := FightData.target_name(String(ultimate.get("target", "enemy")))
	body.text = "%s\n%s\n目标：%s" % [ultimate.get("desc", "终结技"), "退场时自动释放，不能主动点击" if ultimate.get("locked", false) else "%s：%d" % ["涅槃充能" if hero_id == "li_anya" else "能量", FightSystem.ultimate_max(index)], target_name]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", BATTLE_THEME.TEXT)
	box.add_child(body)

func _hide_skill_popup() -> void:
	if is_instance_valid(_skill_popup):
		_skill_popup.queue_free()
		_skill_popup = null

func _show_intent_popup(detail: Dictionary, anchor: Rect2, tint: Color) -> void:
	_show_battle_detail(detail, anchor, tint)

func _show_battle_detail(detail: Dictionary, anchor: Rect2, tint: Color, is_status: bool = false) -> void:
	_hide_status_popup()
	_status_popup = PanelContainer.new()
	_status_popup.name = "StatusDescription" if is_status else "IntentDescription"
	# Keep layout active, but do not expose its temporary size/position for one frame.
	if is_status: _status_popup.modulate.a = 0.0
	_status_popup.set_meta("above_anchor", anchor if is_status and anchor.position.y > SCREEN.y * 0.6 else Rect2())
	_status_popup.custom_minimum_size.x = 350
	_status_popup.z_index = 55
	_status_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := BATTLE_THEME.frame(BATTLE_THEME.INK, BATTLE_THEME.LINE, 1, 8)
	style.shadow_color = Color(0.015, 0.02, 0.04, 0.65)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 19
	_status_popup.add_theme_stylebox_override("panel", style)
	_ui.add_child(_status_popup)
	var popup_x := anchor.end.x + 16
	if popup_x + 350 > SCREEN.x - 16: popup_x = anchor.position.x - 366
	_place(_status_popup, Rect2(popup_x, anchor.position.y, 350, 0))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 9)
	_status_popup.add_child(column)
	var caption := Label.new()
	caption.text = ("负 面 状 态" if detail.get("debuff", false) else "增 益 状 态") if is_status else "敌 人 意 图"
	if is_status and String(detail.get("icon", "")) in ["dead", "downed"]: caption.text = "角 色 状 态"
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", BATTLE_THEME.quiet(tint))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption)
	var title := Label.new()
	title.name = "StatusTitle" if is_status else "IntentTitle"
	title.text = String(detail.name).trim_prefix("敌人意图：")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", BATTLE_THEME.TEXT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var rule := HSeparator.new()
	var rule_style := StyleBoxLine.new()
	rule_style.color = Color(tint, 0.28)
	rule_style.thickness = 1
	rule.add_theme_stylebox_override("separator", rule_style)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	var body := Label.new()
	body.name = "StatusDescriptionText" if is_status else "IntentDescriptionText"
	body.text = String(detail.desc)
	body.custom_minimum_size.x = 310
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_constant_override("line_spacing", 5)
	body.add_theme_color_override("font_color", BATTLE_THEME.TEXT)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)
	if is_status:
		var facts: Array[String] = []
		if int(detail.get("stacks", 0)) > 0: facts.append("%d 层" % int(detail.stacks))
		if detail.has("turns"): facts.append("无回合限制" if int(detail.turns) < 0 else "剩余 %d 回合" % int(detail.turns))
		if not facts.is_empty():
			var footer := Label.new()
			footer.text = " · ".join(facts)
			footer.add_theme_font_size_override("font_size", 15)
			footer.add_theme_color_override("font_color", BATTLE_THEME.quiet(tint))
			footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.add_child(footer)
	_fit_intent_popup.call_deferred(_status_popup)

func _fit_intent_popup(popup: Control) -> void:
	# Containers first measure wrapped text at its final width. Shrink only after
	# that pass, otherwise the temporary narrow layout leaves a large blank tail.
	await get_tree().process_frame
	if not is_instance_valid(popup): return
	popup.size = Vector2(350, 0)
	var above: Rect2 = popup.get_meta("above_anchor", Rect2())
	if above.has_area():
		popup.position = Vector2(above.position.x - 20, above.position.y - popup.size.y - 14)
	_fit_status_popup(popup)
	popup.modulate.a = 1.0

func _show_status_popup(status: Dictionary, pos: Vector2) -> void:
	var detail := status.duplicate(true)
	# The status-list description contains duration already; the hover card has a footer.
	if detail.has("turns"):
		var duration := "无回合限制" if int(detail.turns) < 0 else "剩余 %d 回合" % int(detail.turns)
		var stacks := " · %d 层" % int(detail.stacks) if int(detail.get("stacks", 0)) > 1 else ""
		detail.desc = String(detail.get("desc", "")).trim_suffix(" " + duration + stacks)
	_show_battle_detail(detail, Rect2(pos - Vector2(0, 34), Vector2(32, 32)), Color("d4a5cc") if status.get("debuff", false) else Color("9acfc4"), true)

func _fit_status_popup(popup: Control) -> void:
	if not is_instance_valid(popup): return
	# Bottom-row status details grow upward once their wrapped text is measured.
	popup.position.x = clampf(popup.position.x, 12, maxf(12, SCREEN.x - popup.size.x - 12))
	popup.position.y = clampf(popup.position.y, 12, maxf(12, SCREEN.y - popup.size.y - 12))
	if is_instance_valid(_finale_ui):
		var instruments := Rect2(_finale_ui.meters.position, Vector2(1342, 88))
		if Rect2(popup.position, popup.size).intersects(instruments):
			popup.position.y = maxf(12, instruments.position.y - popup.size.y - 12)

func _hide_status_popup() -> void:
	if is_instance_valid(_status_popup):
		if _status_popup.get_parent() != null: _status_popup.get_parent().remove_child(_status_popup)
		_status_popup.queue_free()
	_status_popup = null

func _icon_texture(icon_name: String) -> Texture2D:
	return load(ICON_DIR + icon_name + ".webp") as Texture2D


func _status_icon_texture(status: Dictionary) -> Texture2D:
	return BATTLE_ART.status_icon(String(status.get("icon", "")), bool(status.get("debuff", false)), String(status.get("art_key", "")))

func _toggle_log_popup() -> void:
	_open_archive("log")

func _target_label(target: String) -> String:
	match target:
		"enemy": return "敌人"
		"ally": return "队友"
		"party": return "全队"
		"self": return "自身"
	return target

func _on_end_turn() -> void:
	if _turn_interaction_locked(): return
	_commands.end_turn()
func _on_message(_text: String) -> void: _refresh()
func _on_won(_reward: Dictionary) -> void:
	if _story_busy or not _story_queue.is_empty():
		_pending_victory = true
	else:
		_show_victory_after_last_hit.call_deferred()

func _show_victory_after_last_hit() -> void:
	if _victory_sequence_started: return
	_victory_sequence_started = true
	# Let the final attack reach the target and its damage number become readable.
	while _enemy_damage_staged or _banner_busy or not _turn_queue.is_empty() or _turn_interaction_locked():
		await get_tree().process_frame
		if not is_inside_tree(): return
	if is_instance_valid(_finale_ui):
		await _finale_ui.play_victory_dissolve()
	else:
		await Settings.battle_timer(0.95).timeout
	if is_inside_tree():
		_show_result(true)
func _on_lost() -> void:
	_show_defeat_after_last_hit.call_deferred()

func _show_defeat_after_last_hit() -> void:
	if _defeat_sequence_started: return
	_defeat_sequence_started = true
	while _enemy_damage_staged or _turn_interaction_locked():
		await get_tree().process_frame
		if not is_inside_tree(): return
	_show_result(false)

func _show_result(won: bool) -> void:
	while not _ally_exits.is_empty():
		await get_tree().process_frame
		if not is_inside_tree(): return
	if is_instance_valid(_result_panel): return
	_clear_drag_visual()
	if is_instance_valid(_damage_preview): _damage_preview.clear()
	Music.clear_override()
	Music.play("battle_victory" if won else "battle_defeat", 0.35, true)
	_result_panel = preload("res://scripts/ui/battle_result.gd").new()
	if won and is_instance_valid(_finale_ui): _result_panel.victory_message = "你们守住了希望。"
	_ui.add_child(_result_panel)
	_result_panel.continued.connect(_leave_battle)
	_result_panel.configure(won, FightSystem.last_reward, FightSystem.allies, FightSystem.round, not FightSystem.return_location.is_empty())
	_relayout()

func _leave_battle() -> void:
	if TowerRun.active:
		if _turn_interaction_locked(): return
		if FightSystem.last_reward.get("wave_clear", false) and TowerRun.has_next_wave():
			if TowerRun.continue_wave(false):
				await SceneRouter.go_to("fight")
				return
			TowerRun.settle(false, true)
		FightSystem.abandon_encounter()
		TowerRun.finish_lesson_session()
		FightSystem.return_location = ""
		await SceneRouter.go_to("tower")
		return
	if _turn_interaction_locked(): return
	FightSystem.abandon_encounter()
	if FightSystem.return_location != "":
		var destination := FightSystem.return_location
		FightSystem.return_location = ""
		await SceneRouter.go_to(destination, "default", true)
	else:
		await GameFlow.back_to_title(GameState.slot > 0)

func _alive(unit: Dictionary) -> bool: return FightSystem._is_alive(unit)
func _progress_bar(pos: Vector2, size: Vector2, value: int, maximum: int, color: Color, text: String = "", downed: bool = false, paper_style: bool = false, poison: int = 0) -> Control:
	var holder := Control.new()
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)
	_place(holder, Rect2(pos, size))
	var back := Panel.new()
	var back_style := BATTLE_THEME.frame(BATTLE_THEME.RECESSED, Color(color, 0.45), 1, int(size.y * 0.5))
	back_style.shadow_size = 0
	back.add_theme_stylebox_override("panel", back_style)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(back)
	_place(back, Rect2(Vector2.ZERO, size))
	var fill := Panel.new()
	fill.name = "Fill"
	var fill_style := BATTLE_THEME.frame(color, Color(color, 0.5), 0, int(size.y * 0.5))
	fill_style.shadow_size = 0
	fill.add_theme_stylebox_override("panel", fill_style)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fill)
	var ratio: float = clampf(float(value) / float(maxi(1, maximum)), 0.0, 1.0)
	if downed and ratio <= 0.0:
		ratio = 0.12
	_place(fill, Rect2(Vector2.ZERO, Vector2(size.x * ratio, size.y)))
	fill.visible = ratio > 0
	BATTLE_THEME.decorate(fill, color)
	# Show poison layers against max HP from the left edge of the displayed HP.
	# This is the poison amount; shields still resolve separately on detonation.
	var poison_ratio := minf(ratio, float(maxi(0, poison)) / float(maxi(1, maximum)))
	if poison_ratio > 0:
		var poison_mask := Control.new()
		poison_mask.name = "PoisonSegment"
		poison_mask.clip_contents = true
		poison_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(poison_mask)
		_place(poison_mask, Rect2(0, 0, size.x * poison_ratio, size.y))
		var poison_fill := Panel.new()
		var poison_color := Color("4ead6d")
		var poison_style := BATTLE_THEME.frame(poison_color, poison_color, 0, int(size.y * 0.5))
		poison_style.shadow_size = 0
		poison_fill.add_theme_stylebox_override("panel", poison_style)
		poison_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		poison_mask.add_child(poison_fill)
		# Clip a full capsule, preserving the HP edge even for a subpixel poison span.
		_place(poison_fill, Rect2(0, 0, size.x * ratio, size.y))
		BATTLE_THEME.decorate(poison_fill, poison_color)
	if text != "":
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", BATTLE_THEME.TEXT)
		label.add_theme_constant_override("outline_size", 1 if poison_ratio > 0 else 0)
		label.add_theme_color_override("font_outline_color", Color(color.darkened(0.7), 0.8))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(label)
		_place(label, Rect2(Vector2.ZERO, size))
	return holder

func _paper_status_button(button: Button, accent: Color) -> void:
	button.get_node("SurfaceArt").hide()
	for state in ["normal", "hover", "pressed", "focus"]:
		var frame := BATTLE_THEME.frame(CHROME.PAPER if state == "normal" else CHROME.SELECTED, Color(accent, 0.65), 1, 7)
		frame.shadow_size = 2
		if state == "focus": frame.draw_center = false
		button.add_theme_stylebox_override(state, frame)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]: button.add_theme_color_override(state, CHROME.INK)
	button.add_theme_constant_override("outline_size", 0)

func _rect(pos: Vector2, size: Vector2, color: Color, border: Color = Color.TRANSPARENT, width: int = 0) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(color, border, maxi(1, width), 14))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(panel)
	_place(panel, Rect2(pos, size))
	return panel
func _rect_in(parent: Node, pos: Vector2, size: Vector2, color: Color, border: Color = Color.TRANSPARENT, width: int = 0) -> ColorRect:
	var r := ColorRect.new(); r.color = color; r.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(r); _place(r, Rect2(pos,size)); return r
func _label(text: String, pos: Vector2, size: Vector2, font: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return _label_in(_ui, text, pos, size, font, color, align)
func _label_in(parent: Node, text: String, pos: Vector2, size: Vector2, font: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	# Establish the wrapping width before text calculates its minimum height.
	_place(label, Rect2(pos, size))
	label.text = text
	return label
func _button(text: String, pos: Vector2, size: Vector2, handler: Callable, accent: Color, font: int) -> Button:
	return _button_in(_ui,text,pos,size,handler,accent,font)
func _button_in(parent: Node, text: String, pos: Vector2, size: Vector2, handler: Callable, accent: Color, font: int) -> Button:
	var b := Button.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_OFF
	BATTLE_THEME.button(b, accent)
	b.add_theme_font_size_override("font_size", font)
	b.pressed.connect(handler)
	parent.add_child(b)
	_place(b, Rect2(pos, size))
	return b
func _place(node: Control, rect: Rect2) -> void:
	node.position=rect.position; node.size=rect.size
func _relayout() -> void:
	if _ui == null: return
	if preload("res://scripts/ui/tower_mobile.gd").enabled():
		_ui.size = SCREEN
		preload("res://scripts/ui/tower_mobile.gd").fit(_ui, get_viewport())
		if _result_panel != null: _result_panel.size = SCREEN
		return
	var vp := get_viewport_rect().size
	_ui.size=vp
	var s: float = minf(vp.x / SCREEN.x, vp.y / SCREEN.y)
	_ui.scale = Vector2(s,s)
	_ui.position = (vp - SCREEN*s) * 0.5
	if _result_panel != null: _result_panel.size=SCREEN

func _toggle_items() -> void:
	if FightSystem.can_use_items(): _open_archive("items")

func _hide_calculation() -> void:
	if is_instance_valid(_calculation_popup):
		_calculation_popup.hide()
		_calculation_popup.queue_free()
	_calculation_popup = null

func _toggle_calculation() -> void:
	var owner: int = FightSystem._ally_index("zhoumingyuan")
	if not FightSystem.fc.is_math(owner) or _turn_interaction_locked(): return
	if is_instance_valid(_calculation_popup):
		_hide_calculation()
		return
	var x := clampf(_math_portrait_rect.position.x, 24, 1296)
	_calculation_popup = FC_VISUALS.panel(_ui, Rect2(x, 240, 600, 500), BATTLE_THEME.INK, BATTLE_THEME.LINE, 6)
	var pane := _calculation_popup
	pane.name = "CalculationQueue"
	pane.z_index = 85
	pane.mouse_filter = Control.MOUSE_FILTER_STOP
	FC_VISUALS.text(pane, "演算区", Rect2(24, 16, 350, 42), 28, FC_VISUALS.GOLD)
	FC_VISUALS.text(pane, "%d 张" % FightSystem.fc.calculation.size(), Rect2(484, 20, 80, 34), 21, FC_VISUALS.MUTED)
	var locked := "无"
	if FightSystem.fc.locked_alive(): locked = "%d号 · %s" % [FightSystem.fc.locked_enemy + 1, FightSystem.enemies[FightSystem.fc.locked_enemy].name]
	FC_VISUALS.text(pane, "锁定  %s" % locked, Rect2(24, 66, 552, 32), 21)
	FC_VISUALS.text(pane, "追击  %d 次        魔术计数  %d / 3" % [FightSystem.fc.pursuit_count, FightSystem.fc.magic_count], Rect2(24, 105, 552, 32), 21, BATTLE_THEME.MUTED)
	FC_VISUALS.text(pane, "从上到下释放 · 右键卡牌查看详情", Rect2(24, 150, 552, 30), 18, FC_VISUALS.MUTED)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 194)
	scroll.size = Vector2(552, 242)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pane.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	if FightSystem.fc.calculation.is_empty(): FC_VISUALS.text(rows, "等待装入演算牌", Rect2(0, 0, 530, 52), 21, FC_VISUALS.MUTED, true)
	for i in FightSystem.fc.calculation.size():
		var card: Dictionary = FightSystem.fc.calculation[i]
		var row := Button.new()
		row.name = "Calculation_%d" % int(card.uid)
		row.set_meta("card_uid", int(card.uid))
		row.set_meta("release_order", i + 1)
		row.custom_minimum_size = Vector2(524, 60)
		row.add_theme_stylebox_override("normal", FC_VISUALS.style(BATTLE_THEME.SURFACE, Color(BATTLE_THEME.GOLD if i == 0 else BATTLE_THEME.LINE, 0.5), 1, 5))
		row.add_theme_stylebox_override("hover", FC_VISUALS.style(BATTLE_THEME.HOVER, BATTLE_THEME.GOLD, 1, 5))
		rows.add_child(row)
		FC_VISUALS.text(row, str(i + 1), Rect2(8, 11, 30, 36), 23, FC_VISUALS.GOLD, true)
		FC_VISUALS.icon(row, FightData.skill_icon(String(card.skill_id)), Rect2(46, 8, 44, 44))
		FC_VISUALS.text(row, FC_VISUALS.card_title(card), Rect2(107, 3, 300, 29), 21, BATTLE_THEME.TEXT)
		var effect := "追加技能" if card.get("counterfeit", false) else "回复1能量" if card.get("lemma", false) else "追击弹药"
		FC_VISUALS.text(row, ("下一张 · " if i == 0 else "") + effect, Rect2(107, 32, 300, 23), 16, FC_VISUALS.MUTED)
		row.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				_show_fc_card_detail(card)
				row.accept_event()
		)
	var close := _button_in(pane, "关闭", Vector2(434, 448), Vector2(142, 38), _hide_calculation, Color("95d0df"), 18)
	close.name = "CloseCalculation"
	FC_VISUALS.text(pane, "点击空白处或按 Esc 关闭", Rect2(24, 450, 390, 34), 17, FC_VISUALS.MUTED)

func _show_fc_card_detail(card: Dictionary) -> void:
	if is_instance_valid(_fc_card_detail): _fc_card_detail.queue_free()
	_fc_card_detail = FC_VISUALS.detail(_ui, card)

func _show_fc_pile(key: String) -> void:
	_open_archive(key)

func _open_archive(key: String) -> void:
	if _commands.pending(): return
	if key != "settings" and _turn_interaction_locked(): return
	if is_instance_valid(_archive):
		if _archive.page == key: _archive.close()
		else: _archive.show_page(key)
		return
	_hide_skill_popup()
	_hide_status_popup()
	_hide_calculation()
	_clear_drag_visual()
	_archive = ARCHIVE.new()
	_archive.initial_page = key
	_archive.closed.connect(_clear_archive_references)
	_archive.page_changed.connect(_archive_page_changed)
	_archive.item_requested.connect(_commands.request_item)
	_ui.add_child(_archive)

func _archive_page_changed(key: String) -> void:
	_battle_settings = _archive.find_child("ArchiveSettings", true, false) as SettingsPanel if key == "settings" else null
	_pile_popup = _archive if key in ["deck", "discard", "hand", "exhausted", "calculation"] else null
	_pile_popup_key = key if is_instance_valid(_pile_popup) else ""
	_log_popup = _archive if key == "log" else null
	_item_popup = _archive if key == "items" else null

func _clear_archive_references() -> void:
	Settings.save_settings()
	_battle_settings = null
	_archive = null
	_pile_popup = null
	_log_popup = null
	_item_popup = null
	_pile_popup_key = ""


func _sync_anya_background() -> void:
	if FightSystem.fc.ANYA.phoenix(FightSystem.fc):
		if _arena_id != "anya_phoenix":
			_anya_saved_arena = _arena_id
			set_background("anya_phoenix", true)
	elif _arena_id == "anya_phoenix":
		set_background(_anya_saved_arena, true)

func _on_anya_form_changed(_kind: String) -> void:
	_sync_anya_background()

func _queue_anya_return(kind: String, resolve: Callable, complete: Callable) -> void:
	_anya_return_queue.append({"kind":kind, "resolve":resolve, "complete":complete, "before":FightSystem.allies.duplicate(true)})
	if _enemy_damage_staged:
		_capture_enemy_action_end()
		if not _enemy_effect_queue.is_empty(): _enemy_effect_queue[-1]["anya_return"] = true

func _present_anya_entry(owner: int, resolve: Callable) -> void:
	var serial := FightSystem.encounter_serial
	var before := FightSystem.allies.duplicate(true)
	_refresh()
	await _show_anya_resolution("downed", before, owner)
	if not FightSystem.battle_active or serial != FightSystem.encounter_serial: return
	_present_anya_transition("enter", func() -> void:
		if not FightSystem.battle_active or serial != FightSystem.encounter_serial: return
		resolve.call()
		_show_anya_resolution("enter", before, owner)
	)

func _show_anya_resolution(kind: String, before: Array, owner: int) -> void:
	if not Settings.ultimate_presentation_enabled(): return
	var effect := preload("res://scripts/ui/anya_resolution_fx.gd").new()
	effect.kind = kind
	effect.actor_index = owner
	effect.before = before
	effect.after = FightSystem.allies.duplicate(true)
	effect.regions = _target_rects.duplicate()
	_anya_resolution_fx = effect
	_ui.add_child(effect)
	await effect.finished
	if _anya_resolution_fx == effect: _anya_resolution_fx = null

func _play_anya_return() -> void:
	if _anya_return_queue.is_empty(): return
	var pending: Dictionary = _anya_return_queue.pop_front()
	_anya_active_return = pending
	var ticket := {"finished":false}
	_present_anya_transition(String(pending.kind), func() -> void:
		pending.resolve.call()
		if _enemy_damage_staged:
			_enemy_display_allies.assign(FightSystem.allies.duplicate(true))
			_enemy_display_shared_guard = FightSystem.shared_guard
			_enemy_display_temporary_guard = FightSystem.fc.temporary_guard
		_refresh()
		ticket.finished = true
	)
	while not ticket.finished: await get_tree().process_frame
	await _show_anya_resolution(String(pending.kind), pending.before, FightSystem.fc.ANYA.owner(FightSystem.fc))
	pending.complete.call()
	_anya_active_return = {}

func _try_anya_return() -> void:
	if _anya_return_queue.is_empty() or is_instance_valid(_ultimate_cutin): return
	if is_instance_valid(_anya_resolution_fx): return
	if _enemy_damage_staged or _banner_busy or _player_effects_busy or _active_player_casts > 0 or not _pending_player_effects.is_empty() or not _turn_queue.is_empty(): return
	_play_anya_return()

func _present_anya_transition(kind: String, resolve: Callable) -> void:
	if not Settings.ultimate_presentation_enabled():
		resolve.call()
		_refresh()
		return
	_ultimate_cutin = preload("res://scripts/ui/anya_transition.gd").new()
	_ultimate_cutin.kind = kind
	_ultimate_cutin.finished.connect(func() -> void:
		_ultimate_cutin = null
		resolve.call()
		_refresh()
	, CONNECT_ONE_SHOT)
	_ui.add_child(_ultimate_cutin)
	_refresh()
