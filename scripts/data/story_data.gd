class_name StoryData
extends RefCounted
## 后半段主线的**剧本与开关**（用户 `request/01_GOALS.md` 第 7 段）。
##
## 这一段回答的是"艾莉娜从跟宠变成'能带你回到过去的人'"：
##   晚间想起去照相馆取洗好的照片 → 取到 → 回宿舍与舍友寒暄 →
##   发现**只有主角能看见听见她** → 晚上看照片 → 翻到李安雅的合影 →
##   艾莉娜觉醒"以照片为媒介魂附过去"的能力 → 签订天使（精灵）契约 → 高中篇。
##
## 为什么单独一个文件：
##   ① 台词很长、且是**纯数据**，塞进场景脚本会让"怎么走"和"说什么"搅在一起；
##   ② 开关名被"照片取件点 / 室友对话 / 书桌看照片 / 任务指引 / 走查断言"五处读，
##      手写字符串拼错一个字母就静默失效 —— 所以集中成常量。

## 剧情开关（全部进 `GameState.story_flags`，跟着存档走）
const FLAG_REMINDER := "photo_reminder"        ## 晚间想起"该去取照片了"
const FLAG_TAKEN := "photo_taken"              ## 照片已经取到手（背包里有 photo_print）
const FLAG_ROOMMATE_CHAT := "roommate_photo_chat"  ## 回宿舍跟陈默寒暄过、并发现只有自己看得见她
## "已经在宿舍床上睡到过晚上 20:00"——**一次性**开关（用户 2026-09-19：
## "即使是遇到精灵后，躺在床上睡觉也只应该触发一次"）。
## 它是 `RestOnBed` 的 `hide_after_flag`：睡过一次之后床边那个交互点就不再出现。
const FLAG_SLEPT := "slept_until_evening"
## 契约后休息到翌日早晨；独立于下午那一次小睡，随存档保存。
const FLAG_MORNING := "contract_next_morning"
## 第二天早晨的连续流程：起床对白、洗漱、体育场门口会面。
const FLAG_MORNING_INTRO := "second_morning_intro"
const FLAG_MORNING_WASHED := "second_morning_washed"
## 旧版本在第一次交互后就写入这个标记；保留常量以兼容旧存档，但不再用它结束会面。
const FLAG_STADIUM_MET := "second_morning_stadium_met"
## 真正选择“出发”并完成后续过场后才应写入的标记。
const FLAG_STADIUM_DEPARTED := "second_morning_stadium_departed"
const FLAG_ALYINA_LEFT_DORM := "alyina_left_dorm"
## 契约已签订（常量本身在 `HighschoolData.STORY_CONTRACT`）
const FLAG_CONTRACT := HighschoolData.STORY_CONTRACT

## 照片道具 id（在 `ItemDb` 里）
const ITEM_PHOTO := "photo_print"


## 契约后的第二天早晨，睡醒后立即播放；只触发一次。
static func morning_intro() -> Array:
	return [
		{"speaker": "周明远", "text": "现在……几点了？"},
		{"speaker": "艾莉娜", "text": "早上好，粥粥！已经太阳晒屁股啦！"},
		{"speaker": "周明远", "text": "早上好，艾莉娜。"},
		{"speaker": "艾莉娜", "text": "等你准备好了，我们就出发吧！"},
		{"speaker": "周明远", "text": "好呀，你先去体育场的大门处等我吧，等我整理一下就过去。"},
		{"speaker": "艾莉娜", "text": "嗯，一会见！"},
	]


## 第二天早晨在卫生间洗手池完成的第一步。
static func morning_wash() -> Array:
	return [
		{"speaker": "", "text": "你打开水龙头，掬起一捧凉水洗了把脸。"},
		{"speaker": "周明远", "text": "清醒多了。"},
	]


## 第二天早晨在体育场大门处的可重复会面。
##
## “出发”写入稳定开关，由运动区场景负责播放同行离场并切入高中入口；
## “不出发”不写开关，玩家可以稍后再次交互。
static func morning_stadium_gate() -> Array:
	return [
		{
			"speaker": "艾莉娜",
			"text": "粥粥你来啦！我们要现在出发吗？",
			"choices": [
				{"text": "出发", "flag": FLAG_STADIUM_DEPARTED},
				{"text": "不出发"},
			],
		},
	]


