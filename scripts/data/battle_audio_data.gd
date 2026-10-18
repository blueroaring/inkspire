extends RefCounted
## Presentation-only sound routing. No rule or combat-RNG dependency.
## Byte-for-byte copies from newrecgen/; preserve authored timing without conversion.
const ULTIMATE_VOICES := {
	"hero_zhoumingyuan_none_ultimate":"res://assets/audio/ultimate_voice/我们，永不言弃.mp3",
	"hero_zhoumingyuan_math_ultimate":"res://assets/audio/ultimate_voice/看清了，解已确定.mp3",
	"hero_alyina_ultimate":"res://assets/audio/ultimate_voice/来吧，发起总攻.mp3",
	"hero_chenmo_ultimate":"res://assets/audio/ultimate_voice/都往我这边站.mp3",
	"hero_wangjiaqi_ultimate":"res://assets/audio/ultimate_voice/看好了，这才叫魔术.mp3",
	"hero_xumingming_ultimate":"res://assets/audio/ultimate_voice/这一轮，全力冲刺.mp3",
	"hero_suwanqing_ultimate":"res://assets/audio/ultimate_voice/藏不住了吧，该爆料了.mp3",
	"hero_liudanya_ultimate":"res://assets/audio/ultimate_voice/这一笔，一气呵成.mp3",
	"hero_anya_enter":"res://assets/audio/ultimate_voice/找到我，然后拯救我.mp3",
	"hero_anya_return":"res://assets/audio/ultimate_voice/这一次，我们在一起.mp3",
	"hero_anya_defeated":"res://assets/audio/ultimate_voice/我在，别松开我的手.mp3",
}
const ULTIMATES := {
	"zhou_wuji":["zhou", "hero_zhoumingyuan_none_ultimate"],
	"zhou_math":["math", "hero_zhoumingyuan_math_ultimate"],
	"alyina":["alyina", "hero_alyina_ultimate"], "chen":["chen", "hero_chenmo_ultimate"],
	"xu":["xu", "hero_xumingming_ultimate"], "wang":["wang", "hero_wangjiaqi_ultimate"],
	"su":["su", "hero_suwanqing_ultimate"], "liu":["liu", "hero_liudanya_ultimate"],
}
const RELEASES := {
	"N01":"zhou_slash_release", "N02":"zhou_heavy_release", "N03":"", "N04":"zhou_slash_release",
	"N05":"", "N06":"zhou_heavy_release", "N07":"zhou_resolve", "N08":"zhou_slash_release",
	"N09":"math_calculation", "N10":"zhou_heavy_release", "N11":"zhou_resolve", "N12":"zhou_heavy_release", "N13":"zhou_heavy_release",
	"A01":"", "A02":"", "A03":"", "A04":"", "A05":"alyina_support", "A06":"alyina_support",
	"A07":"alyina_support", "A08":"", "A09":"alyina_support", "A10":"", "A11":"alyina_support", "A12":"", "A13":"alyina_support",
	"C01":"", "C02":"chen_reflect_ready", "C03":"", "C04":"chen_reflect_ready", "C05":"chen_transfer",
	"C06":"", "C07":"chen_reflect_ready", "C08":"chen_transfer", "C09":"chen_break_free",
	"C10":"chen_reflect_ready", "C11":"", "C12":"chen_transfer", "C13":"math_calculation",
	"X01":"xu_dash_release", "X02":"xu_mark_gain", "X03":"xu_mark_consume", "X04":"xu_mark_gain",
	"X05":"xu_regroup", "X06":"xu_mark_consume", "X07":"xu_regroup", "X08":"xu_regroup",
	"X09":"xu_dash_release", "X10":"xu_mark_gain", "X11":"xu_mark_consume", "X12":"xu_regroup", "X13":"xu_mark_gain",
	"W01":"wang_cards_release", "W02":"wang_cards_release", "W03":"", "W04":"wang_shuffle",
	"W05":"wang_shuffle", "W06":"wang_shuffle", "W07":"wang_reveal", "W08":"wang_reveal",
	"W09":"wang_shuffle", "W10":"wang_reveal", "W11":"wang_shuffle", "W12":"wang_cards_release", "W13":"wang_shuffle",
	"M01":"math_pursuit_release", "M02":"math_calculation", "M03":"math_calculation", "M04":"math_calculation",
	"M05":"math_calculation", "M06":"math_calculation", "M07":"math_pursuit_release", "M08":"math_lock",
	"M09":"math_calculation", "M10":"math_calculation", "M11":"math_calculation", "M12":"math_calculation", "M13":"math_calculation",
	"D01":"", "D02":"", "D03":"", "D04":"su_poison_spread", "D05":"su_mark", "D06":"su_mark",
	"D07":"", "D08":"su_poison_spread", "D09":"su_mark", "D10":"", "D11":"su_mark", "D12":"", "D13":"su_mark",
	"Y01":"", "Y02":"", "Y03":"", "Y04":"", "Y05":"", "Y06":"", "Y07":"liu_color_group", "Y08":"liu_ink_group",
	"Y09":"liu_swift", "Y10":"", "Y11":"liu_ink_group", "Y12":"liu_color_group", "Y13":"", "Y14":"liu_color_group",
	"Y15":"liu_ink", "Y16":"", "red_pen":"zhou_red_pen", "hang_on":"", "lemma":"math_calculation", "pursuit":"math_pursuit_release",
}
const VOICES := {
	"N02":"zhoumingyuan_none_heavy", "N05":"zhoumingyuan_none_recover", "N06":"zhoumingyuan_none_heavy", "N10":"zhoumingyuan_none_heavy",
	"A01":"alyina_heal", "A02":"alyina_guard", "A03":"alyina_guard", "A04":"alyina_heal", "A08":"alyina_heal", "A10":"alyina_heal", "A12":"alyina_guard", "hang_on":"alyina_rescue",
	"C01":"chenmo_guard", "C06":"chenmo_cover", "C07":"chenmo_guard",
	"X02":"xumingming_mark", "X03":"xumingming_burst", "X04":"xumingming_mark", "X06":"xumingming_burst", "X11":"xumingming_burst",
	"W03":"wangjiaqi_enchant", "W05":"wangjiaqi_shuffle", "W06":"wangjiaqi_shuffle", "W09":"wangjiaqi_shuffle", "W13":"wangjiaqi_shuffle",
	"D01":"suwanqing_poison", "D02":"suwanqing_burst", "D03":"suwanqing_poison", "D08":"suwanqing_burst",
	"Y02":"liudanya_wash", "Y04":"liudanya_ink", "Y05":"liudanya_wash", "Y07":"liudanya_group", "Y08":"liudanya_group",
	"pursuit":"zhoumingyuan_math_pursuit",
}
static func code(skill: String) -> String:
	return String(FightData.skill(skill).get("code", skill))

