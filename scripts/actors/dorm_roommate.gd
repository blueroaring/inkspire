extends Npc
## 室友 NPC（周明远的同寝室友）。
##
## 台词随剧情分支，用来演示对话系统 + 选项分支。
##
## ------------------------------------------------------------------ 为什么台词改成了常量
##
## 2026-09-19 加了**对话编辑器**（`tools/dialogue_editor.tscn`）：它要在不跑游戏的情况下
## 读到"陈默有哪几段台词"，所以每段都必须有一个**能在静态上下文里取到**的版本
## （`dialogue_lines(which)`），而且必须是**原文**、不能带补丁。
## 于是：常量保存原文 → `build_dialogue()` 只做"选哪一段 + 套补丁"两件事。
##
## ⚠️ 对话里的说话人写成字面量"陈默"（原来是 `roommate_name` 变量）：
##    常量里不能用实例变量。`roommate_name` 仍然管名牌与交互提示。
##    改名字的话这两处要一起改（`Portraits` 那张头像表也是按名字查的）。

@export var roommate_name: String = "陈默"

@onready var _walk_sprite: ActorSprite = get_node_or_null("AnimatedSprite2D") as ActorSprite
@onready var _gaming_overlay: Sprite2D = get_node_or_null("GamingOverlay") as Sprite2D
var _visual_branch := ""

## 还没看手机（人还没醒）
const LINES_SLEEPING := [
	{"speaker": "陈默", "text": "……（陈默戴着耳机，似乎没注意到你醒了）"},
]

## 第一次搭话（带选项分支）。
##
## 台词照 `request/08_DIALOG.md` 开场那一段（"任务更新：与还在寝室的室友对话"）：
##   陈默在宿舍待着、论文初审已过 → 调侃主角 → 吐槽考研室友 → 提醒下午两点的课 →
##   托主角带饭。中间那两个选项（问他上午怎么样 / 先说"不聊了"）是**原有的交互分支**，
##   08 里没有，但对话系统需要玩家有得选；两句分支台词也按 08 里"念 PPT / 全靠我签到"
##   那两句改过，跟主线说法一致。
const LINES_FIRST := [
	{"speaker": "陈默", "text": "醒了？我还以为你能一觉睡到第二天早上呢。",
		"flag": "chatted_with_chenmo", "emotion": "调侃"},
	{"speaker": "周明远", "text": "别在这调侃我了，你现在还在宿舍待着，你也半斤八两。",
		"emotion": "无语"},
	{"speaker": "陈默", "text": "我的毕业论文已经初审通过了，呆在宿舍啥也不干一点问题没有。",
		"emotion": "得意"},
	{"speaker": "陈默", "text": "倒是你还是想想怎么赶紧把论文写出来吧，睡神。", "emotion": "看戏"},
	{"speaker": "周明远",
		"text": "站着说话不腰疼。要我说咱们宿舍那个一大早就去图书馆卷考研的才是卷王。",
		"emotion": "不服"},
	{"speaker": "陈默", "text": "反正他早起你那时候睡熟了也听不见动静。", "emotion": "无所谓"},
	{
		"speaker": "周明远",
		"text": "算了，不和你唠了，我吃饭去了。",
		"emotion": "摆手",
		"choices": [
			{
				"text": "问他上午的课怎么样",
				"next": [
					{"speaker": "陈默", "text": "老样子，老师念 PPT，台下睡一片。", "emotion": "平淡"},
					{"speaker": "陈默", "text": "不过我帮你把作业题抄回来了，在你桌上。", "emotion": "邀功"},
					{"speaker": "周明远", "text": "……谢了。", "emotion": "敷衍"},
					{"speaker": "陈默", "text": "对了，下午两点有毕业论文写作课，记得准时去。你也不想挂科吧。",
						"emotion": "提醒"},
					{"speaker": "周明远", "text": "你让我去了，然后你到时候又翘课不去了。", "emotion": "吐槽"},
					{"speaker": "陈默", "text": "我毕业论文写完了，去什么去（笑）。", "emotion": "笑"},
					{"speaker": "周明远", "text": "站着说话不腰疼。到时候如果签到不还是全靠我。",
						"emotion": "认命"},
				],
			},
			{
				"text": "先不聊了",
				"next": [
					{"speaker": "陈默", "text": "行。对了，下午两点有毕业论文写作课，记得准时去。你也不想挂科吧。",
						"emotion": "提醒"},
					{"speaker": "周明远", "text": "你让我去了，然后你到时候又翘课不去了。", "emotion": "吐槽"},
					{"speaker": "陈默", "text": "我毕业论文写完了，去什么去（笑）。", "emotion": "笑"},
				],
			},
		],
	},
	{"speaker": "陈默", "text": "好好好，全靠你。还有记得一会给我带饭。", "emotion": "理所当然"},
	{"speaker": "周明远", "text": "不去。你自己去外面吃饭去得了。人得出去走走，不能烂在宿舍里。",
		"emotion": "嫌弃"},
	{"speaker": "陈默", "text": "你已经睡死在宿舍里了。行吧，我出去吃。", "emotion": "无语"},
	# 08 里这句紧跟在"行吧，我出去吃"之后（原来做成"看手机"时再播，位置不对）：
	# 它是主角**此刻**的盘算，玩家看完这段话就该知道"下一步可以去食堂打工"。
	{"speaker": "周明远（内心）", "text": "那就一会顺便做个食堂帮工赚点外快吧。", "emotion": "盘算"},
]

