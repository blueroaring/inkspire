class_name FightEquipmentData
extends RefCounted
## Two physical slots per character. Only equipped pieces contribute to combat.
const SLOT_COUNT := 2
const ITEMS_PER_BATTLE := 2
const RARITIES := {"common":{"name":"普通", "color":Color("647681")}, "uncommon":{"name":"精良", "color":Color("397dac")}, "rare":{"name":"稀有", "color":Color("a87522")}}
const ACCESSORIES := {
	"phoenix_ribbon":{"name":"同归羽结", "icon_path":"res://assets/graphics/battle/anya/icons/weapon.webp", "exclusive":"li_anya", "max_hp":6, "damage_bonus":0.08, "opening_ult":1, "desc":"李安雅专武：生命+6，普通伤害+8%，开场1点涅槃充能。", "rarity":"rare", "price":0, "fit":"角色专武 · 教学实战奖励"},
	"tower_metronome":{"name":"节拍器","rarity":"rare","turn_energy":1,"desc":"装备者存活时，全队每回合能量上限+1；同队效果最多+2。","price":16,"fit":"通用遗物 · 尖塔补给"},
	"tower_bookmark":{"name":"长页书签","rarity":"uncommon","retain_every":1,"desc":"每回合结束时，保留装备者最左侧一张尚未保留的手牌。","price":10,"fit":"通用遗物 · 尖塔补给"},
	"tower_lantern":{"name":"引路灯","rarity":"uncommon","turn_draw":1,"desc":"装备者存活时，全队每回合及开场多抽1张；同队最多+2，不改变手牌上限。","price":10,"fit":"通用遗物 · 尖塔补给"},
	"tower_hourglass":{"name":"逆流沙漏","rarity":"rare","first_discount":1,"desc":"装备者每回合第一张非X费技能少耗1能量，最低为0。","price":16,"fit":"通用遗物 · 尖塔补给"},
	"tower_thermos":{"name":"温热水壶","rarity":"common","round_heal":3,"desc":"第2回合起，每回合开始恢复装备者3点生命；不救回退场角色。","price":6,"fit":"通用遗物 · 尖塔补给"},
	"tower_shell":{"name":"回声壳","rarity":"uncommon","round_guard":4,"desc":"每回合开始，装备者获得4点常驻护盾。","price":10,"fit":"通用遗物 · 尖塔补给"},
	"tower_chalk":{"name":"红色粉笔","rarity":"common","damage_bonus":0.1,"max_hp":-3,"desc":"普通伤害+10%，生命上限-3。","price":6,"fit":"通用遗物 · 尖塔补给"},
	"tower_badge":{"name":"急救员徽记","rarity":"rare","rescue_healing_bonus":0.6,"healing_bonus":0.15,"desc":"技能治疗+15%，治疗濒死队友额外+60%。","price":16,"fit":"通用遗物 · 尖塔补给"},
	"tower_battery":{"name":"蓄光石","rarity":"common","opening_ult":2,"desc":"装备者开场获得2点终结技能量。","price":6,"fit":"通用遗物 · 尖塔补给"},
	"courage_badge":{"name":"勇气徽章", "rarity":"common", "price":6, "desc":"生命上限 +4，普通伤害 +4%。", "fit":"通用 · 稳定攻防", "max_hp":4, "damage_bonus":0.04},
	"shared_ribbon":{"name":"同心缎带", "rarity":"common", "price":6, "desc":"生命上限 +3，造成的技能治疗 +8%。仅装备者生效。", "fit":"艾莉娜 · 治疗支援", "max_hp":3, "healing_bonus":0.08},
	"canvas_wrap":{"name":"帆布护腕", "rarity":"common", "price":6, "desc":"生命上限 +2；战斗开始获得 5 点个人常驻护盾。", "fit":"通用 · 开局防护", "max_hp":2, "opening_guard":5},
	"focus_clip":{"name":"专注笔夹", "rarity":"common", "price":6, "desc":"普通伤害 +6%。不增加毒爆、反伤或道具伤害。", "fit":"输出角色 · 稳定增伤", "damage_bonus":0.06},
	"proof_compass":{"name":"验算圆规", "rarity":"uncommon", "price":10, "desc":"生命上限 +3；数学形态的追击伤害 +12%，不增加次数或充能。", "fit":"周明远·数学 · 演算追击", "max_hp":3, "pursuit_bonus":0.12},
	"guardian_knot":{"name":"守望羽结","exclusive":"alyina","max_hp":8,"healing_bonus":0.15,"opening_guard":6,"desc":"艾莉娜专武：生命+8，技能治疗+15%，开场6常驻护盾。","rarity":"rare","price":0,"fit":"角色专武 · 教学实战奖励"},
	"mirror_pin":{"name":"镜盾胸针","exclusive":"chenmo","max_hp":10,"opening_guard":10,"reflect_bonus":0.2,"desc":"陈默专武：生命+10，开场10常驻护盾，反伤倍率额外增加20个百分点。","rarity":"rare","price":0,"fit":"角色专武 · 教学实战奖励"},
	"sprinter_band":{"name":"起跑腕带","exclusive":"xumingming","max_hp":5,"opening_marks":2,"damage_bonus":0.08,"desc":"徐明明专武：生命+5，开场2潜印，普通伤害+8%。","rarity":"rare","price":0,"fit":"角色专武 · 教学实战奖励"},
	"ember_brooch":{"name":"不熄余烬","exclusive":"zhoumingyuan","form":"none","max_hp":6,"low_hp_bonus":0.12,"desc":"周明远·无极专武：生命+6，低于30%生命时普通伤害+12%。","rarity":"rare","price":0,"fit":"角色专武 · 无极形态 · 教学实战奖励"},
	"proof_compass_math":{"name":"验算圆规·专武","icon":"proof_compass","exclusive":"zhoumingyuan","form":"math","max_hp":4,"pursuit_bonus":0.12,"desc":"周明远·数学专武：生命+4，演算追击伤害+12%。","rarity":"rare","price":0,"fit":"角色专武 · 数学形态 · 教学实战奖励"},
	"stage_locket":{"name":"返场怀坠","exclusive":"wangjiaqi","max_hp":6,"enchant_bonus":0.08,"opening_ult":1,"desc":"王嘉琪专武：生命+6，首位附魔追加真伤提高8个百分点，开场1终结技能量。","rarity":"rare","price":0,"fit":"角色专武 · 教学实战奖励"},
	"herb_pendant":{"name":"凝翠药坠","exclusive":"suwanqing","max_hp":6,"poison_bonus":0.2,"opening_ult":1,"desc":"苏婉青专武：生命+6，毒爆伤害+20%，开场1终结技能量。","rarity":"rare","price":0,"fit":"角色专武 · 教学实战奖励"},
	"pigment_charm":{"name":"留白画珐","exclusive":"liudanya","max_hp":6,"healing_bonus":0.15,"round_guard":3,"desc":"刘丹雅专武：生命+6，技能治疗+15%，每回合开始获得3常驻护盾。","rarity":"rare","price":0,"fit":"角色专武 · 教学实战奖励"},
	"breaker_weight":{"name":"破题铅坠", "rarity":"common", "price":6, "desc":"生命上限 +2；目标有个人常驻护盾时，普通伤害 +6%。护盾耗尽后不再加成。", "fit":"输出角色 · 破盾先手", "max_hp":2, "shielded_bonus":0.06},
	"clear_lens":{"name":"晴窗镜片", "rarity":"common", "price":6, "desc":"生命上限 +2；自身满生命时，普通伤害 +6%。适合由护盾保护的输出角色。", "fit":"输出角色 · 保持满血", "max_hp":2, "full_hp_bonus":0.06},
	"dusk_watch":{"name":"晚自习怀表", "rarity":"uncommon", "price":10, "desc":"生命上限 +3；第 2 回合开始时获得 8 点个人常驻护盾。每场仅一次，不受护盾强度增幅。", "fit":"准备型角色 · 延后防护", "max_hp":3, "second_guard":8},
	"ward_pouch":{"name":"平安香囊", "rarity":"uncommon", "price":10, "desc":"生命上限 +3；每场抵挡一次可净化负面状态的施加。优先消耗其他负面免疫，不抵挡无法净化的状态。", "fit":"通用 · 防止关键干扰", "max_hp":3, "opening_ward":1},
	"folded_corner":{"name":"续页书角", "rarity":"uncommon", "price":10, "desc":"生命上限 +3；第 1 回合结束时，为最左侧一张属于装备者且尚未保留的手牌赋予仅本次回合结束有效的保留。", "fit":"准备型角色 · 留住下一步", "max_hp":3, "first_retain":1},
	"rescue_whistle":{"name":"后援哨", "rarity":"rare", "price":16, "desc":"生命上限 +4；对濒死队友造成的技能治疗额外 +25%，与其他饰品治疗增幅加算。不影响道具、吸血、比例恢复或禁疗。", "fit":"治疗角色 · 深度救援", "max_hp":4, "rescue_healing_bonus":0.25},
	"prism_chain":{"name":"同频棱链", "rarity":"rare", "price":16, "desc":"生命上限 +3；与目标学科属性相同时，普通伤害 +10%。无极不生效，不改变属性克制关系。", "fit":"学科角色 · 同属性对局", "max_hp":3, "matching_bonus":0.10},
	"last_pin":{"name":"压轴胸针", "rarity":"rare", "price":16, "desc":"生命上限 +3；命中时剩余手牌不超过 3 张，普通伤害 +10%。不增加毒爆、反伤或道具伤害。", "fit":"输出角色 · 安排出牌顺序", "max_hp":3, "small_hand_bonus":0.10},
}
const CONSUMABLES := {
	"tower_soup":{"name":"暖心汤","rarity":"uncommon","target":"party","party_heal":0.2,"desc":"所有未退场队友恢复各自最大生命的20%。","kind_label":"全队比例恢复","price":4},
	"tower_catalyst":{"name":"充能墨水","rarity":"uncommon","target":"ally","ult":2,"desc":"为一名未退场队友补充2点终结技能量，不超过上限。","kind_label":"终结技充能","price":4},
	"tower_salt":{"name":"净心盐","rarity":"rare","target":"party","party_cleanse":true,"desc":"清除所有未退场队友的可净化负面状态。","kind_label":"全队净化","price":7},
	"tower_firecracker":{"name":"墨响爆竹","rarity":"common","target":"party","area_damage":10,"desc":"对所有可选中的敌人各造成10固定伤害，不触发攻击连携。","kind_label":"群体固定伤害","price":2},
	"tower_shield":{"name":"厚书封","rarity":"rare","target":"ally","permanent_guard":30,"desc":"一名未退场队友获得30点常驻护盾。","kind_label":"跨回合防护","price":7},
	"tower_coupon":{"name":"预习便签","rarity":"common","target":"party","next_draw_only":2,"desc":"下回合额外抽2张牌，不能突破12张手牌上限。","kind_label":"延后补牌","price":2},
	"battle_bandage":{"name":"急救绷带", "rarity":"common", "price":2, "desc":"一名未退场队友恢复 12 点生命。可治疗濒死角色，但需恢复至正生命才能站起。", "target":"ally", "heal":12, "kind_label":"单体治疗"},
	"battle_flash":{"name":"闪光瓶", "rarity":"common", "price":2, "desc":"对一名敌人造成 8 点固定伤害，先扣护盾；不触发追击、毒计数或终结技充能。", "target":"enemy", "damage":8, "kind_label":"固定伤害"},
	"battle_guard":{"name":"护身织片", "rarity":"common", "price":2, "desc":"一名未退场队友获得 8 点个人临时护盾，本轮敌方行动结束后消失。", "target":"ally", "guard":8, "kind_label":"临时护盾"},
	"battle_cleanse":{"name":"清醒露", "rarity":"uncommon", "price":4, "desc":"清除一名队友的所有可净化负面状态。不会移除无法净化的状态或已退场状态。", "target":"ally", "cleanse":true, "kind_label":"负面净化"},
	"battle_energy":{"name":"能量补给", "rarity":"uncommon", "price":4, "desc":"恢复 1 点战斗能量，不超过上限。满能量时不可使用。", "target":"party", "energy":1, "kind_label":"补充能量"},
	"battle_medkit":{"name":"应急药箱", "rarity":"uncommon", "price":4, "desc":"一名未退场队友恢复 24 点生命。治疗量固定，不受角色等级和装备增幅。", "target":"ally", "heal":24, "kind_label":"强化治疗"},
	"battle_bell":{"name":"守夜铃", "rarity":"rare", "price":7, "desc":"所有未退场队友各获得 8 点个人临时护盾，本轮敌方行动结束后消失。每战最多用一件稀有道具。", "target":"party", "party_guard":8, "kind_label":"全队应急防护"},
	"battle_feather":{"name":"归息羽", "rarity":"rare", "price":7, "desc":"仅对濒死且可接受治疗的队友使用：将生命恢复至最大生命的 30%。无法救回已退场角色。每战最多用一件稀有道具。", "target":"ally", "rescue":0.30, "kind_label":"濒死救援"},
	"battle_powder":{"name":"破障粉", "rarity":"common", "price":2, "desc":"移除一名敌人最多 12 点个人常驻护盾。不伤害生命，不触发攻击连携。无护盾时不能使用。", "target":"enemy", "strip_guard":12, "kind_label":"定量破盾"},
	"battle_mint":{"name":"醒神薄荷", "rarity":"common", "price":2, "desc":"清除一名队友的全部「虚弱」与「睡眠不佳」。不移除其他负面或无法净化的状态。", "target":"ally", "cleanse_ids":["weakness", "sleep_bad"], "kind_label":"针对性净化"},
	"battle_smoke":{"name":"遮光烟弹", "rarity":"uncommon", "price":4, "desc":"给一名敌人施加1回合虚弱：造成的普通伤害降低25%。已有虚弱时延长1回合，不叠加减伤幅度。不影响状态施加、分裂或固定伤害。", "target":"enemy", "enemy_status":"weakness", "kind_label":"施加虚弱"},
	"battle_ink":{"name":"破绽墨水", "rarity":"uncommon", "price":4, "desc":"使一名敌人受到的普通伤害提高 15%，持续到本轮敌方行动结束。不增加毒爆、反伤或道具伤害。", "target":"enemy", "enemy_status":"item_exposed", "kind_label":"创造集火机会"},
	"battle_seal":{"name":"静心纸封", "rarity":"uncommon", "price":4, "desc":"一名队友获得1层临时「可净化负面免疫」，本轮敌方行动结束后失效。与香囊共用层数，优先消耗临时层；已有负面免疫或临时可净化负面免疫时不能使用。", "target":"ally", "ward":1, "kind_label":"预防负面状态"},
	"battle_notes":{"name":"备用笔记", "rarity":"uncommon", "price":4, "desc":"立即抽 1 张牌，下回合额外抽 1 张。手牌已满或无可抽牌时不能使用，不改变 12 张手牌上限。", "target":"party", "draw":1, "next_draw":1, "kind_label":"两回合补牌"},
	"battle_clip":{"name":"封页金夹", "rarity":"rare", "price":7, "desc":"使当前所有尚未保留的手牌在本次回合结束时保留。之后抽到的牌不受影响，下回合恢复原规则。", "target":"party", "retain_hand":true, "kind_label":"保存当前手牌"},
	"battle_eraser":{"name":"消印橡皮", "rarity":"rare", "price":7, "desc":"清除一名敌人所有可移除的正面状态。不会移除护盾数值、负面状态、意图或无法净化的效果。", "target":"enemy", "dispel":true, "kind_label":"驱散敌方增益"},
}

