extends RefCounted
const MOBILE := preload("res://scripts/ui/tower_mobile.gd")
const T := preload("res://scripts/ui/battle_theme.gd")
const DATA := preload("res://scripts/data/tower_data.gd")
const BOOK := preload("res://scripts/data/enemy_bestiary.gd")

static func text(parent: Node, words: String, font_size: int = 40) -> Label:
	var label := Label.new()
	label.text = words
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

static func button(parent: Node, words: String, action: Callable, disabled: bool = false) -> Button:
	var control := Button.new()
	control.text = words
	control.custom_minimum_size = Vector2(300, 144)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.add_theme_font_size_override("font_size", 40)
	control.disabled = disabled
	T.button(control, T.GOLD)
	control.pressed.connect(action)
	parent.add_child(control)
	return control

static func row(parent: Node) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 24)
	parent.add_child(line)
	return line

static func build(scene: Control) -> void:
	var root: Control = scene.body
	var panel := Panel.new()
	panel.position = Vector2(30, 190)
	panel.size = Vector2(1860, 860)
	panel.add_theme_stylebox_override("panel", T.frame(T.INK, T.GOLD, 2, 8))
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.name = "TowerMobilePageScroll"
	scroll.position = Vector2(40, 26)
	scroll.size = Vector2(1780, 808)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 30)
	scroll.add_child(rows)
	if scene.page == "title":
		text(rows, DATA.GAME_TITLE, 64)
		text(rows, "战斗测试版 · " + DATA.VERSION)
		button(rows, "开始 / 继续攀登", scene._start_menu)
		button(rows, "存档管理", func(): scene.page = "saves"; scene._refresh())
		button(rows, "设置", scene._settings)
		button(rows, "制作名单与许可", scene._credits)
		button(rows, "保存并返回标题" if OS.has_feature("web") else "退出游戏", func(): scene.confirm("进度会保存。确定退出游戏吗？", scene._quit))
		return
	var navigation := ScrollContainer.new()
	navigation.position = Vector2(30, 24)
	navigation.size = Vector2(1860, 152)
	navigation.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(navigation)
	var tabs := row(navigation)
	for key in ["lobby", "lessons", "saves", "report", "shop"]:
		if key == "shop" and not TowerRun.shop_available(): continue
		button(tabs, {"lobby":"攀登", "lessons":"教学", "saves":"存档", "report":"测试数据", "shop":"阿姨补给"}[key], func(): scene._ensure_game(key))
	button(tabs, "设置", scene._settings)
	button(tabs, "标题", func(): TowerRun.save_game(); scene.page = "title"; scene._refresh())
	if not TowerRun.data.is_empty():
		text(rows, "%s · 最高 %d 层 · 碎片 %d" % [TowerRun.data.nickname, TowerRun.data.highest, TowerRun.data.shards], 38)
	if not TowerRun.notice.is_empty(): text(rows, TowerRun.notice).add_theme_color_override("font_color", T.GOLD)
	match scene.page:
		"lobby": lobby(scene, rows)
		"lessons": lessons(scene, rows)
		"shop": shop(scene, rows)
		"saves": saves(scene, rows)
		"report": report(scene, rows)

