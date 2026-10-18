extends RefCounted
## Authored, persistent enemy mechanics get their own inspectable HUD frame.
const RULES := {
	"paper_split": {"kind":"被动", "color":"c7ad83", "icon":"split"},
	"limit": {"kind":"被动", "color":"c84957", "icon":"attack"},
	"shadow_taunt": {"kind":"被动", "color":"b47bc2", "icon":"target"},
	"thunder_rule": {"kind":"场地", "color":"d2b561", "icon":"attack"},
	"exam_function": {"kind":"被动", "color":"79c7d1", "icon":"target"},
	"score_rule": {"kind":"被动", "color":"c84957", "icon":"target"},
	"countdown_rule": {"kind":"被动", "color":"c84957", "icon":"attack"},
	"challenge_field": {"kind":"场地", "color":"8ca9cc", "icon":"debuff"},
	"damage_cap": {"kind":"被动", "color":"c7ad83", "icon":"shield"},
	"evasion": {"kind":"闪避", "color":"f3c377", "icon":"bounce"},
	"helpless": {"kind":"场地", "color":"c17caa", "icon":"split"},
	"no_escape": {"kind":"场地", "color":"c8a475", "icon":"shield"},
	"blood_draw": {"kind":"被动", "color":"d1798d", "icon":"healing"},
	"hacker_stolen": {"kind":"暂扣", "color":"e5ac7d", "icon":"sealed"},
	"summon_hits": {"kind":"计数", "color":"bc9bd7", "icon":"target"},
	"finale_power": {"kind":"场地", "color":"c493b6", "icon":"attack"},
}

static func has(key: String) -> bool:
	return RULES.has(key)

static func style(key: String) -> Dictionary:
	return RULES.get(key, {})

static func title(key: String, unit: Dictionary, status: Dictionary) -> String:
	if key == "limit": return "极限 · %d层" % int(status.get("stacks", 0))
	if key == "no_escape": return "无处可逃 · 手牌上限 %d" % int(unit.get("hand_limit", 8))
	if key == "score_rule": return "计分规则  ·  待结算 +%d" % int(unit.get("score_pending", 0))
	if key == "evasion": return "遁逃术 · 50%闪避"
	return String(status.get("name", key))

static func extra(unit: Dictionary) -> Array[Dictionary]:
	if String(unit.get("id", "")) == "paper_large" and not bool(unit.get("split_used", false)):
		return [{"icon":"paper_split", "name":"撕卷！", "desc":"生命降至最大生命的一半或以下且仍存活时，意图变为撕卷！下一次行动分裂为两只试卷兽（小）；本次分裂不造成攻击伤害。", "turns":-1, "debuff":false}]
	if String(unit.get("id", "")) == "quiet_hacker" and not unit.get("stolen_cards", []).is_empty():
		var names: Array[String] = []
		for card in unit.stolen_cards:
			names.append("%s · %s" % [FightData.card_owner(card).get("name", "角色"), FightData.skill(String(card.skill_id)).get("name", "技能")])
		var first_name: String = String(FightData.skill(String(unit.stolen_cards[0].skill_id)).get("name", "技能"))
		return [{"icon":"hacker_stolen", "name":"已偷走：%s%s" % [first_name, " 等%d张" % names.size() if names.size() > 1 else ""], "desc":"暂扣卡牌：%s。击败黑客后全部归还弃牌堆。" % "、".join(names), "turns":-1, "debuff":false}]
	if String(unit.get("id", "")) == "gaokao_countdown":
		return [{"icon":"countdown_rule", "name":"倒计时 · %d回合" % int(unit.get("countdown", 3)), "desc":"每次普通行动后倒计时减少1。倒数至1时，下次行动以自身为中心爆炸，攻击主目标及相邻角色并使其晕眩1回合；自爆后消失。", "turns":-1, "debuff":false}]
	return []
