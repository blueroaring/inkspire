extends Control
## Card identity and flight state survive the battle HUD's frequent rebuilds.
signal settled
var card_size := Vector2(420, 50)
const PILE_SCALE := Vector2(0.18, 0.46)
const DRAW_TIME := 0.42
const DISCARD_TIME := 0.38
const DRAW_DISCARD_HOLD := 0.70
const BURN_REVEAL_TIME := 0.20
const BURN_HOLD_TIME := 0.35
const BURN_SWEEP_TIME := 0.80
const BURN_COLLECT_TIME := 0.30
const BURN_TIME := BURN_REVEAL_TIME + BURN_HOLD_TIME + BURN_SWEEP_TIME + BURN_COLLECT_TIME
const STAGGER := 0.065
var make_ticket: Callable
var hold_draws := true
var played := 0
var _known: Dictionary = {}
var _views: Dictionary = {}
var _flights: Dictionary = {}
var _pulses: Array[Dictionary] = []
var _confused_uids: Dictionary = {}
var _burn_reasons: Dictionary = {}

func mark_burn(uid: int, reason: String) -> void:
	_burn_reasons[uid] = reason

func mark_confused(uid: int) -> void:
	_confused_uids[uid] = true

func finish_confused(uid: int) -> void:
	_confused_uids.erase(uid)

func _ready() -> void:
	if preload("res://scripts/ui/tower_mobile.gd").enabled(): card_size.y = 144
	name = "BattleCardMotion"
	z_index = 68
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1920, 1080)
	# Battles opened with an already-dealt hand still show the opening deal.
	_known = _locations()
	for uid: int in _known:
		if _known[uid].zone == "hand": _known[uid].zone = "deck"

func busy() -> bool:
	return not _flights.is_empty()

func outgoing_busy() -> bool:
	for flight: Dictionary in _flights.values():
		if flight.get("draw_discard", false) and not flight.get("audio_started", false): continue
		if flight.zone not in ["hand", "resolving"]: return true
	return false

func _locations() -> Dictionary:
	var result: Dictionary = {}
	var piles := {"deck":FightSystem.draw_pile, "discard":FightSystem.discard_pile,
		"exhausted":FightSystem.fc.exhausted, "calculation":FightSystem.fc.calculation, "hand":FightSystem.hand}
	for zone: String in piles:
		for i in piles[zone].size():
			var card: Dictionary = piles[zone][i]
			result[int(card.uid)] = {"zone":zone, "index":i, "card":card.duplicate(true)}
	return result

func sync_hand(cards: Array, views: Array[Control]) -> void:
	_views.clear()
	for i in cards.size(): _views[int(cards[i].uid)] = views[i]
	observe_piles()

func observe_piles() -> void:
	var current := _locations()
	var draw_index := 0
	var discard_index := 0
	var reveal_index := 0
	for uid: int in current:
		var dest: Dictionary = current[uid]
		if _confused_uids.has(uid): continue
		var source: Dictionary = _known.get(uid, {"zone":"deck", "index":0, "card":dest.card})
		if source.zone == dest.zone and (dest.zone != "hand" or source.index == dest.index): continue
		if source.zone not in ["hand", "resolving"] and dest.zone not in ["hand", "exhausted"] and not (source.zone == "deck" and dest.zone == "discard"): continue
		var delay := 0.0
		if dest.zone == "hand" and source.zone != "hand":
			delay = draw_index * STAGGER
			draw_index += 1
		elif source.zone == "deck" and dest.zone == "discard":
			delay = reveal_index * (DRAW_TIME + DRAW_DISCARD_HOLD + DISCARD_TIME)
			reveal_index += 1
		elif dest.zone != "hand":
			delay = discard_index * STAGGER
			discard_index += 1
		_start(uid, source, dest, delay)
	for uid: int in _known:
		if current.has(uid) or _known[uid].zone not in ["hand", "resolving"]: continue
		var source: Dictionary = _known[uid]
		# A choice may temporarily keep the played card in the rules' resolving area.
		var zone := "resolving" if FightSystem.resolving_action else "removed"
		var dest := {"zone":zone, "index":source.index, "card":source.card}
		if source.zone != zone: _start(uid, source, dest, discard_index * STAGGER)
		if zone == "resolving": current[uid] = dest
	_known = current
	for uid: int in _flights:
		if _views.has(uid): _views[uid].hide()

func _anchor(location: Dictionary) -> Vector2:
	if preload("res://scripts/ui/tower_mobile.gd").enabled() and location.zone in ["hand", "resolving"]:
		var uid := int(location.get("card", {}).get("uid", -1))
		if _views.has(uid) and is_instance_valid(_views[uid]):
			var view: Control = _views[uid]
			var point := get_global_transform_with_canvas().affine_inverse() * (view.get_global_transform_with_canvas() * (view.size * 0.5))
			return Vector2(point.x, clampf(point.y, 240, 700))
		return Vector2(252, clampf(262 + int(location.index) * 162, 240, 700))
	match String(location.zone):
		"hand": return Vector2(252, 210 + int(location.index) * 57)
		"resolving": return Vector2(292, 210 + int(location.index) * 57)
		"discard": return Vector2(196, 49)
		"exhausted", "removed": return Vector2(624, 49)
		"calculation": return Vector2(780, 835)
	return Vector2(90, 49)

