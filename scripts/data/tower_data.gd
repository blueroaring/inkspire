class_name TowerData
extends RefCounted
## The seed fixes ordinary formations for a save; milestones never depend on RNG.
const VERSION := "tower-0.2.0"
const GAME_TITLE := "高中异闻：尖塔"
const LESSON_OBSERVATIONS := {
 "li_anya":["选择一张队友本局携带的低级非幻形牌。该牌归李安雅所有，由原角色执行；李安雅获得幻形护盾。", "观察施暴者标记与涅槃充能。每位队友每回合首次攻击标记目标可为李安雅充能1；打出幻形牌也能充能。"],
 "zhoumingyuan":["看看下方周明远的状态：生命减少了，护盾增加了。低生命能触发绝境，但也更容易阵亡，记得让队友保护他。", "敌人已经有了颤栗。接下来可以让艾莉娜加护盾或治疗，别让周明远因继续扣血而阵亡。"],
 "alyina":["全队外侧出现了共享护盾，可以替队友挡伤害。带「保留」的治疗牌不用急着打，可以留到需要回血时再用。", "现在让周明远打出「普通攻击」。结束回合后，看看刚才加的护盾替队友挡了多少伤害。"],
 "chenmo":["陈默有了嘲讽和个人护盾。嘲讽会让敌人优先攻击他，护盾可以帮他挡伤害。", "陈默现在有了反伤。结束回合，让敌人攻击他，看看敌人受到的反伤和陈默剩余的护盾。"],
 "xumingming":["徐明明获得了两层潜印。先把潜印攒起来，接下来的攻击就能用上。", "这次攻击消耗了潜印，可以对比伤害预览。记住这个顺序：先攒潜印，再打「起跑枪声」。"],
 "wangjiaqi":["看看手牌上的附魔标记。哪些牌有附魔、排在第几张，都会影响攻击效果，右键可以查看卡牌详情。", "接着让周明远打出「普通攻击」，看看附魔牌和第一张牌的位置。之后可以用「换一下顺序」调整牌序。"],
 "suwanqing":["看看刚才那个敌人身上的毒层数。下一张「催化针」也要打它。", "看看引爆造成的伤害，以及敌人还剩几层毒。先施毒再引爆；队友的攻击也能推进引爆计数。"],
 "liudanya":["画布弹出后，点一个可用区域，选好颜色再确认染色。下方的六块画布会显示结果。", "这次选刚才染色的区域，把颜色洗掉再确认。看看画布空出了哪里，又获得了多少护盾。"]
}
const NORMAL_FLOORS := 60
const HERO_CAP := 50
const ENEMY_CAP := 70
const RECOVERY_DESCRIPTION := "首通恢复：1–20层精英1次、首领2次；21–40层2/3次；41–60层3/4次；极限每层4次。"
const HEROES := ["zhoumingyuan", "alyina", "chenmo", "xumingming", "wangjiaqi", "suwanqing", "liudanya", "li_anya"]
const WEAPONS := {"zhoumingyuan":"ember_brooch", "alyina":"guardian_knot", "chenmo":"mirror_pin", "xumingming":"sprinter_band", "wangjiaqi":"stage_locket", "suwanqing":"herb_pendant", "liudanya":"pigment_charm", "li_anya":"phoenix_ribbon"}
# Ranks follow request/14_FIGHT_CHARACTER.md. Complex mechanics do not imply elite rank.
const ELITES := [["report_card"], ["zeus_dean"], ["magician_master"], ["infirmary_demon"], ["report_card", "report_card"], ["zeus_dean", "report_card"]]
const BOSSES := [["panic_throat"], ["inverse_limit"], ["bullied_phantom"], ["panic_throat"], ["bullied_phantom"], ["inverse_limit", "terminal_echo"]]
# Eight ordinary encounters per ten floors: four introductions, then four combinations.
# Shuffle only within each four-floor segment, so late mechanics cannot leak into the opening.
# Heavy ordinary enemies start alone; avoid stacking several hand-locking rules together.
const MOB_BANDS := [
	[["paper_small"], ["noise"], ["paper_small", "noise"], ["paper_large"], ["biting_book"], ["paper_small", "paper_small"], ["paper_large", "noise"], ["cupid"]],
	[["biting_book", "noise"], ["cupid", "paper_small"], ["nightmare"], ["paper_large", "paper_small"], ["quiet_hacker"], ["biting_book", "paper_small"], ["cupid", "noise"], ["gaokao_countdown", "paper_small"]],
	[["math_exam"], ["nightmare", "paper_small"], ["quiet_hacker", "noise"], ["gaokao_countdown", "biting_book"], ["perfect_score"], ["cupid", "biting_book"], ["paper_large", "noise", "paper_small"], ["nightmare", "noise"]],
	[["claustrophobic_box"], ["quiet_hacker", "paper_small"], ["math_exam", "noise"], ["cupid", "paper_large"], ["perfect_score", "paper_small"], ["biting_book", "noise", "paper_small"], ["gaokao_countdown", "noise"], ["nightmare", "cupid"]],
	[["claustrophobic_box", "paper_small"], ["math_exam", "biting_book"], ["quiet_hacker", "cupid"], ["self_destructive_pain"], ["perfect_score", "noise"], ["gaokao_countdown", "paper_large"], ["nightmare", "paper_small", "noise"], ["biting_book", "cupid", "paper_small"]],
	[["self_destructive_pain", "paper_small"], ["claustrophobic_box", "noise"], ["math_exam", "cupid"], ["quiet_hacker", "biting_book", "paper_small"], ["perfect_score", "biting_book"], ["gaokao_countdown", "cupid", "noise"], ["nightmare", "paper_large"], ["paper_large", "biting_book", "noise"]],
]
const LESSONS := {
 "li_anya":{"title":"幻形与涅槃", "tip":"先用「权且忍受」幻形为队友牌，再让周明远攻击被标记的施暴者。幻形出的队友牌由原角色出手，李安雅获得涅槃充能；攒满12点后可进入独行的涅槃形态。", "key":"LA03", "follow":"basic_strike", "team":["li_anya", "zhoumingyuan", "alyina"], "deck":["LA01", "LA02", "LA02", "LA03", "LA04", "LA04"]},
 "zhoumingyuan":{"title":"以血换血", "tip":"先用「以血换血」消耗生命换取护盾，再用「吃我一击」进攻。血量太低时，让艾莉娜帮忙治疗或加护盾。", "key":"block", "follow":"heavy_strike", "team":["zhoumingyuan", "alyina"], "deck":["block", "block", "basic_strike", "basic_strike", "heavy_strike", "heavy_strike"]},
 "alyina":{"title":"保留与守护", "tip":"治疗牌可以留到需要时再用。先打「天使护卫」保护全队，再让周明远攻击；保留牌还能触发共享护盾。", "key":"angel_guard", "follow":"basic_strike", "team":["alyina", "zhoumingyuan"], "deck":["heal", "heal", "angel_guard", "angel_guard", "help_me", "help_me"]},
 "chenmo":{"title":"嘲讽与反击", "tip":"先打「让我来！」吸引敌人并加上护盾，让徐明明有时间攒潜印，再发动攻击。", "key":"C01", "follow":"C02", "team":["chenmo", "xumingming", "alyina"], "deck":["C01", "C01", "C02", "C02", "C03", "C03"]},
 "xumingming":{"title":"先蓄力，再出手", "tip":"先用「体能训练」攒潜印，再用「起跑枪声」打出更高伤害。攒潜印时，可以让队友帮忙挡住攻击。", "key":"X01", "follow":"X03", "team":["xumingming", "chenmo", "alyina"], "deck":["X01", "X01", "X02", "X02", "X03", "X03"]},
 "wangjiaqi":{"title":"附魔与牌序", "tip":"用「开场白」为牌附魔，再让周明远攻击。附魔攻击牌排在第一张时，看看多打了多少真伤。", "key":"W01", "follow":"basic_strike", "team":["wangjiaqi", "zhoumingyuan", "alyina"], "deck":["W01", "W01", "W02", "W02", "W03", "W03"]},
 "suwanqing":{"title":"叠毒与引爆", "tip":"先用「淬毒针」施毒，再对同一个敌人用「催化针」引爆。队友的攻击也能推进引爆计数。", "key":"D01", "follow":"D02", "team":["suwanqing", "zhoumingyuan", "alyina"], "deck":["D01", "D01", "D02", "D02", "D03", "D03"]},
 "liudanya":{"title":"染色与留白", "tip":"先用「点缀色彩」染色，再用「留白」洗掉颜色。看看三色组和水墨组的效果，再决定怎样配合队友。", "key":"Y01", "follow":"Y02", "team":["liudanya", "zhoumingyuan", "alyina"], "deck":["Y01", "Y01", "Y02", "Y02", "Y04", "Y04"]},
}

