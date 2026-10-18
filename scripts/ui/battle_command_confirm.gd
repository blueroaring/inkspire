extends Node
## Confirmation belongs to player input; simulations and automatic rule effects stay direct.
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const THEME := preload("res://scripts/ui/battle_theme.gd")
var battle: Node
var dialog: Control
var _action: Dictionary = {}

func pending() -> bool:
	return is_instance_valid(dialog)

func enabled() -> bool:
	return bool(Settings.get_value("battle", "confirm_commands", false))

## Control picking follows tree order rather than z_index. Battle rebuilds target boxes,
## status chips and rule buttons after this modal, so keep the modal last in the canvas;
## otherwise those invisible controls eat clicks that belong to 取消 / 确认执行.
func raise_modal() -> void:
	if not pending(): return
	var parent := dialog.get_parent()
	if parent != null:
		parent.move_child(dialog, parent.get_child_count() - 1)

func request_card(index: int) -> bool:
	if pending() or not FightSystem.can_play(index): return false
	if not enabled() or FightSystem.card_target_type(index) in ["enemy", "ally"]:
		return FightSystem.request_card(index)
	_offer({"kind":"card", "identity":int(FightSystem.hand[index].uid)})
	return true

func request_ultimate(index: int) -> bool:
	if pending() or not FightSystem.can_ultimate(index): return false
	if FightSystem.tutorial_step >= 0 and FightSystem.tutorial_step < 4: return false
	if FightSystem.tutorial_step == 4 and not FightSystem._tutorial_opening_state.is_empty(): return false
	if not enabled() or FightSystem.get_ultimate(index).get("target", "enemy") == "enemy":
		return FightSystem.request_ultimate(index)
	_offer({"kind":"ultimate", "identity":index, "owner":FightSystem.allies[index]})
	return true

func request_item(id: String) -> void:
	if pending() or battle._turn_interaction_locked() or not FightSystem.item_error(id, -1, false).is_empty(): return
	if not enabled() or FightEquipmentData.CONSUMABLES[id].target in ["ally", "enemy"]:
		FightSystem.request_item(id)
	else:
		_offer({"kind":"item", "identity":id})

func select_target(side: String, index: int) -> void:
	if pending() or not FightSystem.valid_target(side, index): return
	if not enabled():
		if side == "enemy": FightSystem.select_enemy(index)
		else: FightSystem.select_ally(index)
		return
	var action: Dictionary
	if not FightSystem.pending_item.is_empty():
		if not FightSystem.item_error(FightSystem.pending_item, index).is_empty(): return
		action = {"kind":"item", "identity":FightSystem.pending_item}
	elif FightSystem.pending_ultimate >= 0:
		var owner := FightSystem.pending_ultimate
		action = {"kind":"ultimate", "identity":owner, "owner":FightSystem.allies[owner]}
	else:
		if not FightSystem.can_play(FightSystem.pending_card): return
		action = {"kind":"card", "identity":int(FightSystem.hand[FightSystem.pending_card].uid)}
	var units: Array = FightSystem.enemies if side == "enemy" else FightSystem.allies
	action.merge({"side":side, "target":index, "target_unit":units[index]})
	_offer(action)

func end_turn() -> void:
	if pending() or not FightSystem.battle_active or FightSystem.phase != FightSystem.PLAYER_TURN: return
	if not enabled():
		battle._audio.play_sfx("sfx_turn_end", 220)
		FightSystem.end_player_turn()
	else:
		_offer({"kind":"end_turn"})

func _card_index(identity: int) -> int:
	for i in FightSystem.hand.size():
		if int(FightSystem.hand[i].uid) == identity: return i
	return -1

