extends Control
## First-visit tour of the actual character screens. Progress belongs to the run.
signal page_requested(page: String)
signal completed
const M := preload("res://scripts/ui/battle_management_ui.gd")
const T := preload("res://scripts/ui/battle_theme.gd")
const STEPS := [
	{"page":"loadout", "title":"角色系统，也是你的战斗百科", "text":"这里能调整每名角色的技能、专武和遗物，还能查怪物打法、道具效果与战斗机制。首次进入需要看完这份操作介绍；以后可点「功能教程」重看。\n左侧点击角色切换档案，滚轮向下可查看所有队员。", "focus":Rect2(64, 178, 290, 724)},
	{"page":"loadout", "title":"角色档案、形态与头像", "text":"中间显示等级、生命、被动与终结技。点击终结技图片可看详情，头像下方可以切换立绘风格。\n周明远可在档案下方或尖塔编队卡片直接切换「无极 / 数学」。两种形态分别保存卡组与生命；不匹配的形态专武会卸下。", "focus":Rect2(378, 178, 542, 724), "top":true},
	{"page":"loadout", "title":"点技能看详情，用 ＋ / − 配卡", "text":"点击技能框查看效果、属性与目标，＋ / − 调整携带数量；滚轮向下浏览完整技能表。数学形态先列数学技能，再列可携带的无极技能。\n注意携带 cost、最低张数、同名上限与解锁等级。合法卡组自动保存；红字提示的调整尚未保存，补齐或点「撤销调整」再离开。", "focus":Rect2(944, 178, 908, 446)},
	{"page":"equipment", "title":"专武、遗物：查看并安装到角色", "text":"左侧切换装备角色；右侧用「专武 / 遗物」与品质筛选浏览图鉴。点击物品查看效果和获取条件，再点安装到指定槽位；已装备的物品可卸下。\n角色教学的最终实战奖励专武，阿姨商店出售遗物。专武有角色或形态限制，未获得的物品也能先查看效果。", "focus":Rect2(64, 180, 1792, 510)},
	{"page":"attributes", "title":"属性克制：出战前比较伤害关系", "text":"点击学科查看克制与被克制关系，并与敌人的属性对照。无极不参与属性克制。\n切换周明远形态会同时改变技能方案与属性，选择适合当前敌人的形态再出战。", "focus":Rect2(188, 226, 1544, 450)},
	{"page":"bestiary", "title":"怪物图鉴：找机制，也找应对办法", "text":"搜索怪物名称或关键词，点击条目查看技能、阶段机制、援助与推荐打法。未击败的怪物会限制部分资料，击败后解锁。\n推荐会注明适用的周明远形态；请按敌人的机制和已解锁技能选择队员。楼层预览中的「逐怪打法」与这里使用同一份资料。", "focus":Rect2(64, 180, 1792, 510)},
	{"page":"items", "title":"道具图鉴与库存", "text":"按品质筛选、点击道具，查看效果、持有数量和获取条件。阿姨商店可以补充库存。\n战斗中从「道具」入口使用，注意道具的可用时机与目标；在角色系统里先了解效果，方便决定要买什么。", "focus":Rect2(64, 180, 1792, 510)},
	{"page":"effects", "title":"机制说明：遇到陌生效果就来查", "text":"这里集中解释战斗规则与状态，按分类或关键词查找，并阅读详细说明。战斗里也能从角色与档案入口查看资料，但不能修改卡组和装备。\n周明远数学的头像可以左键或右键打开演算区；正为队友选择技能目标时，左键仍会完成选取。", "focus":Rect2(64, 180, 1792, 510)},
	{"page":"loadout", "title":"准备完成，再去编队出战", "text":"右下「打开编队」返回尖塔选择队员与站位，周明远卡片上的「无极 / 数学」可直接切换形态。检查剩余生命、死亡状态，再开始战斗。\n技能、装备、怪物与道具资料会影响每场战斗；以后可随时从「角色系统与战斗百科」回来调整。", "focus":Rect2(1435, 942, 415, 60), "top":true},
]
var index := 0
var replay := false

func _ready() -> void:
	name = "CharacterSystemGuide"
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not replay: index = clampi(int(TowerRun.data.get("character_guide", {}).get("page", 0)), 0, STEPS.size() - 1)
	show_step(index)

func show_step(value: int) -> void:
	index = clampi(value, 0, STEPS.size() - 1)
	if not replay:
		TowerRun.data.character_guide = {"completed":false, "page":index}
		TowerRun.save_game()
	page_requested.emit(STEPS[index].page)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var step: Dictionary = STEPS[index]
	var hole: Rect2 = step.focus
	for rect in [Rect2(0, 0, 1920, hole.position.y), Rect2(0, hole.end.y, 1920, 1080 - hole.end.y), Rect2(0, hole.position.y, hole.position.x, hole.size.y), Rect2(hole.end.x, hole.position.y, 1920 - hole.end.x, hole.size.y)]:
		var dim := ColorRect.new()
		dim.position = rect.position
		dim.size = rect.size
		dim.color = Color(0.01, 0.025, 0.045, 0.78)
		add_child(dim)
	var border := M.panel(hole, Color.TRANSPARENT, T.GOLD)
	border.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(border)
	var pane := M.panel(Rect2(440, 220 if step.get("top", false) else 718, 1080, 322), T.SURFACE, T.GOLD)
	add_child(pane)
	M.heading(pane, "功能教程  %d / %d · %s" % [index + 1, STEPS.size(), step.title], Rect2(28, 18, 1024, 42), 27)
	M.paragraph(pane, step.text, Rect2(30, 78, 1020, 152), 23)
	var previous := M.button("上一步", Rect2(30, 246, 170, 52), func(): show_step(index - 1))
	previous.disabled = index == 0
	pane.add_child(previous)
	var next := M.button("了解了，开始准备" if index == STEPS.size() - 1 else "下一项", Rect2(760, 246, 290, 52), _next, T.GOLD, true)
	next.name = "CharacterGuideNext"
	pane.add_child(next)
	next.grab_focus()

func _next() -> void:
	if index < STEPS.size() - 1:
		show_step(index + 1)
		return
	if not replay:
		TowerRun.data.character_guide = {"completed":true, "page":index}
		TowerRun.save_game()
	completed.emit()
	queue_free()