func _scale_for(zone: String) -> Vector2:
	return Vector2.ONE if zone == "hand" else Vector2(0.94, 0.94) if zone == "resolving" else PILE_SCALE

func _start(uid: int, source: Dictionary, dest: Dictionary, delay: float) -> void:
	# Let rejected draws finish their readable hand stop before later cards fill it.
	if source.zone == "deck" and dest.zone in ["hand", "discard"]:
		for pending: Dictionary in _flights.values():
			if pending.get("draw_discard", false): delay = maxf(delay, float(pending.duration) - float(pending.age))
	if _flights.has(uid) and _flights[uid].zone not in ["hand", "resolving"] and dest.zone == "hand":
		# A reshuffle can return the departing physical card in the same rules tick.
		# Finish its outgoing leg before showing its incoming leg.
		_flights[uid]["next"] = dest
		_flights[uid]["next_source"] = source
		return
	if _flights.has(uid) and _flights[uid].zone == "hand" and _flights[uid].from_zone != "hand" and dest.zone != "hand":
		# A synchronous draw-and-discard must finish revealing its incoming card first.
		_flights[uid]["next"] = dest
		_flights[uid]["next_source"] = source
		_flights[uid]["hold_after_draw"] = DRAW_DISCARD_HOLD
		return
	var ghost: Control
	var start := _anchor(source)
	var start_scale := _scale_for(source.zone)
	var start_rotation := -0.16 if source.zone == "deck" else 0.0
	if _flights.has(uid):
		ghost = _flights[uid].ghost
		start = ghost.position + card_size * 0.5
		start_scale = ghost.scale
		start_rotation = ghost.rotation
	else:
		ghost = make_ticket.call(dest.card)
		if ghost.get_parent() != null: ghost.get_parent().remove_child(ghost)
		ghost.name = "CardFlight_%d" % uid
		ghost.pivot_offset = card_size * 0.5
		_ignore_input(ghost)
		add_child(ghost)
	ghost.show()
	ghost.modulate = Color.WHITE
	var shifting: bool = source.zone == "hand" and dest.zone == "hand"
	var draw_discard: bool = source.zone == "deck" and dest.zone == "discard"
	var burning: bool = dest.zone == "exhausted" and source.zone != "exhausted"
	var burn_overlay: Control
	if burning:
		burn_overlay = preload("res://scripts/ui/battle_card_burn.gd").new()
		burn_overlay.reason = String(_burn_reasons.get(uid, "消耗"))
		ghost.add_child(burn_overlay)
	_burn_reasons.erase(uid)
	_flights[uid] = {"ghost":ghost, "zone":dest.zone, "from_zone":source.zone,
		"start":start, "end":_anchor(dest), "start_scale":start_scale, "end_scale":_scale_for(dest.zone),
		"rotation":start_rotation, "age":-delay, "duration":DRAW_TIME + DRAW_DISCARD_HOLD + DISCARD_TIME if draw_discard else BURN_TIME if burning else 0.22 if shifting else DRAW_TIME if dest.zone == "hand" else DISCARD_TIME,
		"shifting":shifting, "burn_overlay":burn_overlay, "draw_discard":draw_discard,
		"reveal_at":_anchor({"zone":"hand", "index":FightSystem.hand.size()})}
	ghost.position = start - card_size * 0.5
	ghost.scale = start_scale
	ghost.rotation = start_rotation
	# Queued draws wait invisibly for the turn ribbon to leave.
	if dest.zone == "hand" and source.zone != "hand" or draw_discard: ghost.hide()
	played += 1

