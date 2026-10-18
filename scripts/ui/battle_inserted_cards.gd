extends Control
## Readable, noninteractive reveal; actual cards have already entered their destination.
const V := preload("res://scripts/ui/fc_card_visuals.gd")
var entries: Array = []
var source := "敌方干扰"

static func grouped(batches: Array) -> Array:
	var groups: Array = []
	for batch: Dictionary in batches:
		for card: Dictionary in batch.cards:
			var match_group: Dictionary = {}
			for group: Dictionary in groups:
				if group.card.skill_id == card.skill_id and group.pile == batch.pile: match_group = group; break
			if match_group.is_empty(): groups.append({"card":card.duplicate(true), "pile":batch.pile, "count":1})
			else: match_group.count = int(match_group.count) + 1
	return groups

func _ready() -> void:
	name = "InsertedCardReveal"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 85
	size = Vector2(1920, 1080)

func play() -> void:
	var groups := grouped(entries)
	for page in range(0, groups.size(), 3):
		var shown := groups.slice(page, page + 3)
		var width := shown.size() * 310.0 + 32.0
		var pane := V.panel(self, Rect2(1130 - width * 0.5, 410, width, 292), Color("182333"), Color("bb7187"), 12)
		pane.name = "InsertedCardsPane"
		V.text(pane, source + " · 塞入干扰牌", Rect2(18, 8, width - 36, 38), 25, Color("f5b1bf"), true)
		var cards: Array[Control] = []
		for i in shown.size():
			var group: Dictionary = shown[i]
			var data: Dictionary = group.card
			var id := String(data.skill_id)
			var card := V.panel(pane, Rect2(16 + i * 310, 54, 298, 216), Color("ece4d3"), Color("aa677c"), 8)
			card.name = "Inserted_" + id
			card.set_meta("skill_id", id)
			card.set_meta("count", int(group.count))
			card.set_meta("pile", String(group.pile))
			cards.append(card)
			V.icon(card, FightData.skill_icon(id), Rect2(14, 12, 61, 61))
			V.text(card, V.card_title(data), Rect2(86, 12, 202, 34), 25, Color("3f2533")).name = "CardName"
			V.text(card, "×%d" % int(group.count), Rect2(86, 46, 190, 27), 21, Color("a33759"))
			var description := Label.new()
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			description.position = Vector2(15, 81)
			description.size = Vector2(268, 91)
			description.add_theme_font_override("font", V.THEME.BODY)
			description.add_theme_font_size_override("font_size", 18)
			description.add_theme_color_override("font_color", Color("3f4854"))
			description.mouse_filter = Control.MOUSE_FILTER_IGNORE
			description.text = FightData.description(id, 1)
			card.add_child(description)
			var pile_name: String = {"deck":"抽牌堆", "discard":"弃牌堆", "hand":"手牌"}.get(group.pile, "牌堆")
			V.text(card, "进入" + pile_name, Rect2(15, 178, 268, 28), 20, Color("a33759"), true).name = "Destination"
		pane.modulate.a = 0.0
		pane.position.y += 22
		var enter := Settings.battle_tween(self).set_parallel(true)
		enter.tween_property(pane, "modulate:a", 1.0, 0.16)
		enter.tween_property(pane, "position:y", 410.0, 0.2).set_trans(Tween.TRANS_CUBIC)
		await enter.finished
		await Settings.battle_timer(1.5).timeout
		# One soft landing cue per visible batch, including repeated copies.
		preload("res://scripts/ui/battle_generated_audio.gd").sfx(get_parent(), "card_insert", 220)
		for i in cards.size():
			var card: Control = cards[i]
			var destination: Vector2 = {"deck":Vector2(70, 55), "discard":Vector2(185, 55), "hand":Vector2(250, 410)}.get(shown[i].pile, Vector2(70, 55))
			var fly := Settings.battle_tween(self).set_parallel(true)
			fly.tween_property(card, "position", destination - pane.position, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			fly.tween_property(card, "scale", Vector2.ONE * 0.12, 0.32)
			fly.tween_property(card, "modulate:a", 0.0, 0.32)
		await Settings.battle_tween(self).tween_property(pane, "modulate:a", 0.0, 0.36).finished
		pane.queue_free()
	queue_free()
