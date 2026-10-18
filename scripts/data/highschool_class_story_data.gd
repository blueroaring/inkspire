class_name HighschoolClassStoryData
extends RefCounted
## 08_DIALOG.md “坐下来后”至回到第一节课。可编辑对白与可存档演出节点分离。
const STUDY := "morning_study"
const LOST := "alyina_lost"
const STUDY_END := "morning_study_end"
const MATH := "math_intro"
const PHOTO := "alyina_photo"
const BRIDGE := "photo_bridge"
const ECHO := "photo_echo"
const MEMORY := "photo_memory"
const AFTER := "photo_after"
const FIRST_CLASS := "first_class"
const FLAG_SEAT_DIALOGUE := "highschool.rewind.seat_dialogue_done"
const FLAG_HOMEWORK := "highschool.rewind.homework_complete"
const FLAG_MEMORY := "highschool.rewind.photo_memory_seen"
const FLAG_BRIDGE_INTRO := "highschool.rewind.bridge_intro_seen"
const CG_DIR := "res://assets/graphics/cg/highschool_photo/"
const BELL := "res://assets/audio/sfx/highschool_class_bell.wav"
const SHUTTER := "res://assets/audio/sfx/photo_shutter.wav"
const DIALOGUES := {
	"seated_unfed": [
		{
			"speaker": "旁白",
			"text": "周明远急忙赶到了教室，坐了下来，拿出了没写完的卷子。"
		},
		{
			"speaker": "周明远",
			"text": "这个数学卷……这个物理模拟卷……"
		},
		{
			"speaker": "周明远",
			"text": "坏了，丛大哥还没来，没得抄了。"
		},
		{
			"speaker": "周明远",
			"text": "能写点是点吧。"
		},
		{
			"speaker": "周明远",
			"text": "丛大哥叫丛龙业，听名字就霸气，也是打竞赛的好手。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "丛大哥做理科作业就像小菜般简单，写完也愿意直接给我们这些菜的人“借鉴”。",
			"portrait_form": "spirit"
		}
	],
	"seated_fed": [
		{
			"speaker": "旁白",
			"text": "周明远急忙赶到了教室，坐了下来，拿出了没写完的卷子。"
		},
		{
			"speaker": "周明远",
			"text": "这个数学卷……这个物理模拟卷……"
		},
		{
			"speaker": "旁白",
			"text": "周明远拍了拍旁边正在刷题的同学。"
		},
		{
			"speaker": "周明远",
			"text": "丛大哥，借下昨天的数学作业呗。"
		},
		{
			"speaker": "周明远",
			"text": "丛大哥叫丛龙业，听名字就霸气，也是打竞赛的好手。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "丛大哥做理科作业就像小菜般简单，写完也愿意直接给我们这些菜的人“借鉴”。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "丛龙业",
			"text": "喏，给你。"
		},
		{
			"speaker": "周明远",
			"text": "谢啦。"
		}
	],
	"seated_teacher": [
		{
			"speaker": "旁白",
			"text": "周明远急忙赶到了教室，坐了下来，拿出了没写完的卷子。"
		},
		{
			"speaker": "班主任",
			"text": "抓紧坐下来开始早自习了。到高三了，很快就要一模了，都抓紧起来！"
		},
		{
			"speaker": "班主任",
			"text": "你现在多复习一个知识点，将来高考时没准就能多考一分！"
		},
		{
			"speaker": "班主任",
			"text": "这一分，就是上千人的排名差距！"
		},
		{
			"speaker": "周明远",
			"text": "这个数学卷……这个物理模拟卷……"
		},
		{
			"speaker": "周明远",
			"text": "到得太晚了，能补完吗……"
		},
		{
			"speaker": "旁白",
			"text": "周明远偷偷拍了拍旁边正在刷题的同学。"
		},
		{
			"speaker": "周明远",
			"text": "（小声）丛大哥，借下昨天的数学作业呗。"
		},
		{
			"speaker": "周明远",
			"text": "丛大哥叫丛龙业，听名字就霸气，也是打竞赛的好手。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "丛大哥做理科作业就像小菜般简单，写完也愿意直接给我们这些菜的人“借鉴”。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "丛龙业",
			"text": "喏，给你。"
		},
		{
			"speaker": "旁白",
			"text": "丛龙业在桌子底下把卷子给你递了过去。"
		},
		{
			"speaker": "周明远",
			"text": "谢啦。"
		}
	],
	"alyina_lost": [
		{
			"speaker": "艾莉娜",
			"text": "呜呜……我是路痴啊……找不到之前照片的地方了……"
		},
		{
			"speaker": "艾莉娜",
			"text": "也没法找别人问……别人看不见也听不到我……"
		},
		{
			"speaker": "艾莉娜",
			"text": "怎么办呢……也没法心灵感应和粥粥交流。"
		},
		{
			"speaker": "旁白",
			"text": "艾莉娜陷入了迷茫中。"
		}
	],
	"homework_done": [
		{
			"speaker": "周明远",
			"text": "快点啊，再快一点啊！数学课要上课了！"
		},
		{
			"speaker": "旁白",
			"text": "最终还是在早自习结束前赶完了昨天的数学卷。"
		}
	],
	"homework_unfinished": [
		{
			"speaker": "周明远",
			"text": "快点啊，再快一点啊！数学课要上课了！"
		},
		{
			"speaker": "旁白",
			"text": "最终还是没有在早自习结束前赶完昨天的数学卷。"
		}
	],
	"math_start": [
		{
			"speaker": "班主任",
			"text": "来，站着背书的都坐下。现在该上数学课了。把昨天留的数学卷都拿出来。"
		},
		{
			"speaker": "班主任",
			"text": "这才是暑假回来的第二天，都打起精神来啊。"
		},
		{
			"speaker": "班主任",
			"text": "暑假已经过去了，现在你们是正式的高三生。"
		},
		{
			"speaker": "班主任",
			"text": "我希望大家都打起百分百的精神来，现在这段时间是你查漏补缺知识的最后机会了。"
		},
		{
			"speaker": "周明远",
			"text": "暑假第二天……高三……可惜手上没有手机。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "等晚上用手机的日历核对一下那年的具体日期吧。",
			"portrait_form": "spirit"
		}
	],
	"math_worry": [
		{
			"speaker": "周明远",
			"text": "话说回来，应该不会这么点背被老班点到名讲题吧。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "旁白",
			"text": "周明远还在奋笔疾书中，但是数学卷并不是手速快就能很快写完的。"
		}
	],
	"first_class": [
		{
			"speaker": "周明远",
			"text": "对了，李安雅并不在我的班级，她在隔壁班。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "我现在只能附身的情况下，恐怕很难获取什么有效信息。",
			"portrait_form": "spirit"
		},
		{
			"speaker": "周明远",
			"text": "不知道艾莉娜现在在做什么。但是她肯定能比我获取的信息多的多吧。",
			"portrait_form": "spirit"
		}
	],
	"photo_found": [
		{
			"speaker": "艾莉娜",
			"text": "就是这里了！我终于找到了！"
		},
		{
			"speaker": "艾莉娜",
			"text": "我的感觉不会出错！"
		},
		{
			"speaker": "艾莉娜",
			"text": "我的能力好像在这里也有所提升唉！"
		},
		{
			"speaker": "艾莉娜",
			"text": "似乎……可以和当初在废弃校园开传送门一样，看到曾经在这里发生的场景唉！"
		},
		{
			"speaker": "旁白",
			"text": "神秘的潜意识告诉艾莉娜，这个法术叫\"时序回溯之桥\"。"
		},
		{
			"speaker": "艾莉娜",
			"text": "那就用这个\"时序回溯之桥”，看到照片时的具体情况吧！"
		}
	],
	"bridge_spell": [
		{
			"speaker": "艾莉娜",
			"text": "以晨昏为契，以故地为证——"
		},
		{
			"speaker": "艾莉娜",
			"text": "溯流光而上，循旧影而还。"
		},
		{
			"speaker": "艾莉娜",
			"text": "开——！"
		}
	],
	"bridge_transport": [
		{
			"speaker": "旁白",
			"text": "与先前不同的是，艾莉娜直接被传送到了一个神秘的空间。"
		}
	],
	"bridge_inside": [
		{
			"speaker": "艾莉娜",
			"text": "咦？这是哪里？"
		},
		{
			"speaker": "旁白",
			"text": "神秘的潜意识告诉艾莉娜，这是时序回溯之桥的内部。"
		},
		{
			"speaker": "旁白",
			"text": "不同的回溯之桥有不同的形态，但大致都像一个迷宫，需要找到迷宫的出口才能成功回溯。"
		}
	],
	"echo_ready": [
		{
			"speaker": "艾莉娜",
			"text": "成功啦！这段虚影就是回溯的记忆吧。"
		}
	],
	"memory_after": [
		{
			"speaker": "艾莉娜",
			"text": "补充了好多美好的回忆……"
		},
		{
			"speaker": "艾莉娜",
			"text": "不过好像对找到李安雅的失踪原因没有什么帮助？"
		},
		{
			"speaker": "艾莉娜",
			"text": "不过往好了想，至少看起来高三前李安雅还很正常，没有什么奇怪的地方。"
		},
		{
			"speaker": "艾莉娜",
			"text": "总不能是得绝症了吧？"
		},
		{
			"speaker": "艾莉娜",
			"text": "不行不行，肯定不能这么想。"
		},
		{
			"speaker": "艾莉娜",
			"text": "再想想去哪里找线索吧。"
		}
	]
}

