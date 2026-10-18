extends Control
## Resolution-independent architectural drawing, no external image dependency.
var time := 0.0
var highest := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(preload("res://assets/graphics/tower/spire.webp"), Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(0, 0, size.x, 250), Color(0.02, 0.05, 0.08, 0.22))
	for i in 45:
		var x := fmod(i * 193.7, 1920.0)
		var y := fmod(i * 91.3 - time * (3 + i % 4) + 3000, 1080.0)
		draw_circle(Vector2(x, y), 1.0 + i % 2, Color(0.8, 0.75, 0.52, 0.13 + 0.1 * sin(time + i)))