static func cap(highest: int) -> int:
	return mini(HERO_CAP, 5 + int(highest / 5) * 5)

static func xp_needed(level: int) -> int:
	return 30 + 8 * level

static func replay_xp(floor_number: int) -> int:
	# Replays become more time-efficient at higher cleared floors, while the
	# progression cap still comes from the run's highest cleared floor.
	return 70 + maxi(0, floor_number - 1) * 18

## Tower-only vitality budgets. Story enemies retain their authored values.
## Multi-phase/revival HP is a total budget, not a budget per phase.
const VITALITY := {
	"report_card":[90.0, 3.0], "magician_master":[120.0, 4.0],
	"math_exam":[125.0, 4.5], "panic_throat":[160.0, 10.0],
	"inverse_limit":[280.0, 9.0], "bullied_phantom":[220.0, 12.0],
	"claustrophobic_box":[155.0, 4.5], "nightmare":[58.0, 2.2],
}

static func enemy_hp(id: String, level: int, authored: int) -> int:
	if VITALITY.has(id):
		return maxi(1, roundi(float(VITALITY[id][0]) + float(VITALITY[id][1]) * maxi(0, level - 1)))
	var base := int(FightData.enemy(id).get("base_hp", 1))
	return maxi(1, base + roundi((authored - base) * 0.75))

