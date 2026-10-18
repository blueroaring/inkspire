extends Control
## W07/W10 show the chosen draw order, actual enchantments and travel back to deck top.
signal finished
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const THEME := preload("res://scripts/ui/battle_theme.gd")
const TILE_SIZE := Vector2(302, 255)
const PURPLE := Color("c5a0ff")
var cards: Array = []
var fresh_uids: Array = []
var tiles: Array[Control] = []
var stage := "reveal"
var skill_name := "预测未来"

func _ready() -> void:
	name = "ForecastReveal"
	z_index = 105
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color(0.015, 0.025, 0.045, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var deck := V.panel(self, Rect2(40, 24, 340, 104), Color("211932"), PURPLE, 8)
	deck.name = "DeckTopDestination"
	V.text(deck, "↑ 抽牌堆顶部", Rect2(10, 8, 320, 42), 27, Color("ffe8a9"), true)
	var returned := V.text(deck, "即将放回 %d 张" % cards.size(), Rect2(10, 56, 320, 34), 21, Color("d6cce5"), true)
	V.text(self, "王佳琪 · 附魔结果", Rect2(120, 214, 1680, 38), 23, PURPLE, true)
	V.text(self, skill_name, Rect2(120, 256, 1680, 66), 48, Color("f4ead5"), true).add_theme_font_override("font", THEME.HEADING)
	var progress := V.text(self, "已按所选顺序排列 · 高亮卡牌获得附魔" if not fresh_uids.is_empty() else "这些牌均已附魔 · 保持所选牌序", Rect2(120, 332, 1680, 36), 23, Color("d6cce5"), true)
	progress.name = "ForecastRevealProgress"
	var left := (1920.0 - cards.size()*302.0 - (cards.size()-1)*42.0)*0.5
	for i in cards.size():
		var card: Dictionary = cards[i]
		var fresh := fresh_uids.has(int(card.uid))
		var x := left+i*344
		V.text(self, "第 %d 张抽取" % (i+1), Rect2(x, 382, 302, 32), 21, Color("d8c99f"), true)
		var tile := V.tile(card)
		V.select_tile(tile, card, -1, false)
		tile.name = "ForecastCard_%d" % int(card.uid)
		tile.position = Vector2(x, 428)
		tile.size = TILE_SIZE
		tile.pivot_offset = TILE_SIZE*0.5
		tile.set_meta("fresh_enchant", fresh)
		tile.set_meta("draw_order", i+1)
		_ignore_input(tile)
		add_child(tile)
		tiles.append(tile)
		var accent := PURPLE if fresh else Color("70849a")
		if fresh:
			var frame := Panel.new()
			frame.position = Vector2(-5, -5)
			frame.size = TILE_SIZE+Vector2(10, 10)
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_theme_stylebox_override("panel", V.style(Color.TRANSPARENT, PURPLE, 3, 9))
			tile.add_child(frame)
			var pulse := Settings.battle_tween(self).set_loops(3)
			pulse.tween_property(frame, "modulate:a", 0.4, 0.3)
			pulse.tween_property(frame, "modulate:a", 1.0, 0.3)
		var tag := V.panel(self, Rect2(x, 708, 302, 46), Color("211932"), accent, 5)
		tag.name = "ForecastResult_%d" % int(card.uid)
		V.text(tag, "★ 本次附魔" if fresh else "已有附魔" if card.get("enchanted", false) else "未附魔", Rect2(8, 2, 286, 42), 25, Color("ffe8a9") if fresh else Color("bbbfcc"), true)
	V.text(self, "按从左到右的顺序抽取 · 附魔保留至打出", Rect2(120, 786, 1680, 36), 20, Color("aabac8"), true)
	await Settings.battle_timer(2.0).timeout
	stage = "return"
	progress.text = "正在放回抽牌堆顶部 · 第 1 张将最先抽到"
	var fly := Settings.battle_tween(self).set_parallel(true)
	for i in tiles.size():
		fly.tween_property(tiles[i], "position", Vector2(210, 76)-TILE_SIZE*0.5, 0.62).set_delay(i*0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		fly.tween_property(tiles[i], "scale", Vector2.ONE*0.08, 0.62).set_delay(i*0.18)
		fly.tween_property(tiles[i], "modulate:a", 0.0, 0.16).set_delay(i*0.18+0.46)
	await fly.finished
	returned.text = "已放回 %d 张 · 等待抽取" % cards.size()
	await Settings.battle_timer(0.35).timeout
	stage = "finished"
	hide()
	finished.emit()
	queue_free()

func _ignore_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children(): _ignore_input(child)
