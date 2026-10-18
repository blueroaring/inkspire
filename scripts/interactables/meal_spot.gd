class_name MealSpot
extends Interactable
## 大学食堂的**打饭窗口**（按 E：打饭 → 吃饭 → 顺手在食堂帮工）。
##
## 为什么需要它（`request/08_DIALOG.md` 开场那两段一直没有落点）：
##   08 里明明白白写着"打饭时对话"与"吃饭时对话"，而这两段在旧实现里**没有交互点** ——
##   玩家进食堂只能直接去洗碗工位打工，打饭/吃饭这两句谁也没播过。
##   开场的任务链（见 `QuestData.STEPS`）又要求"先去食堂吃饭"，于是必须给它一个落点。
##
## 职责边界（与 `WorkSpot` 同一条口径：本脚本只管"串台词 + 写开关 + 走时间"）：
##   · 台词正文        -> 本文件顶部的三个常量（对话编辑器按 `canteen.meal.*` 覆盖）
##   · 能不能打工      -> `Currency.work_block_reason()` / `Currency.can_work()`
##   · 打工那一趟本身  -> `WorkSpot.start_shift()`（**不重写**：小游戏、结算、时段规则都在那边）
##
## ⚠️ 走时间放在**吃完之后**：吃饭 = 12:04 出门 → 吃完 12:30（08 原文"吃完饭时间改为 12:30"）。
##    用 `advance_time(30)` 而不是 `wait_until(12, 30)` —— 后者在"已经过了 12:30"时会
##    **顺延到第二天**（`GameFlow.wait_until` 的语义就是"下一个 hh:mm"），
##    玩家 11 点来吃饭会被莫名其妙地推到明天。
##
## ⚠️ "只演一次"落在**剧情开关**上（`ate_lunch` / `canteen_meal_worked`），不用节点上的 `_used`：
##    离开食堂再回来就是一个新节点，那两段剧情会重播（与"睡觉/看照片只该触发一次"同一个坑）。

## 吃过饭的开关（`QuestData.STEPS` 读它推进指引；**教学楼那道门与洗碗工位也读它**）
const FLAG_ATE := QuestData.FLAG_ATE
const FLAG_ATE_ALYINA_DINNER := QuestData.FLAG_ATE_ALYINA_DINNER
## "打工这一步已经了结"（干过一趟 / 明确不干 / 这会儿干不了）——
## 任务指引下一步"打开背包看手机"的完成条件（见 `QuestData.FLAG_WORK_CHOICE_DONE`）
const FLAG_WORK_CHOICE_DONE := QuestData.FLAG_WORK_CHOICE_DONE
## "这一趟**真的拿到了工钱**"（由 `WorkSpot` 按"钱包有没有变多"写）。
## 用途：看手机那句"走吧，去教学楼上课去"里的**"赚了点钱"**——没赚到就不该说
## （用户 2026-09-20："如果选择打工没赚到钱同理"）。
const FLAG_EARNED := "canteen_meal_earned"
## "顺手帮工那一趟"走过的开关（打工的时段名额另有 `Currency` 记账，这里是剧情口径）
const FLAG_WORKED := "canteen_meal_worked"


# ---------------------------------------------------------------- 台词（对话编辑器的原文）
#
# ⚠️ 台词登记在 `DialogueCatalog` 的 `canteen.meal.buy` / `.eat` / `.work_choice`，
#    改文案请用 `tools/dialogue_editor.tscn`（覆盖层），不要直接改这里。
#    （"顺便做个帮工"那句不在这里 —— 它在 `dorm.roommate.first`，见下面的说明。）

## 打饭（08："打饭时对话"）
##
## ⚠️ 第二句是**旁白**（`speaker` 留空），第三句是**内心独白** ——
##    08 写的是"周明远（内心）：算了……习惯了"，所以 `speaker` 用
##    `周明远（内心）`（显示名映射见 `scripts/data/speakers.gd`）。
##    这也是用户 2026-09-20 的要求："这句话也是对话框的内容" ——
##    凡是 08 里以"周明远（内心）"开头的，都要在**对话框**里出现，而不是塞进任务提示。
const BUY_LINES := [
	{"speaker": "周明远", "text": "要一份红油干拌羊肉面，加鸡蛋，不加香菜，少加辣。", "emotion": "熟练"},
	{"speaker": "", "text": "食堂阿姨没有听清你的需求，还是给你加了致死量的香菜和辣油。"},
	{"speaker": "周明远（内心）", "text": "算了……习惯了。", "emotion": "认命"},
]