## 物品来历独立于数值效果；专武沿用当前角色身份与已写明的剧情线索。
const ORIGINS := {
	"phoenix_ribbon":"由两束羽丝系成的结，曾紧得像一道解不开的束缚。李安雅把它重新结过，留下了可以伸进手指的空隙。她曾盼着有人找到自己，如今这枚羽结随她一起，记着被接住的那一刻，也记着她伸向别人的手。",
	"tower_metronome":"从旧音乐教室搬出的节拍器，木壳上还留着值日生擦不掉的墨点。琴声早已停了，它却仍一下一下地摆着，像在等迟到的人坐好，再把那首合奏从头练起。",
	"tower_bookmark":"图书馆旧书里夹着的长书签，背面挤满了不同笔迹的页码。每一位借书人都替后来的人记下了一个还没读完的地方，最末一行至今空着。",
	"tower_lantern":"晚归学生留在楼梯转角的小灯，提环被握得发亮。最初是谁点亮的已无人记得，只知道看见它的时候，回去的路就还没有完全暗下来。",
	"tower_hourglass":"值日生清理讲台时找到的沙漏，夹在一叠过期的考试安排之间。倒过来时，总有几粒沙不肯落下，像那些写到最后才想起、却来不及补上的答案。",
	"tower_thermos":"一只常年放在课桌边的旧水壶，壶底贴着已经褪色的姓名贴。送水的人早已离开，拧开盖子却仍有一点热气，仿佛那句“先喝口水”刚刚说完。",
	"tower_shell":"地理课展示柜里留下的海螺壳，曾被一排排学生传着听海。后来教室安静了，把它贴在耳边，听见的却像是走廊里等你一起回去的脚步。",
	"tower_chalk":"从黑板槽里收起的一截红粉笔，曾圈过错题，也写过离考试还有多少天。握住它的人总想把字写得更醒目些，直到指尖也染上擦不净的红。",
	"tower_badge":"校运动会急救站留下的徽记，别针弯过，又被小心掰直。那天佩戴它的人没有站上领奖台，只一次次穿过人群，赶到有人举手求助的地方。",
	"tower_battery":"从夜间校园的碎石缝里捡来的小石头，白天看起来毫不起眼。曾有人把它放在窗台晒了一整天，熄灯后才发现，它还替自己留着一小片白昼。",
	"courage_badge":"校服旧口袋里的一枚徽章，背面的名字已被磨平。它没有奖状相配，只有一道重新缝过的针脚；有人曾在想退回座位的时候，把它别好，走到了讲台前。",
	"shared_ribbon":"班级活动后剩下的一段缎带，被两个人各打了一个结。原本只是怕散队时走失的小记号，后来留下的人把两个结都保存了下来。",
	"canvas_wrap":"用旧书包的帆布裁成的护腕，边角缝得不算整齐。最初是搬书时怕磨破手才戴上的，布面那些深浅不一的痕迹，记着一起搬过的许多趟楼梯。",
	"focus_clip":"一枚从变形笔帽上拆下的金属夹，被学生夹在错题本最难的一页。它陪主人熬过好几个晚自习，终于等到那道题下面出现了没有划掉的答案。",
	"proof_compass":"数学教室失物盒里的旧圆规，铰链略松，针脚却仍笔直。盒底压着一张画满辅助线的草稿纸，最后那个圆被反复描过，像是谁终于想通后留下的记号。",
	"guardian_knot":"随艾莉娜的微光凝成的羽结，系着一段连她自己也说不清的牵挂。初遇时，她忘了来处，也忘了重要的任务，却很自然地喊出了“粥粥”。如今她陪他走进照片里的过去，羽结总朝着同伴所在的方向轻轻晃动。",
	"mirror_pin":"陈默把一片旧镜面嵌进了胸针，边缘磨得很圆。高二暑假前，是他掏出藏着的手机，替周明远和李安雅留下合影。镜面映得下身边的人，却总照不全自己，倒很像那个站在镜头外、还要陪他们走到校门口的家伙。",
	"sprinter_band":"徐明明训练时戴旧的腕带，内侧积着一圈圈洗淡的汗渍。起跑线前的俯身、反复练过的摆臂，都把织纹磨向了同一个方向。比赛只计冲线的一瞬，这条腕带却记得枪声响起以前的每一圈。",
	"ember_brooch":"周明远重返高中记忆后，从一角焦黑的旧纸上拾起的微光，凝成了这枚胸饰。那张合影把他带回了仍有机会追问的过去；只要李安雅的不辞而别还没有答案，这一点余烬便没有熄灭的理由。",
	"proof_compass_math":"周明远旧文具盒里的圆规，握柄上还留着学生时代用力过度的划痕。回到高中后，他又沿着草稿纸上的辅助线，一步步找回曾经会做的题。针尖固定住的只是一个点，他却想从这里重新推到那个尚未弄懂的结局。",
	"stage_locket":"王嘉琪用演出衣服上拆下的小饰件改成的怀坠，打开便能照见自己。穿着黑色连帽衫在课间倒立、戴着面具扮低调黑客时，他都把走廊当作舞台。面具会被没收，校服也得穿回去；下一次开场，他仍会先问一句“帅不帅”。",
	"herb_pendant":"苏婉青用来夹放小纸条的药坠，合上后只透出一点草木气息。替李安雅送合影的那天，她把照片飞快塞给周明远，认真声明自己没偷看，便笑着离开。坠子里收着的东西同那张照片一样，总要交到该收到的人手中。",
	"pigment_charm":"刘丹雅把练笔时留下的一小片墨痕封进了画珐，四周特意留着白。素描、色彩与速写占满了训练表，艺考也不考水墨，她仍会在课后翻开旧画谱。留白里没有分数，只有她不愿在自己手中断掉的笔法。",
	"breaker_weight":"从旧自动铅笔里取出的铅坠，表面刻着一条歪斜的辅助线。它原本压在被风吹卷的试卷角上，陪一个学生把看似无从下手的大题拆成了第一步。",
	"clear_lens":"旧眼镜上保存最完整的一片镜片，曾替主人挡住美术课飞来的颜料。擦干净后仍能看见窗外的树影，于是有人把它留了下来，提醒自己偶尔抬头。",
	"dusk_watch":"晚自习停电那晚传过一排课桌的怀表，表盖上留着细细的指甲痕。大家轮流借窗外的光辨认指针，谁也没有催，只把它轻轻推给下一个还在写的人。",
	"ward_pouch":"家人缝好后塞进书包的香囊，里面除了干草，还有一张折得很小的纸。纸上没有考试名次，只写着出门时没来得及说完的叮嘱。",
	"folded_corner":"从破损笔记本上留下的书角，折痕处补着透明胶带。原主人总在铃响时把它折起，仿佛这样就能向那些没想完的事保证：下次一定接着来。",
	"rescue_whistle":"运动场后援箱里的一只旧哨子，绳结系得格外牢。吹响它不为宣布胜负，只为让跑得太远的人知道，有同伴需要大家回头。",
	"prism_chain":"物理实验剩下的棱镜碎片，被串成了一条细链。不同座位的学生从里面看见过同一束光，颜色各异，却总能在转动时重新相遇。",
	"last_pin":"文艺汇演散场后捡到的胸针，背面粘着一小片节目单。纸上最后一个名字被圈了起来，那位表演者等了一整晚，仍在上台前认真整理了衣领。",
	"tower_soup":"小卖铺阿姨借来保温桶装的热汤，碗沿还挂着没擦净的水珠。她见过太多只顾往楼上赶的孩子，便把汤留到最后，等他们肯坐下来喘口气。",
	"tower_catalyst":"旧书写室里封存的一瓶墨水，瓶底沉着细碎的亮点。曾有人把一支快写不出的钢笔蘸进去，写完了一封改了许多遍、始终没敢寄出的信。",
	"tower_salt":"装在折纸袋里的粗盐，原是清扫旧教室时留下的。纸袋外有人写着“擦完后开窗”，像在认真相信，积了太久的潮气总能有一天散去。",
	"tower_firecracker":"用废习题纸卷成的小爆竹，外面仍能辨出红笔批改的痕迹。它来自一次没能办成的庆祝，被藏起来的人留到了夜里，等一个值得放声的时刻。",
	"tower_shield":"从散架的旧课本上拆下的硬书封，内侧贴着好几届学生的姓名。书页已经散失，它却仍习惯把最脆弱的东西护在里面。",
	"tower_coupon":"夹在明天课本里的便签，字迹写得很匆忙。最后一行不是公式，而是“这一页记得看”；留纸条的人似乎很清楚，困倦时的自己会忘掉什么。",
	"battle_bandage":"从操场边急救盒里取出的绷带，包装背面印着早已褪色的校运会标识。它曾被递过许多次，总伴着一句“先别急着站起来”。",
	"battle_flash":"摄影社清理旧器材时留下的小瓶，瓶中收着一团迟迟不散的白光。仿佛某次快门已经按下，那个让人闭眼的瞬间却还没有过去。",
	"battle_guard":"校服袖口拆下的一块织片，补过的地方比原布更厚。缝补的人怕针脚硌手，把线头都藏在了里面，摸上去只剩温软的一层。",
	"battle_cleanse":"医务室窗边留下的小玻璃瓶，开盖能闻到雨后叶子的气味。标签上没有夸大的承诺，只有校医写下的一句“慢慢呼吸”。",
	"battle_energy":"小卖铺阿姨另装的一份加餐，纸袋折得方方正正。晚自习前总有人捏着零钱跑来，她便提前备好，省下他们在柜台前犹豫的时间。",
	"battle_medkit":"校医整理的便携药箱，每个隔层都贴着用途，搭扣已被开合得发亮。最上面压着一张手写纸条：“别慌，一样一样来。”",
	"battle_bell":"宿舍值夜人曾带在身边的小铃，铃舌被布条缠过，声音并不刺耳。熄灯后的走廊里，那一点轻响曾让许多不敢入睡的人知道，门外还有人。",
	"battle_feather":"一根落在照片夹页里的浅色羽毛，根部微微蜷着。把它握在掌心时，仿佛能听见有人贴近耳边，一遍遍唤着尚未得到回应的名字。",
	"battle_powder":"旧黑板擦里收起的细粉，混着一届届学生留下的笔画。擦掉一道难题的外框后，下面往往还藏着更早的人试着解过它的痕迹。",
	"battle_mint":"同桌在午后悄悄推来的一小包薄荷，包装角已经被捏皱。老师转身写板书时，清凉的气味就会在课桌间短暂停留。",
	"battle_smoke":"舞台社团封存的烟雾道具，外壳贴着手写的出场顺序。曾有演员忘词时躲进它升起的薄雾，等同伴接住台词，再鼓起勇气走出来。",
	"battle_ink":"一瓶用于订正的旧墨水，瓶身沾着不同人的指印。大家用它标出推导里最容易忽略的一步，久而久之，墨迹似乎也学会了寻找缝隙。",
	"battle_seal":"用作业本空白页折成的纸封，里面装着写给自己的短句。折纸的人把那些刺耳的话留在外面，只带走了愿意相信的一句。",
	"battle_notes":"请假同学回来前，课代表多抄的一份笔记。页边补着老师口头讲过的提醒，末尾还画了个箭头：“没讲完，接下一页。”",
	"battle_clip":"老师借给值日生的金属书夹，夹口垫着一小块软纸。它曾把一叠将被风吹散的手稿留在原处，直到写字的人回来继续。",
	"battle_eraser":"从旧课桌缝里找到的橡皮，纸套上密密麻麻写着名字。那些名字大多已经擦去，只剩橡皮自己记得，有些被盖上的印记也可以重新抹掉。",
}

