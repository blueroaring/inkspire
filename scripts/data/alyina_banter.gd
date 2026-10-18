class_name AlyinaBanter
extends RefCounted
## 艾莉娜在**各个交互点**的插话。
##
## 用户 2026-09-19（`request/01_GOALS.md`）：
##   "接下来的交互就要包含主角和艾莉娜在各个交互点的对话，主要核心思想是艾莉娜对这一切
##    都感到好奇，说这就是大学生活吗，十分羡慕主角的生活，而主角说自己其实大学生活比较
##    废柴，没有那么丰富多彩的实践参与生活。"
##
## ------------------------------------------------------------------ 为什么是"池子"而不是逐件写
##
## 校园/教学楼/食堂/宿舍里可交互的东西有**几十处**，逐个手写既写不完也维护不动；
## 而"她对大学生活好奇、他自嘲废柴"本来就是**同一类反应**。
## 所以做成：按物件名里的**关键词**分组取台词，一组台词里艾莉娜好奇 + 主角自嘲成对出现。
##
## ------------------------------------------------------------------ 两条纪律
##
##   ⚠️ **一个话题默认只说一次**（`_used`）：不说的话，同一张长椅按两遍 E
##      她就感叹两遍 —— 玩家很快会从"觉得可爱"变成"嫌烦"。
##      `_used` 是**会话级**的（不存档）：读档重来会重新说一遍，这是可接受的。
##   ⚠️ **开场（还没遇到她）绝对不能插话**：判据见 `enabled()` ——
##      必须等艾莉娜登场 CG 完成并写入 `STORY_ALYINA_MET`，**不是**仅仅
##      "课不上了"（`STORY_SKIPPED_CLASS`）或场上有没有 `Follower` 节点。
##
## ------------------------------------------------------------------ 唯一一段"可重复体验"（用户 2026-09-20）
##
##   用户原话："艾莉娜插话改成在夕阳阶段可重复体验，而不是一次性的"，
##   并明确口径：**"指的是在艾莉娜加入队伍到宿舍睡觉前的阶段"**（不限次数）。
##
##   也就是这一段：她刚跟着你 → 你带她在校园里逛 → 走累了回宿舍**躺床上休息**
##   （床边"躺一会儿"把时间推到 20:00，同时触发晚间提醒"该去取照片了"）。
##   这段时间玩家是**自由探索**的，而她的插话是"跟着你到处看"的全部内容 ——
##   每个话题只给一次的话，逛到第三处她就彻底不说话了，玩家会以为坏掉。
##   所以这一段里**每个话题都可以反复听**（同一处长椅按几次就说几次）。
##
##   ⚠️ **结束点必须是"躺床上休息"**（`StoryData.FLAG_REMINDER`），
##      不能只看"她还在不在队里"：取照片那一段她**照样跟着**，
##      但那时主线已经推进（玩家在按指引跑任务），再不停插话只会打断节奏。
##      ⚠️ 它顺带把时钟拨过了 18:00 —— 天黑了，"逛校园"这件事本身也结束了。
##   ⚠️ **恢复成"一次"之后 `_used` 不重置**：这段里已经听过的话题不会再攒着，
##      所以"躺下之前听过长椅、躺下之后又路过长椅"不会再来一遍（否则等于白改）。
static func is_repeatable() -> bool:
	if not enabled():
		return false
	return not GameFlow.has_flag(StoryData.FLAG_REMINDER)


