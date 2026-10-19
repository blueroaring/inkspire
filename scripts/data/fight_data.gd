class_name FightData
extends RefCounted
## 战斗数据表：技能、角色、敌人与属性反应均集中于此，规则逻辑不写在 UI。

const ATTR_NONE := "none"
const ATTR_CHINESE := "chinese"
const ATTR_MATH := "math"
const ATTR_ENGLISH := "english"
const ATTR_SCIENCE := "science"
const ATTR_SOCIAL := "social"
const ATTRS := [ATTR_NONE, ATTR_CHINESE, ATTR_MATH, ATTR_ENGLISH, ATTR_SCIENCE, ATTR_SOCIAL]
const FC := preload("res://scripts/data/fc_cards.gd")
const ATTR_NAMES := {
	ATTR_NONE: "无极", ATTR_CHINESE: "语文", ATTR_MATH: "数学", ATTR_ENGLISH: "英语",
	ATTR_SCIENCE: "理综", ATTR_SOCIAL: "文综",
}

const ADVANTAGE := {ATTR_CHINESE: [ATTR_MATH, ATTR_ENGLISH], ATTR_MATH: [ATTR_ENGLISH, ATTR_SCIENCE], ATTR_ENGLISH: [ATTR_SCIENCE, ATTR_SOCIAL], ATTR_SCIENCE: [ATTR_SOCIAL, ATTR_CHINESE], ATTR_SOCIAL: [ATTR_CHINESE, ATTR_MATH]}
const ROLES := {"attacker":"绝境爆发", "frequent_attacker":"高频攻击", "healer":"守护治疗", "support":"调度", "defender":"承伤反击", "mark_burst":"蓄势爆发", "poison":"叠毒引爆", "enchanter":"附魔调度", "painter":"构图支援", "metamorph":"幻形涅槃"}
const MAX_SKILL_COPIES := 3
const BASE_SKILL_POINTS := 9
const POINTS_PER_LEVEL := 2
const ULT_ENERGY := 3
const RARITIES := {
	"rare": {"name":"稀有", "color":Color("edc66c")},
	"medium": {"name":"中等", "color":Color("72b7ff")},
	"common": {"name":"普通", "color":Color("edf0f4")},
}
const SKILL_RARITIES := {
	"basic_strike":"common", "block":"common", "heal":"common",
	"heavy_strike":"medium", "angel_guard":"medium", "help_me":"medium",
	"red_pen":"rare", "hang_on":"rare",
}
const SKILL_POINTS := {
	"basic_strike": 1, "heavy_strike": 3, "block": 1, "red_pen": 2,
	"heal": 1, "angel_guard": 2, "help_me": 2, "hang_on": 2,
}