static func definition(id: String) -> Dictionary:
	var result: Dictionary = ACCESSORIES.get(id, CONSUMABLES.get(id, {})).duplicate(true)
	if not result.is_empty(): result["lore"] = String(ORIGINS.get(id, ""))
	if TowerRun.active and (int(result.get("round_guard", 0)) > 0 or int(result.get("round_heal", 0)) > 0):
		result.desc += " 尖塔中每回合恢复/护盾数值随装备者等级成长。"
	return result

static func description(id: String) -> String:
	var def := definition(id)
	var effect := String(def.get("desc", ""))
	var lore := String(def.get("lore", ""))
	return effect if lore.is_empty() else "效果\n%s\n\n物品来历\n%s" % [effect, lore]

static func rarity(id: String) -> Dictionary:
	return RARITIES.get(definition(id).get("rarity", "common"), RARITIES.common)

static func texture(id: String) -> Texture2D:
	if definition(id).has("icon_path"): return load(String(definition(id).icon_path)) as Texture2D
	var icon_id := String(definition(id).get("icon", id))
	var path := "res://assets/graphics/tower/icons/" + icon_id + ".webp" if id.begins_with("tower_") else "res://assets/graphics/battle/equipment/" + icon_id + ".webp"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func required_level(id: String) -> int:
	var def := definition(id)
	if def.has("min_level"): return int(def.min_level)
	if def.has("exclusive"): return 20
	return int({"common":1, "uncommon":10, "rare":20}.get(def.get("rarity", "common"), 1))

