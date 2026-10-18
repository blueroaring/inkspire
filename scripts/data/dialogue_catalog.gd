class_name DialogueCatalog
extends RefCounted
## **全项目可编辑台词的清单**（对话编辑器的数据源）。
##
## ------------------------------------------------------------------ 它是干什么的
##
## 台词散在十几个文件里、而且大多是算出来的（按楼层生成教室号、按剧情开关挑分支）。
## 这份清单把"到底有哪些**对话块**"集中回答一次，每块给四样东西：
##
##   `id`    稳定标识 —— 写进 `data/dialogue_patch.json`，也是运行时 `DialoguePatch.apply()` 的键
##   `group` 分组（编辑器左边树的父节点）
##   `label` 人看的名字
##   `lines` **原文**快照（编辑器拿它当"原始版本"，也是"上游已变"检测的基准）
##
## ⚠️ 取的是**原文**：所以数据文件里**不能**套补丁 —— 套用发生在"播的时候"
##    （`DialogueBox` 的各个调用点）。这一条一破，编辑器就会把"你已经改过的版本"
##    当成原文，改一次之后就再也改不回去。
##
## ⚠️ **为什么用快照而不是 Callable**：表是打开编辑器时现建的，快照天然就是那一刻的原文；
##    用闭包反而容易把"已经套过补丁的返回值"取回来（那正是上面那条陷阱）。
##
## ⚠️ 新增台词时同步这里：没登记的对话块在编辑器里看不到（但游戏照常播原文）。
##    加一块的成本就是下面某一行。
##
## ⚠️ 这份表**只做只读遍历**，不写任何数据文件 —— 其中 `CampusData` 那个文件
##    可能正被另一个会话改着（见 `docs/ARCHITECTURE.md` 的分工说明）。

## 拿没有 class_name 的场景脚本里的常量（陈默的台词分支）
const DormRoommateScript := preload("res://scripts/actors/dorm_roommate.gd")


## 非字典条目（编辑器不允许）的过滤器：这里只保证取到的东西是数组
static func blocks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_add_cg(out)
	_add_story(out)
	_add_teaching(out)
	_add_campus(out)
	_add_dorm(out)
	_add_bathroom(out)
	_add_canteen(out)
	_add_banter(out)
	_add_items(out)
	_add_highschool_rewind(out)
	return out


## 按 id 取一块（自检与"顺便校验 id 有没有拼错"用）；找不到返回空字典
static func block(id: String) -> Dictionary:
	for b in blocks():
		if String(b["id"]) == id:
			return b
	return {}


static func block_ids() -> Array[String]:
	var out: Array[String] = []
	for b in blocks():
		out.append(String(b["id"]))
	return out


## 某个 id 的原文（找不到返回空数组）
static func raw_lines(id: String) -> Array:
	var b := block(id)
	if b.is_empty():
		return []
	return (b["lines"] as Array).duplicate(true)


## 正文里带 `%s`/`%d` 的模板文案（编辑器会提醒"别把占位符删了"）
static func has_format_args(id: String) -> bool:
	for line_variant in raw_lines(id):
		if line_variant is Dictionary:
			var text := String((line_variant as Dictionary).get("text", ""))
			if text.contains("%s") or text.contains("%d"):
				return true
	return false


# ---------------------------------------------------------------- 各来源


static func _add(out: Array[Dictionary], id: String, group: String, label: String,
		lines: Array) -> void:
	out.append({"id": id, "group": group, "label": label, "lines": lines.duplicate(true)})


static func _add_cg(out: Array[Dictionary]) -> void:
	_add_shots(out, CgData.intro(), "cg.intro", "剧情 · 开场 CG", "开场")
	_add_shots(out, CgData.alyina_fall(), "cg.alyina_fall", "剧情 · 艾莉娜登场 CG", "艾莉娜登场")
	# ⚠️ 这三句**不在镜头表里**（用户 2026-09-20 要求它从 CG 里挪到"CG 播完之后"）：
	#    它由 `StoryData.maybe_play_alyina_tour()` 在回到校园时播，所以单独登记一段，
	#    id 用 `cg.alyina_fall.landing`（与播放处那个补丁 id **必须一致**）。
	_add(out, "cg.alyina_fall.landing", "剧情 · 艾莉娜登场 CG",
			"艾莉娜登场 · 落地之后（CG 结束）", CgData.alyina_landing_lines())