const SKILLS := {
	"abyss": {"name":"深渊", "desc":"无法打出。每次抽到时能量减少1，最低0。", "cost":0, "target":"self", "unplayable":true, "curse":true},
	"anya_step": {"name":"后退一步", "desc":"边缘值降低1，抽1张牌。", "cost":0, "target":"self", "finale_support":true},
	"anya_wait": {"name":"再等一分钟", "desc":"使一名角色获得1层坚毅，可抵挡虚无离场并清除虚无。", "cost":1, "target":"ally", "finale_support":true},
	"anya_resist": {"name":"抵住蛊惑！", "desc":"使一名角色获得1层负面免疫。", "cost":0, "target":"ally", "finale_support":true},
	"anya_reconcile": {"name":"自我和解", "desc":"净化一名角色的一个负面效果；虚无会清除全部层数。", "cost":0, "target":"ally", "finale_support":true},
	"anya_refuse": {"name":"不，我拒绝！", "desc":"假黎明全部消散后，获得最后1点希望，结束这场战斗。", "cost":0, "target":"self", "retain":true, "finale_support":true},
	"damp": {"name":"潮湿", "desc":"无法打出。每次抽到时，全队获得1层脆弱：每层使获得护盾降低15%，不自然消退，每次净化只减1层。逆限转入第二阶段时消耗各牌堆潮湿，每张额外增加一段暴雨倾盆。", "cost":0, "target":"self", "unplayable":true, "curse":true},
	"fear_spread": {"name":"恐惧蔓延", "desc":"支付1能量消耗此牌。回合结束仍在手牌中时，相邻位置的牌变成恐惧蔓延；恐惧蔓延不会被自动弃置。", "cost":1, "target":"self", "exhaust":true, "retain":true, "curse":true},
	"mockery": {"name":"嘲弄", "desc":"无法打出。回合结束仍在手牌中时，对我方全体造成伤害，随后正常弃置。可被主动弃置或消耗。", "cost":0, "target":"self", "unplayable":true, "curse":true},
	"ranking": {"name":"排名", "desc":"留在手牌到回合结束时，全队获得1回合颤栗。", "cost":0, "target":"self", "unplayable":true, "curse":true},
	"wound": {"name":"伤口", "desc":"无法打出，可被消耗或弃置。", "cost":0, "target":"self", "unplayable":true, "curse":true},
	"medicine": {"name":"特效药", "desc":"0费，选择并消耗一张手牌；若是伤口，可再消耗一张。", "cost":0, "target":"self", "curse":true},
	"shackle": {"name":"镣铐", "desc":"在手牌中时，本回合最多打出4张牌。", "cost":0, "target":"self", "unplayable":true, "curse":true},
	"do_not_tell": {"name":"不准告人", "desc":"回合结束仍在手牌中时，所有在场幻影获得2点力量。", "cost":0, "target":"self", "unplayable":true, "curse":true},
	"basic_strike": {"name":"普通攻击", "desc":"对一名敌人造成 6 点无极伤害。", "cost":1, "damage":6, "target":"enemy"},
	"heavy_strike": {"name":"吃我一击！", "desc":"对一名敌人造成 12 点无极伤害，附加 3 回合颤栗（受到伤害提高 50%）。", "cost":2, "damage":12, "target":"enemy", "status":"shiver", "status_turns":3},
	"block": {"name":"阻挡", "desc":"自身获得 3 点无极护盾。", "cost":1, "guard":3, "target":"self"},
	"red_pen": {"name":"红笔批注", "desc":"对全体敌人造成 5 点无极伤害；名字含试卷、考试或作业时伤害翻倍。", "cost":1, "damage":5, "target":"all_enemies", "story_unlock":true},
	"heal": {"name":"治疗", "desc":"指定一名角色恢复 10 点生命。", "cost":1, "heal":10, "target":"ally"},
	"angel_guard": {"name":"天使护卫", "desc":"全队共享 24 点外语护盾。", "cost":2, "guard":24, "target":"party", "shared_guard":true},
	"help_me": {"name":"帮帮我！", "desc":"指定一名角色获得 14 点外语护盾，并获得 1 回合嘲讽。", "cost":1, "guard":14, "target":"ally", "status":"taunt", "status_turns":1},
	"hang_on": {"name":"撑住！", "desc":"只能对濒死角色使用，回复至血量上限的一半。使用后消耗。", "cost":1, "target":"ally", "downed_only":true, "exhaust":true, "story_unlock":true},
}