## 晚间独白：主角想起来照片还没取。
##
## 触发点：任何大学场景进入时判一次（`CollegeMap._maybe_play_evening_reminder()`），
## 以及宿舍床边"躺一会儿"把时间推到晚上 20:00 之后立刻判一次。
static func evening_reminder() -> Array:
	return [
		{"speaker": "", "text": "天色沉下来了。路灯一盏一盏亮起来，把影子拉得很长。"},
		{"speaker": "周明远", "text": "……对了。", "emotion": "想起"},
		{"speaker": "周明远", "text": "上周在照相馆洗的那卷，说今天可以取了。", "emotion": "自语"},
		{"speaker": "艾莉娜", "text": "照片？是那种能把时间留住的东西吗？", "emotion": "好奇"},
		{"speaker": "周明远", "text": "……去看看就知道了。走吧。", "emotion": "随口"},
	]


## 照相馆门口取照片。
static func photo_pickup() -> Array:
	return [
		{"speaker": "", "text": "柜台后的阿姨从一摞纸袋里翻出一个牛皮纸信封，推了过来。"},
		{"speaker": "照相馆阿姨", "text": "上周那卷啊，洗好了。看看清不清楚，不清楚我们重洗。", "emotion": "利落"},
		{"speaker": "周明远", "text": "……谢了。", "emotion": "平淡"},
		{"speaker": "艾莉娜", "text": "哇，这就是照片！薄薄一张，可是里面有一整个人。", "emotion": "惊叹"},
		{"speaker": "周明远", "text": "（薄薄一张，压箱底能用四年。）", "emotion": "自嘲"},
	]


## 回宿舍跟陈默寒暄 → 发现只有自己看得见她。
##
## ⚠️ 这条链的**开关写在最后一行**（`"flag"` 字段）：中途退出对话就不算"聊过了"，
##    玩家回来还能接着说 —— 这比"进场景就算聊过"更符合直觉。
static func roommate_photo_chat() -> Array:
	return [
		{"speaker": "陈默", "text": "哟，回来了。今天倒是没在图书馆耗到关灯？", "emotion": "调侃"},
		{"speaker": "周明远", "text": "……遇到了一些突发事情，今天没写毕业论文。", "emotion": "敷衍"},
		{"speaker": "陈默", "text": "行，希望你能按时交上初稿。话说，今天下午的课签到没有?", "emotion": "随口"},
		{"speaker": "周明远", "text": "唉，下午被一个小人砸晕了，没上成课。现在这小人就在我旁边晃呢。", "emotion": "尴尬"},
		{"speaker": "艾莉娜", "text": "（开心地飞来飞去）", "emotion": "开心"},
		{"speaker": "陈默", "text": "哪里有别的人？现在宿舍里就我们俩啊。", "emotion": "奇怪"},
		{"speaker": "陈默", "text": "你别是昨天熬夜熬出幻觉了吧。", "emotion": "奇怪"},
		{"speaker": "艾莉娜", "text": "他……他看不见我吗？我就在这儿呀！", "emotion": "慌张"},
		{"speaker": "周明远", "text": "（原来只有我能看见艾莉娜吗？）", "emotion": "震惊"},
		{"speaker": "周明远", "text": "……陈默。", "emotion": "试探"},
		{"speaker": "周明远", "text": "你真的看不见我旁边的别人吗？", "emotion": "小心"},
		{"speaker": "陈默", "text": "啊？真没有人啊。你还是早点睡觉吧。", "emotion": "莫名其妙"},
		{"speaker": "", "text": "陈默翻了个身，把耳机塞回耳朵里。宿舍里只剩下风扇的声音。"},
		{"speaker": "艾莉娜", "text": "……原来我是个只有你能看见的幽灵啊。", "emotion": "低落"},
		{"speaker": "周明远", "text": "（低声）艾莉娜，虽然别人看不见你，但是我能看见你，和你交流，这就够了。", "emotion": "安慰"},
		{"speaker": "周明远", "text": "我会一直陪着你的，无论你是我的幻想还是真实存在的生物，你的出现都让我的大学生活不再孤独了。", "emotion": "安慰"},
		{"speaker": "周明远", "text": "振作起来，好吗？", "emotion": "安慰"},
		{"speaker": "艾莉娜", "text": "好啦好啦，我没有那么伤心啦。", "emotion": "振作"},
		{"speaker": "艾莉娜", "text": "能和粥粥在一起，我就已经很开心了！", "emotion": "振作"},
		{"speaker": "周明远", "text": "嗯，等后面我们一起寻找线索，解开你身上的谜团吧！", "emotion": "振作"},
		{"speaker": "周明远", "text": "我相信总有一天，艾莉娜能被别人看见，也能享受美食，刷小说……", "emotion": "振作"},
		{"speaker": "艾莉娜", "text": "我期待着那样的一天到来！到时候我就能真的和粥粥一起到处玩了！", "emotion": "开心", "flag": FLAG_ROOMMATE_CHAT},
	]


