extends Control
## Independent resource display; rebirth is never presented as ordinary energy.
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const T := preload("res://scripts/ui/battle_theme.gd")
var amount := -1
var initial := 12
var pulse := 0.0
var age := 0.0
var number: Label
var caption: Label
var detail: Label

func _ready() -> void:
	name = "AnyaRebirthMeter"
	size = Vector2(184, 66)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var enamel := AtlasTexture.new()
	enamel.atlas = preload("res://assets/graphics/battle/anya/phoenix_ui_material.webp")
	enamel.region = Rect2(650, 22, 800, 680)
	V.icon(self, enamel, Rect2(3, 3, 178, 60)).stretch_mode = TextureRect.STRETCH_SCALE
	var crest := AtlasTexture.new()
	crest.atlas = enamel.atlas
	crest.region = Rect2(1550, 30, 530, 590)
	V.icon(self, crest, Rect2(4, 3, 56, 56))
	caption = V.text(self, "重生计数", Rect2(67, 4, 114, 21), 15, Color("f1d3a1"))
	number = V.text(self, "12", Rect2(66, 22, 63, 30), 25, Color("fff1cb"))
	detail = V.text(self, "幻羽", Rect2(132, 30, 46, 23), 13, Color("c8a685"))
	set_process(false)

func update_count(value: int, starting: int) -> void:
	if amount >= 0 and amount != value: pulse = 1.0
	amount = value
	initial = starting
	number.text = str(value)
	number.add_theme_color_override("font_color", Color("ffb599") if value <= 3 else Color("fff1cb"))
	detail.text = "将归" if value <= 3 else "+%d" % (value - starting) if value > starting else "幻羽"
	tooltip_text = "重生计数 %d（入场 %d）\n第二形态技能消耗此计数，回合开始不恢复。\n计数耗尽，或手牌、抽牌堆、弃牌堆都无可负担技能时，自动释放退场终结技。" % [value, starting]
	set_process(visible)
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	pulse = maxf(0, pulse - delta * 2.2)
	queue_redraw()
	if not visible: set_process(false)

func _draw() -> void:
	var low := amount >= 0 and amount <= 3
	var edge := Color("d68a70") if low else Color("d3af70")
	draw_style_box(T.frame(Color("29131c"), edge, 1, 9), Rect2(Vector2.ZERO, size))
	draw_line(Vector2(62, 8), Vector2(62, 52), Color(edge, 0.4), 1, true)
	var count := maxi(1, initial)
	var width := 109.0 / count
	for i in count:
		var lit := i < amount
		var alpha := 0.9 if lit else 0.17
		if lit and low: alpha *= 0.7 + 0.3 * sin(age * 4.0)
		draw_rect(Rect2(67 + i * width, 61, width - 2, 3), Color(edge, alpha))
	if pulse > 0: draw_style_box(T.frame(Color(1, 0.74, 0.4, pulse * 0.13), Color(1, 0.85, 0.6, pulse * 0.7), 2, 9), Rect2(Vector2.ZERO, size))
