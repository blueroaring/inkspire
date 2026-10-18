extends RefCounted
## Read-only catalogue. Shared card/status/enemy terms come from their existing definitions.
const CARDS := preload("res://scripts/data/battle_card_effects.gd")
const STATUS := preload("res://scripts/fight/status_rules.gd")
const ENEMY_TERMS := preload("res://scripts/data/enemy_bestiary_terms.gd")
const ART := preload("res://scripts/data/battle_art.gd")
const CATEGORIES := {"all":"全部", "core":"基础规则", "cards":"卡牌词条", "statuses":"状态效果", "heroes":"角色机制", "enemies":"敌方机制"}

# [title, description, icon source]. Fixed counts and percentages stay explicit.
const CORE := {
	"energy":["战斗能量", "打出技能消耗战斗能量；每次我方回合开始恢复。通常上限随突破为3／5／7，额外收益按对应技能结算。终结技使用独立充能。", "glyph:energy"],
	"draw":["抽牌与手牌上限", "普通战斗起手抽3＋出战人数＋突破阶数；后续每回合抽3＋出战人数的一半向上取整＋突破阶数。按开战人数计算。通常手牌上限12张，保留牌也占格，超出部分进入弃牌堆。特殊战斗规则可改变上限。", "glyph:counterfeit"],
	"discard":["弃牌与洗牌", "使用后的普通技能进入弃牌堆；回合结束弃置未保留手牌。抽牌堆用尽时，将弃牌堆洗回再抽。主动弃置与回合结束自动弃牌触发的角色效果不同。", "glyph:counterfeit"],
	"ultimate":["终结技与充能", "角色积累足够终结技能量后才能释放终结技，通常不消耗战斗能量。各角色所需充能不同；数学周明远通过追击充能，李安雅使用施暴者联动充能。", "glyph:innate"],
	"normal_damage":["普通伤害", "基础伤害按技能与等级确定，再计算各项增伤、减伤、目标减伤和最终修正，最后四舍五入。正常先扣护盾，再扣生命；多段攻击逐段结算。", "glyph:attack"],
	"true_damage":["真实伤害", "穿过护盾直接扣除生命。附魔首牌的追加真伤依照该次攻击计算；坚毅、阶段保护等特殊规则仍可生效。毒爆与反伤按各自规则结算。", "glyph:shield_break"],
	"fixed_damage":["固定伤害", "毒爆与反伤不再乘普通伤害的等级、克制和增减伤倍率，通常仍先扣护盾。敌人特殊结算规则仍可影响最终结果。", "glyph:target"],
	"hp_loss":["失去生命", "自损、隐痛等直接扣除生命的效果不等同于普通攻击，不经普通伤害倍率与护盾结算；是否濒死、退场或损失最大生命以对应效果为准。", "status:downed"],
	"guard_order":["护盾结算顺序", "通常依次消耗：全队临时护盾 → 共享护盾 → 个人临时护盾 → 个人常驻护盾 → 生命。真实伤害及明确写明穿盾的效果另行处理。", "glyph:shield"],
	"shield":["个人常驻护盾", "只保护持有者，本场战斗跨回合保留，耗尽或被移除后消失。个人临时护盾先于常驻护盾消耗。", "status:shield"],
	"shared_guard":["共享护盾", "全队共用同一护盾池，任一队员受伤时都可消耗；先于个人护盾抵挡。共享常驻盾跨回合保留。", "status:shield"],
	"temporary_guard":["全队临时护盾", "全队共用，优先于其他护盾消耗，在下一次我方回合开始时清空。艾莉娜被动可通过队友打出保留牌获得。", "status:temporary_guard"],
	"downed":["濒死", "生命降至非正数时进入濒死，仍可使用技能。敌方回合开始已濒死的角色，受到新的生命伤害会退场；护盾完全挡住的伤害不会导致退场。治疗至正生命可解除濒死。", "status:downed"],
	"dead":["退场", "退出本场战斗并移除该角色的卡牌，普通治疗无法使其回场。复活、涅槃回场等明确的特殊效果按各自规则处理。", "status:dead"],
	"attributes":["属性克制", "克制时最终伤害修正＋50%，被克制时－50%；无极不参与克制。五种学科各克制两种、被两种克制，完整关系见「属性克制」。", "glyph:attribute_none"],
	"attribute_marks":["属性标记", "目标身上带有持续回合的学科标记；是否施加、触发或移除标记取决于技能说明。标记与角色自身属性、属性克制是不同信息。", "status:chinese"],
	"cleanse":["净化", "移除可净化的负面状态；标明不可净化的状态保留。毒、虚无、知识遗忘等一次清空；脆弱、反噬、消亡等每次只减1层。具体技能可能限定目标或状态。", "glyph:healing"],
	"dispel":["驱散", "移除敌人的可解除增益。带有不可解除标记的战斗规则不会被移除；自我封闭每次驱散只减1层。", "glyph:shield_break"],
	"targeting":["单体、群体与弹射", "单体技能选择一个合法目标；群体技能分别命中各目标；弹射逐段选择目标，可能重复命中。嘲讽影响单体选取，群体仍可命中其他目标。", "glyph:all"],
}