## 宿舍书桌上"看照片"：全段的情绪顶点，也是契约。
##
## 这一段把用户给的设定全部落到台词里：
##   · 青梅竹马叫**李安雅**，高三时不知为何退学，从此杳无音讯（主角找过，没有结果）；
##   · 艾莉娜看到合影后**抱头**，像被激发了体内的什么东西；
##   · 她的能力是"**通过照片为媒介，让人魂附到曾经照片上的自己**，重新过一遍先前的经历"；
##   · 有**时间限制**：必须过一段时间后回来，然后**冷却**一段时间才能回到退出前那一刻继续；
##   · 她说：也许能用这个能力找到李安雅失踪的缘由与真相；
##   · 主角答应 → 签订**天使（精灵）契约**。
static func photo_viewing() -> Array:
	return [
		{"speaker": "", "text": "台灯下摊开那一摞照片。宿舍楼下的猫、食堂的窗口、下雨天的操场……"},
		{"speaker": "艾莉娜", "text": "这么多好看的景色！都是你一个人拍的吗？", "emotion": "疑问"},
		{"speaker": "周明远", "text": "是的。不过这么多是因为我从高中一直攒到现在，这周才都一起洗出来。", "emotion": "回忆"},
		{"speaker": "艾莉娜", "text": "等我有了实体，我也要和粥粥拍这么多照片。", "emotion": "轻声"},
		{"speaker": "", "text": "周明远翻到一张合照的时候，手停住了。"},
		{"speaker": "", "text": "照片上并排站着两个人：一个是他，另一个是穿着高中校服的女生，笑得很甜。背景是典型的高中校园景色。", "photo": "res://assets/graphics/cg/photo_highschool_friends.png"},
		{"speaker": "艾莉娜", "text": "这是谁呀？", "emotion": "好奇"},
		{"speaker": "周明远", "text": "……李安雅。", "emotion": "停顿"},
		{"speaker": "周明远", "text": "我高中时候的青梅竹马。", "emotion": "平淡"},
		{"speaker": "周明远", "text": "高三那年，她突然就退学了。", "emotion": "沉默"},
		{"speaker": "周明远", "text": "没有告别，没有理由，老师和同学都说她去别的城市读书了。", "emotion": "沉默"},
		{"speaker": "周明远", "text": "后来我找过。问了同学，问了班主任，甚至去过她曾经的家楼下。", "emotion": "回忆"},
		{"speaker": "周明远", "text": "……但是没有一点音讯。就好像这个人被从世界上抹掉了一样。", "emotion": "低沉"},
		{"speaker": "周明远", "text": "只有这张照片，是我和她仅存的念想了。", "emotion": "怀念"},
		{"speaker": "艾莉娜", "text": "……", "emotion": "怔住"},
		{"speaker": "周明远", "text": "艾莉娜？", "emotion": "奇怪"},
		{"speaker": "", "text": "艾莉娜忽然捂住头，整个身子蜷了起来，像是很痛苦地在回想什么东西。"},
		{"speaker": "艾莉娜", "text": "呜……！李……李……李安雅……", "emotion": "痛苦"},
		{"speaker": "周明远", "text": "艾莉娜？！", "emotion": "慌"},
		{"speaker": "", "text": "过了很久，艾莉娜才慢慢松开手。再抬起头的时候，她的眼睛好像发着光。"},
		{"speaker": "艾莉娜", "text": "……我想起来了。", "emotion": "平静"},
		{"speaker": "艾莉娜", "text": "我的使命。", "emotion": "平静"},
		{"speaker": "艾莉娜", "text": "以这张照片为媒介 —— 我可以让你，魂附到这张照片上那个过去的自己身上。", "emotion": "认真"},
		{"speaker": "艾莉娜", "text": "重新过一遍你经历过的那段日子。真真切切地，再过一遍。", "emotion": "认真"},
		{"speaker": "周明远", "text": "……再过一遍？", "emotion": "难以置信"},
		{"speaker": "艾莉娜", "text": "我也不知道为什么我被赋予了这样的能力与使命。", "emotion": "认真"},
		{"speaker": "艾莉娜", "text": "可能是上帝的旨意吧，让你回到过去找到李安雅离开的原因。", "emotion": "认真"},
		{"speaker": "周明远", "text": "……", "emotion": "沉默"},
		{"speaker": "周明远", "text": "（已经四年了。我以为那件事早就过去了。）", "emotion": "自语"},
		{"speaker": "周明远", "text": "附身到过去后，我能做什么？", "emotion": "询问"},
		{"speaker": "艾莉娜", "text": "你可能没法改变过去发生的事情，但是可以作为一个幽灵，离开你过去的视角去找到真相。", "emotion": "认真"},
		{"speaker": "周明远", "text": "（如果这件事是真的，那我确实很想去探寻这个真相。）", "emotion": "思考"},
		{"speaker": "艾莉娜", "text": "但是有时间的限制。", "emotion": "严肃"},
		{"speaker": "艾莉娜", "text": "你必须在过一段时间之后回来，不能一直待在里面。", "emotion": "严肃"},
		{"speaker": "艾莉娜", "text": "回来之后还要等一段冷却，冷却完了，才能回到退出前的那一刻继续。", "emotion": "严肃"},
		{"speaker": "艾莉娜", "text": "所以……急不得。一次只能走一段。", "emotion": "轻声"},
		{"speaker": "艾莉娜", "text": "可是 —— 也许，用这个能力，你就能找到她不知所踪的缘由和真相了。", "emotion": "认真"},
		{"speaker": "周明远", "text": "……好。", "emotion": "下定决心"},
		{"speaker": "周明远", "text": "我需要做什么？", "emotion": "认真"},
		{"speaker": "艾莉娜", "text": "把手给我。", "emotion": "微笑"},
		{"speaker": "", "text": "艾莉娜与周明远十指相扣。周明远发现他竟然能摸到她的身体。"},
		{"speaker": "", "text": "【教学楼钟鸣三度，月光倾入宿舍。】"},
		{"speaker": "艾莉娜", "text": "——以「天使」之名，吾与君立约。", "emotion": "庄严"},
		{"speaker": "艾莉娜", "text": "吾将秉一线之白，犯群盲之忌；", "emotion": "庄严"},
		{"speaker": "艾莉娜", "text": "素牍生赭，众声化鸦，孤曜沉于名籍。", "emotion": "庄严"},
		{"speaker": "艾莉娜", "text": "慈亲执炬，反照成晦；师者掩卷，若未闻风。", "emotion": "庄严"},
		{"speaker": "艾莉娜", "text": "及危台临湖，月影倒悬——", "emotion": "庄严"},
		{"speaker": "艾莉娜", "text": "莫以渊为渡，莫以寂为终。", "emotion": "庄严"},
		{"speaker": "艾莉娜", "text": "吾之旧途，君当再履；", "emotion": "庄严"},
		{"speaker": "艾莉娜", "text": "吾之未竟，君为之守。", "emotion": "庄严"},
		{"speaker": "", "text": "指尖先是一凉，接着有一阵很轻的暖意顺着掌心爬上来，一直走到心口。"},
		{"speaker": "周明远", "text": "（这就是，天使的契约？）", "emotion": "惊讶"},
		{"speaker": "艾莉娜", "text": "契约，已成！", "emotion": "庄严"},
		{"speaker": "周明远", "text": "前面挺神圣的，但这句话又好像变成什么恶魔契约的样子了。", "emotion": "吐槽"},
		{"speaker": "艾莉娜", "text": "喂！我听见了！艾莉娜才不是恶魔，是天使！", "emotion": "不满"},
		{"speaker": "周明远", "text": "（指着合照）所以现在就能通过这张照片回溯到过去了吗？", "emotion": "询问"},
		{"speaker": "艾莉娜", "text": "还不行。我们还需要亲自到这张照片拍摄的地方，也就是那个高中，才能打开回溯的通道。", "emotion": "认真"},
		{"speaker": "周明远", "text": "（这么麻烦啊。）", "emotion": "无奈"},
		{"speaker": "周明远", "text": "我高考也没考到别的城市去，高中离大学也不远，我们是可以回去的。", "emotion": "平静"},
		{"speaker": "艾莉娜", "text": "已经这么晚了，粥粥还是先休息吧！明天我们再去！", "emotion": "关心"},
		{"speaker": "艾莉娜", "text": "不过……你的毕业论文ddl不会有问题吗？", "emotion": "担心"},
		{"speaker": "周明远", "text": "没事的，什么东西都没有这个机会重要。", "emotion": "坚定"},
		{"speaker": "周明远", "text": "话说……天使也会睡觉吗？", "emotion": "好奇"},
		{"speaker": "艾莉娜", "text": "天使不会睡觉！但是艾莉娜会一直在夜间陪着粥粥的！", "emotion": "开心",
			"flag": FLAG_CONTRACT},
	]