## CG 的镜头表：只收**带台词的镜头**（纯旁白的镜头没有"对话"可编辑）。
##
## ⚠️ 两种台词都收：`dialogue`（对话框）与 `blackout`（黑底白字字幕）。
##    后者是 CG1 那种"全屏字幕"（见 `NarrationBox`）：它同样是**要改的词**，
##    漏掉的话"改台词不用动源码"这句话在这几个镜头上就不成立。
##    ⚠️ `blackout` 的 `hold`（这一句停多久）**不在编辑器里改**（那是节奏、不是文案），
##       要调时长请直接改 `cg_data.gd`。
##
## ⚠️ id 用镜头**下标**，所以以后往中间插一个镜头，补丁里的下标就会错位 ——
##    编辑器会因此报"上游已变"（这就是那道提醒的意义）。
static func _add_shots(out: Array[Dictionary], sequence: Array, prefix: String,
		group: String, title: String) -> void:
	for i in sequence.size():
		var shot: Dictionary = sequence[i]
		# 一个镜头里两种台词并存时（现在没有），对话框那份优先 —— 免得同一个 id 被写两次
		var lines: Array = shot.get("dialogue", [])
		if lines.is_empty():
			lines = shot.get("blackout", [])
		if lines.is_empty():
			continue
		_add(out, "%s.%d" % [prefix, i], group,
				"%s · %s" % [title, String(shot.get("shot_name", "镜头 %d" % (i + 1)))],
				lines)


static func _add_story(out: Array[Dictionary]) -> void:
	var g := "剧情 · 后半段主线"
	_add(out, "story.evening_reminder", g, "晚间想起去取照片", StoryData.evening_reminder())
	_add(out, "story.photo_pickup", g, "照相馆取照片", StoryData.photo_pickup())
	_add(out, "story.roommate_photo_chat", g, "宿舍里发现只有自己看得见她",
			StoryData.roommate_photo_chat())
	_add(out, "story.photo_viewing", g, "看照片 → 觉醒 → 天使契约", StoryData.photo_viewing())
	_add(out, "story.bed_rest", g, "床边「躺一会儿」", StoryData.bed_rest())
	_add(out, "story.morning_wash", g, "第二天早晨 · 洗漱", StoryData.morning_wash())
	_add(out, "story.morning_stadium_gate", g, "第二天早晨 · 体育场大门", StoryData.morning_stadium_gate())


static func _add_teaching(out: Array[Dictionary]) -> void:
	# ⚠️ 原来这里还有一条 `teaching.skip`（"三楼翘课独白"）：那套"一上三楼自动播"的机制
	#    已按用户要求改成"交互 301 教室之后触发"，台词并进了 `teaching.classroom.301`，
	#    所以那张单子也删掉了 —— 留一条运行时永远不会播的 id 只会让人以为它还在用。
	for floor in TeachingData.FLOORS:
		for room_variant in TeachingData.classrooms(floor):
			var room: Dictionary = room_variant
			_add(out, "teaching.classroom.%d" % int(room["number"]), "教学楼",
					"%s（%s）" % [String(room["label"]), TeachingData.FLOOR_LABELS[floor]],
					room["lines"])


