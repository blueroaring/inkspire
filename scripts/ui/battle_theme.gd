extends RefCounted
const SURFACE_ART := preload("res://scripts/ui/battle_surface.gd")
## Coloured satin: mid-light surfaces, dark ink, saturated enamel in the frame.
const INK := Color("9bacb3")
const SURFACE := Color("b0bfc0")
const RECESSED := Color("8ea6ae")
const HOVER := Color("b9cbcc")
const SELECTED := Color("a2bac0")
const TEXT := Color("293e50")
const MUTED := Color("506575")
const FAINT := Color("657c87")
const GOLD := Color("86622e")
const TRIM := Color("d6b97c")
const ON_STAGE := Color("cdd7d9")
const LINE := Color("708995")
const BLUE := Color("276e98")
const GREEN := Color("286e5c")
const RED := Color("a44762")
const HEALTH := Color("c36f91")
const HEADING := preload("res://assets/fonts/noto_serif_sc/battle_ui.tres")
const BODY := preload("res://assets/fonts/noto_sans_sc/NotoSansSC-Regular.otf")

static func apply(parent: Control) -> void:
	var theme := Theme.new()
	theme.default_font = BODY
	theme.default_font_size = 20
	theme.set_font("font", "Button", HEADING)
	theme.set_font("normal_font", "RichTextLabel", BODY)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_stylebox("panel", "TooltipPanel", frame(INK, LINE, 1, 5))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", 18)
	for type in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type, frame(RECESSED, Color.TRANSPARENT, 0, 3))
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			theme.set_stylebox(state, type, frame(LINE if state == "grabber" else GOLD, Color.TRANSPARENT, 0, 3))
	parent.theme = theme

static func quiet(tint: Color) -> Color:
	return tint.lerp(TEXT, 0.38)

static func identity(hero_id: String, attribute: String = "none") -> Dictionary:
	match hero_id:
		"li_anya":
			return {"fill":Color("b7b5cf"), "accent":Color("7868af"), "edge":Color("825c79"), "motif":"wing"}
		"liudanya":
			return {"fill":Color("d3cfbc"), "accent":Color("ad5345"), "edge":Color("4f6261"), "motif":"quill"}
		"suwanqing":
			return {"fill":Color("91b9a3"), "accent":Color("269b65"), "edge":Color("625078"), "motif":"serpent"}
		"chenmo":
			return {"fill":Color("9eb8d2"), "accent":Color("497ed6"), "edge":Color("465d81"), "motif":"shield"}
		"xumingming":
			return {"fill":Color("d4ac92"), "accent":Color("e76835"), "edge":Color("875536"), "motif":"track"}
		"zhoumingyuan":
			if attribute == "math":
				return {"fill":Color("93c2d7"), "accent":Color("269cd0"), "edge":Color("356b8a"), "motif":"orbit"}
			return {"fill":Color("d0b48d"), "accent":Color("d49136"), "edge":Color("806037"), "motif":"quill"}
		"alyina":
			return {"fill":Color("94cbb7"), "accent":Color("28aa83"), "edge":Color("366c5b"), "motif":"wing"}
		"wangjiaqi":
			return {"fill":Color("baa6d6"), "accent":Color("9660d0"), "edge":Color("665080"), "motif":"diamond"}
	return {"fill":SURFACE, "accent":BLUE, "edge":LINE, "motif":"orbit"}

static func frame(bg: Color = INK, accent: Color = LINE, width: int = 1, radius: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = accent
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.corner_detail = 12
	style.shadow_color = Color("161d1d", 0.16)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	style.set_content_margin_all(0)
	return style

static func decorate(parent: Control, accent: Color = GOLD, ornate: bool = false) -> Control:
	if parent.has_node("SurfaceArt"):
		var existing := parent.get_node("SurfaceArt") as Control
		existing.accent = accent
		existing.ornate = ornate
		existing.queue_redraw()
		return existing
	var surface := SURFACE_ART.new()
	surface.name = "SurfaceArt"
	surface.accent = accent
	surface.ornate = ornate
	parent.add_child(surface)
	parent.move_child(surface, 0)
	surface.size = parent.size
	parent.resized.connect(func() -> void: surface.size = parent.size)
	return surface

static func material_identity(parent: Control, role: Dictionary) -> void:
	var surface := decorate(parent, role.get("accent", GOLD), true)
	surface.family = String(role.get("motif", "paper"))
	surface.queue_redraw()

static func button(button: Button, accent: Color, primary: bool = false) -> void:
	button.add_theme_stylebox_override("normal", frame(SELECTED if primary else SURFACE, Color(GOLD if primary else LINE, 0.5), 1, 5))
	button.add_theme_stylebox_override("hover", frame(HOVER, Color(GOLD, 0.7), 1, 5))
	button.add_theme_stylebox_override("pressed", frame(INK, GOLD, 1, 5))
	button.add_theme_stylebox_override("disabled", frame(INK, Color(LINE, 0.22), 1, 5))
	var focus := frame(Color.TRANSPARENT, GOLD, 1, 5)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_font_override("font", HEADING)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_disabled_color", FAINT)
	button.add_theme_constant_override("outline_size", 0)
	decorate(button, quiet(accent), primary)