## 床边"躺一会儿"的台词。
##
## 不带参数：`wait_until()` 一定会把时间推到**下一个 20:00**（已经过了就推到第二天），
## 而 20:00 正是 `Daylight` 的夜间起点（用户 2026-09-20："让晚上改为 20 点之后"），
## 所以"醒来天已经黑了"这句在任何时候都成立 —— 分成两套台词反而多一个状态要维护。
static func bed_rest() -> Array:
	return [
		{"speaker": "", "text": "往床上一躺，眼皮立刻就沉了。\n再睁开的时候，窗外已经是暖橙色。"},
		{"speaker": "周明远", "text": "……几点了。", "emotion": "发懵"},
	]


## 剧情触发：到了晚间、还没想起取照片 → 播提醒并写下开关。返回是否播了。
##
## [param host] 只用来拿场景树与玩家（任何在树里的节点都行）。
##
## 为什么触发判据放在**基类/每个场景进入时**，而不是某一个场景里：
##   条件是"现在是不是晚间"这个**全局状态**。玩家可能在校园、教学楼、食堂任何地方
##   把时间推到晚上（打工结算一小时一档），放在某个场景里就会出现
##   "在别的场景到了晚上却不触发"。所以每个大学场景进来都判一次，
##   另外"躺一会儿"把时间推过 20:00 之后也立刻判一次（不用等玩家换场景）。
static func maybe_play_evening_reminder(host: Node) -> bool:
	if host == null or not host.is_inside_tree():
		return false
	if GameFlow.has_flag(FLAG_REMINDER):
		return false
	if not GameFlow.has_flag(TeachingData.STORY_ALYINA_MET):
		return false
	if not GameFlow.is_evening():
		return false

	var player := host.get_tree().get_first_node_in_group("player")
	var was_moving := false
	if player != null and player.has_method("set_control_enabled"):
		was_moving = bool(player.get("can_move"))
		player.call("set_control_enabled", false)
	await DialogueBox.play_script(
			DialoguePatch.apply("story.evening_reminder", evening_reminder()))
	if not is_instance_valid(host) or not host.is_inside_tree(): return false
	GameFlow.set_flag(FLAG_REMINDER, true)
	# ⚠️ 恢复成"播之前的样子"，不要无脑解锁：本函数可能在别的剧情锁里面被调用
	#    （例如床边的"躺一会儿"正锁着玩家）。
	if player != null and player.has_method("set_control_enabled") and was_moving:
		player.call("set_control_enabled", true)
	return true