func _ignore_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
		node.tooltip_text = ""
	for child in node.get_children(): _ignore_input(child)

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	var was_busy := busy()
	for uid in _flights.keys():
		var flight: Dictionary = _flights[uid]
		var drawing: bool = flight.zone == "hand" and flight.from_zone != "hand" or flight.draw_discard
		if drawing and hold_draws and not flight.get("audio_started", false): continue
		flight.age += delta
		if float(flight.age) < 0: continue
		if not flight.get("audio_started", false):
			flight["audio_started"] = true
			if flight.shifting:
				preload("res://scripts/ui/battle_generated_audio.gd").sfx(get_parent(), "card_shift", 220)
			elif drawing:
				preload("res://scripts/ui/battle_generated_audio.gd").sfx(get_parent(), "card_draw", 220)
			elif flight.from_zone in ["hand", "resolving"] and flight.zone == "discard":
				preload("res://scripts/ui/battle_generated_audio.gd").sfx(get_parent(), "card_play", 220)
		var ghost := flight.ghost as Control
		ghost.show()
		var t := clampf(float(flight.age) / float(flight.duration), 0, 1)
		if flight.draw_discard:
			_animate_draw_discard(flight, ghost)
		elif is_instance_valid(flight.burn_overlay):
			_animate_burn(flight, ghost)
		else:
			var eased := 1.0 - pow(1.0 - t, 3) if flight.zone == "hand" else t * t * (3.0 - 2.0 * t)
			var arc := Vector2(48 if drawing else 62, -18) * sin(t * PI) if not flight.shifting else Vector2.ZERO
			ghost.position = (flight.start as Vector2).lerp(flight.end, eased) + arc - card_size * 0.5
			ghost.scale = (flight.start_scale as Vector2).lerp(flight.end_scale, eased)
			ghost.rotation = lerpf(float(flight.rotation), 0.0 if flight.zone == "hand" else 0.15, eased) + sin(t * PI) * (-0.08 if drawing else 0.10)
			ghost.modulate.a = 1.0 if flight.zone == "hand" else 1.0 - smoothstep(0.72, 1.0, t) * (0.35 if flight.zone == "resolving" else 1.0)
		if t < 1.0 or flight.zone == "resolving": continue
		if float(flight.age) < float(flight.duration) + float(flight.get("hold_after_draw", 0.0)): continue
		if not flight.has("next") and _views.has(uid) and is_instance_valid(_views[uid]): _views[uid].show()
		if not flight.shifting: _pulses.append({"point":flight.end, "age":0.0, "draw":flight.zone == "hand", "burn":is_instance_valid(flight.burn_overlay)})
		ghost.queue_free()
		_flights.erase(uid)
		if flight.has("next"):
			_start(uid, flight.next_source, flight.next, 0.04)
	for pulse in _pulses: pulse.age += delta
	_pulses = _pulses.filter(func(p: Dictionary) -> bool: return p.age < 0.30)
	queue_redraw()
	if was_busy and not busy(): settled.emit()

func _animate_draw_discard(flight: Dictionary, ghost: Control) -> void:
	var elapsed := float(flight.age)
	var incoming := 1.0 - pow(1.0 - clampf(elapsed / DRAW_TIME, 0.0, 1.0), 3)
	var outgoing := smoothstep(DRAW_TIME + DRAW_DISCARD_HOLD, float(flight.duration), elapsed)
	var at := (flight.start as Vector2).lerp(flight.reveal_at, incoming).lerp(flight.end, outgoing)
	ghost.position = at - card_size * 0.5
	ghost.scale = (flight.start_scale as Vector2).lerp(Vector2.ONE, incoming).lerp(flight.end_scale, outgoing)
	ghost.rotation = lerpf(float(flight.rotation), 0.0, incoming) + outgoing * 0.15
	ghost.modulate.a = 1.0 - outgoing
	if elapsed >= DRAW_TIME + DRAW_DISCARD_HOLD and not flight.get("discard_audio_started", false):
		flight.discard_audio_started = true
		preload("res://scripts/ui/battle_generated_audio.gd").sfx(get_parent(), "card_play", 220)

func _animate_burn(flight: Dictionary, ghost: Control) -> void:
	var elapsed := float(flight.age)
	var reveal := smoothstep(0.0, BURN_REVEAL_TIME, elapsed)
	var sweep_start := BURN_REVEAL_TIME + BURN_HOLD_TIME
	if elapsed >= sweep_start and not flight.get("burn_sound_started", false):
		flight["burn_sound_started"] = true
		preload("res://scripts/ui/battle_generated_audio.gd").sfx(get_parent(), "card_burn", 220)
	var collect_start := sweep_start + BURN_SWEEP_TIME
	var collect := smoothstep(collect_start, BURN_TIME, elapsed)
	# Keep the card and its reason readable before the char line crosses the name.
	# Cards leaving a pile first expand below the toolbar, above the hand rows.
	var focus: Vector2 = flight.start + Vector2(24, 0) if flight.from_zone in ["hand", "resolving"] else Vector2(292, 145)
	var at: Vector2 = (flight.start as Vector2).lerp(focus, reveal).lerp(flight.end, collect)
	ghost.position = at - card_size * 0.5
	ghost.scale = (flight.start_scale as Vector2).lerp(Vector2.ONE, reveal).lerp(flight.end_scale, collect)
	ghost.rotation = lerpf(float(flight.rotation), 0.0, reveal) + collect * 0.15
	ghost.modulate.a = 1.0 - collect
	flight.burn_overlay.progress = clampf((elapsed - sweep_start) / BURN_SWEEP_TIME, 0.0, 1.0)
	flight.burn_overlay.queue_redraw()

func _draw() -> void:
	for pulse in _pulses:
		var t := float(pulse.age) / 0.30
		var tint := Color("bceaff") if pulse.draw else Color("ffae72") if pulse.burn else Color("d8b6ff")
		draw_set_transform(pulse.point, 0, Vector2(1.8, 0.7))
		draw_arc(Vector2.ZERO, 17 + t * 24, 0, TAU, 40, Color(tint, (1.0 - t) * 0.75), 2.0, true)
	draw_set_transform(Vector2.ZERO)
