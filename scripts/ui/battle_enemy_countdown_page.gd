extends Node2D
## Covers the portrait's fixed "10" with a changing leaf-calendar date.
const FONT := preload("res://assets/fonts/noto_serif_sc/battle_ui.tres")
const RED := Color("aa3546")
var remaining := 3:
	set(value):
		value = maxi(0, value)
		if remaining == value: return
		remaining = value
		if not is_inside_tree():
			_shown = value
			queue_redraw()
			return
		if is_instance_valid(_flip): _flip.kill()
		_flip = Settings.battle_tween(self)
		_flip.tween_property(self, "fold", 0.06, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_flip.tween_callback(func() -> void:
			_shown = remaining
			queue_redraw()
		)
		_flip.tween_property(self, "fold", 1.0, 0.19).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
var fold := 1.0:
	set(value):
		fold = value
		queue_redraw()
var _shown := 3
var _flip: Tween

func _draw() -> void:
	var shadow := PackedVector2Array([Vector2(193, 177), Vector2(251, 163), Vector2(354, 171), Vector2(393, 190), Vector2(389, 273), Vector2(353, 295), Vector2(250, 286), Vector2(205, 294), Vector2(190, 275)])
	var paper := PackedVector2Array([Vector2(192, 170), Vector2(250, 157), Vector2(352, 165), Vector2(391, 183), Vector2(387, 267), Vector2(351, 289), Vector2(250, 280), Vector2(203, 288), Vector2(189, 268)])
	draw_colored_polygon(shadow, Color("281821", 0.48))
	draw_colored_polygon(paper, Color("e8dfd0"))
	draw_set_transform(Vector2(0, 170.0 * (1.0 - fold)), 0.0, Vector2(1.0, fold))
	draw_colored_polygon(paper, Color("e8dfd0"))
	draw_polyline(PackedVector2Array([paper[0], paper[1], paper[2], paper[3], paper[4], paper[5], paper[6], paper[7], paper[8]]), Color("ad8c83", 0.75), 2, true)
	draw_colored_polygon(PackedVector2Array([Vector2(353, 166), Vector2(391, 183), Vector2(358, 189)]), Color("cbbcac"))
	for y in [195.0, 216.0, 237.0, 258.0]:
		draw_line(Vector2(202, y), Vector2(376, y + 2), Color("9a6e72", 0.11), 1, true)
	var number := str(_shown)
	var width := FONT.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 67).x
	draw_string(FONT, Vector2(290 - width * 0.5, 257), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 67, RED)
	draw_line(Vector2(225, 272), Vector2(355, 273), Color(RED, 0.65), 2, true)
	draw_set_transform(Vector2.ZERO)