const HEROES := {
	"li_anya": {"name":"李安雅", "portrait":"res://assets/graphics/battle/anya/portrait_bound.webp", "attribute":ATTR_NONE, "role":"metamorph", "identity":"幻羽涅槃 · 被困之羽 / 涅槃·幻羽", "bio":"她曾盼着有人找到自己。如今，她也会伸出手，接住身边的人。", "base_hp":36, "hp_per_level":2.0, "skills":[], "ultimate":{"name":"找到我，然后拯救我", "desc":"12点涅槃充能：队友实际给予增益（不含护盾、治疗）、打出幻形牌、每位队友每回合首次攻击施暴者均+1。进入涅槃·幻羽，队友暂离，当前生命为队友当前生命总和的1.5倍，最大生命为队友最大生命总和的1.5倍，最高可回复生命受战斗机制限制；变身不触发幻形被动护盾，抽8张牌，获得8/10/12重生计数。", "energy":12, "target":"self", "icon":"res://assets/graphics/battle/anya/icons/enter.webp"}},
	"liudanya": {"name":"刘丹雅", "portrait":"res://assets/graphics/battle/costumes/20261015/liu/portrait.webp", "attribute":ATTR_SOCIAL, "role":"painter", "identity":"艺术生 · 立志传承水墨画技艺", "bio":"艺考不考水墨画，她却始终为它留出时间。刘丹雅对水墨有独特的热忱，立志将这些笔法与技艺传承下去。", "base_hp":30, "hp_per_level":1.5, "skills":[], "ultimate":{"name":"一气呵成", "desc":"任选0–6片区域染色或洗去（不能选择彩色），未选区域保留原样；按最终三色组与水墨组总数抽牌。", "energy":6, "target":"self", "icon":"res://assets/graphics/battle/fc_art/refined/liu_icons/icon-17.webp"}},
	"suwanqing": {"name":"苏婉青", "portrait":"res://assets/graphics/battle/costumes/20261015/su/portrait.webp", "attribute":ATTR_SOCIAL, "role":"poison", "identity":"李安雅的闺蜜 · 代送照片的女孩", "base_hp":30, "hp_per_level":1.5, "skills":[], "ultimate":{"name":"该爆料了！", "desc":"依次引爆所有敌人的毒三次；每次造成当前毒层数的固定伤害，先扣护盾，随后毒减少1层并清空计数。", "energy":6, "target":"all_enemies", "icon":"res://assets/graphics/battle/fc_art/refined/su_icons/icon-14.webp"}},
	"chenmo": {"name":"陈默", "portrait":"res://assets/graphics/battle/costumes/20261015/chen/portrait.webp", "attribute":ATTR_CHINESE, "role":"defender", "base_hp":50, "hp_per_level":3.0, "skills":[], "ultimate":{"name":"都往我这边站！", "desc":"获得两回合嘲讽、反伤及S(30)护盾；两回合内反伤倍率为200%。", "energy":6, "target":"self"}},
	"xumingming": {"name":"徐明明", "portrait":"res://assets/graphics/battle/costumes/20261015/xu/portrait.webp", "attribute":ATTR_SCIENCE, "role":"mark_burst", "identity":"体育生", "base_hp":28, "hp_per_level":1.5, "skills":[], "ultimate":{"name":"一级运动员", "desc":"获得3层潜印。本回合消耗潜印造成的伤害翻倍，不叠加；无法获得个人护盾和被治疗，不可净化。", "energy":10, "target":"self"}},
	"zhoumingyuan": {"name":"周明远", "portrait":"res://assets/graphics/portraits/generated/noel/processed/anime.webp", "attribute":ATTR_NONE, "role":"attacker", "base_hp":25, "hp_per_level":1.0, "skills":["basic_strike","heavy_strike","block","red_pen"], "ultimate":{"name":"我们，永不言弃！", "desc":"指定一名敌人造成20点无极伤害，并获得一层坚毅：第一次受到的致命伤害不会造成伤害。", "energy":5, "target":"enemy", "damage":20, "status":"resilience", "icon":"res://assets/graphics/battle/skills/ultimate_zhoumingyuan.webp"}},
	"alyina": {"name":"艾莉娜", "portrait":"res://assets/graphics/portraits/generated/celia/processed/anime.webp", "attribute":ATTR_ENGLISH, "role":"healer", "base_hp":40, "hp_per_level":2.5, "skills":["heal","angel_guard","help_me","hang_on"], "ultimate":{"name":"来吧，发起总攻！", "desc":"使全队获得总攻：全体角色造成的最终伤害提高25%，持续2回合。该效果不与其他最终伤害提升叠加。", "energy":6, "target":"party", "status":"rally", "status_turns":2, "damage_out_mult":1.25, "icon":"res://assets/graphics/battle/skills/ultimate_alyina.webp"}},
	"wangjiaqi": {"name":"王嘉琪", "portrait":"res://assets/graphics/battle/fc_art/wang_portrait/clean.webp", "attribute":ATTR_SOCIAL, "role":"enchanter", "base_hp":30, "hp_per_level":1.5, "skills":[], "ultimate":{"name":"魔术技巧", "desc":"为当前所有手牌附魔，再抽三张牌，逐张选择放入手牌的位置。", "energy":8, "target":"self"}},
}