func _offer(action: Dictionary) -> void:
	_action = action
	_action.merge({"round":FightSystem.round, "encounter":FightSystem.encounter_serial})
	battle._buffered_action.clear()
	battle._clear_drag_visual()
	var title := "结束回合"
	var detail := "结束我方回合，进入敌方行动。"
	var cost := "剩余能量：%d" % FightSystem.action_points
	var target := ""
	match String(action.kind):
		"card":
			var card: Dictionary = FightSystem.hand[_card_index(int(action.identity))]
			var def := FightData.skill(String(card.skill_id))
			title = "释放技能 · " + V.card_title(card)
			detail = "施术者：" + String(FightSystem.allies[FightSystem.caster_index(card)].name)
			cost = "消耗 %d 能量" % FightSystem.card_cost(card)
			target = FightData.target_name(String(def.get("target", "enemy")))
		"ultimate":
			var def := FightSystem.get_ultimate(int(action.identity))
			title = "释放终结技 · " + String(def.get("name", "终结技"))
			detail = "施术者：" + String(action.owner.name)
			cost = "消耗 %d 终结技能量" % FightSystem.ultimate_max(int(action.identity))
			target = FightData.target_name(String(def.get("target", "self")))
		"item":
			var def: Dictionary = FightEquipmentData.CONSUMABLES[action.identity]
			title = "使用道具 · " + String(def.name)
			detail = String(def.desc)
			cost = "消耗 1 个道具 · 占用本回合道具次数"
			target = FightData.target_name(String(def.target))
	if action.has("target"):
		target = "%s %d · %s" % ["敌人" if action.side == "enemy" else "队友", int(action.target) + 1, action.target_unit.name]
	dialog = Control.new()
	dialog.name = "BattleCommandConfirmation"
	dialog.size = Vector2(1920, 1080)
	# Above the hand, HUD and status list: the confirmation is the only live surface.
	dialog.z_index = 115
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	battle._ui.add_child(dialog)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.04, 0.065, 0.65)
	shade.size = dialog.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.add_child(shade)
	var pane := V.panel(dialog, Rect2(540, 320, 840, 440), THEME.INK, THEME.GOLD, 8)
	V.text(pane, "指令确认", Rect2(36, 20, 768, 30), 20, THEME.GOLD)
	V.text(pane, title, Rect2(36, 66, 768, 52), 32)
	var description := V.text(pane, detail, Rect2(36, 130, 768, 82), 22)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not target.is_empty(): V.text(pane, "目标：" + target, Rect2(36, 218, 768, 38), 24)
	V.text(pane, cost, Rect2(36, 268, 768, 32), 21, THEME.MUTED)
	V.text(pane, "Enter 确认执行    ·    Esc 取消", Rect2(36, 300, 768, 26), 17, THEME.MUTED)
	_button(pane, "取消", Rect2(36, 330, 360, 72), cancel, "CancelCommand")
	_button(pane, "确认执行", Rect2(444, 330, 360, 72), accept, "ConfirmCommand")
	battle._refresh()

func _button(parent: Control, words: String, rect: Rect2, callback: Callable, node_name: String) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = words
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 24)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", THEME.TEXT)
	button.add_theme_color_override("font_hover_color", THEME.TEXT)
	button.add_theme_color_override("font_pressed_color", THEME.TEXT)
	button.add_theme_stylebox_override("pressed", V.style(THEME.SELECTED, THEME.GOLD, 2, 5))
	button.add_theme_stylebox_override("normal", V.style(THEME.SURFACE, THEME.LINE, 1, 5))
	button.add_theme_stylebox_override("hover", V.style(THEME.HOVER, THEME.GOLD, 2, 5))
	button.pressed.connect(callback)
	parent.add_child(button)

func _close() -> void:
	if pending():
		dialog.hide()
		dialog.queue_free()
	dialog = null
	_action = {}

func cancel() -> void:
	_close()
	FightSystem.cancel_targeting()
	battle._refresh()

func accept() -> void:
	if not pending(): return
	var action := _action
	print("DEBUG accept start action=", action)
	_close() # Consume the ticket before any signals or a second click can re-enter.
	if not FightSystem.battle_active or FightSystem.phase != FightSystem.PLAYER_TURN or int(action.encounter) != FightSystem.encounter_serial or int(action.round) != FightSystem.round:
		print("DEBUG accept bail state")
		FightSystem.cancel_targeting()
		return
	if battle._turn_interaction_locked():
		print("DEBUG accept bail locked: impact=", Time.get_ticks_msec() < int(battle._impact_until), " motion=", battle._card_motion.busy(), " casts=", battle._active_player_casts, " fx=", (battle._player_effects_busy as Variant), " banner=", (battle._banner_busy as Variant), " queue=", (battle._turn_queue as Array).size(), " resolving=", FightSystem.resolving_action, " item_motion=", is_instance_valid(battle._item_motion), " interrupt=", (battle._enemy_interrupt_busy as Variant), " anya_queue=", (battle._anya_return_queue as Array).size(), " ally_exits=", (battle._ally_exits as Dictionary).size())
		FightSystem.cancel_targeting()
		return
	if action.has("target"):
		var units: Array = FightSystem.enemies if action.side == "enemy" else FightSystem.allies
		if int(action.target) >= units.size() or not is_same(units[int(action.target)], action.target_unit):
			print("DEBUG accept bail target")
			FightSystem.cancel_targeting()
			return
	var accepted := false
	match String(action.kind):
		"card": accepted = FightSystem.request_card(_card_index(int(action.identity)))
		"ultimate":
			var owner := int(action.identity)
			if owner < FightSystem.allies.size() and is_same(FightSystem.allies[owner], action.owner):
				accepted = FightSystem.request_ultimate(owner)
		"item": accepted = FightSystem.request_item(String(action.identity))
		"end_turn":
			battle._audio.play_sfx("sfx_turn_end", 220)
			FightSystem.end_player_turn()
			accepted = true
	if accepted and action.has("target"):
		if action.side == "enemy": accepted = FightSystem.select_enemy(int(action.target))
		else: accepted = FightSystem.select_ally(int(action.target))
	print("DEBUG accept accepted=", accepted)
	if not accepted: FightSystem.cancel_targeting()
	battle._refresh()