## 一个话题 = 关键词组 + 台词。
## 匹配规则：`object_kind` 里**包含**任一关键词就算命中；**从上往下第一个命中的生效**
## （所以"垃圾桶"这种同时属于校园与宿舍的词，放在哪一组就是哪一组，别两边都写）。
##
## ⚠️⚠️ **顺序是有语义的**（2026-09-20 用户实报两处错配）：
##    "书柜的艾莉娜对话有问题，目前是图书馆的对话；衣柜的艾莉娜对话有问题，
##     目前是教育超市的对话"。
##    根因就是"从上往下第一个命中"：
##      · 图书馆那组里有 **"书柜"**，而宿舍里也有书柜 → 宿舍的书柜先被图书馆组吃掉了；
##      · 商店那组里有 **"柜"**，而宿舍的衣柜名字是"我的衣柜/别人的衣柜" → 又被商店组吃掉。
##    两处修法：
##      ① **宿舍组提到图书馆/商店之前**（它是"具体到房间里"的组，优先）；
##      ② 图书馆组里的 "书柜" 换成 **"书架"**、商店组里的 "柜" 去掉
##         （词表按"每件东西只属于一个话题"来配 —— 图书馆那里叫书架，宿舍才叫书柜）。
##    ⚠️ 以后加词表时先问一句："这个词会不会在别的话题的物件名里也出现？"
const TOPICS: Array[Dictionary] = [
	{
		"key": "dorm",
		"keys": ["床", "书桌", "桌", "书柜", "衣柜", "窗", "地毯", "盆栽", "灯", "挂画", "柜子"],		"lines": [
			{"speaker": "艾莉娜", "text": "这就是你住的地方吗？小小的，但是很暖和。", "emotion": "好奇"},
			{"speaker": "周明远", "text": "一张床，一张桌。四年就塞在这两个格子之间。", "emotion": "平淡"},
			{"speaker": "周明远", "text": "（社团、比赛、实习、恋爱……宣传册上写的那种大学生活，一样都没轮到我。）",
				"emotion": "沉默"},
			{"speaker": "艾莉娜", "text": "……可是你在这里，认认真真地过了四年呀。", "emotion": "轻声"},
		],
	},
	{
		"key": "classroom",
		"keys": ["教室", "门牌", "毕业论文"],
		"lines": [
			{"speaker": "艾莉娜", "text": "哇……门上还写着号码。里面就是在讲课吗？", "emotion": "好奇"},
			{"speaker": "艾莉娜", "text": "大家都坐在里面听，那一定是很厉害的地方吧！", "emotion": "憧憬"},
			{"speaker": "周明远", "text": "（厉害是厉害。）我大学四年，认真坐进去的课一只手数得过来。", "emotion": "心虚"},
			{"speaker": "周明远", "text": "……大部分时间，我要么在睡觉，要么在赶下一门课的作业。", "emotion": "自嘲"},
		],
	},
	{
		"key": "stairs",
		"keys": ["楼梯", "上楼", "下楼"],
		"lines": [
			{"speaker": "艾莉娜", "text": "这么高的楼，你们都要自己一层一层爬上去吗？", "emotion": "惊叹"},
			{"speaker": "周明远", "text": "当锻炼了。反正我也没什么别的运动。", "emotion": "认命"},
			{"speaker": "艾莉娜", "text": "那……那你一定很健康！", "emotion": "认真"},
			{"speaker": "周明远", "text": "不。我连体测都是压线过的。", "emotion": "无语"},
		],
	},
	{
		"key": "library",
		# ⚠️ 这里是"书架"，不是"书柜"（宿舍那件才叫书柜，见文件头的错配说明）
		"keys": ["图书馆", "书架", "还书", "自习"],
		"lines": [
			{"speaker": "艾莉娜", "text": "这里好多书呀！你都读完了吗？", "emotion": "好奇"},
			{"speaker": "周明远", "text": "……我在这儿待的时间，基本都在写同一份东西。", "emotion": "疲惫"},
			{"speaker": "周明远", "text": "毕业论文初稿。熬夜熬了半个月，还剩最后一章写不出来。", "emotion": "自嘲"},
			{"speaker": "艾莉娜", "text": "写不出来还一直写，你好努力呀。", "emotion": "佩服"},
			{"speaker": "周明远", "text": "（那不叫努力，那叫拖。）", "emotion": "心虚"},
		],
	},
	{
		"key": "canteen",
		"keys": ["食堂", "餐桌", "饭菜", "窗口", "洗碗", "回收桶", "盘子", "桶"],
		"lines": [
			{"speaker": "艾莉娜", "text": "这里就是吃饭的地方吗？大家都自己端着盘子！", "emotion": "兴奋"},
			{"speaker": "艾莉娜", "text": "羡慕……我要是也能吃一口就好了。", "emotion": "馋"},
			{"speaker": "周明远", "text": "吃了四年，我闭着眼都知道哪个窗口的肉最薄。", "emotion": "平淡"},
			{"speaker": "周明远", "text": "（说起来，我好像从来没有跟谁一起吃过饭。都是一个人来，一个人走。）",
				"emotion": "沉默"},
		],
	},
	{
		# 自动售货机必须排在通用商店之前，否则“售货”会先命中 shop。
		"key": "vending",
		"keys": ["自动售货机"],
		"lines": [
			{"speaker": "艾莉娜", "text": "这个机器里卖的饮料比教育超市的贵唉！"},
			{"speaker": "周明远", "text": "但是它永远会出现在你又渴又累，不想动的时候的旁边。"},
			{"speaker": "艾莉娜", "text": "嘿嘿，我会飞，不会因为走路而累到！"},
			{"speaker": "周明远", "text": "（但是你扑腾翅膀不也会累吗。）"},
		],
	},
	{
		"key": "shop",
		# ⚠️ 去掉了 "柜"（它会把宿舍的"衣柜"吃进来，见文件头的错配说明）
		"keys": ["超市", "商店", "售货", "货架", "买", "文具", "快递"],
		"lines": [
			{"speaker": "艾莉娜", "text": "这里什么都卖吗？那想要什么都能拿到咯？", "emotion": "好奇"},
			{"speaker": "周明远", "text": "想要什么都能拿到，只要你钱包够厚。", "emotion": "现实"},
			{"speaker": "周明远", "text": "（我大学四年最大的实践，大概就是比较过三家店的泡面差价。）", "emotion": "自嘲"},
		],
	},
	{
		"key": "photo",
		"keys": ["照相", "复印", "照片", "证件照"],
		"lines": [
			{"speaker": "艾莉娜", "text": "照片……照片能把时间留住吗？", "emotion": "认真"},
			{"speaker": "周明远", "text": "留个影子而已。洗出来往抽屉里一塞，几年都不翻。", "emotion": "平淡"},
			{"speaker": "艾莉娜", "text": "那多可惜呀。", "emotion": "惋惜"},
		],
	},
	{
		"key": "stadium_gate",
		"keys": ["校门（南）· 运动场"],
		"lines": [
			{"speaker": "艾莉娜", "text": "这个门好老旧呀！真的有人会从这里进出吗？", "emotion": "好奇"},
			{"speaker": "周明远", "text": "这可是离小吃街最近的门。", "emotion": "得意"},
			{"speaker": "周明远",
				"text": "旧是它的保护色，实际上是大家夜间偷偷出门吃宵夜的“秘密通道”。",
				"emotion": "低声"},
			{"speaker": "艾莉娜", "text": "哇！那以后粥粥会带我从后门出去吃宵夜吗？", "emotion": "期待"},
			{"speaker": "周明远", "text": "（虽然吃不到东西，但内心还是吃货的心吗……）", "emotion": "吐槽"},
		],
	},
	{
		"key": "gate",
		"keys": ["校门", "牌坊", "大门", "匾额"],
		"lines": [
			{"speaker": "艾莉娜", "text": "这么大的门！你是从这里进来的吗？", "emotion": "好奇"},
			{"speaker": "周明远", "text": "大一报到那天是。那天我还挺高兴的。", "emotion": "怀念"},
			{"speaker": "周明远", "text": "后来进出过很多次，一次比一次没什么感觉。", "emotion": "平淡"},
			{"speaker": "艾莉娜", "text": "……那今天这一次呢？", "emotion": "轻声"},
			{"speaker": "周明远", "text": "……今天？今天还行。", "emotion": "别过头"},
		],
	},
	{
		"key": "campus_prop",
		"keys": ["长椅", "路灯", "公告栏", "垃圾桶", "自行车", "停车架", "导览", "雕塑", "国旗",
				"横幅", "指示牌", "饮水", "球", "沙坑", "看台", "记分牌", "围网", "牌子"],
		"lines": [
			{"speaker": "艾莉娜", "text": "这些东西摆得整整齐齐的，是给谁看的呀？", "emotion": "好奇"},
			{"speaker": "周明远", "text": "给来参观的家长看，给拍照的招生宣传看。", "emotion": "平淡"},
			{"speaker": "周明远", "text": "（学生自己一般不看。我们只管从这里穿过去。）", "emotion": "自嘲"},
			{"speaker": "艾莉娜", "text": "可是很好看呀！我就要看！", "emotion": "认真"},
		],
	},
]