## 艾莉娜登场 CG **播完、回到地图之后**的那三句（用户 2026-09-20 要求）。
##
## 用户原话："毕业论文少写一天不少这段话应该是 cg 播放结束后触发的，不应该在 cg 对话里"。
## 台词本体在 `CgData.alyina_landing_lines()`（它与 CG 属于同一段剧情，放一起好对照）。
##
## 判据用**会话级**标记 `GameState.alyina_landing_pending`（由 `alyina_cg.gd` 在 CG 播完时置起），
## ⚠️ **不能只用持久开关 `STORY_ALYINA_FOLLOWS`**：
##    那个开关是写进存档的，"读一个已经推到中期的存档"时它照样成立 ——
##    于是玩家一进校园就被这段"刚认识她"的寒暄拦一次，时机完全不对。
##    会话标记只有"这一趟真的刚从那个 CG 里出来"才为真。
##
## ⚠️ 播完（含玩家按 ESC 跳过这段对话）才清标记：中途退出游戏的话下次还会补播，
##    总比"这段永远丢了一次"好。
static func maybe_play_alyina_tour(host: Node) -> bool:
	if host == null or not host.is_inside_tree():
		return false
	if not GameState.alyina_landing_pending:
		return false
	if not GameFlow.has_flag(TeachingData.STORY_ALYINA_FOLLOWS):
		# 理论上不会发生（这个标记只在 CG 播完时置起，而那时开关也写了）；
		# 真遇上了就当场清掉，免得留下一个永远为真的标记反复进这个分支。
		GameState.alyina_landing_pending = false
		return false

	var player := host.get_tree().get_first_node_in_group("player")
	var was_moving := false
	if player != null and player.has_method("set_control_enabled"):
		was_moving = bool(player.get("can_move"))
		player.call("set_control_enabled", false)
	await DialogueBox.play_script(
			DialoguePatch.apply("cg.alyina_fall.landing", CgData.alyina_landing_lines()))
	if not is_instance_valid(host) or not host.is_inside_tree(): return false
	GameState.alyina_landing_pending = false
	# ⚠️ 恢复成"播之前的样子"，不要无脑解锁（同 `maybe_play_evening_reminder`）
	if player != null and player.has_method("set_control_enabled") and was_moving:
		player.call("set_control_enabled", true)
	return true


