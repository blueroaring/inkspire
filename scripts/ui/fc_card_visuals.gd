extends RefCounted
## Shared card art and typography for searches and the calculation queue.
const GOLD := Color("86622e")
const MUTED := Color("506575")
const GLYPH := preload("res://scripts/ui/battle_glyph.gd")
const THEME := preload("res://scripts/ui/battle_theme.gd")
const EFFECTS := preload("res://scripts/data/battle_card_effects.gd").DEFINITIONS

static func effect_icons(parent: Node, card: Dictionary, position: Vector2, icon_size: float = 24, named_enchant: bool = false) -> Control:
	var holder := Control.new()
	holder.name = "CardEffects"
	holder.position = position
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var keys: Array[String] = FightSystem.fc.effect_keys(card)
	var offset := 0.0
	for i in keys.size():
		var key := keys[i]
		var data: Array = EFFECTS[key]
		var with_name := named_enchant and key in ["enchant", "trojan"]
		var width := icon_size + (35.0 if with_name else 0.0)
		var badge := panel(holder, Rect2(offset, 0, width, icon_size), Color("62617b") if with_name else Color("536b7b"), Color(THEME.quiet(data[2]), 0.45), 5)
		badge.name = "Effect_" + key
		badge.mouse_filter = Control.MOUSE_FILTER_PASS
		badge.tooltip_text = "%s\n%s" % [data[0], data[1]]
		if preload("res://scripts/ui/tower_mobile.gd").enabled():
			badge.mouse_filter = Control.MOUSE_FILTER_STOP
			badge.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					preload("res://scripts/ui/tower_mobile.gd").instance().show_help(String(data[0]), String(data[1]))
					badge.accept_event())
		glyph(badge, key, Rect2(Vector2(1, 1), Vector2.ONE * (icon_size - 2)), data[2])
		if with_name: text(badge, "木马" if key == "trojan" else "附魔", Rect2(icon_size, 0, 34, icon_size), 14, THEME.ON_STAGE, true)
		offset += width + 5
	holder.size = Vector2(maxf(0, offset - 5), icon_size)
	return holder

static func glyph(parent: Node, kind: String, rect: Rect2, accent: Color) -> Control:
	var symbol := GLYPH.new()
	symbol.kind = kind
	symbol.accent = accent
	symbol.position = rect.position
	symbol.size = rect.size
	parent.add_child(symbol)
	return symbol

static func energy_badge(parent: Node, card: Dictionary, rect: Rect2) -> Control:
	var cost := "X" if int(FightData.skill(String(card.skill_id)).get("cost", 0)) < 0 else str(FightSystem.card_cost(card))
	var rebirth := String(card.skill_id).begins_with("LP")
	var badge := glyph(parent, "rebirth" if rebirth else "energy", rect, card_identity(card).accent)
	badge.name = "EnergyCost"
	badge.paper_style = true
	badge.set_meta("cost", cost)
	var value := text(badge, cost, Rect2(Vector2.ZERO, rect.size - Vector2(0, 2)), roundi(rect.size.y * 0.49), THEME.TEXT, true)
	value.add_theme_color_override("font_outline_color", Color("132235"))
	value.add_theme_constant_override("outline_size", 0)
	if rebirth: value.add_theme_color_override("font_color", Color("fff0c8"))
	return badge

static func style(bg: Color, border: Color, width: int = 1, radius: int = 16) -> StyleBoxFlat:
	return THEME.frame(bg, border, width, radius)