const STATUS_DETAILS := {
	"cleanseable_immunity":["可净化负面免疫", "每层抵挡一次可净化负面状态，不抵挡不可净化效果。临时与常驻层数可共存，优先消耗临时层数；临时层数在本轮敌方行动结束后消失。", "status:cleanseable_immunity"],
	"no_guard":["迎着死亡", "无法获得个人护盾；共享护盾仍有效。持续时间以技能或状态面板为准。", "status:no_guard"],
	"rally":["总攻", "提高全队最终伤害，与其他最终修正加算。艾莉娜终结技提供25%，持续2回合；其他来源以技能说明为准。", "status:rally"],
	"noticed":["注意到", "数学周明远获得后，作用于敌方的技能即可触发对锁定目标的追击；数学终结技本身不触发。仍需有效锁定目标与演算弹药。", "status:noticed"],
	"poison":["毒", "叠加毒层数；每受到5段攻击或被技能直接引爆时，造成当前毒层数的固定伤害，先扣护盾，再减少1层毒。技能直接引爆会清空引爆计数；一次净化可清空毒。", "status:poison"],
	"poison_counter":["引爆计数", "带毒目标每受到1段攻击增加1点，达到5时引爆；多段攻击逐段计数。施毒、毒爆本身不算攻击。直接引爆会清零。", "status:poison_counter"],
	"poison_weakness":["毒性虚弱", "苏婉青在场时，毒达到目标最大生命10%（向上取整）使其普通伤害降低10%／15%／20%（按突破）。随毒量变化，不是可单独净化的状态；毒爆不受此减伤影响。", "status:poison_weakness"],
	"grudge":["记仇", "本回合每受到一段攻击，在该段可能触发的毒引爆后，再获得1层毒。", "status:grudge"],
	"hair_pull":["扯头花", "持有者每段攻击结束后，自身获得2层毒；可净化。", "status:hair_pull"],
	"backlash":["反噬", "施加新层数时立即结算该层；以后每回合按当时最大生命的5%×层数扣减最大和当前生命，向下取整。濒死时直接退场；净化只减1层。", "status:backlash"],
	"perishing":["消亡", "每层使受到的最终伤害提高25%，不会自然消退；净化只减1层。", "status:perishing"],
	"gossip_draw":["讲个爆的", "每引爆一次毒抽1张牌；重复使用延长持续回合。", "status:gossip_draw"],
	"offstage":["离场", "暂时免疫伤害且不被敌人锁定，无法直接释放技能或终结技；持续至技能规定的时间。与永久退场不同。", "status:offstage"],
	"latent_marks":["潜印", "徐明明主动弃置手牌时获得潜印；回合结束自动弃牌不触发。用于技能蓄力与爆发，不随回合结束衰减。", "status:latent_marks"],
	"restraint":["收力", "每次消耗潜印后返还50%，向下取整；层数表示剩余返还次数。PB恢复期内不能获得返还。", "status:restraint"],
	"pb_lock":["PB · 恢复期", "无法获得潜印，包括收力返还；持续3回合，不可净化。", "status:pb_lock"],
	"athlete_burst":["一级运动员", "本回合消耗潜印造成的伤害翻倍，不叠加；无法被治疗或获得个人护盾，不可净化。", "status:athlete_burst"],
	"last_stand":["孤注一掷", "本场战斗无法被治疗，不可净化。", "status:last_stand"],
	"trust":["信任", "造成的普通伤害提高20%，持续2回合；属于普通增伤。", "status:trust"],
	"trust_pending":["信任链接", "本轮没有损失生命时，下回合获得持续2回合的信任。护盾吸收不算损失生命。", "status:trust_pending"],
	"damage_record":["以逸待劳", "记录本轮承受的护盾及生命伤害，下回合转为护盾。", "status:damage_record"],
	"calculation_pending":["精密计算", "本轮未损失生命，额外获得2点终结技能量。", "status:calculation_pending"],
	"pain_guard":["无惧疼痛", "受到的普通伤害降低50%，持续至本轮敌方行动结束。", "status:pain_guard"],
	"reflect_double":["都往我这边站", "反伤倍率提高至200%，持续2回合；须同时具有反伤状态。", "status:reflect_double"],
	"armor_break":["碎甲", "攻击有个人护盾的目标时，整段伤害提高50%；重复获得延长回合数。", "status:armor_break"],
	"shield_strength":["护盾强效", "增加获得的护盾量；个人常驻盾与临时盾均生效，共享盾按施盾者计算一次。绘画技能每次增加50%；终末援助的永久加成为每次30%。", "status:shield_strength"],
	"swift":["疾行", "下一次技能耗能为0；每次释放消耗1层。", "status:swift"],
	"sketch":["素描", "仅下次技能抵消全部洗去操作；即使下次技能没有洗去，也会消失。", "status:sketch"],
	"anya_abuser":["施暴者", "每位队友本回合首次对被标记敌人造成攻击、毒爆或反伤，为李安雅增加1点涅槃充能。", "status:anya_abuser"],
	"anya_buffer":["缓冲", "每层抵挡一次护盾结算后的生命伤害；附带反伤时，按本次阻挡值反伤。", "status:anya_buffer"],
	"anya_shelter":["不惧，我在", "受到的普通伤害降低10%，持续至本轮敌方行动结束。", "status:anya_shelter"],
	"anya_unbroken":["我还在这里", "涅槃形态生命最低保留1；仅在重生计数耗尽或无可负担技能时退场，不可清除。", "status:anya_unbroken"],
	"anya_rally":["总攻·直到天亮", "每层增加20%最终伤害，可叠加；涅槃形态的持续增益。", "status:anya_rally"],
	"finale_defiance":["我不接受这样的结局", "每次使用永久增加全队25%最终伤害、15%最终减伤和30%护盾强效；本场战斗可叠加、不可清除，李安雅退场或退出涅槃后仍保留。", "status:finale_defiance"],
	"item_exposed":["破绽墨迹", "受到的普通伤害提高15%，本轮敌方行动结束后消失。", "status:item_exposed"],
	"hidden_pain":["隐痛", "回合结束一次性失去等于层数的生命，可陷入濒死；疼痛放大会额外结算，层数不消耗。净化清空全部层数。", "status:hidden_pain"],
}

