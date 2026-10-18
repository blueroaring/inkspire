extends RefCounted
## Separate amounts and lifetimes; read only, including staged enemy-hit snapshots.
const V := preload("res://scripts/ui/fc_card_visuals.gd")

static func badge(parent: Node, rect: Rect2, amount: int, temporary: bool, max_hp: int = 0) -> Control:
	var tint := Color("ffe0a0") if temporary else Color("a5dcf2")
	var fill := Color("49381f") if temporary else Color("193347")
	var plate := V.panel(parent, rect, fill, Color(tint, 0.75), 4)
	plate.set_meta("amount", amount)
	plate.set_meta("temporary", temporary)
	plate.set_meta("overflow", maxi(0, amount-max_hp))
	plate.tooltip_text = "个人临时盾：%d\n本轮敌方行动结束后消失；在共享护盾之后、常驻盾之前抵挡伤害。" % amount if temporary else "个人常驻盾：%d\n本场战斗保留，直到耗尽或被移除；超过生命上限的部分仍完整生效。" % amount
	var icon_size := rect.size.y-4
	var icon := V.glyph(plate, "temporary" if temporary else "shield", Rect2(2, 2, icon_size, icon_size), tint)
	icon.name = "TemporaryShieldIcon" if temporary else "PersistentShieldIcon"
	V.text(plate, "临时盾" if temporary else "常驻盾", Rect2(icon_size+4, 0, 48, rect.size.y), 16, tint).name = "GuardKind"
	var value_rect := Rect2(icon_size+54, 0, rect.size.x-icon_size-58, rect.size.y)
	var font := 19
	while font > 8 and (V.THEME.BODY.get_string_size(str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1, font).x > value_rect.size.x-2 or V.THEME.BODY.get_height(font) > rect.size.y): font -= 1
	var value := V.text(plate, str(amount), value_rect, font, Color("fff7e8"), true)
	# V.text enables trimming after assigning text; reapply the compact bounds
	# once Label has released its initial full-text minimum width.
	value.size = value_rect.size
	value.name = "GuardValue"
	return plate