static func lobby(scene: Control, rows: VBoxContainer) -> void:
	scene.chosen_floor = clampi(scene.chosen_floor, 1, int(TowerRun.data.highest) + 1)
	var floor_info := DATA.floor_data(scene.chosen_floor, int(TowerRun.data.seed))
	var picker := OptionButton.new()
	picker.name = "MobileFloorPicker"
	picker.custom_minimum_size.y = 144
	picker.add_theme_font_size_override("font_size", 42)
	for number in range(1, int(TowerRun.data.highest) + 2): picker.add_item("第 %d 层%s" % [number, " · 已通关，可重演" if TowerRun.data.clears.has(str(number)) else " · 继续攀登"])
	picker.select(scene.chosen_floor - 1)
	picker.item_selected.connect(func(index: int): scene.chosen_floor = index + 1; scene._refresh())
	rows.add_child(picker)
	var enemies := PackedStringArray()
	for id in floor_info.enemies: enemies.append(FightData.enemy(id).name)
	text(rows, "%s关卡 · %s\n经验 %d / 人 · 碎片 %d" % [floor_info.kind, " / ".join(enemies), floor_info.xp, floor_info.shards])
	var actions := row(rows)
	button(actions, "查看逐怪打法", func():
		var description := ""
		for id in floor_info.enemies: description += FightData.enemy(id).name + "\n" + BOOK.recommendation(id) + "\n\n"
		MOBILE.instance().show_help("本层敌人与应对", description))
	button(actions, "重演本层" if TowerRun.data.clears.has(str(scene.chosen_floor)) else "进入战斗", scene._begin)
	if TowerRun.data.clears.has(str(scene.chosen_floor)): button(rows, "重置到本层前", scene._confirm_reset)
	text(rows, "出战顺序 · 点角色换人", 46)
	var team := FightSystem.formation_slots()
	for i in 4:
		var id := String(team[i])
		var line := row(rows)
		if id.is_empty():
			button(line, "第 %d 位 · 选择队员" % (i + 1), func(): formation(scene, i)).name = "FormationSlot_%d" % i
			continue
		var portrait := TextureRect.new()
		portrait.texture = load(FightData.hero(id).portrait)
		portrait.custom_minimum_size = Vector2(144, 144)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		line.add_child(portrait)
		button(line, "%d · %s · Lv.%d · 生命 %d / %d%s" % [i + 1, FightData.hero(id).name, FightProgression.hero_level(id), TowerRun.health(id), FightSystem.hero_max_hp(id), " · 需复活" if TowerRun.health(id) <= 0 else ""], func(): formation(scene, i)).name = "FormationSlot_%d" % i
		if id == "zhoumingyuan":
			button(line, "形态：" + FightData.attr_name(FightSystem.current_attribute(id)), func(): form(scene))
	var tools := row(rows)
	button(tools, "恢复 · %d 次" % TowerRun.recovery_charges(), scene._recovery_picker)
	button(tools, "角色系统与战斗百科", scene._characters).name = "TowerCharacters"
	button(rows, "新手教程", func(): scene._open_tutorial(true))
	text(rows, "每过5层可以找阿姨补给。挑战下一层才关店，教学和重演不影响。")
	var warning := TowerRun.formation_warning()
	if not warning.is_empty(): text(rows, warning).add_theme_color_override("font_color", T.RED)

static func form(scene: Control) -> void:
	var choices: Array[Dictionary] = []
	for attribute in FightSystem.unlocked_attributes():
		choices.append({"text":FightData.attr_name(attribute), "action":func():
			if FightSystem.set_attribute("zhoumingyuan", attribute): TowerRun.save_game(); scene._refresh()})
	MOBILE.instance().show_help("周明远形态", "切换形态会同步独立卡组与剩余生命；不匹配的形态专武会卸下。", "", Callable(), false, choices)

static func formation(scene: Control, slot: int) -> void:
	var choices: Array[Dictionary] = []
	for id in DATA.HEROES:
		choices.append({"text":"%s · Lv.%d · 生命 %d / %d%s" % [FightData.hero(id).name, FightProgression.hero_level(id), TowerRun.health(id), FightSystem.hero_max_hp(id), " · 需复活" if TowerRun.health(id) <= 0 else ""], "action":func():
			var team := FightSystem.formation_slots()
			var previous := team.find(id)
			if previous >= 0: team[previous] = team[slot]
			team[slot] = id
			if not FightSystem.set_formation(team): TowerRun.notice = FightSystem.last_configuration_error
			TowerRun.save_game(); scene._refresh(); scene._resume_tutorial()})
	choices.append({"text":"移出队伍", "action":func():
		var team := FightSystem.formation_slots()
		team[slot] = ""
		FightSystem.set_formation(team); TowerRun.save_game(); scene._refresh(); scene._resume_tutorial()})
	choices.append({"text":"周明远形态", "action":func(): form(scene)})
	choices.append({"text":"进入角色系统与战斗百科", "action":scene._characters})
	MOBILE.instance().show_help("编队 · 第 %d 位" % (slot + 1), "点按换人。已在队中的角色会交换位置。", "", Callable(), false, choices)