## 吃饭（08："吃饭时对话"：两句都是"周明远（内心）"）
const EAT_LINES := [
	{"speaker": "周明远（内心）", "text": "食堂还是一如既往的难吃。", "emotion": "面无表情"},
	{"speaker": "周明远（内心）",
		"text": "要不是一会要在食堂打工赚钱，今天还不如直接去校外吃了。", "emotion": "盘算"},
]

## 艾莉娜登场后的晚间第一次来到窗口：这是独立于开场午饭的晚饭交互。
## 旁白与艾莉娜都保留在对话框里，播完后只写晚饭开关；下一次再按窗口
## 才回到通用的“饭已经打过了”提示。
const ALYINA_DINNER_LINES := [
	{"speaker": "", "text": "你在食堂吃了一顿晚饭。"},
	{"speaker": "", "text": "或许是因为交了一个新\"小精灵\"朋友，你感觉食堂的饭菜都变好吃了。"},
	{"speaker": "艾莉娜", "text": "呜呜呜，我也想吃东西……但是我吃不到！"},
]

## ⚠️ 原来这里还有一句"那就一会顺便做个食堂帮工赚点外快吧"（`WORK_OFFER_LINES`），
##    用户 2026-09-20 明确了它的位置：08 里它紧跟在**陈默那段对话**的末尾
##    （见 `dorm.roommate.first` 的最后一行），所以那句话整个搬去了宿舍，
##    这里**不再保留任何副本** —— 留一个空常量 + 一条空台词登记只会让人以为它还在用。

## 紧接着那个选项（"要不要这就去打工"）。
##
## ⚠️ 它单独列成常量、并登记进对话编辑器，是因为**带 `choices` 的行也能改文案**
##    （见 `DialoguePatch` 的说明：选项分支跟着行一起走，编辑器会把 `choices` 原样保留）。
##    内联写在 `_offer_shift()` 里的话，这段字就没法在编辑器里改。
##
## ⚠️ 第二个选项那句是 08 的原文（第 153 行"周明远（内心）:走吧，去教学楼上课去……"），
##    所以它也是"内心"口径。
##
## ⚠️ 第一个选项里的 `flag` 写的是**字面量**、不是 `FLAG_CHOSE_WORK`：
##    `const` 里不能引用同一脚本另一个 const 之外的运行期值，而 GDScript 的
##    const 字典又是只读的（不能事后塞字段）。两边的值由 `meal_spot` 的自检断言钉住。
const WORK_CHOICE_LINE := {
	"speaker": "周明远（内心）", "text": "现在就去后厨报个到？", "emotion": "犹豫",
	"choices": [
		{
			"text": "去后厨打工（玩一把盘子分类）",
			"flag": "canteen_meal_choice_work",
			"next": [],
		},
		{
			"text": "先不打工，去教学楼那边",
			"next": [
				{"speaker": "周明远（内心）",
					"text": "走吧，去教学楼上课去。赚了点钱，去教学楼前顺便在自动贩卖机"
						+ "或者教育超市买点可乐什么的也行。",
					"emotion": "点头"},
			],
		},
	],
}

## 吃完这一顿要花掉多少游戏内时间（分钟）
const MEAL_MINUTES := 30

## 这次交互里玩家到底选了什么 —— 用**开关**记，不去读对话框的内部状态。
##
## 为什么这么做：`DialogueBox.play_script()` 内部走完 `choices` 分支就返回了，
## 它**不把选中项交出来**（`ask()` 才交）。而这里要的是"选完之后接着去打工"，
## 所以让选项分支自己写一个开关，播完再读 —— 这比反射式地去摸 `_choice_made` 稳得多。
const FLAG_CHOSE_WORK := "canteen_meal_choice_work"

## 打饭这一段的口子：**跟陈默聊过之后**才开。
##
## 为什么要有这道门槛（而不是进食堂就能打饭）：
##   ① 那句"给我带饭"是陈默在宿舍说的，先打饭再回宿舍问"带什么"就前后颠倒了；
##   ② 任务指引也是这个顺序（`QuestData.STEPS`：先室友 → 再食堂 → 再去上课），
##      两处口径必须一致，否则玩家会先看见"去食堂吃饭"却打不了饭。
##
## ⚠️ 名字转发自 `QuestData`（那边是任务链的同一个开关）：
##    这里再写一遍字面量的话，改任务链时两边会静默分家（门开着、任务却还说没做）。
const FLAG_ROOMMATE := QuestData.FLAG_ROOMMATE


func _ready() -> void:
	# 提示与"看看洗碗池"区分开：这是打饭的那扇窗，不是洗东西的池子
	if custom_prompt == "":
		custom_prompt = "在打饭窗口打饭"
	if object_kind == "物件":
		object_kind = "打饭窗口"
	super._ready()


