extends Control
## Shared collection / supply counter, embedded in character management.
const T := preload("res://scripts/ui/battle_theme.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const M := preload("res://scripts/ui/battle_management_ui.gd")
const MOTION := preload("res://scripts/ui/equipment_motion.gd")
signal hero_changed(id: String)
var hero_id := "zhoumingyuan"
var mode := "accessories"
var read_only := false
var selected := ""
var busy := false
var mobile_page := 1
var _body: Control
var _scroll := 0
var _quality := "all"
var _category := "all"

func _ready() -> void:
	name = "EquipmentCollection" if mode == "accessories" else "SupplyCollection"
	size = Vector2(1792, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build()

func build() -> void:
	if is_instance_valid(_body):
		var previous := _body.find_child("CollectionScroll", true, false) as ScrollContainer
		if previous: _scroll = previous.scroll_vertical
		remove_child(_body)
		_body.queue_free()
	_body = Control.new()
	_body.size = size
	_body.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_body)
	var accessories := mode == "accessories"
	var catalog: Dictionary = FightEquipmentData.ACCESSORIES if accessories else FightEquipmentData.CONSUMABLES
	if _quality != "all":
		catalog = catalog.duplicate()
		for id in catalog.keys():
			if catalog[id].rarity != _quality: catalog.erase(id)
	if accessories:
		catalog = catalog.duplicate()
		for id in catalog.keys():
			if _category == "weapons" and not catalog[id].has("exclusive"): catalog.erase(id)
			elif _category == "relics" and catalog[id].has("exclusive"): catalog.erase(id)
	if not catalog.has(selected):
		var signature: String = "proof_compass_math" if hero_id == "zhoumingyuan" and FightSystem.current_attribute(hero_id) == "math" else String(TowerData.WEAPONS.get(hero_id, ""))
		selected = signature if accessories and catalog.has(signature) else String(catalog.keys()[0]) if not catalog.is_empty() else ""
	if preload("res://scripts/ui/tower_mobile.gd").enabled():
		_build_mobile(catalog, accessories)
		return
	_build_left(accessories)
	M.heading(_body, "专武 / 遗物收藏" if accessories else "战斗补给", Rect2(466, 0, 330, 44), 28)
	var qualities := ["all", "common", "uncommon", "rare"]
	for i in qualities.size():
		var quality: String = qualities[i]
		var filter := M.button("全部" if quality == "all" else FightEquipmentData.RARITIES[quality].name, Rect2(822 + i * 99, 0, 90, 40), func() -> void:
			_quality = quality
			_scroll = 0
			var old_scroll := _body.find_child("CollectionScroll", true, false) as ScrollContainer
			if old_scroll: old_scroll.scroll_vertical = 0
			selected = ""
			build()
		, T.GOLD, _quality == quality)
		filter.name = "EquipmentFilter_" + quality
		_body.add_child(filter)
	if accessories:
		var categories := {"all":"全部装备", "weapons":"角色专武", "relics":"通用遗物"}
		var category_index := 0
		for key in categories:
			var filter := M.button(categories[key], Rect2(466 + category_index * 254, 52, 240, 40), func(): _category = key; _quality = "all"; selected = ""; _scroll = 0; build(), T.GOLD, _category == key)
			filter.name = "EquipmentCategory_" + key
			_body.add_child(filter)
			category_index += 1
	else:
		V.text(_body, "白 / 蓝 / 金三档品质 · 道具为一次性物品", Rect2(466, 52, 750, 30), 18, T.MUTED)
	var scroll := ScrollContainer.new()
	scroll.name = "CollectionScroll"
	scroll.position = Vector2(466, 110)
	scroll.size = Vector2(756, 591)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	for id in catalog:
		var def: Dictionary = catalog[id]
		var quality := FightEquipmentData.rarity(id)
		var tile := M.button("", Rect2(0, 0, 358, 184), func() -> void: selected = id; mobile_page = 2; build(), quality.color, id == selected)
		tile.name = "Equipment_" + id
		tile.custom_minimum_size = Vector2(358, 184)
		grid.add_child(tile)
		V.icon(tile, FightEquipmentData.texture(id), Rect2(10, 15, 112, 112))
		M.heading(tile, def.name, Rect2(132, 20, 208, 36), 23)
		V.text(tile, quality.name + (" · 专武" if def.has("exclusive") else " · 遗物" if accessories else " · 消耗品"), Rect2(134, 64, 204, 28), 18, quality.color)
		var owned := GameState.fight_accessories.has(id) if accessories else Inventory.has(id, 1, GameState.BAG_HIGHSCHOOL)
		var owner := FightEquipmentData.owner(id) if accessories else ""
		var note := ("收藏中" if owner.is_empty() else "装备于 " + String(FightData.hero(owner).name)) if accessories and owned else ("持有 %d" % Inventory.count(id, GameState.BAG_HIGHSCHOOL) if not accessories else "尚未获得")
		V.text(tile, note, Rect2(134, 102, 210, 27), 17, T.GREEN if owned else T.MUTED)
		V.text(tile, ("仅限" + String(FightData.hero(def.exclusive).name)) if def.has("exclusive") else def.fit if accessories else def.kind_label, Rect2(18, 147, 324, 27), 17, T.MUTED)
	scroll.set_deferred("scroll_vertical", _scroll)
	if not selected.is_empty(): _build_detail(accessories)
	else: M.paragraph(_body, "此分类暂无该品质装备，请切换品质。", Rect2(1260, 200, 480, 120), 24)

func _build_left(accessories: bool) -> void:
	var pane := M.panel(Rect2(24, 0, 420, 702), T.RECESSED)
	_body.add_child(pane)
	if not accessories:
		M.heading(pane, "关键时刻的支援", Rect2(24, 22, 372, 44), 28)
		V.icon(pane, FightEquipmentData.texture(selected), Rect2(90, 100, 240, 240))
		M.paragraph(pane, "每回合最多使用 1 次\n每场战斗最多使用 2 次\n其中稀有道具最多使用 1 次\n\n不消耗战斗能量。\n取消选目标不会消耗道具。\n道具不会触发角色的攻击连携。", Rect2(28, 370, 364, 245), 22)
		return
	var roster: Array = FightSystem.roster()
	if not roster.has(hero_id): hero_id = roster[0]
	pane.add_child(M.button("‹", Rect2(20, 20, 42, 44), func() -> void: _cycle(-1), T.GOLD))
	pane.add_child(M.button("›", Rect2(358, 20, 42, 44), func() -> void: _cycle(1), T.GOLD))
	M.heading(pane, String(FightData.hero(hero_id).name), Rect2(68, 20, 284, 44), 29, true)
	V.icon(pane, load(String(FightData.hero(hero_id).portrait)), Rect2(80, 82, 260, 212))
	var equipped := FightEquipmentData.slots(hero_id)
	V.text(pane, "已装备 %d / 2 · 战斗外调整" % (2 - equipped.count("")), Rect2(20, 299, 380, 30), 18, T.MUTED, true)
	for i in equipped.size():
		var id := String(equipped[i])
		var slot := M.button("", Rect2(16 + i * 202, 343, 186, 178), func() -> void:
			if not id.is_empty(): _quality = "all"; selected = id; build()
		)
		slot.name = "AccessorySlot_%d" % i
		pane.add_child(slot)
		V.text(slot, "装备槽 %d" % (i + 1), Rect2(8, 8, 170, 26), 17, T.GOLD, true)
		if id.is_empty():
			V.glyph(slot, "innate", Rect2(63, 54, 60, 60), T.LINE)
			V.text(slot, "未装备", Rect2(8, 136, 170, 28), 19, T.MUTED, true)
		else:
			V.icon(slot, FightEquipmentData.texture(id), Rect2(47, 39, 92, 92))
			V.text(slot, FightEquipmentData.definition(id).name, Rect2(8, 136, 170, 28), 19, FightEquipmentData.rarity(id).color, true)
			var remove := M.button("卸下", Rect2(16 + i * 202, 532, 186, 38), func() -> void: _equip(i, ""), T.MUTED)
			remove.name = "UnequipSlot_%d" % i
			remove.disabled = read_only
			pane.add_child(remove)
	var bonus := FightEquipmentData.bonuses(hero_id)
	M.paragraph(pane, "生命上限 +%d  /  常规伤害 +%d%%\n技能治疗 +%d%%  /  开场护盾 %d" % [bonus.max_hp, roundi(bonus.damage_bonus * 100), roundi(bonus.healing_bonus * 100), bonus.opening_guard], Rect2(22, 603, 376, 66), 19, T.MUTED)

func _cycle(direction: int) -> void:
	if busy: return
	var roster: Array = FightSystem.roster()
	hero_id = roster[posmod(roster.find(hero_id) + direction, roster.size())]
	hero_changed.emit(hero_id)
	build()

func _build_detail(accessories: bool) -> void:
	var def := FightEquipmentData.definition(selected)
	var quality := FightEquipmentData.rarity(selected)
	var pane := M.panel(Rect2(1244, 0, 524, 702), T.SURFACE, quality.color)
	_body.add_child(pane)
	V.text(pane, quality.name + (" · 角色专武" if def.has("exclusive") else " · 遗物" if accessories else " · 道具"), Rect2(28, 22, 468, 30), 20, quality.color)
	V.icon(pane, FightEquipmentData.texture(selected), Rect2(188, 58, 148, 148))
	M.heading(pane, def.name, Rect2(24, 212, 476, 45), 32, true)
	M.equipment_description(pane, selected, Rect2(30, 269, 464, 223))
	if accessories and GameState.fight_accessories.has(selected):
		var owner := FightEquipmentData.owner(selected)
		var note := "选择一个饰品槽安装；原饰品回到收藏。" if owner.is_empty() else "当前装备于%s；可移交到所选角色。" % FightData.hero(owner).name
		if def.has("exclusive"): note = "仅%s可装备；来自该角色的尖塔教学实战。" % FightData.hero(def.exclusive).name
		if FightProgression.hero_level(hero_id) < FightEquipmentData.required_level(selected): note = "需要 Lv.%d 才能装备。" % FightEquipmentData.required_level(selected)
		elif def.has("form") and FightSystem.current_attribute(hero_id) != String(def.form): note = "仅限周明远的%s形态。" % FightData.attr_name(String(def.form))
		M.paragraph(pane, note, Rect2(30, 502, 464, 58), 18, T.MUTED)
		for i in FightEquipmentData.SLOT_COUNT:
			var button := M.button("安装到槽 %d" % (i + 1), Rect2(28 + i * 242, 581, 226, 56), func() -> void: _equip(i, selected), quality.color, true)
			button.name = "InstallSlot_%d" % i
			button.disabled = read_only or FightEquipmentData.slots(hero_id)[i] == selected or String(def.get("exclusive", hero_id)) != hero_id or FightProgression.hero_level(hero_id) < FightEquipmentData.required_level(selected) or (def.has("form") and FightSystem.current_attribute(hero_id) != String(def.form))
			pane.add_child(button)
	else:
		var error := FightSystem.EQUIPMENT.purchase_error(FightSystem, selected)
		var buy := M.button(("教学实战专属奖励" if def.has("exclusive") else "请在小卖铺购买") if TowerRun.active else "兑换 · %d 墨痕碎片" % int(def.price), Rect2(28, 581, 468, 56), _purchase, quality.color, true)
		buy.name = "PurchaseEquipment"
		buy.disabled = read_only or not error.is_empty()
		pane.add_child(buy)
		var source := "先完成%s的机制练习，再通关多人实战。" % FightData.hero(def.exclusive).name if def.has("exclusive") else error if not error.is_empty() else "胜利获得墨痕碎片，在这里兑换所需物品。"
		M.paragraph(pane, source, Rect2(30, 502, 464, 58), 18, T.MUTED)
	V.text(pane, "墨痕碎片  %d" % (int(TowerRun.data.get("shards", 0)) if TowerRun.active else Inventory.count("ink_fragment", GameState.BAG_HIGHSCHOOL)), Rect2(28, 657, 468, 28), 19, T.GOLD, true)

func _equip(slot: int, id: String) -> void:
	if busy or read_only: return
	var old := String(FightEquipmentData.slots(hero_id)[slot])
	var moving := old if id.is_empty() else id
	if moving.is_empty(): return
	busy = true
	if preload("res://scripts/ui/tower_mobile.gd").enabled():
		FightSystem.equip_accessory(hero_id, slot, id)
		if TowerRun.active: TowerRun.save_game()
		busy = false
		build()
		return
	var motion := MOTION.new()
	motion.item_id = moving
	var slot_center := Vector2(24 + 16 + slot * 202 + 93, 343 + 87)
	motion.origin = slot_center if id.is_empty() else Vector2(1506, 172)
	motion.destination = Vector2(830, 370) if id.is_empty() else slot_center
	motion.caption = ("卸下 · " if id.is_empty() else "安装 · ") + String(FightEquipmentData.definition(moving).name)
	motion.contacted.connect(func() -> void:
		FightSystem.equip_accessory(hero_id, slot, id)
		if TowerRun.active: TowerRun.save_game()
		build()
	)
	motion.finished.connect(func() -> void: busy = false)
	add_child(motion)

func _purchase() -> void:
	if busy or read_only or not FightSystem.purchase_equipment(selected): return
	busy = true
	var motion := MOTION.new()
	motion.item_id = selected
	motion.origin = Vector2(1506, 172)
	motion.destination = Vector2(830, 370)
	motion.caption = "获得 · " + String(FightEquipmentData.definition(selected).name)
	motion.contacted.connect(build)
	motion.finished.connect(func() -> void: busy = false)
	add_child(motion)

func _build_mobile(catalog: Dictionary, accessories: bool) -> void:
	var pages := preload("res://scripts/ui/tower_mobile_pages.gd")
	for i in 3:
		var tab := M.button(["角色与装备槽", "收藏与筛选", "详情与操作"][i], Rect2(i * 598, 0, 580, 140), func(): mobile_page = i; build(), T.GOLD, mobile_page == i)
		tab.add_theme_font_size_override("font_size", 36)
		_body.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.name = "CollectionScroll"
	scroll.position = Vector2(0, 162)
	scroll.size = Vector2(1792, 548)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 30)
	scroll.add_child(rows)
	if mobile_page == 0:
		if not accessories:
			pages.text(rows, "每回合最多使用1次道具，每场最多2次，其中稀有道具最多1件。道具不消耗战斗能量。取消选目标不会消耗道具。")
			return
		var roster := FightSystem.roster()
		var picker := OptionButton.new()
		picker.custom_minimum_size.y = 144
		picker.add_theme_font_size_override("font_size", 40)
		for id in roster: picker.add_item(FightData.hero(id).name)
		picker.select(roster.find(hero_id))
		picker.item_selected.connect(func(index: int): hero_id = roster[index]; hero_changed.emit(hero_id); build())
		rows.add_child(picker)
		var slots := FightEquipmentData.slots(hero_id)
		for index in slots.size():
			var id := String(slots[index])
			pages.text(rows, "装备槽 %d · %s" % [index + 1, "空槽位" if id.is_empty() else FightEquipmentData.definition(id).name])
			var line := pages.row(rows)
			if not id.is_empty():
				pages.button(line, "查看详情", func(): selected = id; mobile_page = 2; build())
				pages.button(line, "卸下", func(): _equip(index, ""), read_only)
			pages.button(line, "从收藏选择", func(): mobile_page = 1; build())
		var bonus := FightEquipmentData.bonuses(hero_id)
		pages.text(rows, "生命上限 +%d · 常规伤害 +%d%%\n技能治疗 +%d%% · 开场护盾 %d" % [bonus.max_hp, roundi(bonus.damage_bonus * 100), roundi(bonus.healing_bonus * 100), bonus.opening_guard])
	elif mobile_page == 1:
		var filters := pages.row(rows)
		var quality_picker := OptionButton.new()
		quality_picker.custom_minimum_size = Vector2(800, 144)
		quality_picker.add_theme_font_size_override("font_size", 40)
		var qualities := ["all", "common", "uncommon", "rare"]
		for quality in qualities: quality_picker.add_item("全部品质" if quality == "all" else FightEquipmentData.RARITIES[quality].name)
		quality_picker.select(qualities.find(_quality))
		quality_picker.item_selected.connect(func(index: int): _quality = qualities[index]; _scroll = 0; build())
		filters.add_child(quality_picker)
		if accessories:
			var category_picker := OptionButton.new()
			category_picker.custom_minimum_size = Vector2(800, 144)
			category_picker.add_theme_font_size_override("font_size", 40)
			for name in ["全部装备", "角色专武", "通用遗物"]: category_picker.add_item(name)
			var categories := ["all", "weapons", "relics"]
			category_picker.select(categories.find(_category))
			category_picker.item_selected.connect(func(index: int): _category = categories[index]; _scroll = 0; build())
			filters.add_child(category_picker)
		for id in catalog:
			var definition: Dictionary = catalog[id]
			var line := pages.row(rows)
			var art := TextureRect.new()
			art.texture = FightEquipmentData.texture(id)
			art.custom_minimum_size = Vector2(144, 144)
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			line.add_child(art)
			var owned := GameState.fight_accessories.has(id) if accessories else Inventory.has(id, 1, GameState.BAG_HIGHSCHOOL)
			pages.button(line, "%s · %s · %s" % [definition.name, FightEquipmentData.rarity(id).name, "已获得" if owned else "尚未获得"], func(): selected = id; mobile_page = 2; build()).name = "Equipment_" + id
		if catalog.is_empty(): pages.text(rows, "没有符合筛选条件的物品。")
	else:
		if selected.is_empty(): pages.text(rows, "请先从收藏选择物品。"); return
		var definition := FightEquipmentData.definition(selected)
		pages.text(rows, definition.name, 48)
		pages.text(rows, FightEquipmentData.description(selected))
		if accessories and GameState.fight_accessories.has(selected):
			var owner := FightEquipmentData.owner(selected)
			pages.text(rows, "当前角色：" + FightData.hero(hero_id).name + "\n" + ("尚未装备" if owner.is_empty() else "装备于 " + FightData.hero(owner).name))
			for index in FightEquipmentData.SLOT_COUNT:
				var forbidden: bool = read_only or FightEquipmentData.slots(hero_id)[index] == selected or String(definition.get("exclusive", hero_id)) != hero_id or FightProgression.hero_level(hero_id) < FightEquipmentData.required_level(selected) or (definition.has("form") and FightSystem.current_attribute(hero_id) != String(definition.form))
				pages.button(rows, "安装到槽 %d" % (index + 1), func(): _equip(index, selected), forbidden).name = "InstallSlot_%d" % index
			if definition.has("exclusive"): pages.text(rows, "仅限 " + FightData.hero(definition.exclusive).name + (" · " + FightData.attr_name(definition.form) if definition.has("form") else ""))
			pages.text(rows, "需要 Lv.%d；可在「角色与装备槽」切换安装对象。" % FightEquipmentData.required_level(selected))
		else:
			pages.text(rows, ("完成%s的机制练习与多人实战后获得。" % FightData.hero(definition.exclusive).name) if definition.has("exclusive") else "在阿姨的塔间补给处购买。")