static func _add_campus(out: Array[Dictionary]) -> void:
	for zone_id in CampusData.ZONE_IDS:
		var zone := CampusData.zone(zone_id)
		if zone.is_empty():
			continue
		var zone_label := String(zone.get("label", zone_id))
		for npc_variant in (zone.get("npcs", []) as Array):
			var npc: Dictionary = npc_variant
			var npc_id := String(npc.get("id", "npc"))
			var npc_name := String(npc.get("name", ""))
			var npc_lines: Array = npc.get("lines", [])
			# ⚠️ 台词**可以为空**：08 里"抱着课本的同学"就是一句话都不说、
			#    急匆匆进教学楼然后消失。那种 NPC 不登记（编辑器不允许空段），
			#    它走之前那句旁白仍按下面 `vanish_line` 登记。
			if not npc_lines.is_empty():
				_add(out, "campus.%s.npc.%s" % [zone_id, npc_id],
						"校园 NPC 与校门",
						"%s · %s" % [zone_label, npc_name],
						npc_lines)
			# 剧情改写与夜间台词是彼此独立的整段，不能继续共用白天原文的补丁 id；
			# 否则白天保存过的覆盖会把运行时刚换上的台词整段盖回去。
			var rewrite_lines: Array = npc.get("lines_after", [])
			if not rewrite_lines.is_empty():
				_add(out, "campus.%s.npc.%s_rewrite" % [zone_id, npc_id],
						"校园 NPC 与校门",
						"%s · %s（剧情改写后）" % [zone_label,
								String(npc.get("name_after", npc_name))], rewrite_lines)
			var night_lines: Array = npc.get("night_lines", [])
			if not night_lines.is_empty():
				_add(out, "campus.%s.npc.%s_night" % [zone_id, npc_id],
						"校园 NPC 与校门 · 夜间",
						"%s · %s（夜间）" % [zone_label,
								String(npc.get("night_name", npc_name))], night_lines)
			# 多阶段对话的第二段（`talk_order`）：它只在第一个交互点之后播，
			# 但**同样是要改的词**，所以登记成单独一段（id 与 `Npc.dialogue_block_id()` 同源）。
			var order: Array = npc.get("talk_order", [])
			for i in order.size():
				var entry: Variant = order[i]
				_add(out, "campus.%s.npc.%s_after%d" % [zone_id, npc_id, i + 1],
						"校园 NPC 与校门",
						"%s · %s（后面的对话 %d）" % [zone_label, npc_name, i + 1],
						entry if entry is Array else [entry])
			# "说完就走"那位走之前的旁白
			var vanish: Array = npc.get("vanish_line", [])
			if not vanish.is_empty():
				_add(out, "campus.%s.npc.%s_leave" % [zone_id, npc_id],
						"校园 NPC 与校门",
						"%s · %s（走之前）" % [zone_label, npc_name], vanish)
		var gates: Array = zone.get("gates", [])
		for i in gates.size():
			var gate: Dictionary = gates[i]
			_add(out, "campus.%s.gate.%d" % [zone_id, i], "校园 NPC 与校门",
					"%s · %s" % [zone_label, String(gate.get("label", "校门"))],
					gate.get("lines", []))
			var gate_rewrite: Array = gate.get("lines_after", [])
			if not gate_rewrite.is_empty():
				_add(out, "campus.%s.gate.%d_rewrite" % [zone_id, i],
						"校园 NPC 与校门",
						"%s · %s（剧情改写后）" % [zone_label,
								String(gate.get("label", "校门"))], gate_rewrite)
		# 楼门口那块牌子（`CampusData.SIGN_LINES`）
		for building_variant in (zone.get("buildings", []) as Array):
			var building: Dictionary = building_variant
			var building_id := String(building.get("id", ""))
			var sign: Array = CampusData.sign_lines(building_id)
			if sign.is_empty():
				continue
			_add(out, "campus.%s.sign.%s" % [zone_id, building_id], "校园 NPC 与校门 · 牌子",
					"%s · %s 的牌子" % [zone_label, String(building.get("label", building_id))], sign)
	# 楼门口那句"现在还不能去"（上锁时的台词；见 `CampusData.ENTRANCE_LOCKED`）
	for building_id_variant in CampusData.ENTRANCE_LOCKED:
		var building_id := String(building_id_variant)
		_add(out, "campus.entrance.%s.locked" % building_id, "校园 NPC 与校门 · 门",
				"%s · 还没吃饭时的那两句" % building_id,
				CampusData.entrance_locked(building_id))
	_add(out, "campus.entrance.canteen.night_locked", "校园 NPC 与校门 · 门",
			"第一食堂 · 夜间已关门",
			[{"speaker": "", "text": "食堂今天已经关门了。"}])


static func _add_dorm(out: Array[Dictionary]) -> void:
	var g := "宿舍"
	_add(out, "dorm.roommate.sleeping", g, "陈默 · 还没看手机时",
			DormRoommateScript.dialogue_lines("sleeping"))
	_add(out, "dorm.roommate.first", g, "陈默 · 刚醒来第一次说话",
			DormRoommateScript.dialogue_lines("first"))
	_add(out, "dorm.roommate.after", g, "陈默 · 之后重复的那句",
			DormRoommateScript.dialogue_lines("after"))
	# 08 定稿（艾莉娜入队那一段）：他在打游戏，只留一句旁白 + 一句内心戏
	_add(out, "dorm.roommate.alyina", g, "陈默 · 艾莉娜入队之后（他在打游戏）",
			DormRoommateScript.dialogue_lines("alyina"))
	# `photo_chat` 已在剧情组登记为 `story.roommate_photo_chat`；
	# 不再重复生成一个不会被运行时使用的 `dorm.roommate.photo_chat`。
	# 家具的"查看"文案：**每个位置一段**（`bed.up_left` / `desk.down_left` …）。
	# ⚠️ id 与 `dorm.gd` 建交互区时用的那一个必须同源 —— 都走 `MapData.dorm_examine_id()`，
	#    不然编辑器里改了、游戏里播的还是原文（而且是静默的）。
	for key_variant in MapData.DORM_EXAMINES:
		var key := String(key_variant)
		var def: Dictionary = MapData.DORM_EXAMINES[key]
		_add(out, "map.dorm_examine.%s" % key, g,
				"%s（%s）" % [String(def.get("name", key)), _dorm_spot_label(key)],
				def.get("lines", []))