func can_interact() -> bool:
	# 还没跟陈默说过话：这个窗口不存在（连提示都不给，理由见 `FLAG_ROOMMATE`）
	if not GameFlow.has_flag(FLAG_ROOMMATE):
		return false
	return super.can_interact()


## 提示**随进度变**：吃过饭之后就不能再写"打饭"了。
##
## ⚠️ 用户 2026-09-20："打饭后不应该还有打饭的交互" ——
##    交互点本身留着（后厨那一趟是从这里接上的），但名字必须改掉：
##    否则吃完之后再站到窗口前，提示还写着"在打饭窗口打饭"，玩家会以为能再打一份。
func get_prompt() -> String:
	if _is_alyina_dinner_window() and not GameFlow.has_flag(FLAG_ATE_ALYINA_DINNER):
		return "在打饭窗口打饭"
	if GameFlow.has_flag(FLAG_ATE):
		return "在窗口前站一会儿"
	return super.get_prompt()


## 排位**动态**：只有"还没吃上这顿饭"的时候才排在前面。
##
## ⚠️ 为什么必须动态（实测踩到）：打饭窗口的交互区是**从柜台一路伸到过道**的
##    （见 `CanteenData.MEAL_REACH_PX` —— 不伸出去就够不到），而洗碗工位就在那片过道上。
##    如果窗口永远带着高优先级，那么吃完之后站在工位前按 E，出来的会是
##    "在打饭窗口打饭"而不是"干一趟活（食堂帮工）"—— 主线的下一步反而按不到了。
##    吃完之后它退回 0，按距离排，工位那边（能开工时是 10）自然赢。
func interaction_priority() -> int:
	if _is_alyina_dinner_window() and not GameFlow.has_flag(FLAG_ATE_ALYINA_DINNER):
		return 9
	return 9 if not GameFlow.has_flag(FLAG_ATE) else 0


func _interact() -> void:
	var was_moving := begin_dialogue_lock()

	# 艾莉娜登场后的晚间晚饭不应复用午饭流程：午饭开关已经为真时，
	# 仍先检查这条独立分支。晚间窗口覆盖 17:00 后的食堂晚班以及 20:00
	# 后的剧情晚间，保证登场 CG 在 17:00 返回校园后即可触发。
	if _is_alyina_dinner_window():
		if not GameFlow.has_flag(FLAG_ATE_ALYINA_DINNER):
			await DialogueBox.play_script(
				DialoguePatch.apply("canteen.meal.alyina_dinner", ALYINA_DINNER_LINES))
			GameFlow.set_flag(FLAG_ATE_ALYINA_DINNER, true)
		else:
			await _play_meal_done_line()
		end_dialogue_lock(was_moving)
		return

	# 08 的顺序：打饭（点单）→ 到桌子吃饭（走 30 分钟）→（可选）打工
	# → **打开背包看手机** → 去教学楼。
	# ⚠️ "帮工"那句原话在**陈默那段对话**里（见 `dorm.roommate.first`），这里不重复。
	if not GameFlow.has_flag(FLAG_ATE):
		await DialogueBox.play_script(DialoguePatch.apply("canteen.meal.buy", BUY_LINES))
		# ⚠️ 时间**必须在"吃饭"这一步走**（08："吃完饭时间改为 12:30"），不要挪到后面：
		#    这一串里玩家可能中途退出（按 ESC 跳过对话不算），时间走得越靠后越容易漏。
		await DialogueBox.play_script(DialoguePatch.apply("canteen.meal.eat", EAT_LINES))
		GameFlow.advance_time(MEAL_MINUTES)
		GameFlow.set_flag(FLAG_ATE, true)
	else:
		# ⚠️ 别再"报个时"了（用户 2026-09-20："在窗口前站一会儿的对话不应该有
		#    「现在 13:34」这一部分"）：那句话既啰嗦，又把"时间"当成窗口在回答的事。
		#    现在吃过之后再站在窗口前，只说一句"没什么事了"。
		await _play_meal_done_line()
		end_dialogue_lock(was_moving)
		return

	# 08 的顺序：打饭 → 吃饭 →（可选）打工 → **打开背包看手机** → 去教学楼。
	# ⚠️ 所以"要不要这就去打工"紧跟在吃饭之后（用户 2026-09-20 明确的三步顺序）。
	await _offer_shift(was_moving)

	end_dialogue_lock(was_moving)


func _play_meal_done_line() -> void:
	await DialogueBox.play_script([
		{"speaker": "周明远（内心）",
			"text": "饭已经打过了，窗口这儿没什么事了。", "emotion": "自语"},
	])


func _is_alyina_dinner_window() -> bool:
	if not GameFlow.has_flag(TeachingData.STORY_ALYINA_MET):
		return false
	# 艾莉娜登场 CG 在 17:00 返回校园；食堂晚班从 17:00 开始，
	# 而剧情晚间从 20:00 开始。两者都属于这条晚饭流程的有效时间。
	return Currency.current_period() == Currency.SLOT_EVENING or GameFlow.is_evening()


