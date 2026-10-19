extends RefCounted
## Read only predictions from the same cloned rules used by the desktop overlay.
static func describe(card_index: int = -1, ultimate_index: int = -1, selected_target: int = -1) -> String:
	if card_index < 0 and ultimate_index < 0: return ""
	var definition: Dictionary = FightSystem.get_ultimate(ultimate_index) if ultimate_index >= 0 else FightData.skill(String(FightSystem.hand[card_index].skill_id))
	var side := String(definition.get("target", "self"))
	var targets: Array = [selected_target]
	if selected_target < 0 and side in ["enemy", "ally"]:
		targets = range(FightSystem.enemies.size() if side == "enemy" else FightSystem.allies.size())
	var lines := PackedStringArray(["效果预估 · 查看不会消耗资源"])
	for target in targets:
		var preview := FightSystem.preview_ultimate(ultimate_index, target) if ultimate_index >= 0 else FightSystem.preview_card(card_index, target)
		if preview.is_empty(): continue
		if not preview.get("exact", false):
			lines.append("不确定：" + String(preview.get("note", "结果随随机效果或后续选择变化。")))
			continue
		if side in ["enemy", "ally"] and target >= 0:
			var units: Array = FightSystem.enemies if side == "enemy" else FightSystem.allies
			lines.append("选择 %s 时：" % units[target].name)
		for entry in preview.get("targets", []):
			lines.append("%s：扣血 %d · 破盾 %d · 治疗 %d · 加盾 %d\n预计剩余生命 %d%s" % [entry.name, entry.hp, entry.guard, entry.healing, entry.shield, entry.remaining, " · 可击败" if entry.defeated else " · 将濒死" if entry.downed else ""])
		if int(preview.get("shared_guard", 0)) > 0: lines.append("共享护盾 +%d" % int(preview.shared_guard))
	return "\n\n".join(lines)