const ENEMIES := {
	"terminal_echo": {"name":"天台深渊·终末回响", "portrait":"res://assets/graphics/battle/new_enemies/terminal_echo.webp", "attribute":ATTR_NONE, "base_hp":500, "hp_per_level":20.0, "boss":true},
	"whisper_silhouette": {"name":"低语剪影", "portrait":"res://assets/graphics/battle/new_enemies/whisper_silhouette.webp", "attribute":ATTR_NONE, "base_hp":24, "hp_per_level":1.2},
	"terminal_choir": {"name":"终末合唱", "portrait":"res://assets/graphics/battle/new_enemies/terminal_choir.webp", "attribute":ATTR_NONE, "base_hp":30, "hp_per_level":1.5},
	"false_dawn": {"name":"假黎明", "portrait":"res://assets/graphics/battle/new_enemies/false_dawn.webp", "attribute":ATTR_NONE, "base_hp":38, "hp_per_level":1.8},
	"math_exam": {"name":"普通高等学校招生全国统一考试-数学卷", "portrait":"res://assets/graphics/battle/new_enemies/math_exam.webp", "attribute":ATTR_MATH, "base_hp":145, "hp_per_level":7.0},
	"perfect_score": {"name":"满分的执念", "portrait":"res://assets/graphics/battle/new_enemies/perfect_score.webp", "attribute":ATTR_SOCIAL, "base_hp":100, "hp_per_level":1.0},
	"inverse_limit": {"name":"破限心魔·逆限", "portrait":"res://assets/graphics/battle/new_enemies/inverse_limit.webp", "attribute":ATTR_SCIENCE, "base_hp":360, "hp_per_level":18.0, "boss":true},
	"cupid": {"name":"未成年丘比特", "portrait":"res://assets/graphics/battle/new_enemies/cupid.webp", "attribute":ATTR_SOCIAL, "base_hp":58, "hp_per_level":3.0},
	"zeus_dean": {"name":"神王宙斯-教导主任", "portrait":"res://assets/graphics/battle/new_enemies/zeus_dean.webp", "attribute":ATTR_SCIENCE, "base_hp":150, "hp_per_level":7.0},
	"biting_book": {"name":"咬人的书", "portrait":"res://assets/graphics/battle/new_enemies/biting_book.webp", "attribute":ATTR_CHINESE, "base_hp":64, "hp_per_level":3.5},
	"nightmare": {"name":"夜魇", "portrait":"res://assets/graphics/battle/new_enemies/nightmare.webp", "attribute":ATTR_ENGLISH, "base_hp":70, "hp_per_level":4.0},
	"panic_throat": {"name":"窒息之喉·恐慌候群", "portrait":"res://assets/graphics/battle/new_enemies/panic_throat.webp", "attribute":ATTR_NONE, "base_hp":300, "hp_per_level":15.0, "boss":true},
	"snicker_shadow": {"name":"窃笑之影", "portrait":"res://assets/graphics/battle/new_enemies/snicker_shadow.webp", "attribute":ATTR_NONE, "base_hp":20, "hp_per_level":1.0},
	"gaokao_countdown": {"name":"高考倒计时", "portrait":"res://assets/graphics/battle/new_enemies/gaokao_countdown.webp", "attribute":ATTR_NONE, "base_hp":52, "hp_per_level":2.8},
	"report_card": {"name":"一张成绩单", "portrait":"res://assets/graphics/battle/new_enemies/report_card.webp", "attribute":ATTR_MATH, "base_hp":140, "hp_per_level":6.5},
	"quiet_hacker": {"name":"低调的黑客", "portrait":"res://assets/graphics/battle/new_enemies/quiet_hacker.webp", "attribute":ATTR_SCIENCE, "base_hp":68, "hp_per_level":3.4},
	"magician_master": {"name":"魔术大师", "portrait":"res://assets/graphics/battle/new_enemies/magician_master.webp", "attribute":ATTR_SOCIAL, "base_hp":176, "hp_per_level":8.0},
	"self_destructive_pain": {"name":"自毁之痛楚", "portrait":"res://assets/graphics/battle/new_enemies/self_destructive_pain.webp", "attribute":ATTR_NONE, "base_hp":150, "hp_per_level":7.5},
	"infirmary_demon": {"name":"医务室恶魔", "portrait":"res://assets/graphics/battle/new_enemies/infirmary_demon.webp", "attribute":ATTR_SCIENCE, "base_hp":190, "hp_per_level":9.0},
	"bullied_phantom": {"name":"被霸凌的苦痛幻灵", "portrait":"res://assets/graphics/battle/new_enemies/bullied_phantom.webp", "attribute":ATTR_NONE, "base_hp":410, "hp_per_level":17.0, "boss":true},
	"fist_phantom": {"name":"拳头的幻影", "portrait":"res://assets/graphics/battle/new_enemies/fist_phantom.webp", "attribute":ATTR_NONE, "base_hp":42, "hp_per_level":2.0},
	"whip_phantom": {"name":"皮鞭的幻影", "portrait":"res://assets/graphics/battle/new_enemies/whip_phantom.webp", "attribute":ATTR_NONE, "base_hp":46, "hp_per_level":2.2},
	"bruised_hand": {"name":"淤青之手", "portrait":"res://assets/graphics/battle/new_enemies/bruised_hand.webp", "attribute":ATTR_NONE, "base_hp":55, "hp_per_level":2.5},
	"shackle_phantom": {"name":"镣铐的幻影", "portrait":"res://assets/graphics/battle/new_enemies/shackle_phantom.webp", "attribute":ATTR_NONE, "base_hp":48, "hp_per_level":2.2},
	"claustrophobic_box": {"name":"幽闭之匣", "portrait":"res://assets/graphics/battle/new_enemies/claustrophobic_box.webp", "attribute":ATTR_NONE, "base_hp":182, "hp_per_level":8.5},
	"paper_large": {"name":"试卷兽（大）", "portrait":"res://assets/graphics/battle/试卷兽（大）.webp", "attribute":ATTR_NONE, "base_hp":48, "hp_per_level":2.0, "split":true},
	"paper_small": {"name":"试卷兽（小）", "portrait":"res://assets/graphics/battle/试卷兽（小）.webp", "attribute":ATTR_NONE, "base_hp":24, "hp_per_level":1.0},
	"noise": {"name":"噪音兽", "portrait":"res://assets/graphics/battle/噪音兽.webp", "attribute":ATTR_CHINESE, "base_hp":25, "hp_every_five":5},
	"ink_wolf": {"name":"试卷兽（大）", "portrait":"res://assets/graphics/battle/试卷兽（大）.webp", "attribute":ATTR_NONE, "base_hp":48, "hp_per_level":2.0, "split":true},
	"ink_wolf_echo": {"name":"试卷兽（小）", "portrait":"res://assets/graphics/battle/试卷兽（小）.webp", "attribute":ATTR_NONE, "base_hp":24, "hp_per_level":1.0},
}