static func lessons(scene: Control, rows: VBoxContainer) -> void:
	text(rows, "角色教学", 48)
	text(rows, "教学使用专用 Lv.40 队伍，战后恢复原队伍。")
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = 144
	picker.add_theme_font_size_override("font_size", 40)
	for id in DATA.HEROES: picker.add_item(FightData.hero(id).name)
	picker.select(DATA.HEROES.find(scene.chosen_hero))
	picker.item_selected.connect(func(index: int): scene.chosen_hero = DATA.HEROES[index]; scene._refresh())
	rows.add_child(picker)
	var lesson: Dictionary = DATA.LESSONS[scene.chosen_hero]
	text(rows, lesson.title, 46)
	text(rows, "先打出「%s」，再打出「%s」。\n%s" % [FightData.skill(lesson.key).name, FightData.skill(lesson.follow).name, FightData.passive(scene.chosen_hero, "none")])
	var weapon: String = DATA.WEAPONS[scene.chosen_hero]
	text(rows, "首通专武 · " + FightEquipmentData.definition(weapon).name + "\n" + FightEquipmentData.description(weapon))
	button(rows, "机制练习" + (" · 已领取" if TowerRun.data.lessons.has(scene.chosen_hero + "_basic") else " · 首通20碎片"), func(): scene._lesson(false))
	button(rows, "多人实战 · 专武奖励", func(): scene._lesson(true), not TowerRun.data.lessons.has(scene.chosen_hero + "_basic"))

static func shop(scene: Control, rows: VBoxContainer) -> void:
	text(rows, "阿姨的塔间补给", 48)
	if not TowerRun.shop_available(): text(rows, "通关第5、10、15…层后开放补给。教学和重演不影响当前商店。"); return
	var stock: Dictionary = TowerRun.data.get("shop", {})
	if stock.is_empty(): return
	for index in stock.stock.size():
		var offer: Dictionary = stock.stock[index]
		text(rows, FightEquipmentData.definition(offer.id).name + "\n" + FightEquipmentData.description(offer.id))
		button(rows, "已售出" if offer.sold else "%d 碎片 · 购买" % offer.price, func():
			scene.confirm("购买「%s」，消耗 %d 碎片？" % [FightEquipmentData.definition(offer.id).name, offer.price], func():
				if not TowerRun.buy(index): TowerRun.notice = TowerRun.error
				scene._refresh()), offer.sold)
	button(rows, "刷新全部 · %d 碎片（剩 %d 次）" % [4 + stock.refreshes * 3, 2 - stock.refreshes], func():
		scene.confirm("确认刷新货架？将消耗碎片和一次刷新次数。", func():
			if not TowerRun.refresh_shop(): TowerRun.notice = TowerRun.error
			scene._refresh()), int(stock.refreshes) >= 2)
	button(rows, "装备遗物", scene._characters)

static func saves(scene: Control, rows: VBoxContainer) -> void:
	text(rows, "存档与迁移", 48)
	text(rows, "浏览器会自动保存进度。清除网站数据会删除此设备的存档；换设备请导出迁移包。" if OS.has_feature("web") else "更新安装时保留应用数据即可继续。换设备请先导出迁移包；迁移包包含完整战斗记录。")
	for slot in range(1, 4):
		var saved := TowerRun.read_save(slot)
		text(rows, "%02d · %s%s" % [slot, saved.get("nickname", "空存档"), "" if saved.is_empty() else " · 最高 %d 层" % saved.highest])
		var line := row(rows)
		button(line, "继续", func():
			if TowerRun.load_game(slot): scene.page = "lobby"; scene.chosen_floor = int(TowerRun.data.highest) + 1
			else: TowerRun.notice = TowerRun.error
			scene._refresh(), saved.is_empty())
		button(line, "导入", func(): scene._import_save(slot)).name = "ImportSlot_%d" % slot
		button(line, "新建", func(): scene._new_dialog(slot, not saved.is_empty()))
	button(rows, "导出当前存档迁移包", scene._export_save, TowerRun.data.is_empty()).name = "ExportSaveTransfer"
	button(rows, "保存当前记录", func():
		TowerRun.notice = "存档已保存。" if TowerRun.save_game() else TowerRun.error
		scene._refresh(), TowerRun.data.is_empty())
	text(rows, "导入前会备份原槽位。旧版单独的存档不含历史战斗记录；请优先用旧设备导出完整迁移包。")

static func report(scene: Control, rows: VBoxContainer) -> void:
	text(rows, "分享这次的战斗记录", 48)
	text(rows, "最高 %d 层 · %d 场战斗 · 胜利 %d 场\n游玩 %d 分钟" % [TowerRun.data.highest, TowerRun.data.battle_count, TowerRun.data.victories, int(float(TowerRun.data.seconds) / 60)])
	text(rows, "报告包含昵称、版本、楼层、阵容、卡组装备、出牌、伤害和胜负。导出后可自行上传到测试网站；游戏不会自动上传。是否公开成绩，由你选择。")
	button(rows, "导出测试报告", scene._export)
	button(rows, "打开测试网站", func(): OS.shell_open("https://inkspire-game.freemyip.com"))
