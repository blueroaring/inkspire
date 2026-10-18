extends Control
## Reuse the supplied curtain as narrow perimeter strips; never cover card contents.
const ART := preload("res://assets/graphics/battle/new_effects/fx_infirmary_isolation_v2.webp")
var texture: Texture2D = ART
var pulse := 0.0

func _ready() -> void:
	name = "IsolationCurtain"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	pulse = (sin(Time.get_ticks_msec() * 0.003) + 1.0) * 0.5
	queue_redraw()

func _draw() -> void:
	var tint := Color(0.85, 1.0, 1.0, 0.78 + pulse * 0.18)
	# Both cloth columns sit on the card edges. Their original empty middle is
	# discarded rather than stretching the complete square over the portrait.
	draw_texture_rect_region(texture, Rect2(-6, -8, 22, size.y + 16), Rect2(57, 57, 168, 398), tint)
	draw_texture_rect_region(texture, Rect2(size.x - 16, -8, 22, size.y + 16), Rect2(287, 57, 168, 398), tint)
	draw_texture_rect_region(texture, Rect2(8, size.y - 5, size.x - 16, 14), Rect2(65, 384, 380, 71), tint)
	var rail := Color("a3edf0", 0.65 + pulse * 0.25)
	draw_style_box(_rail_style(rail), Rect2(Vector2(-2, -3), size + Vector2(4, 6)))
	for x in [18.0, size.x - 18.0]:
		draw_circle(Vector2(x, -3), 3.2, Color("d0eeee"))
		draw_circle(Vector2(x, -3), 1.7, Color("345760"))

func _rail_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style
