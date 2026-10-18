class_name HighschoolBreakEvents
extends RefCounted
const PREFIX := "highschool.break."
const PENDING := PREFIX + "pending_event"
const KNOWS_ZHANG := PREFIX + "knows_zhang"
const ANYA_EVENTS := PREFIX + "anya_events"
const WALKED_HOME := PREFIX + "walked_home_with_anya"
const PHOTO_RECEIVED := PREFIX + "photo_received"
const MOCK_EXAM_STARTED := "highschool.mock_exam.started"
const INVITE_RESULT := PREFIX + "invite_result"
const NOTE_FRONT := "res://assets/graphics/items/generated/highschool_boxing_note/processed/note-1.png"
const NOTE_BACK := "res://assets/graphics/items/generated/highschool_boxing_note/processed/note-2.png"
const EVENT_CLUES := {
	"chat_roof": "roof", "walk_exam": "perfect_score", "walk_grove": "grove",
	"toilet_note": "toilet_note", "corridor_ghost": "dorm_ghost", "corridor_show": "masked_performer",
}
## request/08_DIALOG.md 的课间原文；条件判断和完成效果见文件末尾。
const DIALOGUES := {
	"nap": [
		{"speaker": "旁白", "text": "周明远在桌子上很快进入了休眠模式。"},
		{"speaker": "周明远", "text": "补补觉吧。就是这样没法搜集信息了。", "portrait_form": "spirit"},
	],
	"chat_copied": [
		{"speaker": "丛龙业", "text": "挺惨啊，老周。被老师抓包了。"},
		{"speaker": "丛龙业", "text": "下次借鉴时记得大致看看题。"},
		{"speaker": "周明远", "text": "话说……下次你能不能把解题过程一起借给我？"},
		{"speaker": "丛龙业", "text": "我自己都不知道写在哪张草稿纸上了。"},
		{"speaker": "周明远", "text": "好吧。"},
	],
	"chat_notes": [
		{"speaker": "周明远", "text": "丛大哥，这节课的笔记借我看看呗。"},
		{"speaker": "丛龙业", "text": "喏，给你。"},
		{"speaker": "旁白", "text": "丛龙业把笔记给你后，就出去上厕所了。"},
	],
	"chat_zhang": [
		{"speaker": "周明远", "text": "张姐，这节课留作业了吗？"},
		{"speaker": "周明远", "text": "张姐叫张飒，人如其名很飒。", "portrait_form": "spirit", "unless_flag": "highschool.break.knows_zhang"},
		{"speaker": "周明远", "text": "记得她好像还是个什么小团体的二把手。", "portrait_form": "spirit", "unless_flag": "highschool.break.knows_zhang"},
		{"speaker": "周明远", "text": "总之和我一样不咋学习就是了。", "portrait_form": "spirit", "unless_flag": "highschool.break.knows_zhang"},
		{"speaker": "张飒", "text": "我咋知道？我跟你一起睡的。"},
		{"speaker": "周明远", "text": "……好吧，不打扰你了。"},
	],
	"chat_meal": [
		{"speaker": "周明远", "text": "陈默，一会一起吃饭去不。"},
		{"speaker": "陈默", "text": "去啊。"},
		{"speaker": "陈默", "text": "不跟你小女友去？"},
		{"speaker": "周明远", "text": "一起吃饭不等着落下话柄吗。"},
		{"speaker": "周明远", "text": "并且，不是小女友！"},
		{"speaker": "陈默", "text": "我定义的，就是。"},
		{"speaker": "周明远", "text": "行吧，你爱怎么想怎么想，别乱传就行。"},
	],
	"chat_chen": [
		{"speaker": "周明远", "text": "陈默，这节课讲了什么重要的东西吗？"},
		{"speaker": "陈默", "text": "如果你指的是作业的话，没啥。"},
		{"speaker": "陈默", "text": "要课堂笔记的话找丛哥要去。"},
		{"speaker": "周明远", "text": "ok。"},
	],
	"chat_empty": [
		{"speaker": "旁白", "text": "你想跟周围的人搭话，却发现他们都不在座位。"},
		{"speaker": "周明远", "text": "后排靠窗，王的故乡。"},
		{"speaker": "周明远", "text": "就是没啥人能唠嗑。"},
		{"speaker": "周明远", "text": "算了，懒得动了。等到上课吧。"},
		{"speaker": "周明远", "text": "给我动动收集信息啊喂！", "portrait_form": "spirit"},
	],
	"chat_roof": [
		{"speaker": "张飒", "text": "唉，我跟你说，咱们高三搬到了五楼后，我才知道这教学楼是有通往天台的楼梯的。"},
		{"speaker": "张飒", "text": "就是被铁丝网门拦住了。"},
		{"speaker": "张飒", "text": "你有啥法子找到钥匙不？"},
		{"speaker": "周明远", "text": "我估计钥匙在教导主任手上吧。并且你要去天台干什么？"},
		{"speaker": "张飒", "text": "开party啊！你不觉得那是个绝佳的帮派聚会地点吗。"},
		{"speaker": "周明远", "text": "……我没啥好的点子。你尝试下怎么和教导主任交涉吧。"},
		{"speaker": "张飒", "text": "一点不man。行吧，指不上你。"},
		{"speaker": "周明远", "text": "但是我行啊。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "我记得张飒最后不知道怎么的是拿到了钥匙的复制品。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "所以说天台还是有必要调查的。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "我估计钥匙教导主任不会一直拿着，应该都放在教务处。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "只要能进去教务处就好说了。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "这样能去天台的话，没准就能找到什么更多的线索。", "portrait_form": "spirit"},
	],
	"chat_busy": [
		{"speaker": "周明远", "text": "丛哥。"},
		{"speaker": "旁白", "text": "丛龙业正在刷题，没有搭理周明远。"},
		{"speaker": "旁白", "text": "周明远自讨没趣，放弃了。"},
	],
	"walk_exam": [
		{"speaker": "旁白", "text": "周明远在教室漫无目的地闲逛着，听着周围的闲聊。"},
		{"speaker": "张飒", "text": "姐妹们，我跟你们说，我听到个特别好笑的梦！", "unknown_speaker": "很飒的女生"},
		{"speaker": "周明远", "text": "这个女生叫张飒，人如其名很飒。", "portrait_form": "spirit", "unless_flag": "highschool.break.knows_zhang"},
		{"speaker": "周明远", "text": "记得她好像还是个什么小团体的二把手。", "portrait_form": "spirit", "unless_flag": "highschool.break.knows_zhang"},
		{"speaker": "周明远", "text": "总之和我一样不咋学习就是了。", "portrait_form": "spirit", "unless_flag": "highschool.break.knows_zhang"},
		{"speaker": "围着的女生", "text": "什么什么，说来听听！"},
		{"speaker": "张飒", "text": "有个高一的小鬼说自己做了个梦，梦里说自己进了一个不考满分就没法出去的房间！"},
		{"speaker": "张飒", "text": "只要房间里的卷子没打满分，自己不仅进不去，还要挨揍呢！"},
		{"speaker": "旁边的某个女生", "text": "哈哈哈，怕不是小说看多了！"},
		{"speaker": "张飒", "text": "对吧！要是我的话，就把房间改成不加入我们的组织就没法出去的房间。"},
		{"speaker": "周围的女生", "text": "对对！"},
		{"speaker": "周明远", "text": "这梦确实无厘头。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "不过飒姐说的话，听个乐就得了。", "portrait_form": "spirit"},
	],
	"walk_show": [
		{"speaker": "旁白", "text": "周明远在教室漫无目的地闲逛着，听着周围的闲聊。"},
		{"speaker": "旁白", "text": "你突然发现了已经换装的王嘉琪。", "story_cg": "classroom_reveal"},
		{"speaker": "旁白", "text": "王嘉琪正穿着黑色连帽衫，戴着黑色面罩，连帽衫上有着一个白色的“AW”LOGO。"},
		{"speaker": "旁白", "text": "王嘉琪正在展示他曼妙的身姿，并时不时做个倒立。", "story_cg": "classroom_handstand"},
		{"speaker": "王嘉琪", "text": "帅不帅，帅不帅！"},
		{"speaker": "周围的同学", "text": "嘉豪牛逼！嘉豪牛逼！"},
		{"speaker": "周明远", "text": "搞耍的高手。", "portrait_form": "spirit"},
	],
	"walk_teacher": [
		{"speaker": "旁白", "text": "班主任突然进来了。", "story_cg": "classroom_teacher"},
		{"speaker": "班主任", "text": "王嘉琪，赶紧把校服穿上！"},
		{"speaker": "班主任", "text": "别显摆你那身姿了。"},
		{"speaker": "旁白", "text": "一场好戏就这么告吹了。"},
	],
	"walk_problem": [
		{"speaker": "旁白", "text": "周明远在教室漫无目的地闲逛着，听着周围的闲聊。"},
		{"speaker": "旁白", "text": "一旁的同学正聚集在一起，讨论着一道很难的题目。"},
		{"speaker": "旁白", "text": "大家众说纷纭，各自有各自的解题想法。"},
		{"speaker": "周明远", "text": "我当时太菜了，加入不了这仙家对话。", "portrait_form": "spirit"},
	],
	"walk_chen": [
		{"speaker": "旁白", "text": "周明远走到了正在墙边站着的陈默身边。"},
		{"speaker": "周明远", "text": "别装深沉了。来唠点什么。"},
		{"speaker": "陈默", "text": "你说，咱们班有多少能上一本的啊。"},
		{"speaker": "周明远", "text": "我不知道，不过你应该能吧，我是肯定没戏了。"},
		{"speaker": "陈默", "text": "扯淡。你一轮二轮复习努力点，一本还不是轻轻松松。"},
		{"speaker": "周明远", "text": "最终结果是两人都没做到。", "portrait_form": "spirit"},
	],
	"walk_food": [
		{"speaker": "旁白", "text": "周明远在教室漫无目的地闲逛着，听着周围的闲聊。"},
		{"speaker": "周围的同学", "text": "今天吃什么呢。"},
		{"speaker": "周明远", "text": "是啊，吃什么。"},
	],
	"walk_grove": [
		{"speaker": "旁白", "text": "周明远在教室漫无目的地闲逛着，听着周围的闲聊。"},
		{"speaker": "附近的同学A", "text": "你知道吗，有一对小情侣被教导主任抓包了，听说叫家长了！"},
		{"speaker": "附近的同学B", "text": "早恋这事说大不大，但是上称就千斤重，算祂俩倒霉呗。"},
		{"speaker": "附近的同学B", "text": "要我说，就得去球场旁边的小树林，那块晚上铁定不会被抓。"},
		{"speaker": "附近的同学A", "text": "扯。你都知道的地方，教导主任能不知道？"},
		{"speaker": "周明远", "text": "小树林确实是这种绯闻的好载体。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "不过当时是不是真的有人去小树林就不得而知了。", "portrait_form": "spirit"},
	],
	"toilet_quick": [
		{"speaker": "旁白", "text": "周明远很快地上完了厕所就回去了。"},
	],
	"toilet_stomach": [
		{"speaker": "旁白", "text": "周明远感到肚子不太舒服。很快地前去蹲坑了。"},
	],
	"toilet_phone": [
		{"speaker": "旁白", "text": "周明远在蹲坑时，发现旁边也有同学一起在……上厕所？"},
		{"speaker": "周明远", "text": "好像是借着上厕所在刷手机吧。", "portrait_form": "spirit"},
	],
	"toilet_note": [
		{"speaker": "旁白", "text": "周明远在蹲坑时，在厕所角落发现了一张纸条。"},
		{"speaker": "旁白", "text": "纸条正面写着：WCB（厕所拳击联赛）正式开赛！", "photo": NOTE_FRONT},
		{"speaker": "旁白", "text": "弱者，就该被踩在脚下！", "photo": NOTE_FRONT},
		{"speaker": "旁白", "text": "纸条背面写着：好害怕……", "photo": NOTE_BACK},
		{"speaker": "旁白", "text": "谁来救救我……", "photo": NOTE_BACK},
		{"speaker": "旁白", "text": "还有一句很潦草的批注：幽闭恐惧症！", "photo": NOTE_BACK},
		{"speaker": "周明远", "text": "谁写的这纸条？"},
		{"speaker": "周明远", "text": "在厕所隔间打拳击说是。"},
		{"speaker": "旁白", "text": "周明远顺手把纸条收进了口袋。"},
		{"speaker": "周明远", "text": "是很奇怪。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "还好过去的我收起来了纸条。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "等晚上调查一下究竟怎么回事吧。", "portrait_form": "spirit"},
	],
	"toilet_exam": [
		{"speaker": "旁白", "text": "周明远上完厕所后，在洗手台附近待了一会，听了会旁边同学的对话。"},
		{"speaker": "同学A", "text": "马上就要一模了，压力好大。"},
		{"speaker": "同学B", "text": "怕啥，咱们考差了后面去后面考场没准是好事呢。"},
		{"speaker": "同学B", "text": "第一考场那些都是怪物，心理压力太大了。"},
		{"speaker": "周明远", "text": "学校是按照上次考试的排名按顺序分考场的。", "portrait_form": "spirit"},
	],
	"neighbor_intro": [
		{"speaker": "旁白", "text": "隔壁班是文科班级，以女生为主。"},
		{"speaker": "周明远", "text": "男生过来除非是和某个女生很熟，属于是稀客。", "portrait_form": "spirit"},
	],
	"neighbor_absent": [
		{"speaker": "旁白", "text": "周明远在门口扫视了一下，没有看见李安雅。"},
		{"speaker": "周明远", "text": "她应该上厕所去了。"},
		{"speaker": "旁白", "text": "周明远回到了自己教室的座位。"},
		{"speaker": "周明远", "text": "可惜。没遇到李安雅。", "portrait_form": "spirit"},
	],
	"neighbor_morning": [
		{"speaker": "旁白", "text": "周明远在门口扫视了一下，找到了李安雅。"},
		{"speaker": "旁白", "text": "李安雅就坐在中间排的中间位置。"},
		{"speaker": "旁白", "text": "一袭黑发罩住脸庞，她正在写东西。"},
		{"speaker": "旁白", "text": "周明远走到了李安雅旁边。"},
		{"speaker": "周明远", "text": "李安雅。"},
		{"speaker": "旁白", "text": "李安雅抬起了头，看了看面前的来客，然后莞尔一笑。"},
		{"speaker": "李安雅", "text": "早上好啊，周明远！昨晚睡得好吗？"},
		{"speaker": "周明远", "text": "挺好的。"},
		{"speaker": "周明远", "text": "拖老班的福，现在精神清醒的很。", "requires_standing": true},
		{"speaker": "李安雅", "text": "那就好。有什么事吗？"},
		{"speaker": "周明远", "text": "没啥事，就是下课了顺便串个门。"},
		{"speaker": "李安雅", "text": "好。马上要上课了，你抓紧回去吧。"},
		{"speaker": "周明远", "text": "好，回见！"},
		{"speaker": "周明远", "text": "不怪陈默说我当时是木头一个。", "portrait_form": "spirit"},
	],
	"neighbor_afternoon": [
		{"speaker": "旁白", "text": "周明远在门口扫视了一下，找到了李安雅。"},
		{"speaker": "旁白", "text": "李安雅就坐在中间排的中间位置。"},
		{"speaker": "旁白", "text": "一袭黑发罩住脸庞，她正趴在桌子上休息。"},
		{"speaker": "周明远", "text": "……那就不打扰她休息了。"},
	],
	"neighbor_evening": [
		{"speaker": "旁白", "text": "周明远在门口扫视了一下，找到了李安雅。"},
		{"speaker": "旁白", "text": "李安雅就坐在中间排的中间位置。"},
		{"speaker": "旁白", "text": "一袭黑发罩住脸庞，她正在安静地学习着。"},
		{"speaker": "旁白", "text": "周明远走到了李安雅旁边。"},
		{"speaker": "周明远", "text": "晚上好。"},
		{"speaker": "旁白", "text": "李安雅抬起了头。"},
		{"speaker": "李安雅", "text": "晚上好呀！马上就要放学了，然后就可以休息了。"},
		{"speaker": "周明远", "text": "要不要放学时跟我们一起走一段回宿舍的道?"},
		{"speaker": "周明远", "text": "“我们”指的是我和陈默。", "portrait_form": "spirit"},
	],
	"invite_yes": [
		{"speaker": "李安雅", "text": "好呀！放学见！"},
		{"speaker": "周明远", "text": "放学见！"},
	],
	"invite_no": [
		{"speaker": "李安雅", "text": "抱歉呀，今天我和其他人有约了，就不和你们一起回去了。"},
		{"speaker": "周明远", "text": "欧，好，那注意安全！"},
		{"speaker": "李安雅", "text": "好。谢谢你。"},
	],
	"neighbor_chalk": [
		{"speaker": "旁白", "text": "周明远此行不是来找李安雅的，而是来还东西的。"},
		{"speaker": "旁白", "text": "先前周明远班借过李安雅班粉笔，现在周明远奉命还回去几盒粉笔。"},
		{"speaker": "旁白", "text": "周明远还完粉笔后就回去了。"},
		{"speaker": "周明远", "text": "别离开的这么快啊。", "portrait_form": "spirit"},
	],
	"neighbor_photo": [
		{"speaker": "旁白", "text": "周明远在门口扫视了一下，没有看见李安雅。"},
		{"speaker": "周明远", "text": "她应该上厕所去了。"},
		{"speaker": "旁白", "text": "周明远正准备离开时，被一个李安雅班里的女生拉到了墙角。"},
		{"speaker": "周明远", "text": "……什么情况，干什么？"},
		{"speaker": "女生", "text": "（凑过耳边）我是雅雅的好闺蜜，来代她给你送个东西。"},
		{"speaker": "周明远", "text": "雅雅就是李安雅。", "portrait_form": "spirit"},
		{"speaker": "旁白", "text": "女生拿出了一张照片，很快速地塞给了周明远。", "story_cg": "res://assets/graphics/cg/anya_gift/photo_handoff.png"},
		{"speaker": "女生", "text": "先说明下，这照片我完全没看到底是什么，我不是那种窥探人家隐私的人。"},
		{"speaker": "女生", "text": "总之，我任务完成了，bye！"},
		{"speaker": "旁白", "text": "女生发出稀碎的笑声离开了。", "story_cg": ""},
		{"speaker": "周明远", "text": "什么啊，神神秘秘的……"},
		{"speaker": "周明远", "text": "我看看……欧，是这张啊。"},
		{"speaker": "旁白", "text": "你看着这张合影照片。", "photo": "res://assets/graphics/cg/photo_highschool_friends.png"},
		{"speaker": "周明远", "text": "好像确实是这么拿到的照片？", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "不对，不一样。穿越用的照片是我当天洗的，不是这张。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "这张好像在大学搬宿舍时丢了，我一直没去找。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "难道这张后面丢失的照片和穿梭时空有隐约的关联？", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "现在没法知道，往后面再看看吧。", "portrait_form": "spirit"},
		{"speaker": "旁白", "text": "周明远把照片收好，回到了教室。"},
		{"speaker": "周明远", "text": "李安雅是这样的，有时候挺害羞的，还喜欢搞神秘。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "但是你为什么后面要神秘到搞失踪啊……", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "这次，一定要找到你。", "portrait_form": "spirit"},
	],
	"corridor_food": [
		{"speaker": "旁白", "text": "周明远在走廊里听着别的班同学的谈话。"},
		{"speaker": "同学A", "text": "这高三搬到五楼了，吃饭也太不方便了。"},
		{"speaker": "同学B", "text": "是啊，错峰吃饭还让高三最后一个去吃饭，等到地方早就没得吃了，都被高一高二的吃光了。"},
		{"speaker": "同学A", "text": "是啊，我们吃什么。"},
		{"speaker": "同学B", "text": "是啊，吃什么。"},
	],
	"corridor_ghost": [
		{"speaker": "旁白", "text": "周明远在走廊碰到了正在看窗外风景的陈默。"},
		{"speaker": "周明远", "text": "景色好看吗？"},
		{"speaker": "陈默", "text": "看两年多了，有啥新意。"},
		{"speaker": "周明远", "text": "不像你平时的样子。昨晚没睡好？"},
		{"speaker": "陈默", "text": "你懂我。舍友的呼噜声太大了，然后还有那什么“校园怪谈”吓死人了。"},
		{"speaker": "周明远", "text": "什么校园怪谈？"},
		{"speaker": "陈默", "text": "你到时候有时间随便找个同学问下“宿舍幽灵”的怪谈就行了。下课时间太短了说不完。"},
		{"speaker": "陈默", "text": "昨晚宿舍门突然开了，真是吓死我了。"},
		{"speaker": "周明远", "text": "你真信这个？估计就只是宿管阿姨半夜查寝吧。"},
		{"speaker": "周明远", "text": "你还是坚定的唯物主义战士不。"},
		{"speaker": "陈默", "text": "不是。真的，给你碰上一次你也不是了。"},
		{"speaker": "周明远", "text": "好吧。反正我是不信有什么幽灵的。"},
		{"speaker": "周明远", "text": "我用最直白，最简单，最不绕弯子的话告诉你，幽灵真的存在。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "那就是我。虽然你不知道。", "portrait_form": "spirit"},
	],
	"corridor_anya": [
		{"speaker": "旁白", "text": "周明远在走廊碰到了李安雅。"},
		{"speaker": "周明远", "text": "hello!"},
		{"speaker": "李安雅", "text": "你好呀，周明远。"},
		{"speaker": "旁白", "text": "二人分开了。"},
		{"speaker": "周明远", "text": "就这样？", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "无效交流。", "portrait_form": "spirit"},
	],
	"corridor_show": [
		{"speaker": "旁白", "text": "走廊突然爆发了洪水般的笑声。"},
		{"speaker": "旁白", "text": "周明远好奇地走到了笑声的源头。"},
		{"speaker": "周明远", "text": "这是王嘉琪吗……哈哈哈哈哈哈哈哈"},
		{"speaker": "旁白", "text": "只见王嘉琪戴着一个黑客面具，在走廊\"招摇过市\"。", "story_cg": "corridor_parade"},
		{"speaker": "王嘉琪", "text": "我是一名低调的黑客。现在我要攻破学校的沃希平板了。"},
		{"speaker": "旁白", "text": "王嘉琪装模作样地模仿敲键盘的样子。", "story_cg": "corridor_keyboard"},
		{"speaker": "旁白", "text": "但是很快，随着聚集的人变多，事态变得不对起来。"},
		{"speaker": "教导主任", "text": "散了散了散了，都干什么呢！"},
		{"speaker": "旁白", "text": "人群被很快打散，只留下了戴着黑客面具的王嘉琪。", "story_cg": ""},
		{"speaker": "旁白", "text": "结局是显而易见的：面具被没收，王嘉琪又在教导主任的小本子上被记过了一笔。", "story_cg": "corridor_confiscated"},
		{"speaker": "周明远", "text": "真是悲伤的结局。", "portrait_form": "spirit"},
	],
}

static func day_token() -> String:
	return "%d:%d" % [GameState.day, int(GameState.get_flag(HighschoolRewindData.FLAG_REWIND_COUNT, 0))]

static func photo_ready() -> bool:
	var related: Array = GameState.get_flag(ANYA_EVENTS, [])
	return GameFlow.has_flag(WALKED_HOME) and related.size() >= 3 and not key_event_completed("neighbor_photo")

static func seen(block: String) -> bool:
	return GameFlow.has_flag(PREFIX + "seen." + block)

static func key_event_completed(event_id: String) -> bool:
	return event_id == "neighbor_photo" and (GameFlow.has_flag(PHOTO_RECEIVED) or seen(event_id))

static func eligible_events(activity: String) -> Array[String]:
	var result: Array[String] = []
	var minute := GameState.in_game_minutes
	match activity:
		"chat":
			result.assign(["chat_notes", "chat_zhang", "chat_chen", "chat_empty", "chat_busy"])
			if GameFlow.has_flag(PREFIX + "seen.chat_zhang"): result.append("chat_roof")
			if (minute >= 710 and minute < 780) or (minute >= 1100 and minute < 1140): result.append("chat_meal")
			if int(GameState.get_flag(HighschoolData.FLAG_DAY_INDEX, 0)) == 0 and minute >= 530 and minute < 540 \
					and HighschoolFirstPeriodData.answer_branch() != "own_answer" \
					and String(GameState.get_flag(PREFIX + "copied_chat_day", "")) != day_token():
				return ["chat_copied"]
		"walk":
			result.assign(["walk_show", "walk_problem", "walk_chen", "walk_food", "walk_grove"])
			if not GameFlow.has_flag(MOCK_EXAM_STARTED): result.append("walk_exam")
		"toilet":
			result.assign(["toilet_quick", "toilet_stomach", "toilet_phone", "toilet_note", "toilet_exam"])
		"neighbor":
			result.assign(["neighbor_absent", "neighbor_chalk"])
			if minute < 720: result.append("neighbor_morning")
			elif minute < 1140: result.append("neighbor_afternoon")
			elif String(GameState.get_flag(PREFIX + "invite_day", "")) != day_token(): result.append("neighbor_evening")
			if photo_ready(): result.append("neighbor_photo")
		"corridor": result.assign(["corridor_ghost", "corridor_anya", "corridor_show", "corridor_food"])
	return result

## 先过滤时间与剧情前置，再优先含未读对话的事件；全部读过才回到完整随机池。
static func selection_pool(activity: String) -> Array[String]:
	var eligible := eligible_events(activity)
	var unread: Array[String] = []
	for event_id in eligible:
		var has_unread := not seen(event_id)
		if event_id == "walk_show": has_unread = has_unread or not seen("walk_teacher")
		if event_id == "neighbor_evening": has_unread = has_unread or not seen("invite_yes") or not seen("invite_no")
		if has_unread: unread.append(event_id)
	return eligible if unread.is_empty() else unread

static func _choose_branch(yes_block: String, no_block: String = "") -> bool:
	var yes_unread := not seen(yes_block)
	var no_unread := no_block != "" and not seen(no_block)
	if yes_unread != no_unread: return yes_unread
	return randf() < 0.5

## 开始活动时抽取并保存；走到另一场景或读档不会重新抽签。
static func begin(activity: String) -> Dictionary:
	var pending: Dictionary = GameState.get_flag(PENDING, {})
	if pending.get("activity", "") == activity:
		# 已完成活动的侧房存档只继续返程，不再抽取另一段事件。
		if key_event_completed(String(pending.get("id", ""))) and not bool(pending.get("completed", false)):
			pending = pending.duplicate(true)
			pending["completed"] = true
			GameFlow.set_flag(PENDING, pending)
		return pending
	var candidates := selection_pool(activity)
	if candidates.is_empty(): return {}
	var event_id: String = candidates.pick_random()
	pending = {"activity": activity, "id": event_id,
		"teacher": _choose_branch("walk_teacher") if event_id == "walk_show" else false,
		"invite": _choose_branch("invite_yes", "invite_no") if event_id == "neighbor_evening" else false}
	GameFlow.set_flag(PENDING, pending)
	return pending

static func dialogue_blocks(event: Dictionary) -> Array[String]:
	var id := String(event.get("id", ""))
	var blocks: Array[String] = []
	if id.begins_with("neighbor_"): blocks.append("neighbor_intro")
	if id in ["toilet_phone", "toilet_note"]: blocks.append("toilet_stomach")
	blocks.append(id)
	if id == "walk_show" and bool(event.get("teacher", false)): blocks.append("walk_teacher")
	if id == "neighbor_evening": blocks.append("invite_yes" if bool(event.get("invite", false)) else "invite_no")
	return blocks

static func lines_for(block: String) -> Array:
	var result: Array = []
	for raw: Dictionary in DialoguePatch.apply("highschool.break." + block, DIALOGUES[block]):
		if raw.has("unless_flag") and GameFlow.has_flag(raw.unless_flag): continue
		if bool(raw.get("requires_standing", false)) and HighschoolFirstPeriodData.answer_branch() == "own_answer": continue
		var line := raw.duplicate(true)
		if line.has("unknown_speaker") and not GameFlow.has_flag(KNOWS_ZHANG): line.speaker = line.unknown_speaker
		result.append(line)
	return result

## 只有完整播完事件才留下线索。纸条、照片及关键节点均幂等。
static func complete(event: Dictionary) -> void:
	var id := String(event.get("id", ""))
	if not DIALOGUES.has(id) or bool(event.get("completed", false)) or key_event_completed(id): return
	if id in ["chat_zhang", "walk_exam"]: GameFlow.set_flag(KNOWS_ZHANG, true)
	if id == "chat_copied": GameFlow.set_flag(PREFIX + "copied_chat_day", day_token())
	if EVENT_CLUES.has(id): GameFlow.set_flag(HighschoolNightTaskData.CLUE_PREFIX + EVENT_CLUES[id], true)
	if id == "toilet_note": HighschoolRewindData.claim_item_once("toilet_note", "highschool_boxing_note")
	if id == "neighbor_evening":
		GameFlow.set_flag(PREFIX + "invite_day", day_token())
		GameFlow.set_flag(INVITE_RESULT, "accepted" if bool(event.get("invite", false)) else "declined")
	if id in ["chat_meal", "neighbor_morning", "neighbor_afternoon", "neighbor_evening", "corridor_anya"]:
		var related: Array = GameState.get_flag(ANYA_EVENTS, []).duplicate()
		if id not in related: related.append(id)
		GameFlow.set_flag(ANYA_EVENTS, related)
	if id == "neighbor_photo" and photo_ready():
		HighschoolRewindData.claim_item_once("anya_gift_photo", "highschool_anya_photo")
		GameFlow.set_flag(PHOTO_RECEIVED, true)
		GameFlow.set_flag(HighschoolRewindData.FLAG_KEY_NODE, true)
		for hud in Engine.get_main_loop().get_nodes_in_group("overworld_hud"):
			hud.show_toast("关键节点解锁：李安雅的照片", 5.0)
	# 包括真正播出的共用引子和随机分支；中途退出不提前记为已读。
	for block in dialogue_blocks(event): GameFlow.set_flag(PREFIX + "seen." + block, true)
	var finished := event.duplicate(true)
	finished["completed"] = true
	GameFlow.set_flag(PENDING, finished)

## 留给放学同行剧情：邀约成功本身不等于已经一起回过宿舍。
static func complete_return_walk() -> void:
	GameFlow.set_flag(WALKED_HOME, true)
