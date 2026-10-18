extends RefCounted
## Presentation only: use the same relationship table as damage resolution.
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const ART := preload("res://scripts/data/battle_art.gd")
const COLORS := {"none":Color("d1d8e1"), "chinese":Color("f0c785"), "math":Color("80deef"), "english":Color("a4dfae"), "science":Color("ffb78b"), "social":Color("cbb5f1")}

static func relation(attacker: String, defender: String) -> Dictionary:
	if FightData.has_advantage(attacker, defender):
		return {"text":"↑ 克制 +50%", "color":Color("a8edbd"), "fill":Color("163c32"), "kind":"advantage"}
	if FightData.has_advantage(defender, attacker):
		return {"text":"↓ 被克制 -50%", "color":Color("ffaaa8"), "fill":Color("492b35"), "kind":"disadvantage"}
	return {"text":"无克制", "color":Color("c4cfda"), "fill":Color("142432"), "kind":"neutral"}

static func icon(parent: Node, attribute: String, rect: Rect2) -> Control:
	var symbol: Control
	if attribute == "none":
		symbol = V.glyph(parent, "attribute_none", rect, COLORS.none)
	else:
		symbol = V.icon(parent, ART.status_icon(attribute), rect)
	symbol.name = "AttributeIcon_" + attribute
	symbol.set_meta("attribute", attribute)
	symbol.tooltip_text = FightData.attr_name(attribute)
	return symbol

static func badge(parent: Node, attribute: String, rect: Rect2) -> Control:
	var tint: Color = COLORS.get(attribute, COLORS.none)
	var plate := V.panel(parent, rect, Color("142432"), tint, 4)
	var icon_size := minf(32, rect.size.y - 2)
	icon(plate, attribute, Rect2(3, (rect.size.y-icon_size)*0.5, icon_size, icon_size))
	V.text(plate, FightData.attr_name(attribute), Rect2(icon_size+6, 0, rect.size.x-icon_size-9, rect.size.y), 16, tint, true)
	return plate

static func matchup(parent: Node, attacks: Array, rect: Rect2, font: int = 20) -> Control:
	var plate := V.panel(parent, rect, Color("142432"), Color("758b9e"), 5)
	var row_height := rect.size.y / maxi(1, attacks.size())
	var relation_width := maxf(148, font * 8.0)
	for i in attacks.size():
		var attack: Dictionary = attacks[i]
		var info := relation(String(attack.attribute), String(attack.target_attribute))
		var row := V.panel(plate, Rect2(1, i*row_height+1, rect.size.x-2, row_height-2), info.fill, Color(info.color, 0.65), 4)
		row.set_meta("attack", attack.duplicate())
		var source_width := font * 3.0
		var icon_size := minf(38, row_height-8)
		var icon_y := (row_height-2-icon_size)*0.5
		V.text(row, String(attack.get("source", "")), Rect2(10, 0, source_width, row_height-2), font, Color("eef2ed"))
		icon(row, String(attack.attribute), Rect2(10+source_width, icon_y, icon_size, icon_size))
		V.text(row, "→", Rect2(12+source_width+icon_size, 0, font+6, row_height-2), font, Color("eef2ed"), true)
		icon(row, String(attack.target_attribute), Rect2(20+source_width+icon_size+font, icon_y, icon_size, icon_size))
		V.text(row, info.text, Rect2(rect.size.x-relation_width-10, 0, relation_width, row_height-2), font, info.color, true).name = "AttributeRelation_%d" % i
	return plate
