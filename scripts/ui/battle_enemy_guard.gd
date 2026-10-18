extends Control
## The ward encloses the HP bar and its shield readout, using the displayed hit snapshot.
const V := preload("res://scripts/ui/fc_card_visuals.gd")
var amount := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("amount", amount)
	tooltip_text = "护盾：%d\n先抵挡伤害，耗尽后伤害才会扣除生命。" % amount
	var badge := V.panel(self, Rect2(size.x - 94, 2, 92, size.y - 4), Color("173449"), Color("9edff8"), 5)
	V.glyph(badge, "shield", Rect2(4, 3, 22, 22), Color("b8ebff"))
	var font := 20
	while font > 9 and V.THEME.BODY.get_string_size(str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1, font).x > 59: font -= 1
	var value := V.text(badge, str(amount), Rect2(27, 0, 61, badge.size.y), font, Color("edfbff"), true)
	value.name = "GuardValue"
	resized.connect(queue_redraw)

func _draw() -> void:
	var bounds := Rect2(Vector2.ONE * 2, size - Vector2.ONE * 4)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("549cc4", 0.10)
	style.border_color = Color("a4e3ff")
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.shadow_color = Color("68caff", 0.24)
	style.shadow_size = 4
	draw_style_box(style, bounds)