## "要不要顺手干一趟"：**每次吃完饭都问一次**（不管干不干，都要把这一步"了结"掉）。
##
## ⚠️ 用户 2026-09-20 的三步顺序：打饭 → 吃饭 →（可选）打工 → 打开背包看手机 → 去教学楼。
##    所以这里有两个出口，**两个都要写 `FLAG_WORK_CHOICE_DONE`**（任务指引那一步的完成条件）：
##      · 去打工：干完（或中途退出）之后算完成；
##      · 不去：选了"先不打工"就算完成 —— 否则指引会一直卡在"在食堂帮工"上，
##        而玩家已经明确表示不干了。
##
## ⚠️ 问之前先判 `Currency.can_work()`：后厨不是饭点不收人（见 `Currency.work_block_reason()`），
##    给一个"选了他也说干不了"的选项比不问更糟；这种情况直接算了结（不耽误下一步）。
##
## ⚠️ 打工那一段会把玩家**锁着**播结算（`WorkSpot.start_shift()` 自己管锁），
##    所以这里把自己的锁先还回去再交给它 —— 否则两层锁叠着，`end_dialogue_lock`
##    恢复出来的状态是错的（见 `Interactable.begin_dialogue_lock` 的说明）。
func _offer_shift(was_moving: bool) -> void:
	if GameFlow.has_flag(FLAG_WORK_CHOICE_DONE):
		return
	var spot := _work_spot()
	if spot == null:
		# 工位没建出来（场景缺数据 / 已经不在场了）：直接了结，免得指引卡住
		GameFlow.set_flag(FLAG_WORK_CHOICE_DONE, true)
		return
	if not Currency.can_work(spot.record_id):
		# 这会儿干不了（不在饭点 / 已经干过）：不了结的话指引会永远卡在"去帮工"
		GameFlow.set_flag(FLAG_WORK_CHOICE_DONE, true)
		return

	GameFlow.set_flag(FLAG_CHOSE_WORK, false)
	await DialogueBox.play_script(
			DialoguePatch.apply("canteen.meal.work_choice", [WORK_CHOICE_LINE]))
	if not GameFlow.has_flag(FLAG_CHOSE_WORK):
		# 选了"先不打工"：**主线这一步**就算了结（指引转去"打开背包看手机"）。
		#
		# ⚠️ 但**不再把工位收掉**（用户 2026-09-20 晚："晚上可以再做一次食堂打工"）：
		#    原来这里 `queue_free()` 掉工位、加上 `canteen.gd` 也不再建它，
		#    后果是**晚上那趟班一起消失了**（`Currency` 的规则本来是"每天中午/晚上各一趟"）。
		#    现在"能不能按"由 `WorkSpot.can_interact()` 按**时段**动态判：
		#      · 这一刻（中午场刚过 / 选择不干）→ `can_work` 为假，按了没反应、也没提示；
		#      · 到了晚上 17:00 之后回食堂 → 它自己又能按了。
		#    "不想干就别再问一遍"这层意思由 `FLAG_WORK_CHOICE_DONE` 保证（本函数开头就返回）。
		GameFlow.set_flag(FLAG_WORK_CHOICE_DONE, true)
		return

	GameFlow.set_flag(FLAG_WORKED, true)
	# 先把自己的锁还回去：`start_shift()` 会按"交互前是否自由移动"自己锁一次
	end_dialogue_lock(was_moving)
	await spot.start_shift()
	# 干完（含中途退出）才算这一步了结：退出虽然没工钱，但那一个钟头与名额都算掉了
	GameFlow.set_flag(FLAG_WORK_CHOICE_DONE, true)
	# 再按"这次交互之前的样子"锁回来，交给调用方的 `end_dialogue_lock` 收尾
	begin_dialogue_lock()


## 场景里那个洗碗工位（同一个食堂场景，节点名由 `canteen.gd` 起成 `Work_<id>`）
##
## ⚠️ 工位**一直都在**（`canteen.gd::_build_work()` 不再按任务开关跳过它）——
##    用户 2026-09-20 晚："晚上可以再做一次食堂打工"。所以这里**不再**用
##    "打饭这一趟处理完没有"（`FLAG_WORK_CHOICE_DONE`）去判断它该不该存在：
##      · 本函数只管"找得到就拿来问一句要不要干"；
##      · "这会儿能不能按"完全交给 `WorkSpot.can_interact()`（按时段动态判）。
func _work_spot() -> WorkSpot:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is WorkSpot:
			return child as WorkSpot
	return null
