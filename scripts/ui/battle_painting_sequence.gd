extends Panel
## A small live score above the battlefield; the rule callback releases each cell.
const P := preload("res://scripts/fight/fc_painting.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const T := preload("res://scripts/ui/battle_theme.gd")
var active_region := -1
var applied := false
var _title: Label
var _detail: Label
var _canvas: Control
var _focus: Panel
var _swatches: Array[Panel] = []
var _results: Array[String] = []

func _ready() -> void:
	name = "PaintingMixSequence"
	position = Vector2(532, 112)
	size = Vector2(1300, 124)
	z_index = 38
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", T.frame(Color("e8dec8"), Color("9f7951"), 2, 5))
	_canvas = preload("res://scripts/ui/painting_canvas.gd").new()
	_canvas.compact = true
	_canvas.position = Vector2(12, 12)
	_canvas.size = Vector2(162, 100)
	add_child(_canvas)
	_focus = V.panel(_canvas, Rect2(0, 0, 54, 50), Color.TRANSPARENT, Color("ba493a"), 3)
	_focus.get_node("SurfaceArt").hide()
	_title = V.text(self, "", Rect2(196, 12, 450, 34), 25, Color("3f5549"))
	for i in 6:
		var swatch := V.panel(self, Rect2(196 + i * 73, 62, 64, 44), Color.WHITE, T.LINE, 3)
		V.text(swatch, str(i + 1), Rect2(0, 0, 64, 44), 19, T.TEXT, true)
		_swatches.append(swatch)
	_detail = V.text(self, "", Rect2(668, 18, 610, 88), 22, Color("4d5b4d"))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

func show_region(colors: Array, index: int) -> void:
	active_region = index
	applied = false
	_results.clear()
	_canvas.set_canvas(colors, -1, {}, [], false)
	_focus.position = Vector2(index % 3, index / 3) * Vector2(54, 50)
	_title.text = "混色 · 第 %d / 6 格 · %s" % [index + 1, P.NAMES[colors[index]]]
	for i in 6:
		_swatches[i].add_theme_stylebox_override("panel", T.frame(P.TINTS[colors[i]], Color("a7483b") if i == index else Color("ad9c79"), 3 if i == index else 1, 3))
		var number: Label = _swatches[i].get_child(_swatches[i].get_child_count() - 1)
		number.add_theme_color_override("font_color", Color("f1ead8") if colors[i] == "ink" else Color("293338"))
	_detail.text = {"white":"共享护盾", "ink":"群体攻击", "red":"随机净化", "yellow":"随机净化", "blue":"随机净化", "rainbow":"共享护盾 → 群体攻击 → 随机净化"}[colors[index]]
	if colors[index] in ["ink", "rainbow"]: _results.append("群体攻击")

func add_result(words: String) -> void:
	_results.append(words)
	_detail.text = "  ·  ".join(_results)