static func seat_dialogue_id() -> String:
	if not GameFlow.has_flag(HighschoolRewindData.FLAG_BREAKFAST_EATEN): return "seated_unfed"
	return "seated_teacher" if HighschoolMorningData.teacher_present(HighschoolMorningData.arrival_minute()) else "seated_fed"

static func homework_complete() -> bool:
	return not GameFlow.has_flag(HighschoolRewindData.FLAG_BREAKFAST_EATEN) or HighschoolMorningData.meal_id() == "soy_combo"

static func target_location(stage: String) -> String:
	var midday := HighschoolMiddayData.target_location(stage)
	if midday != "": return midday
	var next := HighschoolFirstPeriodData.target_location(stage)
	if next != "": return next
	if stage in [STUDY, STUDY_END, MATH, FIRST_CLASS]: return "highschool.classroom_502"
	if stage in [LOST, PHOTO, BRIDGE, ECHO, AFTER]: return "highschool.alyina_memory"
	if stage == MEMORY: return "cg.highschool_photo"
	return ""

static func shots() -> Array:
	return [
		{"bg": "res://assets/graphics/cg/highschool_photo/waiting.png", "shot_name": "waiting", "fade": 0.6, "dialogue": [{"speaker": "旁白", "text": "那是6月30日的下午，天气渐渐步入夏日，热风夹杂着热闹的学生人群的声音，响彻在校园。"}, {"speaker": "旁白", "text": "夕阳的日光穿射过树叶，金黄与树影点缀着热烈的氛围。"}, {"speaker": "旁白", "text": "周明远，陈默正在第一教学楼门口等着谁。"}, {"speaker": "陈默", "text": "你小子，拉着我等半天，就为了等你的小女友班放学？"}, {"speaker": "周明远", "text": "她生病了，我得护送她回家。"}, {"speaker": "陈默", "text": "屁。你就是借机会多跟她待会而已。"}, {"speaker": "周明远", "text": "此言差矣。要是你生病了然后班主任还拖堂了，我也等你。"}, {"speaker": "陈默", "text": "得了。那你还拉着我等干啥呢，不就是想炫耀你有小女友了。"}, {"speaker": "周明远", "text": "就是为了不让别人说这风凉话才让你来的。"}, {"speaker": "周明远", "text": "并且，我和她只是从初中到现在的“很好的朋友”关系，谈不上什么小女友。"}, {"speaker": "周明远", "text": "我俩又没有什么出格的交往。如果有，早被教导主任干了。"}, {"speaker": "陈默", "text": "这我倒是同意。你这块木头根本不知道怎么推进感情。"}, {"speaker": "陈默", "text": "真不知道你俩怎么好上的。"}, {"speaker": "周明远", "text": "……"}]},
		{"bg": "res://assets/graphics/cg/highschool_photo/emerging.png", "shot_name": "emerging", "fade": 0.6, "dialogue": [{"speaker": "周明远", "text": "李安雅！"}]},
		{"bg": "res://assets/graphics/cg/highschool_photo/turning.png", "shot_name": "turning", "fade": 0.6, "dialogue": [{"speaker": "李安雅", "text": "？"}]},
		{"bg": "res://assets/graphics/cg/highschool_photo/conversation.png", "shot_name": "conversation", "fade": 0.6, "dialogue": [{"speaker": "李安雅", "text": "周明远！陈默！暑假愉快呀！"}, {"speaker": "周明远", "text": "李安雅，你也暑假愉快！……你妈妈跟我嘱咐了，你生病了，……"}, {"speaker": "陈默", "text": "让这块木头护送你回家。"}, {"speaker": "周明远", "text": "对。"}, {"speaker": "旁白", "text": "周明远怒视了一下陈默，然后转过头面向李安雅。"}, {"speaker": "周明远", "text": "……你生病了，多喝热水。"}, {"speaker": "李安雅", "text": "……谢谢。"}]},
		{"bg": "res://assets/graphics/cg/highschool_photo/awkward.png", "shot_name": "awkward", "fade": 0.6, "dialogue": [{"speaker": "旁白", "text": "场面一时安静。"}, {"speaker": "陈默", "text": "（要不说你是木头呢……）"}]},
		{"bg": "res://assets/graphics/cg/highschool_photo/prepare.png", "shot_name": "prepare", "fade": 0.6, "dialogue": [{"speaker": "陈默", "text": "好了，二位。这个暑假后也就是高三了，我们能随便串班见面的次数应该就会变得很少了。"}, {"speaker": "陈默", "text": "趁这个机会，我给你俩就在校园里拍个照，留个纪念吧。"}, {"speaker": "陈默", "text": "要放假了，我也不藏着了，我一直藏着手机呢。"}, {"speaker": "周明远", "text": "真有你的，能一直不被宿管阿姨发现。"}, {"speaker": "李安雅", "text": "确实厉害。"}, {"speaker": "李安雅", "text": "机会确实难得，粥粥我们就在这留个影吧。"}, {"speaker": "艾莉娜", "text": "粥粥？她也知道周明远的小名?"}, {"speaker": "艾莉娜", "text": "不对，我是误打误撞猜出来的，青梅竹马知道小名是很正常的事吧。"}, {"speaker": "周明远", "text": "你不一起来合个影吗？"}, {"speaker": "陈默", "text": "我给你们拍照就够了。先前我在学校自己拍的自拍要多少有多少。"}, {"speaker": "陈默", "text": "你们这些乖乖宝没有手机可没法像我一样随便拍。"}]},
		{"bg": "res://assets/graphics/cg/highschool_photo/shoot.png", "shot_name": "shoot", "fade": 0.6, "dialogue": [{"speaker": "陈默", "text": "好嘞，三，二，一，茄子！"}]},
		{"bg": "res://assets/graphics/cg/photo_highschool_friends.png", "shot_name": "photo", "fade": 0.6, "hold": 3.0, "flash": true, "sfx": "res://assets/audio/sfx/photo_shutter.wav"},
		{"bg": "res://assets/graphics/cg/highschool_photo/viewing.png", "shot_name": "viewing", "fade": 0.6, "dialogue": [{"speaker": "旁白", "text": "陈默将照片给二人看。"}, {"speaker": "李安雅", "text": "哇！照的好好！"}, {"speaker": "周明远", "text": "不赖。"}]},
		{"bg": "res://assets/graphics/cg/highschool_photo/viewing.png", "shot_name": "viewing", "fade": 0.6, "dialogue": [{"speaker": "陈默", "text": "你俩快回家吧，记得护送好李安雅。"}]},
		{"bg": "res://assets/graphics/cg/highschool_photo/hold.png", "shot_name": "hold", "fade": 0.6, "dialogue": [{"speaker": "周明远", "text": "不许走。陪我们到校门口再分开。"}, {"speaker": "陈默", "text": "好好好，护花使者周先生。"}]},
		{"bg": "res://assets/graphics/cg/highschool_photo/leaving.png", "shot_name": "leaving", "fade": 0.6, "hold": 3.0},
	]