static func text(parent: Node, words: String, rect: Rect2, font: int, color: Color = THEME.TEXT, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = preload("res://scripts/ui/tower_mobile.gd").words(words)
	label.add_theme_font_override("font", THEME.BODY)
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(label)
	return label

static func icon(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture = texture
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if preload("res://scripts/data/battle_portrait_data.gd").is_pixel(texture) else CanvasItem.TEXTURE_FILTER_LINEAR
	art.position = rect.position
	art.size = rect.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

static func hero_icon(parent: Node, hero_id: String, rect: Rect2, attribute: String = "") -> TextureRect:
	var art := preload("res://scripts/ui/battle_hero_portrait.gd").new()
	art.hero_id = hero_id
	art.attribute = attribute
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = rect.position
	art.size = rect.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

static func owner_icon(parent: Node, card: Dictionary, rect: Rect2) -> TextureRect:
	var art := preload("res://scripts/ui/battle_hero_portrait.gd").new()
	art.source_card = card.duplicate()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = rect.position
	art.size = rect.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

static func panel(parent: Node, rect: Rect2, bg: Color, border: Color, radius: int = 12) -> Panel:
	var result := Panel.new()
	result.position = rect.position
	result.size = rect.size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_stylebox_override("panel", style(bg, border, 1, radius))
	parent.add_child(result)
	var surface := THEME.decorate(result, border, rect.size.y > 120)
	surface.corner_radius = radius
	return result

static func card_title(card: Dictionary) -> String:
	return String(FightData.skill(String(card.skill_id)).get("name", card.skill_id))

static func owner_name(card: Dictionary) -> String:
	return String(FightData.card_owner(card).get("name", ""))

static func card_identity(card: Dictionary) -> Dictionary:
	var owner := String(card.get("original_caster", card.get("caster_id", "")))
	for unit: Dictionary in FightSystem.allies:
		if String(unit.id) == owner:
			return THEME.identity(owner, String(unit.get("attribute", "none")))
	return THEME.identity(owner, FightSystem.current_attribute(owner) if not owner.is_empty() else "none")

static func tile(card: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(302, 255)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_contents = true
	THEME.decorate(button, GOLD, true)
	if card.has("skill_id"): THEME.material_identity(button, card_identity(card))
	if card.has("slot"):
		var width := 198 if int(card.get("placement_count", 0)) > 10 else 238
		button.custom_minimum_size = Vector2(width, 218)
		text(button, String(card.label), Rect2(18, 56, width - 36, 60), 32, GOLD, true)
		text(button, " / ".join(card.get("positions", [])), Rect2(10, 136, width - 20, 34), 23, THEME.GREEN, true)
	elif card.has("ally") or card.has("enemy"):
		var units: Array = FightSystem.allies if card.has("ally") else FightSystem.enemies
		var unit: Dictionary = units[int(card.get("ally", card.get("enemy", 0)))]
		if card.has("ally"): THEME.material_identity(button, THEME.identity(String(unit.id), String(unit.attribute)))
		if card.has("ally"):
			hero_icon(button, String(unit.id), Rect2(80, 22, 142, 142), String(unit.attribute))
		else:
			icon(button, load(String(unit.portrait)) as Texture2D, Rect2(80, 22, 142, 142))
		text(button, String(unit.name), Rect2(12, 166, 278, 36), 23, THEME.TEXT, true).add_theme_font_override("font", THEME.HEADING)
		var detail := "生命 %d / %d" % [int(unit.hp), int(unit.max_hp)]
		if card.has("enemy"): detail += " · 毒 %d" % FightSystem.fc.POISON.layers(unit)
		text(button, detail, Rect2(12, 211, 278, 28), 18, THEME.MUTED, true)
	elif not card.has("skill_id"):
		var label := text(button, String(card.get("label", "选择")), Rect2(22, 50, 258, 130), 26, GOLD, true)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		var id := String(card.skill_id)
		var tint := FightData.rarity_color(id)
		panel(button, Rect2(96, 30, 110, 110), THEME.RECESSED, Color(tint, 0.35), 55)
		var art := icon(button, FightData.skill_icon(id), Rect2(106, 40, 90, 90))
		art.name = "SkillIcon"
		energy_badge(button, card, Rect2(239, 9, 51, 51))
		text(button, card_title(card), Rect2(12, 146, 278, 40), 23, THEME.TEXT, true).add_theme_font_override("font", THEME.HEADING)
		var line := ColorRect.new()
		line.position = Vector2(20, 195)
		line.size = Vector2(262, 1)
		line.color = Color(tint, 0.2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(line)
		owner_icon(button, card, Rect2(19, 208, 29, 31))
		effect_icons(button, card, Vector2(61, 211), 26)
	var badge := text(button, "", Rect2(16, 16, 42, 34), 23, GOLD, true)
	badge.name = "SelectionOrder"
	return button

static func select_tile(button: Button, card: Dictionary, order: int, ordered: bool) -> void:
	var tint := FightData.rarity_color(String(card.skill_id)) if card.has("skill_id") else Color("79b0c9")
	var border := Color(GOLD, 0.75) if order >= 0 else Color(THEME.LINE, 0.35)
	var base: Color = card_identity(card).fill if card.has("skill_id") else THEME.SURFACE
	button.add_theme_stylebox_override("normal", style(base, border, 1, 6))
	button.add_theme_stylebox_override("hover", style(THEME.HOVER, GOLD, 1, 6))
	button.add_theme_stylebox_override("pressed", style(THEME.INK, GOLD, 1, 6))
	button.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, GOLD, 1, 6))
	var badge := button.get_node("SelectionOrder") as Label
	badge.text = (str(order + 1) if ordered else "✓") if order >= 0 else ""

static func detail(parent: Node, card: Dictionary) -> Control:
	var popup := load("res://scripts/ui/battle_archive_detail.gd").new() as Control
	popup.card = card
	parent.add_child(popup)
	return popup
