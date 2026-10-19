extends Control
## Shared in the character editor and in-battle archive.
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const T := preload("res://scripts/ui/battle_theme.gd")
const M := preload("res://scripts/ui/battle_management_ui.gd")
const ROOT := "res://assets/graphics/battle/anya/"

func _ready() -> void:
	preload("res://scripts/ui/tower_mobile.gd").register_back(self, queue_free)
	name = "AnyaFormReference"
	size = Vector2(1920, 1080)
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color(0.02, 0.03, 0.07, 0.94)
	add_child(shade)
	var panel := M.panel(Rect2(110, 70, 1700, 940), Color("111b30"), Color("c6a97c"))
	add_child(panel)
	M.heading(panel, "幻羽涅槃 · 双形态技能对照", Rect2(36, 24, 1350, 48), 31).add_theme_color_override("font_color", Color("edf2fc"))
	panel.add_child(M.button("关闭", Rect2(1370, 10, 290, 120) if preload("res://scripts/ui/tower_mobile.gd").enabled() else Rect2(1514, 24, 150, 48), queue_free))
	for i in 2:
		var x := 38 + i * 830
		var form := "bound" if i == 0 else "phoenix"
		if i == 1:
			var living := preload("res://scripts/ui/anya_living_portrait.gd").new()
			living.position = Vector2(x, 88)
			living.size = Vector2(120, 154)
			panel.add_child(living)
		else: V.icon(panel, load(ROOT + "portrait_" + form + ".webp"), Rect2(x, 88, 120, 154))
		V.icon(panel, load(ROOT + "icons/" + ("enter" if i == 0 else "return") + ".webp"), Rect2(x+140, 91, 66, 66))
		M.heading(panel, "被困之羽" if i == 0 else "涅槃·幻羽", Rect2(x+225, 91, 540, 40), 28).add_theme_color_override("font_color", Color("edf2fc"))
		V.text(panel, "找到我，然后拯救我 · 涅槃充能12" if i == 0 else "这一次，我们在一起！ · 锁定 / 退场自动释放", Rect2(x+140, 166, 640, 32), 20, Color("f5d69e"))
		V.text(panel, "携带左侧技能，变身后按原始数量逐一转为右侧技能。" if i == 0 else "全牌保留 · 消耗重生计数 · 背景切换为羽光天台", Rect2(x+140, 208, 640, 30), 18, Color("bcc9de"))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(38, 268)
	scroll.size = Vector2(1624, 628)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 12)
	scroll.add_child(rows)
	var ultimate_row: BoxContainer = VBoxContainer.new() if preload("res://scripts/ui/tower_mobile.gd").enabled() else HBoxContainer.new()
	ultimate_row.add_theme_constant_override("separation", 20)
	rows.add_child(ultimate_row)
	for phoenix in [false, true]:
		var overview := VBoxContainer.new()
		overview.custom_minimum_size.x = 795
		overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ultimate_row.add_child(overview)
		var unit := {"id":"li_anya", "anya_phoenix":phoenix}
		var ultimate := preload("res://scripts/fight/fc_anya.gd").return_ultimate() if phoenix else FightData.ultimate("li_anya")
		M.ultimate_illustration(overview, unit, 210, func():
			var detail := preload("res://scripts/ui/battle_ultimate_reference.gd").new()
			detail.unit = unit
			detail.ultimate = ultimate
			add_child(detail))
	for n in range(1, 14):
		var row: BoxContainer = VBoxContainer.new() if preload("res://scripts/ui/tower_mobile.gd").enabled() else HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		rows.add_child(row)
		for prefix in ["LA", "LP"]:
			var id := "%s%02d" % [prefix, n]
			var def := FightData.skill(id)
			var card := PanelContainer.new()
			card.custom_minimum_size = Vector2(795, 152)
			card.add_theme_stylebox_override("panel", T.frame(Color("1a2237"), Color("60729e") if prefix == "LA" else Color("ae8f61"), 1, 5))
			row.add_child(card)
			var box := HBoxContainer.new()
			box.add_theme_constant_override("separation", 16)
			card.add_child(box)
			var icon := TextureRect.new()
			icon.texture = FightData.skill_icon(id)
			icon.custom_minimum_size = Vector2(82, 82)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			box.add_child(icon)
			var words := VBoxContainer.new()
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_child(words)
			var heading := Label.new()
			heading.text = "%02d  %s · %s %d" % [n, def.name, "能量" if prefix == "LA" else "重生", def.cost]
			heading.add_theme_font_size_override("font_size", 38 if preload("res://scripts/ui/tower_mobile.gd").enabled() else 21)
			heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			heading.add_theme_color_override("font_color", Color("f5d69e"))
			words.add_child(heading)
			var body := Label.new()
			body.add_theme_color_override("font_color", Color("dce5f4"))
			body.text = FightData.description(id, FightProgression.hero_level("li_anya"))
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.add_theme_font_size_override("font_size", 38 if preload("res://scripts/ui/tower_mobile.gd").enabled() else 18)
			words.add_child(body)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