static func skill(id: String) -> Dictionary:
	if id == "lemma": return {"name":"引理", "desc":"作为弹药追击后消耗，回复1能量。", "target":"enemy", "cost":0, "exhaust":true}
	id = String(FC.ALIASES.get(id, id))
	if FC.CARDS.has(id):
		return (FC.CARDS[id] as Dictionary).duplicate(true)
	var data: Dictionary = (SKILLS.get(id, {}) as Dictionary).duplicate(true)
	if id == "damp" and TowerRun.active:
		data.desc = "无法打出。每次抽到时全队获得1层脆弱：每层护盾量-15%，尖塔中最多3层；每次净化减少1层。逆限转入第二阶段时消耗全部潮湿，最多追加3段暴雨倾盆。"
	if not data.is_empty():
		data["rarity"] = SKILL_RARITIES.get(id, "common")
		data["skill_points"] = int(SKILL_POINTS.get(id, 1))
		data["copies"] = MAX_SKILL_COPIES
	return data

static func skill_points(id: String) -> int:
	return int(skill(id).get("skill_points", 1))

static func copies(id: String) -> int:
	return int(skill(id).get("copies", MAX_SKILL_COPIES))

static func growth(level: int) -> float:
	return 1.0 + 0.03 * maxi(0, level - 1)

static func description(id: String, level: int = 1) -> String:
	var words := String(skill(id).get("desc", ""))
	var mark_formula: bool = String(skill(id).get("code", "")) in ["X03", "X06", "X09", "X11"]
	var regex := RegEx.new()
	regex.compile("[sS]\\s*[（(]\\s*(\\d+)\\s*[）)]")
	var matches := regex.search_all(words)
	for i in range(matches.size() - 1, -1, -1):
		var found: RegExMatch = matches[i]
		var scaled := float(found.get_string(1)) * growth(level)
		var number := String.num(scaled, 2) if mark_formula else str(roundi(scaled))
		words = words.substr(0, found.get_start()) + number + words.substr(found.get_end())
	return words

static func card_level(card: Dictionary) -> int:
	# Ownership stays with Anya; the borrowed actor supplies all numeric scaling.
	return FightProgression.hero_level(String(card.get("anya_actor", card.get("caster_id", ""))))

static func skills_for(hero_id: String, attribute: String = "") -> Array:
	if hero_id == "li_anya":
		return FC.CARDS.keys().filter(func(id: String) -> bool: return id.begins_with("LA"))
	var prefix := String({"zhoumingyuan":"N", "alyina":"A", "wangjiaqi":"W", "chenmo":"C", "xumingming":"X", "suwanqing":"D", "liudanya":"Y"}.get(hero_id, "?"))
	var result: Array = []
	# Show the active form first; the neutral cards remain available below it.
	if hero_id == "zhoumingyuan" and attribute == ATTR_MATH:
		for id in FC.CARDS:
			if String(FC.CARDS[id].code).begins_with("M"): result.append(id)
	for id in FC.CARDS:
		var code := String(FC.CARDS[id].code)
		if code.begins_with(prefix):
			result.append(id)
	if hero_id == "zhoumingyuan": result.append("red_pen")
	if hero_id == "alyina": result.append("hang_on")
	return result

static func target_name(target: String) -> String:
	return String({"enemy": "一名敌人", "ally": "一名队友", "party": "我方全体", "self": "自身", "all_enemies": "敌方全体"}.get(target, target))