## 没命中任何话题时不再插入通用台词。
## 具体交互仍使用 TOPICS 中的专属插话，避免追加泛化的校园感叹。
const FALLBACK: Array = []

## 对"同学"这类活人说的话（由 `Npc._talk()` 追加，不走上面的物件匹配）
const NPC_LINES := [
	{"speaker": "艾莉娜", "text": "大家看起来都好忙呀，走路都很快。", "emotion": "好奇"},
	{"speaker": "周明远", "text": "忙着看起来忙。我也不例外。", "emotion": "自嘲"},
	{"speaker": "艾莉娜", "text": "那你也羡慕他们吗？", "emotion": "小心"},
	{"speaker": "周明远", "text": "……忙着的人，没空羡慕。", "emotion": "别过头"},
]

## 本次游玩已经说过的**话题 key**（不存档；见文件头的说明）
static var _used: Dictionary = {}
## 对 NPC 的插话本次是否已说过
static var _npc_used := false


## 现在该不该插话：要"她已经**真的**登场了"。
##
## ⚠️ 查剧情开关而不是查场上有没有 `Follower` 节点 —— 后者在自检/编辑器里也可能是真的。
##
## ⚠️⚠️ 用 `STORY_ALYINA_MET`（"艾莉娜登场 CG 已完成"）：
##    `STORY_SKIPPED_CLASS` 只代表 301 门口的"课不上了"剧情已经演过，
##    这一步发生在艾莉娜登场 CG 之前，不能作为她已经出现的判据。
##    `STORY_ALYINA_FOLLOWS` 虽然也会在登场 CG 结束时写入，但这里使用
##    `STORY_ALYINA_MET` 更直接表达"她已经登场"，并避免把跟随状态和插话状态绑死。
static func enabled() -> bool:
	return GameFlow.has_flag(TeachingData.STORY_ALYINA_MET) \
			and not GameFlow.has_flag(StoryData.FLAG_MORNING)


