extends Control
## Presentation follows physical card UIDs, never row numbers or redraws.
const FONT := preload("res://assets/fonts/noto_sans_sc/NotoSansSC-Bold.otf")
const PURPLE := Color("c5a0ff")
const GOLD := Color("ffe8a9")
const DURATION := 2.6
var blocked := false
var clock := 0.0
var played_batches := 0
var last_batch_uids: Array[int] = []
var _cards: Dictionary = {}
var _pending: Dictionary = {}
var _recent: Dictionary = {}
var _batch_at := -10.0
var _offhand: Array[String] = []

func _ready() -> void:
	name = "EnchantmentFeedback"
	z_index = 60
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	size = Vector2(1920, 1080)

func queue_card(card: Dictionary) -> void:
	# Snapshot wording; the dictionary may move between piles before the next refresh.
	_pending[int(card.uid)] = {
		"title":String(FightData.skill(String(card.skill_id)).get("name", card.skill_id)),
		"owner":String(FightData.hero(String(card.caster_id)).get("name", "")),
	}

func sync_hand(cards: Array, views: Array[Control]) -> void:
	_cards.clear()
	for i in cards.size():
		_cards[int(cards[i].uid)] = {"view":views[i], "enchanted":bool(cards[i].get("enchanted", false))}
	queue_redraw()

func _process(delta: float) -> void:
	delta *= Settings.battle_effect_speed()
	# Wait for placement choices, turn banners and character actions to finish.
	# The player then gets the full highlight duration with the hand unobscured.
	if blocked: return
	clock += delta
	if not _pending.is_empty():
		# A later enchant replaces the previous action's emphasis, even within 2.6 seconds.
		_recent.clear()
		last_batch_uids.clear()
		_offhand.clear()
		for uid: int in _pending:
			_recent[uid] = clock
			last_batch_uids.append(uid)
			if not _cards.has(uid):
				var destination := _destination(uid)
				_offhand.append("%s · %s（%s）" % [destination, _pending[uid].title, _pending[uid].owner])
		_pending.clear()
		_batch_at = clock
		played_batches += 1
		preload("res://scripts/ui/battle_generated_audio.gd").sfx(get_parent(), "wang_enchant", 160)
	for uid in _recent.keys():
		if clock - float(_recent[uid]) > DURATION: _recent.erase(uid)
	queue_redraw()

func _destination(uid: int) -> String:
	for card: Dictionary in FightSystem.draw_pile:
		if int(card.get("uid", -1)) == uid: return "抽牌堆"
	for card: Dictionary in FightSystem.discard_pile:
		if int(card.get("uid", -1)) == uid: return "弃牌堆"
	return "待入手"

func _draw() -> void:
	for uid: int in _cards:
		var entry: Dictionary = _cards[uid]
		var view := entry.view as Control
		if not entry.enchanted or not is_instance_valid(view): continue
		var rect := Rect2(view.position, view.size * view.scale)
		var age := clock - float(_recent.get(uid, -10.0))
		_draw_card(rect, age)
	var age := clock - _batch_at
	if age < DURATION and not last_batch_uids.is_empty():
		var fade := 1.0 - smoothstep(DURATION - 0.45, DURATION, age)
		# Off-hand targets need names because their physical cards are not on screen.
		if not _offhand.is_empty():
			var rows := mini(3, _offhand.size())
			var panel := Rect2(494, 160, 525, 58 + rows * 30)
			var style := _panel()
			style.bg_color.a *= fade
			style.border_color.a *= fade
			draw_style_box(style, panel)
			draw_string(FONT, panel.position + Vector2(18, 31), "本次附魔 · %d 张" % last_batch_uids.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(GOLD, fade))
			for i in rows:
				draw_string(FONT, panel.position + Vector2(18, 63 + i * 30), _offhand[i], HORIZONTAL_ALIGNMENT_LEFT, 488, 18, Color("eadbff", fade))

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211932", 0.94)
	style.border_color = Color(PURPLE, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	return style

func _draw_card(rect: Rect2, age: float) -> void:
	var fresh := age >= 0 and age < DURATION
	var strength := (1.0 - smoothstep(DURATION - 0.45, DURATION, age)) if fresh else 0.0
	var outline := PackedVector2Array([
		rect.position + Vector2(12, 0), rect.position + Vector2(rect.size.x - 18, 0),
		rect.position + Vector2(rect.size.x, rect.size.y * 0.5), rect.end - Vector2(18, 0),
		rect.position + Vector2(12, rect.size.y), rect.position + Vector2(0, rect.size.y * 0.5), rect.position + Vector2(12, 0),
	])
	draw_polyline(outline, Color(PURPLE, 0.10 + strength * 0.12), 8.0, true)
	draw_polyline(outline, Color(PURPLE.lerp(GOLD, strength * 0.65), 0.72 + strength * 0.28), 1.7 + strength, true)
	if not fresh: return
	var sweep := clampf(age / 0.65, 0, 1)
	var x := rect.position.x + lerpf(105.0, rect.size.x - 30.0, sweep)
	var pulse := sin(sweep * PI) * 0.7
	draw_line(Vector2(x, rect.position.y + 4), Vector2(x - 14, rect.end.y - 4), Color("f0d1ff", pulse), 12, true)
	var center := rect.position + Vector2(77, 25)
	if age < 0.8:
		draw_arc(center, 21 + age * 25, 0, TAU, 40, Color(GOLD, (1.0 - age / 0.8) * 0.9), 2.0, true)
	for i in 6:
		var phase := age * 2.7 + i * TAU / 6
		var p := center + Vector2(cos(phase) * 43, sin(phase) * 21)
		var radius := 2.5 + sin(phase * 2.0) * 1.0
		draw_line(p - Vector2(radius, 0), p + Vector2(radius, 0), Color(GOLD, strength * 0.9), 1.6, true)
		draw_line(p - Vector2(0, radius), p + Vector2(0, radius), Color(GOLD, strength * 0.9), 1.6, true)
	# The label is adjacent to this exact row, so identical card copies remain distinct.
	var tag := Rect2(rect.end.x + 12, rect.position.y + 7, 108, 36)
	var style := _panel()
	style.bg_color.a *= strength
	style.border_color.a *= strength
	draw_style_box(style, tag)
	draw_line(Vector2(rect.end.x + 2, tag.get_center().y), Vector2(tag.position.x, tag.get_center().y), Color(PURPLE, strength), 1.5, true)
	draw_string(FONT, tag.position + Vector2(10, 25), "本次附魔", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(GOLD, strength))