const HERO_RULES := {
	"calculation":["演算区与弹药", "数学周明远把技能放入演算区作为弹药，按队首顺序消耗并追击锁定敌人。演算区独立于抽牌、弃牌与消耗堆。", "glyph:counterfeit"],
	"lock":["锁定与追击", "数学周明远锁定唯一敌人，己方技能命中锁定目标后消耗演算区队首弹药追击。追击不触发自身，每次充能1；注意到可扩大触发条件。", "glyph:target"],
	"lemma":["引理", "特殊演算弹药；追击后消耗并回复1点战斗能量。", "skill:lemma"],
	"magic_count":["魔术计数", "王嘉琪的附魔牌在手牌末位打出时增加1点魔术计数，每累计3点回复1点战斗能量。首位、中位、末位效果按打出时的位置判断。", "skill:magic_card"],
	"painting":["六格画作", "刘丹雅拥有6片画作区域，初始全白。染色覆盖原色，洗去恢复白色；颜色与分组保留到后续技能使用。", "skill:Y01"],
	"ink_group":["水墨组", "白色＋墨色组成1组；每格只能计入1组。部分技能使用水墨组后洗去对应区域。", "skill:Y08"],
	"tri_group":["三色组", "红色＋黄色＋蓝色组成1组；每格只能计入1组。分组时先组成三色组，再组成水墨组。", "skill:Y07"],
	"rainbow":["彩色", "可替代分组所需的任意一种颜色，优先使用原色，先补三色组。彩色占据1格，不会同时计入多个组。", "skill:Y10"],
	"morph":["幻形", "李安雅从在场队友本局携带的非幻形技能中选择变牌。牌属于李安雅，效果由原角色执行；每次成功幻形获得个人护盾。", "path:res://assets/graphics/battle/anya/icons/LA01.webp"],
	"phoenix":["涅槃·幻羽", "特殊充能达到12后变身，队友暂离；当前与最大生命分别取队友对应生命总和的1.5倍，抽8张牌。技能切换为涅槃版本，保留并消耗重生计数。", "path:res://assets/graphics/battle/anya/icons/enter.webp"],
	"rebirth":["重生计数", "涅槃形态按突破获得8／10／12点；涅槃技能以重生计数支付费用。计数耗尽或三处牌堆均无可负担技能时，自动触发退场技能。", "glyph:rebirth"],
	"anya_return":["涅槃回场", "正常退出时平分剩余生命给队友，李安雅回复至可回复上限；被击败时她濒死、队友以1生命回场，并取消本回合后续伤害。两种情况都会清除全队负面效果并获得3点涅槃充能。", "path:res://assets/graphics/battle/anya/icons/return.webp"],
}