## 聊过之后再搭话
const LINES_AFTER := [
	{"speaker": "陈默", "text": "别再睡回去了啊，下午毕业论文写作要签到。"},
]

## 08 定稿（艾莉娜入队那一段）："陈默的对话此时改为：
##   旁白：陈默正在自己的床上打游戏，并没有在意你的到来。
##   周明远：（算了，别打扰他了。）"
##
## ⚠️ 这一段**整体替换** `LINES_AFTER`（不是追加）：她入队之后玩家已经上过课、
##    逛过校园，陈默这会儿在打游戏，也就不再念叨"下午要签到"那件事了。
const LINES_ALYINA := [
	{"speaker": "", "text": "陈默正在自己的床上打游戏，并没有在意你的到来。"},
	{"speaker": "周明远（内心）", "text": "（算了，别打扰他了。）", "emotion": "轻声"},
]

## 第二天早晨：陈默还没起，避免打扰他睡觉。
const LINES_MORNING := [
	{"speaker": "周明远", "text": "他还没起，还是别打扰他睡觉了。"},
]

## ⚠️ 这段的正文在 `StoryData.roommate_photo_chat()`（正文太长，放那边与其它剧情台词一起）。
##    这里只提供"取原文"的入口，对话编辑器与 `build_dialogue()` 都走它。
static func dialogue_lines(which: String) -> Array:
	match which:
		"sleeping":
			return LINES_SLEEPING
		"after":
			return LINES_AFTER
		"alyina":
			return LINES_ALYINA
		"morning":
			return LINES_MORNING
		"photo_chat":
			return StoryData.roommate_photo_chat()
		_:
			return LINES_FIRST


## 现在该走哪个分支（`dialogue_lines()` 的 which）
func current_branch() -> String:
	if not GameFlow.has_flag("woke_up"):
		return "sleeping"
	if GameFlow.has_flag(StoryData.FLAG_MORNING):
		return "morning"
	# 后半段主线：取了照片回宿舍跟陈默寒暄 → 发现"只有自己看得见她"。
	# ⚠️ 必须排在 `chatted_with_chenmo` 那条前面：到这一步玩家早就聊过一次了。
	if GameFlow.has_flag(StoryData.FLAG_TAKEN) \
			and not GameFlow.has_flag(StoryData.FLAG_ROOMMATE_CHAT):
		return "photo_chat"
	if GameFlow.has_flag("chatted_with_chenmo"):
		# ⚠️ 08 定稿：**艾莉娜登场 CG 完成之后**他一直在床上打游戏，
		#    无论玩家是在睡前还是晚上回来，都只留一句旁白 + 主角一句内心戏
		#    （见 `LINES_ALYINA`）。
		# ⚠️ 判据必须用 `STORY_ALYINA_MET`：`STORY_SKIPPED_CLASS` 只代表 301 门口
		#    的"课不上了"已经演过，发生在登场 CG 之前；不能拿它提前切换成床上状态。
		if GameFlow.has_flag(TeachingData.STORY_ALYINA_MET):
			return "alyina"
		return "after"
	return "first"


func _ready() -> void:
	display_name = roommate_name
	object_kind = roommate_name
	custom_prompt = "和陈默说话"
	super._ready()
	_refresh_scene_visual()


func _process(delta: float) -> void:
	# 台词分支仍会随剧情变化；陈默的视觉则始终固定在床上。
	super._process(delta)
	var branch := current_branch()
	if branch != _visual_branch:
		_refresh_scene_visual()


func _refresh_scene_visual() -> void:
	_visual_branch = current_branch()
	# 陈默整段剧情都赖在右上铺打游戏，不再按台词分支切回站立状态。
	if _walk_sprite != null:
		_walk_sprite.visible = false
	if _gaming_overlay != null:
		_gaming_overlay.visible = true


func build_dialogue() -> Array:
	return dialogue_lines(current_branch())


## 对话补丁按分支分段（`dorm.roommate.first` / `.after` / `.alyina` / `.sleeping`），
## "拿到照片回宿舍"这一段使用剧情目录中的正式 id
## `story.roommate_photo_chat`，这样对话编辑器里改的正是运行时播放的段落。
## 套补丁这件事由基类 `Npc._talk()` 统一做（只做一次）。
func dialogue_block_id() -> String:
	if current_branch() == "photo_chat":
		return "story.roommate_photo_chat"
	return "dorm.roommate.%s" % current_branch()


## "发现只有自己看得见她"那一段是情绪戏，不要被艾莉娜的日常插话打断
func allows_banter() -> bool:
	var branch := current_branch()
	return branch != "photo_chat" and branch != "morning"