## 宿舍家具那一段的**方位**中文名（编辑器里的分组标签用；`bed.up_left` → "左上"）。
static func _dorm_spot_label(key: String) -> String:
	var names := {
		"up_left": "左上 · 我的",
		"up_right": "右上 · 陈默的",
		"down_left": "左下 · 考研室友的",
		"down_right": "右下 · 出国交换那位",
		"up": "上墙",
		"left": "左衣柜 · 我的",
		"right": "右衣柜 · 别人的",
	}
	var suffix := key.get_slice(".", 1)
	return String(names.get(suffix, suffix))


static func _add_bathroom(out: Array[Dictionary]) -> void:
	for kind_variant in MapData.BATHROOM_EXAMINES:
		var kind := String(kind_variant)
		var def := MapData.bathroom_examine(kind)
		_add(out, "map.bathroom_examine.%s" % kind, "卫生间",
				String(def.get("name", kind)), def.get("lines", []))


static func _add_canteen(out: Array[Dictionary]) -> void:
	for kind_variant in CanteenData.EXAMINES:
		var kind := String(kind_variant)
		var def := CanteenData.examine(kind)
		_add(out, "canteen.examine.%s" % kind, "食堂",
				String(def.get("name", kind)), def.get("lines", []))
	# 打饭窗口那一段（`request/08_DIALOG.md` 的"打饭时对话 / 吃饭时对话"）。
	# ⚠️ 这些段落是 **MealSpot 里的常量**、不是 CanteenData 的数据 —— 它们要"写开关、走时间"，
	#    属于场景行为，所以和 `item.phone.*` 一样单独登记。
	_add(out, "canteen.meal.buy", "食堂", "打饭窗口 · 打饭", MealSpot.BUY_LINES)
	_add(out, "canteen.meal.eat", "食堂", "打饭窗口 · 吃饭", MealSpot.EAT_LINES)
	_add(out, "canteen.meal.alyina_dinner", "食堂", "艾莉娜登场后 · 晚饭", MealSpot.ALYINA_DINNER_LINES)
	# 食堂那道门的"现在还不能走"（锁在"出门前看过手机"上）
	_add(out, "canteen.door.locked", "食堂", "回校园的门 · 还没看手机时",
			[{"speaker": "", "text": String(CanteenData.door().get("locked_message", ""))}])
	_add(out, "canteen.meal.work_choice", "食堂", "打饭窗口 · 要不要这就去打工（选项）",
			[MealSpot.WORK_CHOICE_LINE])
	# ⚠️ 原来这里还有 `canteen.seat.<i>.sit/.stand`（食堂凳子上的坐/站）——
	#    用户 2026-09-20 要求"去掉食堂在凳子上坐下的交互"，一并删掉：
	#    留一条永远不会被播的 id，只会让作者以为它还在用。


static func _add_banter(out: Array[Dictionary]) -> void:
	var g := "艾莉娜插话"
	for topic_variant in AlyinaBanter.TOPICS:
		var topic: Dictionary = topic_variant
		var key := String(topic["key"])
		_add(out, "banter.%s" % key, g, "看东西时 · %s" % _banter_label(key),
				topic["lines"])
	_add(out, "banter._npc", g, "跟 NPC 说完话之后", AlyinaBanter.NPC_LINES)
	# 空兜底不会播，也无法在编辑器里形成有效覆盖段；不把空段塞进清单。
	if not AlyinaBanter.FALLBACK.is_empty():
		_add(out, "banter._fallback", g, "没命中关键词时的兜底", AlyinaBanter.FALLBACK)


static func _banter_label(key: String) -> String:
	var names := {
		"classroom": "教室门牌",
		"stairs": "楼梯",
		"library": "图书馆 / 书",
		"canteen": "食堂",
		"vending": "自动售货机",
		"shop": "超市 / 商店",
		"photo": "照相馆",
		"stadium_gate": "运动场南门",
		"gate": "校门",
		"campus_prop": "校园设施（长椅/路灯/公告栏…）",
		"dorm": "宿舍家具",
	}
	return String(names.get(key, key))