## 夜间校园只保留三位指定 NPC 的专属台词；其它建筑、街具和 NPC
## 都不再追加通用艾莉娜插话。夜跑同学的夜间四句由 NPC 数据直接提供。
static func is_night() -> bool:
	return Daylight.period_at(GameState.in_game_minutes) == Daylight.PERIOD_NIGHT


## 把插话追加到 [param lines] 后面（没有可说的就原样返回）。
## [param object_kind] 是交互物的显示名（"长椅" / "101 教室" / "教学楼大门" …）。
static func with_banter(object_kind: String, lines: Array) -> Array:
	var extra := lines_for(object_kind)
	if extra.is_empty():
		return lines
	var out := lines.duplicate()
	out.append_array(extra)
	return out


## ⚠️ **卫生间不插话**（用户 2026-09-20："卫生间也不会触发艾莉娜的对话"）。
##    它现在不会命中任何话题，本来就落进兜底台词 —— 那条也要一并挡掉：
##    "她跟着你进卫生间并发表感想"不是这个角色该有的表现。
##
## ⚠️ **别人（室友）的东西也不插话**（用户 2026-09-20："艾莉娜在宿舍的对话只会在
##    左上角的周明远的物品上的交互出现，其他不会出现"）。
##    判据是**物件名里的"别人"标记**：宿舍里那几张别人的床/桌/书柜，名字里都带
##    "陈默 / 室友 / 空着的"，而周明远自己那套叫"我的床铺 / 我的书桌 / 书柜 / 窗户"。
##    ⚠️ 为什么按名字而不是按坐标问"这是不是玩家自己的位置"：
##       `AlyinaBanter` 是**数据层**，只认识"这个交互物叫什么"（它连场景都没有）；
##       把地图方位引进来会让这一层依赖地图布局 —— 而且宿舍之外根本没有这个概念。## ⚠️ **这几间教室不插话**（用户 2026-09-20："老师办公室，空无一人的教室，自习教室
##    不应该触发艾莉娜对话"）。
##    它们都是"周明远自己的大学回忆"那种戏（走错门 / 空教室 / 别人在自习），
##    她一个刚来的小精灵接不上话 —— 硬接反而把那段独白的味道冲掉。
##    判据落在**物件名**上：那几间的门牌/提示里带着"办公室 / 自习"，普通教室不带。
##    ⚠️ 所以**不能**一刀切按"教室"挡掉：普通教室（"101 教室"…）那一段她本来就要插话
##    （"门上还写着号码…"），那是 `classroom` 话题的正文。
const NO_BANTER_WORDS := ["卫生间", "陈默", "室友", "空着的", "空的",
		"办公室", "自习", "空无一人"]