static func waves_for(ids: Array) -> Array:
	# A boss never shares its field with another encounter's boss/mechanic.
	# Summons created by that boss remain part of its own encounter.
	var boss := ids.any(func(id): return bool(FightData.enemy(String(id)).get("boss", false)))
	if not boss or ids.size() <= 1: return [ids.duplicate()]
	return ids.map(func(id): return [id])

static func ordinary_enemies(floor_number: int, run_seed: int) -> Array:
	var band := clampi(int((floor_number - 1) / 10), 0, MOB_BANDS.size() - 1)
	var slot := (floor_number - 1) % 10
	var half := 0 if slot < 5 else 1
	var offset := slot % 5
	var order := [0, 1, 2, 3]
	# The first four floors teach one enemy at a time before the first mixed encounter.
	if floor_number > 5:
		var rng := RandomNumberGenerator.new()
		rng.seed = run_seed + band * 104729 + half * 8191
		for i in range(3, 0, -1):
			var j := rng.randi_range(0, i)
			var swap: int = order[i]
			order[i] = order[j]
			order[j] = swap
	return MOB_BANDS[band][half * 4 + int(order[mini(offset, 3)])].duplicate()

static func floor_data(floor_number: int, run_seed: int) -> Dictionary:
	var f := maxi(1, floor_number)
	var block := int((f - 1) / 5)
	var level := mini(ENEMY_CAP, 1 + block * 2 + int(block / 2) * 3)
	var kind := "普通"
	var ids: Array
	if f > NORMAL_FLOORS:
		kind = "极限"
		level = mini(ENEMY_CAP, 40 + (f - 61) * 2)
		ids = [["bullied_phantom", "magician_master"], ["panic_throat", "infirmary_demon"], ["inverse_limit", "zeus_dean"], ["terminal_echo", "report_card", "report_card"]][(f - 61) % 4].duplicate()
	elif f % 10 == 0:
		kind = "首领"
		ids = BOSSES[(int(f / 10) - 1) % BOSSES.size()].duplicate()
	elif f % 5 == 0:
		kind = "精英"
		ids = ELITES[(int(f / 5) - 1 - int(f / 10)) % ELITES.size()].duplicate()
	else:
		ids = ordinary_enemies(f, run_seed)
	var waves := waves_for(ids)
	return {"floor":f, "kind":kind, "enemies":ids, "waves":waves, "level":level, "ambience":posmod(run_seed, 8) + f - 1 - int(f / 5) if kind == "普通" else -1, "xp":50 + 12 * f, "shards":3 + int(f / 3) + (4 if f % 5 == 0 else 0), "rest":f % 5 == 0 or f > NORMAL_FLOORS}

static func rarity_weights(floor_number: int) -> Array:
	var progress := clampf(float(floor_number) / 60.0, 0.0, 1.0)
	return [0.65 - 0.4 * progress, 0.30 + 0.10 * progress, 0.05 + 0.30 * progress]

static func price(id: String) -> int:
	var def := FightEquipmentData.definition(id)
	return int({"common":8, "uncommon":16, "rare":30}.get(def.get("rarity", "common"), 8)) * (2 if FightEquipmentData.ACCESSORIES.has(id) else 1)

static func recovery_reward(floor_number: int) -> int:
	if floor_number <= 0: return 0
	if floor_number > NORMAL_FLOORS: return 4
	if floor_number % 5 != 0: return 0
	# Early parties already have combat healing; larger reserves arrive with longer fights.
	return 1 + int((floor_number - 1) / 20) + (1 if floor_number % 10 == 0 else 0)