static func _add_highschool_rewind(out: Array[Dictionary]) -> void:
	var group := "高中剧情 · 回映"
	_add(out, "highschool.rewind.matron_enter", group, "6:30 · 宿管开门",
		HighschoolRewindData.MORNING_MATRON_ENTER)
	_add(out, "highschool.rewind.matron_call", group, "6:30 · 宿管叫醒",
		HighschoolRewindData.MORNING_MATRON_CALL)
	_add(out, "highschool.rewind.matron_leave", group, "6:30 · 宿管离开",
		HighschoolRewindData.MORNING_MATRON_LEAVE)
	_add(out, "highschool.rewind.wake", group, "6:30 · 起床洗漱",
		HighschoolRewindData.MORNING_WAKE)
	_add(out, "highschool.rewind.alyina_view", group, "6:30 · 艾莉娜视角",
		HighschoolRewindData.ALYINA_VIEW)
	for id in HighschoolMorningData.DIALOGUES:
		var label := {"roommate_breakfast": "回 205 找王天博带早饭", "skip_breakfast": "不吃早餐，去补作业",
			"climb_teaching": "第一教学楼 · 上五楼", "classroom_unfed": "502 · 未吃饭时补卷子"}
		_add(out, "highschool.rewind." + id, group, label[id], HighschoolMorningData.DIALOGUES[id])
	for id in HighschoolMorningData.MEALS:
		var meal: Dictionary = HighschoolMorningData.MEALS[id]
		_add(out, "highschool.rewind." + id + ".bought", group, meal.label + " · 排队购买", meal.bought)
		_add(out, "highschool.rewind." + id + ".eating", group, meal.label + " · 就餐", meal.eating)
	for id in HighschoolClassStoryData.DIALOGUES:
		_add(out, "highschool.class." + id, group, "入座后 · " + id, HighschoolClassStoryData.DIALOGUES[id])
	for id in HighschoolFirstPeriodData.DIALOGUES:
		_add(out, "highschool.first_period." + id, group, "数学课与课间 · " + id, HighschoolFirstPeriodData.DIALOGUES[id])
	for id in HighschoolBreakEvents.DIALOGUES:
		_add(out, "highschool.break." + id, group, "课间线索 · " + id, HighschoolBreakEvents.DIALOGUES[id])
	for id in HighschoolMiddayData.Dialogue.LINES:
		_add(out, "highschool.midday." + id, group, "第二节课与医务室 · " + id, HighschoolMiddayData.Dialogue.LINES[id])
	_add_shots(out, HighschoolClassStoryData.shots(), "cg.highschool_photo", "高中剧情 · 合影回忆", "6 月 30 日")


static func _add_items(out: Array[Dictionary]) -> void:
	var g := "道具与商店"
	_add(out, "item.phone.first", g, "第一次看手机", ItemActions.PHONE_FIRST_LOOK)
	_add(out, "item.phone.later", g, "之后看手机 · 报时", ItemActions.PHONE_LATER)
	_add(out, "item.phone.warehouse", g, "仓库中提前查看手机", ItemActions.PHONE_WAREHOUSE)
	_add(out, "highschool.external.phone", "高中剧情", "离开仓库后查看手机（始终播放）", HighschoolData.EXTERNAL_PHONE_LINES)
	_add(out, "item.phone.tasks", g, "跟陈默聊过之后 · 手机上那两件待办",
			ItemActions.PHONE_TASKS)
	# ⚠️ 它是**紧跟在两件待办后面**的一句（艾莉娜加入队伍之后才有），
	#    所以登记在 `item.phone.tasks` 旁边；它有自己的 id，改它不会动到那两件待办。
	_add(out, "item.phone.tasks_undone", g, "艾莉娜加入之后 · 待办一件没完成的独白",
			ItemActions.PHONE_TASKS_UNDONE)
	_add(out, "item.phone.tasks_after_photo", g, "取到照片之后 · 已删除未完成待办的独白",
			ItemActions.PHONE_TASKS_AFTER_PHOTO)
	_add(out, "item.phone.go_to_class_earned", g, "赚到工钱 · 去教学楼上课",
			ItemActions.PHONE_GO_TO_CLASS_EARNED)
	_add(out, "item.phone.go_to_class", g, "没赚到钱 · 去教学楼上课（无「赚了点钱」）",
			ItemActions.PHONE_GO_TO_CLASS)
	_add(out, "item.energy_drink", g, "喝能量饮料", ItemActions.ENERGY_DRINK_LINES)
	_add(out, "item.photo_print", g, "背包使用洗好的照片", ItemActions.PHOTO_PRINT_LINES)
	for shop_id_variant in ShopDb.SHOPS:
		var shop_id := String(shop_id_variant)
		_add(out, "shop.greeting.%s" % shop_id, g, "进店第一句 · %s" % ShopDb.shop_name(shop_id),
				[{"speaker": ShopDb.clerk_of(shop_id), "text": ShopDb.greeting_of(shop_id)}])
