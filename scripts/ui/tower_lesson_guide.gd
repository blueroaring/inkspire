extends Control
## A non-overlapping task rail plus paced, dismissible instruction cards.
const T := preload("res://scripts/ui/battle_theme.gd")
const M := preload("res://scripts/ui/battle_management_ui.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
var seen_stage := -1
var intro_page := 0
var modal: Control
var rail: Control
var task: Label

func _ready() -> void:
	name = "TowerLessonGuide"
	size = Vector2(1920, 1080)
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 80
	rail = M.panel(Rect2(532, 119, 1316, 91), T.SURFACE, T.GOLD)
	add_child(rail)
	task = M.paragraph(rail, "正在准备教学用的手牌…", Rect2(24, 12, 1050, 68), 21)
	rail.add_child(M.button("教学手册", Rect2(1100, 22, 190, 48), func(): _show_step(), T.GOLD))

func _process(_delta: float) -> void:
	if TowerRun.lesson_stage() < 0 or not FightSystem.battle_active:
		hide()
		return
	if FightSystem.resolving_action or FightSystem.pending_turn_draw > 0 or not FightSystem.fc.choice.is_empty(): return
	var stage := TowerRun.lesson_stage()
	task.text = TowerRun.lesson_hint() + "\n" + ("能量不够时可以结束回合。本关每次抽牌的顺序相同。" if stage < 3 else "目标已完成：自由出牌，击败敌人即可领取奖励。")
	if stage != seen_stage:
		seen_stage = stage
		_show_step()

func _show_step() -> void:
	if is_instance_valid(modal) or TowerRun.lesson_stage() < 0: return
	TowerRun.lesson_reading = true
	modal = Control.new()
	modal.name = "LessonTextBox"
	modal.size = size
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.03, 0.05, 0.67)
	dim.size = size
	modal.add_child(dim)
	var box := M.panel(Rect2(570, 245, 1130, 574), T.SURFACE, T.GOLD)
	modal.add_child(box)
	preload("res://scripts/ui/tower_finish.gd").decorate(box)
	var hero: String = TowerRun.pending.hero
	var lesson: Dictionary = TowerData.LESSONS[hero]
	V.icon(box, load(String(FightData.hero(hero).portrait)), Rect2(25, 80, 248, 350))
	M.heading(box, FightData.hero(hero).name, Rect2(27, 445, 244, 42), 28, true)
	var stage := TowerRun.lesson_stage()
	var title := "这关要练什么"
	var words := "这关会给你一支 Lv.40 的教学队伍，结束后恢复原来的阵容。\n\n这次练习：%s\n\n每次重开，以及弃牌堆洗回抽牌堆后，抽牌顺序都一样。先按提示完成操作，再自由出牌打败敌人。" % lesson.tip
	var caption := "下一页 · 操作方式"
	if intro_page == 1:
		title = "看牌 → 出牌 → 选择目标"
		words = "左侧是手牌，左上方的能量牌显示本回合能量。\n\n左键点击亮起的教学牌；如果牌需要目标，再点击敌人或队友。右键可查看完整卡牌说明。\n\n角色状态显示在下方。出牌后观察护盾、潜印、毒或画布的变化；能量不足时点击左下角「结束回合」。"
		caption = "下一页 · 开始练习"
	elif intro_page == 2:
		title = "角色手册 / " + String(FightData.hero(hero).name)
		words = FightData.passive(hero, "none") + "\n\n先试试这名角色的两张关键牌，再让队友配合。想看其他技能，可以点击战斗顶部的「角色」。"
		caption = "下一页 · 开始练习"
	elif intro_page >= 3:
		title = ["01 / 打出第一张牌", "02 / 接着打第二张牌", "03 / 轮到队友出牌", "操作完成 · 打赢这场战斗"][stage]
		caption = "开始出牌"
		if stage < 2:
			var skill: String = lesson.key if stage == 0 else lesson.follow
			var def := FightData.skill(skill)
			var target := String(def.get("target", "self"))
			words = "现在打出「%s」。\n\n%s\n\n%s\n\n%s" % [def.name, FightData.description(skill, 40), ("点击卡牌后，再点刚才施毒的敌人。" if hero == "suwanqing" and stage == 1 else "点击卡牌后，再点一名敌人。") if target == "enemy" else "点击卡牌后选择队友。" if target == "ally" else "点击卡牌即可生效，无需选择敌人。", TowerData.LESSON_OBSERVATIONS[hero][stage]]
		elif stage == 2:
			words = "两张指定的牌已经打完了，现在试着打一张队友的牌。\n\n看看卡面上的角色名字，选另一位队员。可以让队友继续攻击，也可以给受伤的人回血或加护盾。\n\n队友出牌后就能自由操作了。完成这些步骤后，还要打赢这场战斗才能拿到专武。"
		else:
			words = "教学要求已经完成，接下来可以自由出牌了。\n\n留意敌人头顶的意图和队友剩余的生命。结束回合后，敌人会行动，之后你会抽到新的手牌。\n\n打赢就能过关。首次完成多人实战会获得这名角色的专武，去「角色 → 专武 / 遗物 → 角色专武」就能查看和装备。"
	if preload("res://scripts/ui/tower_mobile.gd").enabled():
		words = words.replace("左键点击", "点按").replace("右键可查看完整卡牌说明", "开启左下「详情」后点牌查看说明").replace("右键可以查看卡牌详情", "开启「详情」后点牌查看说明")
	M.heading(box, title, Rect2(304, 32, 790, 54), 32)
	M.paragraph(box, words, Rect2(304, 104, 780, 350), 24)
	box.add_child(M.button(caption, Rect2(654, 488, 425, 58), func():
		modal.queue_free()
		modal = null
		TowerRun.lesson_reading = false
		FightSystem.state_changed.emit()
		if intro_page < 3:
			intro_page += 1
			_show_step.call_deferred()
	, T.GOLD, true))
	box.modulate.a = 0
	create_tween().tween_property(box, "modulate:a", 1.0, 0.18)

func _exit_tree() -> void:
	TowerRun.lesson_reading = false
