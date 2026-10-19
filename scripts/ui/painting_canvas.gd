extends Control
## One continuous landscape, six independently editable portions of rice paper.
signal region_pressed(index: int)
const ART := preload("res://assets/graphics/battle/painting/landscape-v1.webp")
const INK := preload("res://assets/shaders/painting_ink.gdshader")
const P := preload("res://scripts/fight/fc_painting.gd")
const T := preload("res://scripts/ui/battle_theme.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
var compact := false
var colors: Array = P.blank()
var regions: Array[Button] = []
var _cells: Array[Control] = []
var _materials: Array[ShaderMaterial] = []
var _labels: Array[Label] = []
var _group_labels: Array[Label] = []
var _tweens: Array[Tween] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 6:
		var cell := Control.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cell)
		_cells.append(cell)
		var texture := AtlasTexture.new()
		texture.atlas = ART
		texture.region = Rect2(Vector2(i%3, i/3)*Vector2(ART.get_size().x/3, ART.get_size().y/2), Vector2(ART.get_size().x/3, ART.get_size().y/2))
		var picture := V.icon(cell, texture, Rect2())
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var shader := ShaderMaterial.new()
		shader.shader = INK
		shader.set_shader_parameter("region_origin", Vector2(float(i%3)/3.0, float(i/3)/2.0))
		picture.material = shader
		_materials.append(shader)
		_tweens.append(null)
		if compact: continue
		var button := Button.new()
		button.name = "PaintRegion_%d" % i
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(func() -> void: region_pressed.emit(i))
		cell.add_child(button)
		regions.append(button)
		var tag := V.panel(cell, Rect2(12, 12, 116, 32), Color("f2ead6", 0.94), Color("ad9c79", 0.5), 3)
		_labels.append(V.text(tag, "", Rect2(8, 0, 104, 32), 17, Color("394640")))
		var group := V.text(cell, "", Rect2(), 17, Color("8b473c"))
		group.add_theme_color_override("font_outline_color", Color("f6efdd"))
		group.add_theme_constant_override("outline_size", 4)
		_group_labels.append(group)
	if preload("res://scripts/ui/tower_mobile.gd").enabled() and not compact:
		for label in _labels:
			label.get_parent().size = Vector2(240, 60)
			label.size = Vector2(230, 60)
			label.add_theme_font_size_override("font_size", 32)
		for label in _group_labels: label.add_theme_font_size_override("font_size", 28)
	resized.connect(_layout)
	_layout()
	set_canvas(colors, -1, {}, [], false)

func _layout() -> void:
	for i in _cells.size():
		_cells[i].position = Vector2(i%3, i/3)*size/Vector2(3, 2)
		_cells[i].size = size/Vector2(3, 2)
		if not compact:
			_group_labels[i].position = Vector2(14, _cells[i].size.y-36)
			_group_labels[i].size = Vector2(_cells[i].size.x-28, 28)
	queue_redraw()

func set_canvas(next: Array, active: int = -1, edits: Dictionary = {}, allowed: Array = [], animate: bool = true) -> void:
	var previous := colors.duplicate()
	colors = next.duplicate()
	if _materials.is_empty(): return
	var groups := P.groups(colors)
	for i in 6:
		var mat := _materials[i]
		var changed: bool = previous[i] != colors[i]
		if changed or not animate:
			if _tweens[i] != null and _tweens[i].is_valid(): _tweens[i].kill()
			mat.set_shader_parameter("old_pigment", P.TINTS[previous[i]])
			mat.set_shader_parameter("pigment", P.TINTS[colors[i]])
			mat.set_shader_parameter("old_strength", 0.0 if previous[i] == "white" else 1.0)
			mat.set_shader_parameter("strength", 0.0 if colors[i] == "white" else 1.0)
			mat.set_shader_parameter("old_rainbow", 1.0 if previous[i] == "rainbow" else 0.0)
			mat.set_shader_parameter("rainbow", 1.0 if colors[i] == "rainbow" else 0.0)
			mat.set_shader_parameter("progress", 0.0 if animate and changed else 1.0)
			if animate and changed:
				_tweens[i] = Settings.battle_tween(self)
				_tweens[i].tween_method(func(value: float) -> void: mat.set_shader_parameter("progress", value), 0.0, 1.0, 0.38)
		if compact: continue
		var border := Color("a7483b") if active == i else Color("597b68") if edits.has(i) else Color("ab9c80", 0.3)
		regions[i].add_theme_stylebox_override("normal", T.frame(Color.TRANSPARENT, border, 3 if active == i else 2 if edits.has(i) else 1, 0))
		regions[i].add_theme_stylebox_override("disabled", T.frame(Color.TRANSPARENT, Color("ab9c80", 0.2), 1, 0))
		regions[i].add_theme_stylebox_override("hover", T.frame(Color("f5df9f", 0.09), Color("ad7040"), 3, 0))
		regions[i].add_theme_stylebox_override("pressed", T.frame(Color("ba8e55", 0.1), Color("a7483b"), 3, 0))
		regions[i].add_theme_stylebox_override("focus", T.frame(Color.TRANSPARENT, Color("ad7040"), 2, 0))
		regions[i].disabled = not allowed.has(i)
		regions[i].tooltip_text = "区域 %02d · %s%s" % [i+1, P.NAMES[colors[i]], "\n已暂存，确认后落笔" if edits.has(i) else ""]
		_labels[i].text = "%02d  %s" % [i+1, P.NAMES[colors[i]]]
		var memberships: Array[String] = []
		for kind in ["ink", "tri"]:
			for group_index in groups[kind].size():
				if groups[kind][group_index].has(i): memberships.append(("水墨" if kind == "ink" else "三色") + str(group_index+1))
		_group_labels[i].text = ("已选 · " if edits.has(i) else "") + "  ".join(memberships)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("f2ead5"))
	# Static deterministic fibers: no animation loop, no gameplay RNG consumption.
	for i in (65 if compact else 480):
		var at := Vector2(fposmod(i*127.31, size.x), fposmod(i*79.17, size.y))
		draw_line(at, at+Vector2(3+fposmod(i*3.7, 11), 0.5), Color("978265", 0.08), 1)
	draw_rect(Rect2(Vector2.ZERO, size), Color("ae9b78", 0.65), false, 1)