# Existing enemy glossary names map to the same icons shown over combatants.
const TERM_ICONS := {
	"睡眠不佳":"sleep_bad", "爱意":"love", "迷魂":"confusion", "沉默":"silence", "知识遗忘":"forgetfulness",
	"天书":"book_power", "自我封闭":"self_seal", "违纪标记":"sentence", "惩戒之雷":"thunder_rule",
	"无实体":"offstage", "支配":"domination", "隔离":"isolation", "痛楚":"pain_stacks", "窒息":"suffocation",
	"无意义":"nullify", "虚无":"void", "该结束了":"it_ends", "极限":"limit", "终末压制":"finale_seal",
	"终末逼近":"finale_power", "吸血":"lifesteal", "难以销毁":"damage_cap", "遁逃术":"evasion",
	"无处可逃":"no_escape", "嘲讽":"taunt", "反抗援助":"helpless", "被攻击计数":"summon_hits",
	"边缘值":"finale_power", "希望":"finale_defiance", "反伤":"reflect",
}
const ENEMY_RULES := {
	"exam_function":["函数档位", "数学卷共有10档函数；每次函数攻击后前进2档，每次损失生命后退1档，护盾吸收不会退档。", "status:exam_function"],
	"score_rule":["分数", "满分的执念所有正伤害最多结算1点，不能靠伤害击败。每次命中计6分，原伤害每20点额外1分、最多额外4分；毒爆和反伤计入。敌方回合开始结算分数，达到100分退场。", "status:score_rule"],
	"countdown_rule":["倒计时", "高考倒计时从3开始倒数；倒计时结束会发动爆发攻击并施加眩晕。查看敌人意图可确认当前攻击与目标。", "status:countdown_rule"],
	"hacker_stolen":["卡牌窃取", "黑客夺取的牌暂时无法抽到或使用；击败黑客后归还弃牌堆。木马感染则留在原卡上，两者是不同干扰。", "status:hacker_stolen"],
	"paper_split":["分裂", "大试卷兽生命降至一半或以下时准备分裂；行动时本体退场，变为2只小试卷兽。可在分裂行动前击败本体。", "status:paper_split"],
	"field_rain":["阴雨低压 · 脚滑", "我方普通攻击、技能与追击每段基础伤害降低，最低为0；毒爆和反伤等固定伤害不受影响。", "status:field_rain"],
	"field_wound":["旧伤回响 · 伤病复发", "每打出1张攻击牌，使用者获得1层隐痛。回合结束一次性失去等于层数的生命；净化清空全部隐痛。", "status:field_wound"],
	"field_mirror":["破限镜像 · 镜像复制", "每回合回放上一回合第一张攻击牌的伤害段，全部指向原使用者；不复制其他效果。", "status:field_mirror"],
	"helpless":["习得性无助", "苦痛幻灵本体不攻击，召唤幻影并施加干扰。拳头、皮鞭和镣铐幻影与本体共享生命；击败幻影为反抗援助充能。", "status:helpless"],
	"shadow_taunt":["窃笑嘲讽", "单体敌方技能必须先选择窃笑之影，不可解除；群体技能仍可命中其他敌人。", "status:shadow_taunt"],
	"hand_taunt":["求助嘲讽", "单体技能须先选中淤青之手；受到的普通伤害降低20%，持续2回合。", "status:shadow_taunt"],
	"shackle_lock":["锁缚", "生效期间，仅手牌首位、中间位置与末位的牌可以打出；可通过整理位置应对。", "glyph:sealed"],
	"finale_locked":["假黎明锁定", "被锁定的牌本回合无法打出，回合结束破碎并进入消耗区。", "glyph:sealed"],
	"blood_draw":["抽血", "医务室恶魔攻击造成生命伤害时，回复该生命伤害150%的生命；完全由护盾吸收的伤害不会触发。", "status:blood_draw"],
}