static func statuses(unit: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if int(unit.get("finale_defiance", 0)) > 0:
		var n := int(unit.finale_defiance)
		out.append({"icon":"finale_defiance", "name":"我不接受这样的结局", "desc":"本场战斗永久最终增伤%d%%、最终减伤%d%%、护盾强效%d%%；可叠加、不可清除，李安雅退场或退出涅槃形态后仍保留。" % [25 * n, 15 * n, 30 * n], "stacks":n, "turns":-1, "uncleansable":true, "debuff":false})
	if unit.has("finale_original_max"):
		out.append({"icon":"finale_seal", "name":"终末压制", "desc":"最大生命%d不变，最高只能回复至%d。灰色区不可回复，深色区为已损失生命；不可净化。" % [unit.max_hp, mini(int(unit.max_hp), int(unit.get("finale_heal_cap", unit.max_hp)))], "debuff":true})
	if int(unit.get("guard", 0)) > 0:
		out.append({"icon": "shield", "name": "常驻护盾", "desc": "个人常驻盾 %d；本场战斗跨回合保留，耗尽或被移除后消失。个人临时盾先于此盾抵挡伤害。" % unit["guard"], "debuff": false})
	if bool(unit.get("dead", false)):
		out.append({"icon": "dead", "name": "已退场", "desc": "该角色已经退出本场战斗。", "debuff": true, "category": "role"})
	elif bool(unit.get("downed", false)):
		var downed_desc := "敌方回合开始时已濒死，且在该敌方回合受到生命伤害才会退场。" if String(unit.get("id", "")) == "zhoumingyuan" and String(unit.get("attribute", "none")) == "none" else "本回合不会退场；后续回合再次受到生命伤害会退场。"
		out.append({"icon": "downed", "name": "濒死", "desc": downed_desc, "debuff": true, "category": "role"})
	for id in (unit.get("statuses", {}) as Dictionary):
		var status: Dictionary = unit["statuses"][id]
		if id == "poison_guard":
			out.append({"icon":"poison_guard", "name":"个人临时护盾", "desc":"个人临时盾 %d；本轮敌方行动结束后消失，在共享护盾之后、个人常驻盾之前抵挡伤害。" % int(status.get("stacks", 0)), "debuff":false, "turns":int(status.get("turns", 1)), "stacks":int(status.get("stacks", 0))})
			continue
		var turns := int(status.get("turns", 0))
		var duration_text := "无回合限制" if turns < 0 else "剩余 %d 回合" % turns
		var stacks := int(status.get("stacks", 0))
		var stack_text := " · %d 层" % stacks if stacks > 1 else ""
		if id == "poison": stack_text += " · 引爆计数 %d/5 · 达到最大生命10%%时触发毒性虚弱" % int(status.get("counter", 0))
		out.append({"icon": String(id), "art_key":String(status.get("art_key", "")), "name": String(status.get("name", id)), "desc": String(status.get("desc", "")) + " " + duration_text + stack_text, "debuff": bool(status.get("debuff", true)), "category": String(status.get("category", "")), "turns":turns, "stacks":stacks})
		if id == "poison":
			out.append({"icon":"poison_counter", "name":"引爆计数", "desc":"当前 %d/5；达到5时引爆毒。技能直接引爆会清零；施毒与毒爆不计为攻击。" % int(status.get("counter", 0)), "debuff":false, "category":"counter", "stacks":int(status.get("counter", 0)), "badge_text":"%d/5" % int(status.get("counter", 0))})
	var marks: Dictionary = unit.get("marks", {})
	var weakness: float = FightSystem.fc.POISON.weakness(FightSystem.fc, unit)
	if weakness > 0:
		out.append({"icon":"poison_weakness", "name":"毒性虚弱", "desc":"毒层数达到最大生命的10%%，造成的普通伤害降低%d%%。随毒层数变化，不是可单独净化的负面效果。" % roundi(weakness * 100), "debuff":true, "category":"debuff"})
	for attribute in marks:
		out.append({"icon": String(attribute), "name": attr_name(String(attribute)) + "标记", "desc": "剩余 %d 回合；可被对应技能触发属性反应。" % int(marks[attribute]), "debuff": true})
	return out

static func hero(id: String, attribute: String = "") -> Dictionary:
	var result: Dictionary = (HEROES.get(id, {}) as Dictionary).duplicate(true)
	var equipped := attribute if not attribute.is_empty() else String(GameState.fight_attributes.get(id, ATTR_NONE))
	if not result.is_empty(): result["skills"] = skills_for(id)
	if id == "zhoumingyuan":
		# All battle menus use the equipped form; story portraits stay independent.
		var costume := "zhou_math" if equipped == ATTR_MATH else "zhou_wuji"
		if equipped == ATTR_MATH: result["role"] = "frequent_attacker"
		result["portrait"] = "res://assets/graphics/battle/costumes/20261015/" + costume + "/portrait.webp"
	if not result.is_empty():
		result["portrait"] = preload("res://scripts/data/battle_portrait_data.gd").path(id, equipped, String(result.portrait))
	return result

static func card_owner(card: Dictionary) -> Dictionary:
	if String(card.get("caster_id", "")) == "li_anya":
		var result := hero("li_anya")
		if String(card.get("skill_id", "")).begins_with("LP"): result.portrait = "res://assets/graphics/battle/anya/portrait_phoenix.webp"
		return result
	if bool(skill(String(card.get("skill_id", ""))).get("finale_support", false)):
		return {"name":"李安雅", "portrait":preload("res://scripts/data/battle_portrait_data.gd").path("li_anya", "", "res://assets/graphics/battle/finale/anya_refuse.webp")}
	if bool(skill(String(card.get("skill_id", ""))).get("curse", false)):
		return {"name":"敌方干扰", "portrait":interference_icon_path(String(card.skill_id))}
	return hero(String(card.get("original_caster", card.get("caster_id", ""))))

static func ultimate(hero_id: String, attribute: String = "") -> Dictionary:
	if hero_id == "zhoumingyuan" and attribute == ATTR_MATH:
		return {"name":"解已确定", "desc":"首次获得注意到：作用于敌方的技能即可触发追击。后续锁定一名敌人并加入两张引理；引理追击后消耗并回复1能量。本终结技不触发追击。", "energy":5, "target":"enemy", "icon":"res://assets/graphics/battle/skills/math_burst.webp"}
	var data: Dictionary = hero(hero_id).get("ultimate", {}) as Dictionary
	data = data.duplicate(true)
	if hero_id == "zhoumingyuan": data["desc"] = "对一名敌人造成%d点无极伤害，并获得一层坚毅：免疫一次致命伤害，可叠加层数。" % roundi(20.0 * growth(FightProgression.hero_level(hero_id)))
	if hero_id == "alyina": data["desc"] = "全队最终伤害提高25%，持续两回合；与其他最终伤害加成加算。"
	if hero_id == "wangjiaqi": data["icon"] = "res://assets/graphics/battle/fc_art/refined/icons/ultimate_wang.webp"
	if hero_id == "chenmo":
		data["desc"] = "获得两回合嘲讽、反伤和%d点护盾；两回合内反伤倍率为200%%。" % roundi(30.0 * growth(FightProgression.hero_level(hero_id)))
		data["icon"] = "res://assets/graphics/battle/fc_art/refined/icons/A03.webp"
	if hero_id == "xumingming": data["icon"] = "res://assets/graphics/battle/fc_art/refined/icons/N06.webp"
	return data

static func passive(hero_id: String, attribute: String = "") -> String:
	match hero_id:
		"li_anya": return "幻羽涅槃：幻形仅从在场队友本局携带的非幻形牌中选择，牌属于李安雅，效果由原角色完整执行。每次成功幻形获得2/3/4护盾（按突破）。特殊充能12后进入涅槃·幻羽：队友暂离，全部技能保留、消耗8/10/12重生计数；退场技能自动释放。"
		"liudanya": return "画中丹青：经营六格未完的画作。白＋墨组成水墨组，红＋黄＋蓝组成三色组；每格只能计入一组。彩色可替代任意颜色，先用原色，优先补三色组。染色覆盖原色，洗去恢复白色。"
		"suwanqing": return "我的毒，没有解药：每5段攻击或技能引爆毒，造成等于层数的固定伤害，先扣护盾，随后毒减1层、计数清零。毒可一次净化清空。毒达到敌人最大生命的10%时，其普通伤害降低10%/15%/20%（按突破），不作为独立负面效果。"
		"chenmo": return "舍己护阵：嘲讽期间分担队友护盾结算后30%/40%/50%的生命伤害（按突破）；反伤将护盾吸收的伤害100%反弹。嘲讽和反伤持续回合可累加，全队仅保留最后获得的嘲讽。"
		"xumingming": return "体育生 · 坚持就是胜利：每弃置一张手牌，自身获得1/2/3层潜印（按突破）；回合结束自动弃牌不触发。技能积累并消耗潜印爆发；比例返还及增加向下取整。潜印不会因回合结束衰减。"
		"zhoumingyuan":
			if attribute == ATTR_MATH: return "验算：锁定唯一敌人；己方技能命中锁定目标后，消耗演算区队首弹药追击S(6)。追击不触发自身，每次充能1；数学终结技不触发追击。"
			return "绝不认输：正生命低于30%时最终伤害+10%/15%/20%；濒死时+25%/30%/35%（按突破）。仅敌方回合开始已濒死且该回合受到生命伤害才会退场。"
		"alyina": return "保护你！全部技能保留；任意队友打出保留牌，获得艾莉娜最大生命3%/5%/10%的共享临时护盾，优先消耗，持续一轮。"
		"wangjiaqi": return "排出一场好戏：附魔首牌追加20%/25%/30%真实伤害；中牌支援我方后抽1；末牌获得1魔术计数，每3点回1能量。附魔用后移除，可跨回合。"
	return ""

static func ultimate_energy(hero_id: String) -> int:
	return maxi(1, int(ultimate(hero_id).get("energy", ULT_ENERGY)))

static func enemy(id: String) -> Dictionary:
	return (ENEMIES.get(id, {}) as Dictionary).duplicate(true)

static func attr_name(attribute: String) -> String:
	return String(ATTR_NAMES.get(attribute, attribute))

static func has_advantage(attacker: String, defender: String) -> bool:
	return (ADVANTAGE.get(attacker, []) as Array).has(defender)

static func max_hp(hero_id: String, level: int) -> int:
	var data := hero(hero_id)
	return roundi(float(data.get("base_hp", 25)) + float(data.get("hp_per_level", 1.0)) * maxi(0, level - 1))

static func enemy_hp(enemy_id: String, level: int, fluctuation: int = 0) -> int:
	var data := enemy(enemy_id)
	var hp := float(data.get("base_hp", 1)) + float(data.get("hp_per_level", 0.0)) * maxi(0, level - 1)
	if data.has("hp_every_five"):
		hp += floori(float(level) / 5.0) * int(data["hp_every_five"])
	var authored := roundi(hp) + fluctuation
	return TowerData.enemy_hp(enemy_id, level, authored) if TowerRun.active else authored

static func unlock_level(skill_id: String) -> int:
	var original := int(skill(skill_id).get("unlock_level", 1))
	if skill(skill_id).has("anya_form"): return original
	return int({1:1, 3:10, 5:20, 7:30, 10:40}.get(original, original)) if TowerRun.active else original

const INTERFERENCE_IDS := ["abyss", "damp", "fear_spread", "mockery", "ranking", "wound", "medicine", "shackle", "do_not_tell"]
const INTERFERENCE_ART := "res://assets/graphics/battle/icons/interference/20261017/"

static func interference_icon_path(skill_id: String) -> String:
	return INTERFERENCE_ART + skill_id + "_icon.webp" if skill_id in INTERFERENCE_IDS else ""

static func skill_icon(skill_id: String) -> Texture2D:
	if skill_id in INTERFERENCE_IDS:
		return load(interference_icon_path(skill_id)) as Texture2D
	if skill_id.begins_with("anya_"): return load("res://assets/graphics/battle/finale/%s.webp" % skill_id) as Texture2D
	skill_id = String(FC.ALIASES.get(skill_id, skill_id))
	var artwork := preload("res://scripts/data/battle_art.gd").icon(String(skill(skill_id).get("code", skill_id)))
	if artwork != null: return artwork
	var path := "res://assets/graphics/battle/skills/%s.webp" % skill_id
	if ResourceLoader.exists(path): return load(path) as Texture2D
	var def := skill(skill_id)
	var code := String(def.get("code", skill_id))
	# Reuse existing authored art by function until individual card artwork is supplied.
	var fallback := "basic_strike" if def.has("damage") else "heal" if def.has("heal") else "angel_guard" if def.has("guard") else "no_attribute_focus"
	if code.begins_with("M") or skill_id == "lemma": fallback = "math_burst"
	elif code.begins_with("W") and not def.has("damage"): fallback = "social_rally"
	elif code in ["N05", "N11"]: fallback = "heal"
	elif code == "A12": fallback = "angel_guard"
	elif code.begins_with("A") and not def.has("heal") and not def.has("guard"): fallback = "angel_blessing"
	return load("res://assets/graphics/battle/skills/%s.webp" % fallback) as Texture2D

static func default_loadout(hero_id: String, attribute: String = "") -> Array:
	if hero_id == "zhoumingyuan" and attribute == ATTR_MATH:
		return ["M01", "M01", "M01", "M02", "M02", "M02", "M03"]
	match hero_id:
		"li_anya": return ["LA01", "LA02", "LA02", "LA03", "LA04", "LA04"]
		"liudanya": return ["Y01", "Y01", "Y01", "Y02", "Y02", "Y04"]
		"suwanqing": return ["D01", "D01", "D01", "D02", "D03", "D03"]
		"chenmo": return ["C01", "C01", "C01", "C02", "C02", "C03"]
		"xumingming": return ["X01", "X01", "X01", "X02", "X02", "X03"]
		"zhoumingyuan": return ["basic_strike", "basic_strike", "basic_strike", "block", "block", "block", "heavy_strike"]
		"alyina": return ["heal", "heal", "heal", "angel_guard", "help_me", "help_me"]
		"wangjiaqi": return ["W01", "W01", "W01", "W02", "W02", "W02", "W03"]
	return []

static func rarity_name(id: String) -> String:
	return RARITIES[skill(id).get("rarity", "common")].name

static func rarity_color(id: String) -> Color:
	return RARITIES[skill(id).get("rarity", "common")].color