## 契约后睡到第二天早晨的落地对白。艾莉娜说完就离开宿舍，
## 因而第二天早晨不再创建跟宠；她会在洗漱完成后出现在体育场大门。
static func maybe_play_morning_intro(host: Node) -> bool:
	if host == null or not host.is_inside_tree():
		return false
	if not GameFlow.has_flag(FLAG_MORNING) or GameFlow.has_flag(FLAG_MORNING_INTRO):
		return false
	var player := host.get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_control_enabled"):
		player.call("set_control_enabled", false)
	await DialogueBox.play_script(
			DialoguePatch.apply("story.morning_intro", morning_intro()))
	if not is_instance_valid(host) or not host.is_inside_tree(): return false
	GameFlow.set_flag(FLAG_MORNING_INTRO, true)
	# 对白最后一句是“嗯，一会见！”。让艾莉娜沿宿舍导航走到右侧
	# 宿舍门内侧，再标记离场并销毁节点，玩家能看见她确实走出去了。
	var departing: Follower = null
	for follower in host.get_tree().get_nodes_in_group("follower"):
		if is_instance_valid(follower):
			if follower.has_method("depart_to") and follower.has_signal("departure_finished"):
				departing = follower as Follower
				if departing == null:
					continue
				departing.depart_to(_morning_departure_target())
				break
	if departing != null:
		await departing.departure_finished
	if not is_instance_valid(host) or not host.is_inside_tree(): return false
	GameFlow.set_flag(FLAG_ALYINA_LEFT_DORM, true)
	for follower in host.get_tree().get_nodes_in_group("follower"):
		if is_instance_valid(follower):
			follower.queue_free()
	if player != null and player.has_method("set_control_enabled"):
		player.call("set_control_enabled", true)
	return true


## 右侧宿舍门的内侧落点。门的位置来自 MapData，避免离场脚本与布局坐标分叉。
static func _morning_departure_target() -> Vector2:
	for door_variant in MapData.dorm_doors():
		var door: Dictionary = door_variant
		if String(door.get("id", "")) != "exit":
			continue
		var center := Grid.cells_to_rect(door["cells"]).get_center()
		return center + Vector2(-32.0, 0.0)
	return Vector2(464.0, 168.0)