static func _entry(id: String, category: String, data: Array) -> Dictionary:
	var source := String(data[2])
	return {"id":id, "category":category, "name":String(data[0]), "desc":String(data[1]), "icon_kind":source.get_slice(":", 0), "icon_id":source.substr(source.find(":") + 1)}

static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in CORE: result.append(_entry(id, "core", CORE[id]))
	for id in CARDS.DEFINITIONS:
		var data: Array = CARDS.DEFINITIONS[id]
		result.append(_entry("card_" + id, "cards", [data[0], data[1], "glyph:" + id]))
	for id in STATUS.DEFINITIONS:
		var data: Dictionary = STATUS.DEFINITIONS[id]
		result.append(_entry(id, "statuses", [data.name, data.desc, "status:" + id]))
	for id in STATUS_DETAILS: result.append(_entry(id, "statuses", STATUS_DETAILS[id]))
	for term in ENEMY_TERMS.EXTRA:
		# These terms already have a shared card/status definition above.
		if term in ["黑暗遮蔽", "木马", "护盾强效"]: continue
		var id := String(TERM_ICONS.get(term, "debuff"))
		var data := [term, ENEMY_TERMS.EXTRA[term], "status:" + id]
		if term == "吸血": data[1] = "攻击造成生命伤害时回复生命。周明远的吸血作用于下一次攻击并等量回复；医务室恶魔的抽血回复比例为150%。"
		var term_id := "edge" if term == "边缘值" else "hope" if term == "希望" else id
		result.append(_entry("enemy_term_" + term_id, "enemies", data))
	for id in ENEMY_RULES: result.append(_entry("enemy_" + id, "enemies", ENEMY_RULES[id]))
	var card_ids: Array = FightData.INTERFERENCE_IDS.duplicate()
	card_ids.append_array(preload("res://scripts/fight/finale_rules.gd").SUPPORT)
	for id in card_ids:
		var card := FightData.skill(id)
		result.append(_entry("interference_" + id, "cards", [card.name, card.desc, "skill:" + id]))
	for id in HERO_RULES: result.append(_entry("hero_" + id, "heroes", HERO_RULES[id]))
	# The guide remains complete even if a hero or alternate form is not currently equipped.
	for id in FightData.HEROES:
		for attribute in (["none", "math"] if id == "zhoumingyuan" else [String(FightData.HEROES[id].attribute)]):
			var hero := FightData.hero(id, attribute)
			var title := String(hero.name) + (" · " + FightData.attr_name(attribute) if id == "zhoumingyuan" else "") + " · 角色被动"
			result.append(_entry("passive_" + id + "_" + attribute, "heroes", [title, FightData.passive(id, attribute), "path:" + String(hero.portrait)]))
	return result

static func matches(entry: Dictionary, query: String, category: String = "all") -> bool:
	if category != "all" and entry.category != category: return false
	var words := (String(entry.name) + " " + String(entry.desc) + " " + String(CATEGORIES[entry.category])).to_lower()
	for word in query.strip_edges().to_lower().split(" ", false):
		if not words.contains(word): return false
	return true

static func texture(entry: Dictionary) -> Texture2D:
	var id := String(entry.icon_id)
	match String(entry.icon_kind):
		"status": return ART.status_icon(id, true)
		"skill": return FightData.skill_icon(id)
		"path": return load(id) as Texture2D if ResourceLoader.exists(id) else null
	return null