static func release(skill: String) -> String:
	if code(skill).begins_with("LA"): return "anya_bound_release"
	if code(skill).begins_with("LP"): return "anya_phoenix_release"
	return String(RELEASES.get(code(skill), ""))

static func voice(skill: String) -> String:
	if code(skill).begins_with("LA") or code(skill).begins_with("LP"): return "hero_anya_" + code(skill).to_lower()
	var key := String(VOICES.get(code(skill), ""))
	return "hero_" + key if not key.is_empty() else ""

static func contact(effect: String, side: String, damaging: bool, module: String) -> String:
	var id := code(effect)
	if id.begins_with("LA"): return "anya_bound_hit" if damaging else "anya_bound_guard"
	if id.begins_with("LP"): return "anya_phoenix_hit" if damaging else "anya_phoenix_guard"
	if module.begins_with("anya_") and id == "heal": return "anya_heal"
	if id == "anya_buffer": return "anya_buffer"
	if id == "self_loss": return "su_backlash" if module == "su" else "zhou_life_cost"
	if id == "heal": return "zhou_recover" if module == "zhou_wuji" else "alyina_heal"
	if id == "cleanse": return "alyina_cleanse"
	if id == "poison_apply": return "su_poison_apply"
	if id == "poison_burst": return "su_poison_burst"
	if id == "enchant_true": return "wang_enchanted_hit"
	if id == "C_reflect": return "chen_reflect_hit"
	if id == "C_share": return "chen_intercept"
	if id == "pursuit": return "math_pursuit_hit"
	if id == "magician_dodge": return ""
	if damaging:
		if id.begins_with("ultimate"): return "zhou_heavy_hit" if module == "zhou_wuji" else ""
		if id.begins_with("N"): return "zhou_heavy_hit" if id in ["N02", "N06", "N10", "N12", "N13"] else "zhou_slash_hit"
		if id.begins_with("M"): return "math_pursuit_hit"
		if id.begins_with("W"): return "wang_cards_hit"
		if id.begins_with("X"): return "xu_hit"
		if id.begins_with("Y"): return "liu_ink_hit"
		if id.begins_with("D"): return "su_poison_apply"
		if id == "red_pen": return "zhou_slash_hit"
		return ""
	if side != "ally":
		return "su_mark" if id in ["D07", "D12", "D13"] else ""
	if id == "N03": return "zhou_blood_guard"
	if id in ["A02", "A03", "A12"]: return "alyina_guard"
	if id == "hang_on": return "alyina_rescue"
	if id in ["C01", "C02", "C03", "C05", "C06", "C07", "C11"]: return "chen_guard"
	if id == "W03": return "alyina_guard"
	if id == "D10": return "chen_guard"
	if id == "Y02": return "liu_guard"
	return ""

