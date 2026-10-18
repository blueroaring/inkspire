class_name HighschoolFirstPeriodData
extends RefCounted
## 第一次课间及数学课。抄没抄与补没补完是两回事。
const BREAK := "first_break"
const BOARD := "first_break_alyina"
const OUTING := "first_break_outing"
const RETURN := "first_break_return"
const END := "second_class_ready"
const FLAG_COPIED := "highschool.rewind.copied_cong"
const FLAG_TEACHER := "highschool.rewind.teacher_at_seating"
const FLAG_FINISHED := "highschool.rewind.first_math_finished"
const FLAG_BREAK_TUTORIAL := "highschool.rewind.break_tutorial_seen"
const BREAK_TUTORIAL: Array[String] = [
	"不同的选择可能触发不同的事件。",
	"即使选择相同的选项，触发的事件也可能不同。",
	"不同事件可能会获得不同的线索，而线索可以用来接取夜间任务或触发关键节点。",
	"现在你可以用J查看当前可接取的任务与接取该任务需要获得的线索了。",
	"只有触发了关键节点的剧情，剧情才会继续推进。",
	"如果还没有找到某些线索，可以在回溯的每一天中不断尝试寻找。",
]
const FLAG_TRIP := "highschool.rewind.break_trip"
const FLAG_STEP := "highschool.rewind.break_trip_step"
const FLAG_ACTIVITY := "highschool.rewind.break_activity"
const FLAG_BOARD_SEEN := "highschool.rewind.break_board_seen"
const FLAG_MAP := "highschool.alyina.campus_map_unlocked"
const TIMETABLE_ITEM := "highschool_timetable"
const TIMETABLE_IMAGE := "res://assets/graphics/ui/highschool_timetable.png"
const OPTIONS := [
 {"id": "break_alyina", "text": "切换到艾莉娜视角"},
 {"id": "break_nap", "text": "趴在桌子上眯一会"},
 {"id": "break_chat", "text": "和附近的同学聊天"},
 {"id": "break_walk", "text": "在教室走走"},
 {"id": "break_out", "text": "出教室走走"},
]
const OUTSIDE := [
 {"id": "toilet", "text": "去上厕所"},
 {"id": "neighbor", "text": "去隔壁班看看"},
 {"id": "corridor", "text": "在走廊逛逛"},
]
const DIALOGUES := {
	"lesson": [
		{"speaker": "旁白", "text": "第一节课是班主任的数学课。"},
		{"speaker": "班主任", "text": "都把昨天留的卷子拿出来，我们先把选择填空讲了。"},
		{"speaker": "班主任", "text": "老规矩，简单的题我找人回答解题思路，你们不会的我来讲。"},
		{"speaker": "班主任", "text": "大家先对下答案。"},
		{"speaker": "旁白", "text": "同学们纷纷看着沃希平板上的答案对了起来。"},
		{"speaker": "旁白", "text": "一会后。"},
		{"speaker": "班主任", "text": "报一下你们选择填空有哪些题不会的。"},
		{"speaker": "坐最前面的男生", "text": "3。", "story_cg": "math_question"},
		{"speaker": "周明远", "text": "我记得他叫王嘉琪，是个活宝嘉豪。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "至于上课时吗……有时候他举手回答无意间就会变成纯捣乱的情况。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "不过有了他确实让生活变得有趣了。", "portrait_form": "spirit"},
		{"speaker": "丛龙业", "text": "11，14。", "story_cg": ""},
		{"speaker": "周明远", "text": "很多时候并不是他不会，他只是帮我们这些不想举手发言的人代言一下。", "portrait_form": "spirit"},
		{"speaker": "很小声的女生", "text": "第八题。"},
		{"speaker": "周明远", "text": "这位应该是叫刘子涵。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "子涵这个名字重名的真的是太多了。", "portrait_form": "spirit"},
		{"speaker": "班主任", "text": "3，8，10，14。还有吗？"},
		{"speaker": "旁白", "text": "班级静默了一段时间。"},
		{"speaker": "班主任", "text": "行，那就先讲这些题。"},
		{"speaker": "班主任", "text": "第三题……这不就是集合运算和诱导公式吗？"},
		{"speaker": "班主任", "text": "王嘉琪，你说下你具体是哪块不会。", "story_cg": "math_response"},
		{"speaker": "王嘉琪", "text": "老师，我好像是诱导公式算错了，现在已经看懂了。"},
		{"speaker": "班主任", "text": "以后做错了先自己想下为什么再问，性子稳一点，别这么毛糙。"},
		{"speaker": "班主任", "text": "下一题，第八题。", "story_cg": ""},
		{"speaker": "班主任", "text": "这题其实不难，但是你得注意到一些这道题的特点，不能蛮干。"},
		{"speaker": "班主任", "text": "我找个同学问下他的思路吧。"},
		{"speaker": "班主任", "text": "周明远，你说下你怎么算的这个数学期望。"},
		{"speaker": "旁白", "text": "周明远本来在不断地“点头”打瞌睡。"},
	],
	"called": [
		{"speaker": "旁白", "text": "听到名字后，周明远惊醒站了起来。"},
		{"speaker": "周明远", "text": "老师，这题选A。"},
		{"speaker": "班主任", "text": "让你讲下你做这道题的思路。"},
	],
	"own_answer": [
		{"speaker": "周明远", "text": "（还好这道题补作业的时候做了。）"},
		{"speaker": "周明远", "text": "这道题就是观察到原来没有剔除（1，1，1）这个点时总期望为0……"},
		{"speaker": "旁白", "text": "周明远很顺利地回答了问题。"},
		{"speaker": "班主任", "text": "好，坐吧。"},
	],
	"own_after": [
		{"speaker": "旁白", "text": "周明远偷偷松了一口气。"},
		{"speaker": "旁白", "text": "后面老班继续讲解着卷子，不过周明远已经无心听课了。"},
		{"speaker": "旁白", "text": "周明远只是在一直点着头，处于半梦半醒的状态。"},
	],
	"copied_answer": [
		{"speaker": "周明远", "text": "（坏了坏了，光抄了根本没看题。）"},
		{"speaker": "周明远", "text": "（快速扫视题目）"},
		{"speaker": "周明远", "text": "额……把样本空间按照这个函数都加起来然后求平均？"},
		{"speaker": "班主任", "text": "你真是这么做的吗？这么大的样本空间一个一个算吗。"},
		{"speaker": "班主任", "text": "要是真考试，你这一道题就得花20分钟。"},
	],
	"copied_early": [
		{"speaker": "班主任", "text": "你先站会清醒一下，好好听这道题该怎么做最好。"},
		{"speaker": "旁白", "text": "后面老班继续讲解着卷子，不过周明远已经无心听课了。"},
		{"speaker": "旁白", "text": "周明远只是在想什么时候能让他坐下。"},
		{"speaker": "旁白", "text": "可惜直到下课铃响起，老班也没有让他坐下。"},
	],
	"copied_late": [
		{"speaker": "班主任", "text": "你这第一天就写不完作业，后面一轮复习二轮复习怎么跟上啊。"},
		{"speaker": "班主任", "text": "你先站会，抓紧把卷子补完。"},
		{"speaker": "旁白", "text": "后面老班继续讲解着卷子，不过周明远已经无心补卷子了。"},
		{"speaker": "旁白", "text": "周明远只是在想什么时候能让他坐下。"},
		{"speaker": "旁白", "text": "可惜直到下课铃响起，老班也没有让他坐下。"},
	],
	"after_bell": [
		{"speaker": "周明远", "text": "真倒霉，真能被点到啊。", "portrait_form": "spirit"},
		{"speaker": "周明远", "text": "不过上课打瞌睡老班肯定在讲台看的一清二楚，叫起来也正常。", "portrait_form": "spirit"},
	],
	"board": [
		{"speaker": "艾莉娜", "text": "唉，仓库旁竟然有校园地图唉！这下不会迷路了！"},
		{"speaker": "艾莉娜", "text": "还有校园时刻表！"},
	],
	"board_reward": [
		{"speaker": "旁白", "text": "艾莉娜现在能使用校园地图了。"},
		{"speaker": "旁白", "text": "校园时刻表可以在背包回看。"},
	],
	"nap": [
		{"speaker": "旁白", "text": "周明远把卷子往旁边推了推，趴在桌子上眯了一会。"},
	],
	"chat": [
		{"speaker": "周明远", "text": "丛大哥，第八题你也是这么做的？"},
		{"speaker": "丛龙业", "text": "先看整体，再把多出来的那个点去掉，就不用挨个算了。"},
		{"speaker": "旁白", "text": "附近的同学凑过来，几个人又聊起了刚才的卷子。"},
	],
	"walk": [
		{"speaker": "旁白", "text": "周明远沿着课桌间的过道走了走，在窗边伸展了一下肩膀。"},
	],
	"toilet": [
		{"speaker": "旁白", "text": "周明远上完厕所，在洗手池洗了洗手。"},
	],
	"neighbor": [
		{"speaker": "旁白", "text": "隔壁的501班也下课了，有人还在对答案，有人已经趴在桌上休息。"},
	],
	"corridor": [
		{"speaker": "旁白", "text": "周明远沿着五楼走廊慢慢走了一圈，隔着窗户看了看楼下的校园。"},
	],
}

static func snapshot_seating() -> void:
	GameFlow.set_flag(FLAG_COPIED, GameFlow.has_flag(HighschoolRewindData.FLAG_BREAKFAST_EATEN))
	GameFlow.set_flag(FLAG_TEACHER, HighschoolMorningData.teacher_present(HighschoolMorningData.arrival_minute()))

static func answer_branch() -> String:
	if not bool(GameState.get_flag(FLAG_COPIED, GameFlow.has_flag(HighschoolRewindData.FLAG_BREAKFAST_EATEN))): return "own_answer"
	return "copied_late" if bool(GameState.get_flag(FLAG_TEACHER,
		HighschoolMorningData.teacher_present(HighschoolMorningData.arrival_minute()))) else "copied_early"

static func target_location(stage: String) -> String:
	if stage in [BREAK, RETURN, END]: return "highschool.classroom_502"
	if stage == BOARD: return "highschool.alyina_memory"
	if stage == OUTING:
		return "highschool.teaching_room" if String(GameState.get_flag(FLAG_STEP, "")) == "room" else "highschool.teaching_5f"
	return ""

static func grant_board() -> void:
	GameFlow.set_flag(FLAG_MAP, true)
	if not Inventory.has(TIMETABLE_ITEM, 1, GameState.BAG_HIGHSCHOOL):
		Inventory.add(TIMETABLE_ITEM, 1, GameState.BAG_HIGHSCHOOL)
	GameFlow.set_flag(FLAG_BOARD_SEEN, true)

static func append_tree(nodes: Array[Dictionary]) -> void:
	if not GameFlow.has_flag(FLAG_FINISHED): return
	nodes.append({"id": "first_break", "text": "08:50 · 第一节课下课", "at": Vector2(1840, 210), "parents": ["seated_502"], "state": "done"})
	var choices: Array = GameState.get_flag(HighschoolRewindData.FLAG_DAY_CHOICES, [])
	var committed := HighschoolRewindData.stage() == END or choices.any(func(id: String) -> bool:
		return id in ["break_nap", "break_chat", "break_walk", "break_out", "finish"])
	for i in OPTIONS.size():
		var option: Dictionary = OPTIONS[i]
		nodes.append({"id": option.id, "text": option.text, "at": Vector2(2110, i * 150), "parents": ["first_break"],
			"state": "done" if option.id in choices else ("missed" if committed else "available")})
	if "break_out" in choices:
		for i in OUTSIDE.size():
			var option: Dictionary = OUTSIDE[i]
			nodes.append({"id": option.id, "text": option.text, "at": Vector2(2380, 480 + i * 150), "parents": ["break_out"],
				"state": "done" if option.id in choices else ("missed" if committed else "available")})
