extends Control
signal selected
signal inspect_ultimate
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const T := preload("res://scripts/ui/battle_theme.gd")
const ROOT := "res://assets/graphics/battle/anya/"
var unit: Dictionary = {}
var portrait: Control
var health_bar: Control
var health_fill: Control
var health_sealed: Control
var health_caption: Label

func _ready() -> void:
	name = "AnyaPhoenixFrame"
	size = Vector2(1240, 196)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := V.icon(self, preload(ROOT + "phoenix_ui_plate.webp"), Rect2(Vector2.ZERO, size))
	bg.name = "PhoenixEnamelMaterial"
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	var enamel := ShaderMaterial.new()
	enamel.shader = preload("res://assets/shaders/anya_phoenix_material.gdshader")
	enamel.set_shader_parameter("intensity", 0.75)
	bg.material = enamel
	portrait = preload("res://scripts/ui/anya_living_portrait.gd").new()
	portrait.position = Vector2(35, -9)
	portrait.size = Vector2(207, 260)
	portrait.fit_cover = true
	add_child(portrait)
	V.text(self, "李安雅", Rect2(276, 16, 258, 46), 33, Color("fff0cf"))
	V.text(self, "涅槃·幻羽", Rect2(418, 31, 270, 30), 19, Color("ddbe8d"))
	V.text(self, "这一次，由我来接住你。", Rect2(278, 54, 550, 28), 18, Color("d9bfb8"))
	health_bar = V.panel(self, Rect2(278, 88, 662, 30), Color("28131b"), Color("c79655"), 4)
	health_bar.name = "PhoenixHealthBar"
	health_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	health_fill = V.panel(health_bar, Rect2(2, 2, 658, 26), Color("b88a67"), Color("deb582"), 3)
	var molten := ShaderMaterial.new()
	molten.shader = preload("res://assets/shaders/anya_phoenix_material.gdshader")
	molten.set_shader_parameter("health_fill", true)
	health_fill.material = molten
	health_sealed = V.panel(health_bar, Rect2(2, 2, 658, 26), Color("767d89"), Color("767d89"), 0)
	health_caption = V.text(health_bar, "", Rect2(Vector2.ZERO, health_bar.size), 19, Color("fff5e5"), true)
	health_caption.add_theme_constant_override("outline_size", 3)
	health_caption.add_theme_color_override("font_outline_color", Color("4c3540"))
	update_health()
	V.text(self, "羽翼仍在，便不会让你独自面对。", Rect2(278, 170, 662, 22), 14, Color("c9a58c"))
	V.icon(self, preload(ROOT + "icons/rebirth.webp"), Rect2(808, 24, 42, 48))
	V.text(self, "%d" % int(unit.get("rebirth", 0)), Rect2(859, 25, 76, 43), 31, Color("f8deaa"))
	var crest := Control.new()
	crest.position = Vector2(990, 18)
	crest.size = Vector2(224, 160)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crest)
	V.text(crest, "这一次，我们在一起！", Rect2(3, 109, 218, 25), 17, Color("fff0cf"), true)
	V.text(crest, "锁定 · 退场时自动释放", Rect2(3, 135, 218, 23), 14, Color("d6b291"), true)
	var button := Button.new()
	button.name = "PhoenixReturnDetails"
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("hover", T.frame(Color(1, 0.68, 0.3, 0.07), Color("f6cd84", 0.6), 1, 8))
	button.add_theme_stylebox_override("focus", T.frame(Color.TRANSPARENT, Color("ffe4ae"), 2, 8))
	button.size = crest.size
	button.tooltip_text = "锁定终结技 · 点击查看退场规则"
	button.pressed.connect(func() -> void: inspect_ultimate.emit())
	crest.add_child(button)
	queue_redraw()

func update_health(view: Dictionary = {}) -> void:
	var maximum := maxi(1, int(unit.max_hp))
	var hp := float(view.get("hp", unit.hp))
	var cap := float(view.get("cap", FightSystem.healing_ceiling(unit)))
	var width := health_bar.size.x - 4
	health_fill.size.x = width * clampf(hp / maximum, 0, 1)
	health_fill.visible = hp > 0
	health_sealed.position.x = 2 + width * clampf(cap / maximum, 0, 1)
	health_sealed.size.x = maxf(0, width + 2 - health_sealed.position.x)
	health_sealed.visible = unit.has("finale_heal_cap") and health_sealed.size.x > 0
	health_caption.text = "生命  %d / %d" % [roundi(hp), maximum]
	health_bar.tooltip_text = "最大生命%d；最高可回复至%d。灰色区不可回复，深色区为失去的生命。" % [maximum, roundi(cap)] if unit.has("finale_heal_cap") else "生命 %d / %d" % [roundi(hp), maximum]

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		portrait.affirm()
		selected.emit()

func react(guarded: bool) -> void:
	portrait.react(guarded)

func _draw() -> void:
	# A restrained double rim leaves the generated feather art readable.
	draw_style_box(T.frame(Color("101625"), Color("e3bd7d"), 2, 10), Rect2(Vector2.ZERO, size))