## [param object_kind] 对应的插话；不该说的时候返回空数组。
##
## ⚠️ 注意"没命中任何话题"与"命中了但已经说过"是**两种不同的空**：
##    前者可以退到兜底台词（她什么都好奇），后者必须闭嘴（同一类东西感叹两遍很烦）。
##    ⚠️ 唯一的例外是 `is_repeatable()` 那一段（她刚加入到躺床上休息之前）：
##       那段时间里"已经说过"也照说 —— 见文件头的说明。
##
## 每段插话也有自己的对话补丁 id（`banter.<key>` / `banter._fallback` / `banter._npc`），
## 所以作者可以在对话编辑器里单独改"看长椅时她说的话"，不用碰其它台词。
static func lines_for(object_kind: String) -> Array:
	if not enabled() or is_night() or not kind_allows_banter(object_kind):
		return []
	# 生活区南门的完整重写台词已经写在 CampusData.lines_after，
	# 不再追加通用“校门”插话，避免播完新段落后又重复“这么大的门”。
	if object_kind == "校门（南）":
		return []
	var repeat := is_repeatable()
	for topic_variant in TOPICS:
		var topic: Dictionary = topic_variant
		var matched := false
		for keyword_variant in topic["keys"]:
			if object_kind.contains(String(keyword_variant)):
				matched = true
				break
		if not matched:
			continue
		var key := String(topic["key"])
		# 宿舍家具的艾莉娜插话只播一次；其它校园物件仍沿用“休息前可重复”的规则。
		if _used.has(key) and (key == "dorm" or not repeat):
			return []
		_used[key] = true
		return DialoguePatch.apply("banter.%s" % key, topic["lines"])
	return fallback_lines()


## 这个交互物名允不允许她插话（见 `NO_BANTER_WORDS` 的说明）。
static func kind_allows_banter(object_kind: String) -> bool:
	for word_variant in NO_BANTER_WORDS:
		if object_kind.contains(String(word_variant)):
			return false
	return true


## 跟 NPC 说完话之后她插一句。
##
## ⚠️ **NPC 这一路也吃"可重复"**：她刚加入那段时间里，跟同一个同学聊两次、
##    她就会感叹两次（用户 2026-09-20 的口径是"这一段随便听"）。
##    ⚠️ 这里能放心这么做，是因为"可重复"**不会**把 NPC 的推进卡住：
##       `Npc._talk()` 是**先** `build_dialogue()`（里面推进多阶段进度）**再**追加插话的,
##       所以"说完就走"那几位（抱课本的同学 / 出图书馆的同学）照样会走 ——
##       插话清不清空跟它们的 `finished` 没关系。
static func npc_lines() -> Array:
	if not enabled() or is_night():
		return []
	if _npc_used and not is_repeatable():
		return []
	_npc_used = true
	return DialoguePatch.apply("banter._npc", NPC_LINES)


## 兜底插话（给"没有任何关键词命中的东西"用）。
## ⚠️ 与其它话题同一条口径：她刚加入那段时间里可以反复听（见 `is_repeatable()`）。
static func fallback_lines() -> Array:
	if not enabled() or is_night():
		return []
	if _used.has("_fallback") and not is_repeatable():
		return []
	_used["_fallback"] = true
	return DialoguePatch.apply("banter._fallback", FALLBACK)


## 自检/走查用：把"已经说过的话题"清空，让每个用例都能从干净状态开始
static func reset_session() -> void:
	_used.clear()
	_npc_used = false


## 自检/走查用：这个话题说过没有
static func has_said(key: String) -> bool:
	return _used.has(key) or (key == "npc" and _npc_used)
