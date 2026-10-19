extends RefCounted
## Shared battle materials for character management and formation.
const T := preload("res://scripts/ui/battle_theme.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const A := preload("res://scripts/ui/battle_attribute_hint.gd")

static func shell(root: Control, title: String, subtitle: String, background_path: String) -> TextureRect:
	T.apply(root)
	var background := V.icon(root, load(background_path), Rect2(0, 0, 1920, 1080))
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.04, 0.065, 0.40)
	shade.size = Vector2(1920, 1080)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var frame := panel(Rect2(32, 24, 1856, 1018), T.INK, T.LINE)
	frame.name = "ManagementFrame"
	root.add_child(frame)
	V.glyph(root, "retain", Rect2(68, 51, 48, 48), T.GOLD)
	heading(root, title, Rect2(136, 44, 900, 55), 38)
	V.text(root, subtitle, Rect2(139, 101, 1460, 30), 18, T.MUTED)
	var rule := ColorRect.new()
	rule.position = Vector2(64, 148)
	rule.size = Vector2(1792, 1)
	rule.color = Color(T.LINE, 0.45)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rule)
	return background

static func panel(rect: Rect2, fill: Color = T.SURFACE, edge: Color = T.LINE) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", T.frame(fill, Color(edge, 0.65), 1, 6))
	T.decorate(node, edge, false)
	return node

static func button(words: String, rect: Rect2, callback: Callable, accent: Color = T.GOLD, primary: bool = false) -> Button:
	var node := Button.new()
	node.position = rect.position
	node.size = rect.size
	node.text = words
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	T.button(node, accent, primary)
	node.pressed.connect(callback)
	return node

static func identity_button(node: Button, id: String, selected: bool = false, attribute: String = "") -> void:
	var role := T.identity(id, attribute if not attribute.is_empty() else FightSystem.current_attribute(id))
	T.material_identity(node, role)
	node.add_theme_stylebox_override("normal", T.frame(role.fill, role.edge if selected else Color(role.edge, 0.45), 2 if selected else 1, 6))
	node.add_theme_stylebox_override("hover", T.frame(role.fill.lerp(T.HOVER, 0.4), T.GOLD, 2, 6))

static func heading(parent: Node, words: String, rect: Rect2, font: int = 28, centered: bool = false) -> Label:
	var label := V.text(parent, words, rect, font, T.TEXT, centered)
	label.add_theme_font_override("font", T.HEADING)
	return label

static func paragraph(parent: Node, words: String, rect: Rect2, font: int = 18, color: Color = T.TEXT) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = rect.position
	label.size = rect.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", T.BODY)
	label.add_theme_font_size_override("font_size", font)
	label.add_theme_color_override("font_color", color)
	label.text = preload("res://scripts/ui/tower_mobile.gd").words(words)
	parent.add_child(label)
	return label

## Shared, scrollable effect and origin text. Actions remain outside the scroll area.
static func equipment_description(parent: Node, id: String, rect: Rect2) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "EquipmentDescription"
	scroll.position = rect.position
	scroll.size = rect.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	var def := FightEquipmentData.definition(id)
	for section in [{"title":"效果", "body":String(def.get("desc", ""))}, {"title":"物品来历", "body":String(def.get("lore", ""))}]:
		if section.body.is_empty(): continue
		var title := heading(column, section.title, Rect2(), 19)
		title.add_theme_color_override("font_color", T.GOLD)
		var words := paragraph(column, section.body, Rect2(), 20, T.TEXT if section.title == "效果" else T.MUTED)
		words.name = "ItemEffect" if section.title == "效果" else "ItemOrigin"
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return scroll

## Use the same full actor and setting as the battle ultimate presentation.
static func ultimate_illustration(parent: Node, unit: Dictionary, height: float = 180.0, inspect: Callable = Callable()) -> Control:
	var art := preload("res://scripts/data/battle_art.gd")
	var presentation := preload("res://scripts/data/battle_presentation.gd")
	var module := art.module(unit)
	var frame: Control = button("", Rect2(), inspect) if inspect.is_valid() else Control.new()
	frame.name = "UltimateIllustration"
	frame.set_meta("module", module)
	frame.custom_minimum_size = Vector2(0, height)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_STOP if inspect.is_valid() else Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	var background := V.icon(frame, load(presentation.ultimate_path(module)), Rect2())
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.65, 0.65, 0.65)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var illustration: Texture2D = load("res://assets/graphics/battle/anya/" + ("cg_return.webp" if module == "anya_phoenix" else "cg_enter.webp")) if module.begins_with("anya_") else art.actor(module)
	var actor := V.icon(frame, illustration, Rect2())
	actor.name = "UltimateActor"
	actor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if inspect.is_valid():
		var caption := V.text(frame, "点击查看立绘与效果", Rect2(0, 0, 0, 28), 17, Color.WHITE, true)
		caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		caption.offset_top = -28
	return frame

static func hero_button(id: String, rect: Rect2, callback: Callable, selected: bool = false, compact: bool = false, attribute: String = "") -> Button:
	var node := button("", rect, callback)
	node.name = "Hero_" + id
	node.clip_contents = true
	if attribute.is_empty(): attribute = FightSystem.current_attribute(id)
	identity_button(node, id, selected, attribute)
	var profile := FightData.hero(id, attribute)
	if compact:
		V.hero_icon(node, id, Rect2(10, 9, 70, 74), attribute)
		heading(node, String(profile.name), Rect2(90, 9, rect.size.x - 102, 33), 23)
		V.text(node, "Lv.%d · %s" % [FightProgression.hero_level(id), FightData.attr_name(attribute)], Rect2(92, 47, rect.size.x - 104, 27), 17, T.MUTED)
	else:
		V.hero_icon(node, id, Rect2((rect.size.x - 136) / 2, 12, 136, 140), attribute)
		heading(node, String(profile.name), Rect2(12, 158, rect.size.x - 24, 38), 26, true)
		V.text(node, "Lv.%d · %s" % [FightProgression.hero_level(id), FightData.attr_name(attribute)], Rect2(12, 199, rect.size.x - 24, 27), 17, T.MUTED, true)
	return node

static func focus_rect(root: Control, target: Control) -> Rect2:
	if not is_instance_valid(target): return Rect2()
	var transform := root.get_global_transform_with_canvas().affine_inverse() * target.get_global_transform_with_canvas()
	return Rect2(transform * Vector2.ZERO, target.size * transform.get_scale())