static func slots(hero_id: String) -> Array:
	var result: Array = GameState.fight_equipment.get(hero_id, []).duplicate()
	result.resize(SLOT_COUNT)
	for i in result.size():
		if result[i] == null: result[i] = ""
	return result

static func owner(id: String) -> String:
	for hero_id in GameState.fight_equipment:
		if slots(hero_id).has(id): return hero_id
	return ""

static func normalize(legacy: bool = false) -> void:
	if legacy:
		GameState.fight_equipment.clear()
		for id in GameState.fight_accessories:
			var hero_id := String(GameState.fight_accessories[id])
			if hero_id == "party": hero_id = "alyina"
			if not FightData.HEROES.has(hero_id) or not ACCESSORIES.has(id): continue
			var equipped := slots(hero_id)
			var empty := equipped.find("")
			if empty >= 0:
				equipped[empty] = id
				GameState.fight_equipment[hero_id] = equipped
	var seen: Array = []
	for hero_id in GameState.fight_equipment.keys():
		if not FightData.HEROES.has(hero_id):
			GameState.fight_equipment.erase(hero_id)
			continue
		var equipped := slots(hero_id)
		for i in equipped.size():
			var id := String(equipped[i])
			if id.is_empty() or not ACCESSORIES.has(id) or not GameState.fight_accessories.has(id) or seen.has(id): equipped[i] = ""
			elif String(ACCESSORIES[id].get("exclusive", hero_id)) != String(hero_id): equipped[i] = ""
			elif FightProgression.hero_level(String(hero_id)) < required_level(id): equipped[i] = ""
			elif ACCESSORIES[id].has("form") and String(GameState.fight_attributes.get(hero_id, "none")) != String(ACCESSORIES[id].form): equipped[i] = ""
			else: seen.append(id)
		GameState.fight_equipment[hero_id] = equipped
	for id in GameState.fight_accessories: GameState.fight_accessories[id] = owner(id)

