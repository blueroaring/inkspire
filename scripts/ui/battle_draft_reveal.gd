extends Control
## M06 exposes the real drawn cards before their actual destination is committed.
signal finished
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const THEME := preload("res://scripts/ui/battle_theme.gd")
const TILE_SIZE := Vector2(302, 255)
var cards: Array = []
var owner_id := "zhoumingyuan"
var calculation_anchor := Vector2(780, 835)
var stage := "draw"
var tiles: Array[Control] = []

func _ready() -> void:
	name = "DraftReveal"
	z_index = 105
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color(0.015, 0.035, 0.06, 0.80)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	V.text(self, "周明远 · 数学", Rect2(120, 230, 1680, 38), 23, Color("80deef"), true)
	var heading := V.text(self, "展开草稿", Rect2(120, 270, 1680, 66), 48, Color("f4ead5"), true)
	heading.add_theme_font_override("font", THEME.HEADING)
	var progress := V.text(self, "抽取 %d 张牌" % cards.size(), Rect2(120, 340, 1680, 34), 23, Color("b7c8cf"), true)
	progress.name = "DraftProgress"
	var deck := V.panel(self, Rect2(40, 96, 298, 54), Color("182637"), Color("bca575"), 10)
	V.text(deck, "↑ 抽牌堆 · 原序放回顶部", Rect2(10, 0, 278, 54), 21, Color("e2d1a9"), true)
	var calc := V.panel(self, Rect2(calculation_anchor.x - 168, calculation_anchor.y - 66, 336, 54), Color("123747"), Color("80deef"), 10)
	V.text(calc, "↓ 演算区 · 按抽牌顺序入队", Rect2(8, 0, 320, 54), 20, Color("c2f4ff"), true)
	var left := (1920.0 - cards.size() * 302.0 - (cards.size() - 1) * 22.0) * 0.5
	var deal := Settings.battle_tween(self).set_parallel(true)
	for i in cards.size():
		var card: Dictionary = cards[i]
		var tile := V.tile(card)
		V.select_tile(tile, card, -1, false)
		tile.name = "DraftCard_%d" % int(card.uid)
		tile.size = TILE_SIZE
		tile.pivot_offset = TILE_SIZE * 0.5
		tile.position = Vector2(90, 49) - TILE_SIZE * 0.5
		tile.scale = Vector2.ONE * 0.08
		tile.modulate.a = 0.0
		_ignore_input(tile)
		add_child(tile)
		tiles.append(tile)
		var own := String(card.caster_id) == owner_id
		tile.set_meta("destination", "calculation" if own else "deck")
		var caption := V.text(self, "进入演算区" if own else "放回抽牌堆", Rect2(left + i * 324, 684, 302, 38), 23, Color("9ce7f6") if own else Color("e2c68c"), true)
		caption.modulate.a = 0.0
		deal.tween_property(tile, "position", Vector2(left + i * 324, 408), 0.42).set_delay(i * 0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		deal.tween_property(tile, "scale", Vector2.ONE, 0.42).set_delay(i * 0.13)
		deal.tween_property(tile, "modulate:a", 1.0, 0.18).set_delay(i * 0.13)
		deal.tween_property(caption, "modulate:a", 1.0, 0.20).set_delay(i * 0.13 + 0.3)
	await deal.finished
	stage = "revealed"
	progress.text = "自己的牌进入演算区 · 其余牌放回抽牌堆"
	await Settings.battle_timer(1.15).timeout
	stage = "distribute"
	progress.text = "正在归入牌堆…"
	var distribute := Settings.battle_tween(self).set_parallel(true)
	for i in tiles.size():
		var tile := tiles[i]
		var destination := calculation_anchor if tile.get_meta("destination") == "calculation" else Vector2(90, 49)
		distribute.tween_property(tile, "position", destination - TILE_SIZE * 0.5, 0.46).set_delay(i * 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		distribute.tween_property(tile, "scale", Vector2.ONE * 0.08, 0.46).set_delay(i * 0.15)
		distribute.tween_property(tile, "modulate:a", 0.0, 0.16).set_delay(i * 0.15 + 0.3)
	await distribute.finished
	stage = "finished"
	hide()
	finished.emit()
	queue_free()

func _ignore_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children(): _ignore_input(child)
