extends "res://scripts/ui/fc_card_detail.gd"
## Battle palette and typography; keeps the shared adaptive description layout.
const PAPER_THEME := preload("res://scripts/ui/battle_theme.gd")

func _ready() -> void:
	PAPER_THEME.apply(self)
	super._ready()
	(get_child(0) as ColorRect).color.a = 0.4
	var identity := V.card_identity(card)
	pane.add_theme_stylebox_override("panel", PAPER_THEME.frame(PAPER_THEME.SURFACE.lerp(identity.fill, 0.4), identity.edge, 1, 8))
	var engraving := preload("res://scripts/ui/battle_archive_art.gd").new()
	engraving.seal = true
	engraving.family = identity.motif
	engraving.accent = identity.edge
	engraving.position = Vector2(pane.size.x - 42, 17)
	engraving.size = Vector2(28, 28)
	pane.add_child(engraving)
	var surface := pane.get_node("SurfaceArt") as Control
	surface.accent = identity.accent
	surface.family = identity.motif
	surface.queue_redraw()
	for child in pane.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", PAPER_THEME.TEXT if child.position.y < 75 else PAPER_THEME.MUTED)
			if child.position.y < 75: child.add_theme_font_override("font", PAPER_THEME.HEADING)
	body.add_theme_font_override("font", PAPER_THEME.BODY)
	body.add_theme_color_override("font_color", PAPER_THEME.TEXT)
	footer.add_theme_color_override("font_color", PAPER_THEME.MUTED)