static func bonuses(hero_id: String) -> Dictionary:
	var result := {"max_hp":0, "damage_bonus":0.0, "healing_bonus":0.0, "opening_guard":0, "opening_marks":0, "pursuit_bonus":0.0, "low_hp_bonus":0.0, "enchant_bonus":0.0, "poison_bonus":0.0, "shielded_bonus":0.0, "full_hp_bonus":0.0, "second_guard":0, "opening_ward":0, "first_retain":0, "rescue_healing_bonus":0.0, "matching_bonus":0.0, "small_hand_bonus":0.0, "turn_energy":0, "turn_draw":0, "retain_every":0, "first_discount":0, "round_heal":0, "round_guard":0, "opening_ult":0, "reflect_bonus":0.0}
	for id in slots(hero_id):
		if not GameState.fight_accessories.has(id): continue
		var def: Dictionary = ACCESSORIES.get(id, {})
		if String(def.get("exclusive", hero_id)) != hero_id or FightProgression.hero_level(hero_id) < required_level(id): continue
		if def.has("form") and String(GameState.fight_attributes.get(hero_id, "none")) != String(def.form): continue
		for key in result: result[key] += def.get(key, 0)
	if TowerRun.active:
		for key in ["round_heal", "round_guard"]:
			result[key] = roundi(float(result[key]) * FightData.growth(FightProgression.hero_level(hero_id)))
	return result

static func item(id: String) -> Dictionary:
	var def: Dictionary = CONSUMABLES.get(id, {}).duplicate(true)
	if not def.is_empty(): def.merge({"scope":"highschool", "kind":"battle_consumable", "action":"", "droppable":true, "lore":String(ORIGINS.get(id, ""))})
	return def
