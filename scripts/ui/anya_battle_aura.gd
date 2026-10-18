extends Control
## Presentation-only motes, independent of combat RNG and bounded draw work.
var age := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1920, 1080)
	z_index = 2

func _process(delta: float) -> void:
	age += delta
	visible = FightSystem.fc.ANYA.phoenix(FightSystem.fc)
	if visible: queue_redraw()

func _draw() -> void:
	for i in 34:
		var x := 510 + fmod(i * 137.1 + sin(age * 0.3 + i) * 25 + 1400, 1370)
		var y := 120 + fmod(i * 97.0 - age * (9 + i % 12) + 20000, 700)
		var opacity := (0.18 + 0.2 * pow(sin(age * 0.7 + i), 2))
		draw_line(Vector2(x, y), Vector2(x + 3, y - 8), Color("ffd99a", opacity), 1.5, true)
		if i % 4 == 0: draw_circle(Vector2(x, y), 7, Color("edb37c", opacity * 0.08))
