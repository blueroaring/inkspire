extends Control
## Shared battle notebook: reference pages and embedded settings.
signal closed
signal page_changed(key: String)
signal item_requested(id: String)

const MOBILE := preload("res://scripts/ui/tower_mobile.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const THEME := preload("res://scripts/ui/battle_theme.gd")
const ART := preload("res://scripts/ui/battle_archive_art.gd")
const DETAIL := preload("res://scripts/ui/battle_archive_detail.gd")
const BATTLE_ART := preload("res://scripts/data/battle_art.gd")
const ATTRIBUTE_HINT := preload("res://scripts/ui/battle_attribute_hint.gd")
const ATTRIBUTE_CHART := preload("res://scripts/ui/battle_attribute_chart.gd")
const PERSONAL_GUARD := preload("res://scripts/ui/battle_personal_guard.gd")
const FONT := THEME.HEADING
const GOLD := THEME.GOLD
const WHITE := THEME.TEXT
const MUTED := THEME.MUTED
const INK := THEME.INK
const PAPER := THEME.SURFACE
const SELECTED := THEME.SELECTED
const PAGES := {
	"deck": ["抽牌堆", "待抽取的技能 · 按施术者整理，不代表抽取顺序", Color("91bddf"), "counterfeit"],
	"discard": ["弃牌堆", "抽牌堆耗尽时，弃牌将洗回抽牌堆", Color("b5a1cd"), "counterfeit"],
	"hand": ["当前手牌", "查看当前费用与卡牌状态 · 返回战斗后选择技能释放", Color("9dccb5"), "retain"],
	"exhausted": ["消耗堆", "本场战斗中，这些卡牌不会再次被抽取", Color("d9a48f"), "exhaust"],
	"log": ["战斗记录", "按发生顺序记录 · 最新事件位于底部", GOLD, "retain"],
	"characters": ["角色档案", "当前出战角色 · 战斗中只能查看资料与技能配置", Color("b7c2df"), "all"],
	"attributes": ["属性克制", "箭头由克制方指向被克制方 · 点击学科查看对应关系", Color("91bddf"), "all"],
	"bestiary": ["怪物图鉴", "怪物介绍、技能与机制 · 伤害与恢复量使用定性描述", Color("c7b296"), "all"],
	"effects": ["机制说明", "查阅卡牌词条、状态与特殊规则 · 支持分类和搜索", Color("c7b296"), "innate"],
	"items": ["战斗道具", "选择道具后使用 · 需要目标时，返回战场选择目标", Color("9bd8c5"), "innate"],
	"settings": ["设置", "音量、特效与操作偏好 · 修改后自动保存", Color("c7b296"), "retain"],
	"calculation": ["演算区", "按当前顺序展示 · 从上至下依次消耗", Color("91bddf"), "counterfeit"],
}
var initial_page := "deck"
var page := ""
var selected_hero := 0
var _pane: Panel
var _body: Control
var _tabs: Control
var _title: Label
var _subtitle: Label
var _footer: Label
var _detail: Control
var _preview_tween: Tween
var _page_tween: Tween
var _selected_tile: Button
var _selected_item := ""
var _closing := false

func _ready() -> void:
	preload("res://scripts/ui/tower_mobile.gd").register_back(self, close)
	THEME.apply(self)
	if MOBILE.enabled():
		_ready_mobile()
		return
	name = "BattleArchive"
	z_index = 95
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.045, 0.05, 0.36)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_pane = V.panel(self, Rect2(156, 110, 1608, 860), INK, Color(THEME.LINE, 0.65), 6)
	_pane.name = "ArchiveFrame"
	_pane.get_node("SurfaceArt").ornate = false
	_pane.mouse_filter = Control.MOUSE_FILTER_STOP
	var engraving := ART.new()
	engraving.accent = GOLD
	engraving.size = _pane.size
	_pane.add_child(engraving)
	V.glyph(_pane, "retain", Rect2(32, 24, 48, 48), GOLD)
	_title = _title_text(_pane, "", Rect2(98, 18, 740, 48), 34)
	_subtitle = V.text(_pane, "", Rect2(100, 64, 1130, 24), 17, MUTED)
	V.text(_pane, "战斗手札  /  第 %02d 回合" % FightSystem.round, Rect2(1100, 28, 278, 34), 18, GOLD, true)
	_button(_pane, "关闭  ×", Rect2(1414, 26, 154, 44), close, GOLD)
	_tabs = Control.new()
	_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pane.add_child(_tabs)
	_body = Control.new()
	_body.name = "ArchiveBody"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pane.add_child(_body)
	_footer = V.text(_pane, "", Rect2(34, 815, 1230, 26), 16, MUTED)
	V.text(_pane, "ESC / 点击外侧返回", Rect2(1290, 815, 280, 26), 16, GOLD, true)
	show_page(initial_page)
	modulate.a = 0
	_pane.position.y += 16
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(_pane, "position:y", 110.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func show_page(key: String) -> void:
	if not PAGES.has(key) or _closing: return
	page = key
	if MOBILE.enabled():
		_mobile_content(key)
		return
	_selected_tile = null
	_detail = null
	_clear(_body)
	_clear(_tabs)
	_title.text = String(PAGES[key][0])
	_subtitle.text = String(PAGES[key][1])
	if key == "hand": _subtitle.text = "当前 %d / %d 张 · 超出上限进入弃牌堆 · 返回战斗后选择技能释放" % [FightSystem.hand.size(), FightSystem.expansion_hand_limit]
	var page_tint := THEME.quiet(PAGES[key][2])
	_pane.add_theme_stylebox_override("panel", THEME.frame(INK, Color(page_tint, 0.5), 1, 6))
	var index := 0
	var tab_count := PAGES.size() - (0 if key == "calculation" else 1)
	var tab_width := (1544.0 - 12.0 * (tab_count - 1)) / tab_count
	for tab_key in PAGES:
		if tab_key == "calculation" and key != "calculation": continue
		var data: Array = PAGES[tab_key]
		var caption := String(data[0])
		if tab_key in ["deck", "discard", "hand", "exhausted", "calculation"]: caption += "  %d" % _pile(tab_key).size()
		var tab := _button(_tabs, caption, Rect2(32 + index * (tab_width + 12), 112, tab_width, 48), func() -> void: show_page(tab_key), data[2], key == tab_key)
		tab.name = "ArchiveTab_" + tab_key
		tab.get_node("SurfaceArt").hide()
		# Tabs are text-led navigation; only the current page gets a quiet underline.
		var tab_tint := THEME.quiet(data[2])
		var tab_style := THEME.frame(INK.lerp(tab_tint, 0.23) if key == tab_key else Color.TRANSPARENT, Color(tab_tint, 0.8) if key == tab_key else Color(THEME.LINE, 0.25), 0, 3)
		tab_style.border_width_bottom = 2 if key == tab_key else 1
		tab_style.shadow_size = 0
		tab.add_theme_stylebox_override("normal", tab_style)
		tab.disabled = (tab_key == "items" and not FightSystem.can_use_items()) or (tab_key == "characters" and FightSystem.tutorial_step >= 0 and FightSystem.tutorial_step < 4)
		index += 1
	_footer.text = "仅查看当前战斗信息"
	match key:
		"log": _build_log()
		"characters": _build_characters()
		"attributes": _build_attributes()
		"bestiary": _build_bestiary()
		"effects": _build_effects()
		"items": _build_items()
		"settings": _build_settings()
		_: _build_pile()
	if is_instance_valid(_page_tween): _page_tween.kill()
	_body.modulate.a = 0.35
	_body.position.y = 7
	_page_tween = create_tween().set_parallel(true)
	_page_tween.tween_property(_body, "modulate:a", 1.0, 0.16)
	_page_tween.tween_property(_body, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	page_changed.emit(key)

func _build_settings() -> void:
	var settings := SettingsPanel.new()
	settings.name = "ArchiveSettings"
	settings.embedded = true
	settings.position = Vector2(32, 184)
	_body.add_child(settings)
	_footer.text = "设置自动保存 · 特效模式可选择1倍速或2倍速 · 音量即时生效"

func _build_bestiary() -> void:
	var bestiary := preload("res://scripts/ui/enemy_bestiary.gd").new()
	bestiary.position = Vector2(32, 184)
	bestiary.size = Vector2(1544, 600)
	_body.add_child(bestiary)
	_footer.text = preload("res://scripts/ui/tower_mobile.gd").words("全部怪物均可查阅 · 滚轮浏览列表与详情")

func _build_effects() -> void:
	var guide := preload("res://scripts/ui/battle_mechanics.gd").new()
	guide.position = Vector2(32, 184)
	guide.size = Vector2(1544, 600)
	_body.add_child(guide)
	_footer.text = "与角色系统共用机制说明 · 搜索名称或效果 · 滚动查看"

func _pile(key: String) -> Array:
	match key:
		"deck": return FightSystem.draw_pile
		"discard": return FightSystem.discard_pile
		"hand": return FightSystem.hand
		"calculation": return FightSystem.fc.calculation
		_: return FightSystem.fc.exhausted

func _build_pile() -> void:
	var pile := _pile(page).duplicate(true)
	if page in ["deck", "discard"]:
		pile.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.caster_id) + String(a.skill_id) < String(b.caster_id) + String(b.skill_id))
	_footer.text = preload("res://scripts/ui/tower_mobile.gd").words("共 %d 张   ·   点击卡牌查看右侧详情   ·   滚轮浏览" % pile.size())
	var scroll := _scroll(_body, Rect2(32, 184, 1002, 600))
	scroll.name = "PileScroll"
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	_detail = V.panel(_body, Rect2(1058, 184, 518, 600), PAPER, Color(GOLD, 0.26), 6)
	_detail.name = "CardPreview"
	if pile.is_empty():
		_empty(_body, Rect2(32, 184, 1002, 600), "这里暂时没有卡牌", String(PAGES[page][1]), String(PAGES[page][3]), PAGES[page][2])
		_empty(_detail, Rect2(0, 0, 518, 600), "等待下一张牌", "卡面与技能说明将在这里显示", "innate", PAGES[page][2])
		return
	for i in pile.size():
		var card: Dictionary = pile[i]
		var tile := _card_tile(card, i)
		grid.add_child(tile)
		tile.pressed.connect(func() -> void:
			AudioManager.play_card_select()
			_select_card(card, tile))
		if i == 0: _select_card(card, tile)

func _card_tile(card: Dictionary, index: int) -> Button:
	var id := String(card.skill_id)
	var identity := V.card_identity(card)
	var tint: Color = identity.edge
	var button := Button.new()
	button.name = "ArchiveCard_%d" % index
	button.custom_minimum_size = Vector2(234, 280)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("identity", identity)
	_skin(button, identity.accent)
	var ring := ART.new()
	ring.emblem = true
	ring.accent = identity.accent
	ring.family = identity.motif
	ring.position = Vector2(52, 34)
	ring.size = Vector2(130, 130)
	button.add_child(ring)
	# Small enamel corner and inset rules retain detail without a bright card face.
	var detail_art := ART.new()
	detail_art.card_frame = true
	detail_art.accent = identity.edge
	detail_art.family = identity.motif
	detail_art.size = Vector2(234, 280)
	button.add_child(detail_art)
	V.icon(button, FightData.skill_icon(id), Rect2(68, 50, 98, 98))
	V.energy_badge(button, card, Rect2(178, 12, 44, 44))
	V.text(button, "%02d" % (index + 1), Rect2(15, 14, 42, 26), 16, MUTED)
	_title_text(button, V.card_title(card), Rect2(12, 163, 210, 35), 22, tint, true)
	V.text(button, V.owner_name(card), Rect2(12, 202, 210, 24), 16, MUTED, true)
	var effects := V.effect_icons(button, card, Vector2(14, 241), 22)
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in effects.get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if effects.get_child_count() == 0: V.text(button, FightData.rarity_name(id), Rect2(14, 239, 200, 27), 15, Color(tint, 0.8), true)
	button.mouse_entered.connect(func() -> void:
		var tween := button.create_tween()
		tween.tween_property(ring, "modulate", Color(1.08, 1.08, 1.08), 0.12))
	button.mouse_exited.connect(func() -> void:
		var tween := button.create_tween()
		tween.tween_property(ring, "modulate", Color.WHITE, 0.18))
	return button

func _select_card(card: Dictionary, tile: Button) -> void:
	if is_instance_valid(_selected_tile):
		_selected_tile.remove_theme_stylebox_override("normal")
		_selected_tile.add_theme_stylebox_override("normal", _selected_tile.get_meta("rest_style"))
	_selected_tile = tile
	var identity := V.card_identity(card)
	tile.add_theme_stylebox_override("normal", THEME.frame(identity.fill, identity.edge, 2, 5))
	_clear(_detail, true)
	var id := String(card.skill_id)
	var tint: Color = identity.edge
	_detail.add_theme_stylebox_override("panel", THEME.frame(PAPER.lerp(identity.fill, 0.3), Color(identity.accent, 0.6), 1, 6))
	THEME.material_identity(_detail, identity)
	V.text(_detail, "技能详解  /  %s" % FightData.rarity_name(id), Rect2(28, 22, 380, 28), 17, tint)
	V.icon(_detail, FightData.skill_icon(id), Rect2(30, 70, 112, 112))
	_title_text(_detail, V.card_title(card), Rect2(162, 69, 326, 48), 27, WHITE)
	V.text(_detail, V.owner_name(card), Rect2(164, 119, 310, 28), 19, MUTED)
	V.text(_detail, "能量 %s   ·   携带 cost %d" % ["X" if int(FightData.skill(id).get("cost", 0)) < 0 else str(FightSystem.card_cost(card)), FightData.skill_points(id)], Rect2(164, 151, 326, 26), 16, GOLD)
	_rule(_detail, Rect2(28, 200, 462, 1), tint)
	var scroll := _scroll(_detail, Rect2(28, 224, 462, 310))
	var text := RichTextLabel.new()
	text.name = "CardDescription"
	text.bbcode_enabled = false
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size.x = 440
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 22)
	text.add_theme_color_override("default_color", WHITE)
	text.add_theme_constant_override("line_separation", 9)
	text.text = FightData.description(id, FightData.card_level(card))
	for key in FightSystem.fc.effect_keys(card):
		var data: Array = V.EFFECTS[key]
		text.text += "\n\n%s · %s" % [data[0], data[1]]
	scroll.add_child(text)
	V.effect_icons(_detail, card, Vector2(28, 550), 28)
	if is_instance_valid(_preview_tween): _preview_tween.kill()
	_detail.modulate.a = 0.45
	_preview_tween = create_tween()
	_preview_tween.tween_property(_detail, "modulate:a", 1.0, 0.16)

func _build_log() -> void:
	var entries := FightSystem.get_log()
	var summary := V.panel(_body, Rect2(32, 184, 300, 600), THEME.SURFACE, Color(GOLD, 0.3), 6)
	_emblem(summary, Rect2(66, 35, 168, 168), GOLD, "retain")
	_title_text(summary, "战况回顾", Rect2(24, 225, 252, 44), 29, WHITE, true)
	V.text(summary, "%03d" % entries.size(), Rect2(24, 290, 252, 80), 60, GOLD, true)
	V.text(summary, "条战斗记录", Rect2(24, 371, 252, 30), 18, MUTED, true)
	_button(summary, "跳至最新 ↓", Rect2(34, 492, 232, 48), func() -> void:
		var scroll := _body.get_node("LogScroll") as ScrollContainer
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value), GOLD)
	var log_scroll := _scroll(_body, Rect2(364, 184, 1212, 600))
	log_scroll.name = "LogScroll"
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	log_scroll.add_child(rows)
	for i in entries.size():
		var words := String(entries[i])
		var is_turn := words.contains("回合") and (words.contains("开始") or words.contains("第"))
		var tint := GOLD if is_turn else THEME.RED if words.contains("伤害") else THEME.GREEN if words.contains("恢复") or words.contains("治疗") else THEME.BLUE
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", THEME.frame(SELECTED if is_turn else PAPER, Color(tint, 0.27), 1, 5))
		rows.add_child(row)
		var margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
		row.add_child(margin)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 22)
		margin.add_child(line)
		var number := Label.new()
		number.text = "%03d" % (i + 1)
		number.custom_minimum_size.x = 50
		number.add_theme_font_size_override("font_size", 18)
		number.add_theme_color_override("font_color", tint)
		line.add_child(number)
		var label := Label.new()
		label.text = words
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 21)
		label.add_theme_color_override("font_color", WHITE)
		line.add_child(label)
	if entries.is_empty(): _empty(_body, Rect2(364, 184, 1212, 600), "记录尚未开始", "战斗事件将在这里依次留存", "retain", GOLD)
	else: _scroll_latest.call_deferred(log_scroll)
	_footer.text = preload("res://scripts/ui/tower_mobile.gd").words("伤害、治疗与回合以不同颜色区分   ·   滚轮回看较早记录")

func _scroll_latest(scroll: ScrollContainer) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll): scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

func _build_characters() -> void:
	var allies := FightSystem.allies
	if allies.is_empty(): return
	selected_hero = clampi(selected_hero, 0, allies.size() - 1)
	var unit: Dictionary = allies[selected_hero]
	var id := String(unit.id)
	var profile := FightData.hero(id)
	var identity := THEME.identity(id, String(unit.get("attribute", "none")))
	var accent: Color = identity.edge
	for i in allies.size():
		var member: Dictionary = allies[i]
		var button := _button(_body, "", Rect2(32, 184 + i * 132, 208, 114), func() -> void:
			selected_hero = i
			show_page("characters"), BATTLE_ART.accent(BATTLE_ART.module(member)), i == selected_hero)
		button.name = "ArchiveHero_%d" % i
		var member_identity := THEME.identity(String(member.id), String(member.get("attribute", "none")))
		button.set_meta("identity", member_identity)
		_skin(button, member_identity.accent, i == selected_hero)
		V.hero_icon(button, String(member.id), Rect2(8, 7, 74, 98), String(member.attribute))
		V.text(button, String(member.name), Rect2(86, 26, 114, 30), 21, WHITE)
		V.text(button, "Lv.%d" % FightProgression.hero_level(String(member.id)), Rect2(86, 62, 114, 25), 17, GOLD)
	var portrait := V.panel(_body, Rect2(258, 184, 418, 600), identity.fill, Color(identity.edge, 0.65), 6)
	THEME.material_identity(portrait, identity)
	_emblem(portrait, Rect2(40, 60, 338, 338), Color(identity.accent, 0.6), "", identity.motif)
	var hero_portrait := V.hero_icon(portrait, id, Rect2(18, 12, 382, 346), String(unit.attribute))
	hero_portrait.name = "ArchiveCharacterPortrait"
	hero_portrait.interactive_motion = true
	if bool(unit.get("anya_phoenix", false)):
		hero_portrait.form_portrait = String(unit.portrait)
		hero_portrait.texture = load(String(unit.portrait))
	var portrait_style := preload("res://scripts/ui/battle_portrait_style.gd").new()
	portrait_style.hero_id = id
	portrait_style.position = Vector2(20, 355)
	portrait_style.scale = Vector2(0.77, 0.77)
	portrait_style.style_selected.connect(func() -> void: show_page("characters"))
	portrait.add_child(portrait_style)
	var nameplate := V.panel(portrait, Rect2(18, 426, 382, 156), PAPER, Color(accent, 0.28), 3)
	_title_text(nameplate, String(profile.name), Rect2(20, 10, 340, 48), 34, WHITE, true)
	V.text(nameplate, "Lv.%d" % FightProgression.hero_level(id), Rect2(40, 64, 74, 30), 19, accent, true)
	ATTRIBUTE_HINT.badge(nameplate, String(unit.attribute), Rect2(125, 64, 90, 30))
	V.text(nameplate, FightData.ROLES.get(profile.role, profile.role), Rect2(232, 64, 110, 30), 19, accent, true)
	var growth: Dictionary = GameState.fight_profiles.get(id, {})
	V.text(nameplate, "经验 %d / %d" % [int(growth.get("xp", 0)), TowerData.xp_needed(FightProgression.hero_level(id)) if TowerRun.active else FightProgression.hero_level(id) * 100], Rect2(12, 100, 358, 24), 16, MUTED, true)
	V.text(nameplate, "等级上限 %d%s" % [FightProgression.level_cap(), " · 经验储存中" if FightProgression.hero_level(id) >= FightProgression.level_cap() else ""], Rect2(12, 126, 358, 23), 15, MUTED, true)
	var right := V.panel(_body, Rect2(700, 184, 876, 600), PAPER, Color(accent, 0.25), 6)
	THEME.material_identity(right, identity)
	_title_text(right, "当前状态", Rect2(24, 16, 260, 36), 24)
	var state := "羽翼庇护 · 暂离" if unit.get("anya_hidden", false) else "已退场" if unit.get("dead", false) else "濒死" if unit.get("downed", false) else "作战中"
	V.text(right, state, Rect2(690, 18, 155, 30), 19, THEME.RED if state != "作战中" else accent, true)
	_meter(right, Rect2(24, 66, 398, 34), int(unit.hp), int(unit.max_hp), THEME.HEALTH, "生命")
	if bool(unit.get("anya_phoenix", false)):
		_meter(right, Rect2(446, 66, 404, 34), int(unit.rebirth), int(unit.rebirth_max), Color("c99452"), "重生计数")
	else:
		_meter(right, Rect2(446, 66, 404, 34), int(unit.get("ult", 0)), FightSystem.ultimate_max(selected_hero), accent, "涅槃充能" if id == "li_anya" else "终结技能量")
	var statuses := FightData.statuses(unit)
	var status_words := PackedStringArray()
	for status in statuses: status_words.append(String(status.get("name", "")))
	PERSONAL_GUARD.badge(right, Rect2(24, 112, 178, 30), int(unit.get("guard", 0)), false, int(unit.max_hp))
	PERSONAL_GUARD.badge(right, Rect2(212, 112, 178, 30), int(unit.statuses.get("poison_guard", {}).get("stacks", 0)), true, int(unit.max_hp))
	V.text(right, "无附加状态" if statuses.is_empty() else " / ".join(status_words), Rect2(406, 112, 444, 30), 17, MUTED)
	var scroll := _scroll(right, Rect2(24, 158, 826, 418))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)
	_paragraph(column, "角色被动", FightData.passive(id, String(unit.attribute)), accent)
	var ultimate := FightSystem.get_ultimate(selected_hero)
	preload("res://scripts/ui/battle_management_ui.gd").ultimate_illustration(column, unit, 250, func():
		var detail := preload("res://scripts/ui/battle_ultimate_reference.gd").new()
		detail.unit = unit
		detail.ultimate = ultimate
		get_parent().add_child(detail))
	var ultimate_path := String(ultimate.get("icon", ""))
	var ultimate_icon: Texture2D = load(ultimate_path) if not ultimate_path.is_empty() and ResourceLoader.exists(ultimate_path) else null
	_paragraph(column, "终结技 · %s" % ultimate.get("name", ""), String(ultimate.get("desc", "")), GOLD, ultimate_icon)
	if id == "li_anya":
		var compare := _button(column, "查看双形态技能对照", Rect2(0, 0, 800, 48), func() -> void: get_parent().add_child(preload("res://scripts/ui/anya_form_reference.gd").new()), GOLD)
		compare.custom_minimum_size = Vector2(0, 48)
	var loadout := FightSystem.loadout(id)
	_paragraph(column, "携带技能 · %d 张 / cost %d / %d" % [loadout.size(), FightSystem.loadout_points(loadout), FightSystem.skill_point_limit(id)], "点击技能查看完整效果", accent)
	var counts := {}
	for skill in loadout: counts[skill] = int(counts.get(skill, 0)) + 1
	for skill in counts:
		var row := _button(column, "", Rect2(0, 0, 800, 72), func() -> void:
			_show_equipped_skill(skill, id), FightData.rarity_color(skill))
		row.name = "EquippedSkill_" + String(skill)
		THEME.material_identity(row, identity)
		row.custom_minimum_size = Vector2(0, 72)
		V.icon(row, FightData.skill_icon(skill), Rect2(14, 9, 54, 54))
		V.text(row, String(FightData.skill(skill).get("name", skill)), Rect2(84, 10, 480, 30), 21, WHITE)
		V.text(row, "携带 cost %d" % FightData.skill_points(skill), Rect2(84, 40, 460, 22), 15, MUTED)
		V.text(row, "× %d" % counts[skill], Rect2(702, 20, 76, 32), 23, GOLD, true)
	for accessory in unit.get("accessories", []):
		var def: Dictionary = FightEquipmentData.ACCESSORIES.get(accessory, {})
		if not def.is_empty():
			_paragraph(column, "%s饰品 · %s" % [FightEquipmentData.rarity(accessory).name, def.name], FightEquipmentData.description(accessory), FightEquipmentData.rarity(accessory).color, FightEquipmentData.texture(accessory))
	_footer.text = "切换左侧角色查看资料   ·   右侧滚动查看被动、终结技、卡组与饰品"

func _show_equipped_skill(skill: String, owner: String) -> void:
	if MOBILE.enabled():
		V.detail(self, {"skill_id":skill, "caster_id":owner})
		return
	var detail := DETAIL.new()
	detail.card = {"skill_id":skill, "caster_id":owner}
	add_child(detail)

func _build_attributes() -> void:
	var chart := ATTRIBUTE_CHART.new()
	chart.position = Vector2(32, 184)
	chart.size = Vector2(1544, 600)
	if selected_hero >= 0 and selected_hero < FightSystem.allies.size():
		var attribute := String(FightSystem.allies[selected_hero].get("attribute", "none"))
		if FightData.ADVANTAGE.has(attribute): chart.selected_attribute = attribute
	_body.add_child(chart)
	_footer.text = "箭头指向被克制的一方   ·   点击学科切换高亮   ·   同属性与无极之间没有克制修正"

func _build_items() -> void:
	var inventory: Array[String] = []
	for id in FightEquipmentData.CONSUMABLES:
		if Inventory.count(id, GameState.BAG_HIGHSCHOOL) > 0: inventory.append(id)
	if inventory.is_empty():
		_empty(_body, Rect2(32, 184, 1544, 600), "暂无战斗道具", "获得战斗消耗品后，可在我方回合从这里使用", "innate", Color("9bd8c5"))
		_footer.text = "道具来自高中背包   ·   成功使用后扣除 1 个"
		return
	if not inventory.has(_selected_item): _selected_item = inventory[0]
	var scroll := _scroll(_body, Rect2(32, 184, 646, 600))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	scroll.add_child(rows)
	for i in inventory.size():
		var id := inventory[i]
		var def: Dictionary = FightEquipmentData.CONSUMABLES[id]
		var tint := _item_tint(id)
		var button := _button(rows, "", Rect2(0, 0, 616, 154), func() -> void:
			_selected_item = id
			show_page("items"), tint, id == _selected_item)
		button.name = "ArchiveItem_" + id
		button.custom_minimum_size = Vector2(616, 154)
		_item_art(button, id, Rect2(24, 23, 116, 116))
		_title_text(button, String(def.name), Rect2(166, 27, 360, 42), 29, WHITE)
		V.text(button, "%s · %s" % [FightEquipmentData.rarity(id).name, def.kind_label], Rect2(168, 80, 344, 30), 20, tint)
		V.text(button, "持有  %02d" % Inventory.count(id, GameState.BAG_HIGHSCHOOL), Rect2(430, 118, 160, 28), 18, GOLD, true)
	var def: Dictionary = FightEquipmentData.CONSUMABLES[_selected_item]
	var tint := _item_tint(_selected_item)
	var detail := V.panel(_body, Rect2(706, 184, 870, 600), PAPER, Color(tint, 0.4), 6)
	_item_art(detail, _selected_item, Rect2(70, 24, 146, 146))
	_title_text(detail, String(def.name), Rect2(244, 46, 556, 50), 35, WHITE)
	V.text(detail, "%s消耗品  /  %s" % [FightEquipmentData.rarity(_selected_item).name, FightData.target_name(def.target)], Rect2(246, 110, 554, 28), 18, tint)
	preload("res://scripts/ui/battle_management_ui.gd").equipment_description(detail, _selected_item, Rect2(70, 192, 730, 275))
	var error := FightSystem.item_error(_selected_item, -1, false)
	var use := _button(detail, "选择目标" if def.target != "party" else "使用道具", Rect2(240, 486, 390, 58), _use_item, tint, true)
	use.name = "UseBattleItem"
	use.disabled = not error.is_empty()
	V.text(detail, error if not error.is_empty() else "成功使用后消耗 1 个", Rect2(30, 556, 810, 25), 17, THEME.RED if not error.is_empty() else MUTED, true)
	_footer.text = "本战剩余 %d / 2 次  ·  每回合限 1 次  ·  每战最多 1 件稀有道具  ·  取消选目标不消耗" % maxi(0, FightEquipmentData.ITEMS_PER_BATTLE - FightSystem.items_used)

func _use_item() -> void:
	var id := _selected_item
	if not FightSystem.item_error(id, -1, false).is_empty(): return
	hide()
	closed.emit()
	queue_free()
	item_requested.emit(id)

func _item_art(parent: Node, id: String, rect: Rect2) -> void:
	_emblem(parent, rect, _item_tint(id), "")
	V.icon(parent, FightEquipmentData.texture(id), Rect2(rect.position + rect.size * 0.08, rect.size * 0.84))

func _item_tint(id: String) -> Color:
	return FightEquipmentData.rarity(id).color

func _paragraph(parent: Node, heading: String, words: String, tint: Color, icon: Texture2D = null) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	parent.add_child(header)
	if icon != null:
		var art := V.icon(header, icon, Rect2(0, 0, 38, 38))
		art.custom_minimum_size = Vector2(38, 38)
	var title := Label.new()
	title.text = heading
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", tint)
	header.add_child(title)
	var body := Label.new()
	body.text = words
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", WHITE)
	parent.add_child(body)

func _meter(parent: Node, rect: Rect2, value: int, maximum: int, tint: Color, caption: String) -> void:
	var track := V.panel(parent, rect, THEME.RECESSED, Color(tint, 0.25), 4)
	var fill := ColorRect.new()
	fill.position = Vector2(3, 3)
	fill.size = Vector2((rect.size.x - 6) * clampf(float(value) / maxi(1, maximum), 0, 1), rect.size.y - 6)
	fill.color = tint.lerp(THEME.RECESSED, 0.65)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	V.text(track, "%s  %d / %d" % [caption, value, maximum], Rect2(Vector2.ZERO, rect.size), 18, WHITE, true)

func _empty(parent: Node, rect: Rect2, heading: String, hint: String, glyph: String, tint: Color) -> void:
	_emblem(parent, Rect2(rect.position + Vector2((rect.size.x - 160) / 2, 110), Vector2(160, 160)), tint, glyph)
	_title_text(parent, heading, Rect2(rect.position + Vector2(10, 310), Vector2(rect.size.x - 20, 46)), 29, WHITE, true)
	var label := V.text(parent, hint, Rect2(rect.position + Vector2(42, 371), Vector2(rect.size.x - 84, 70)), 20, MUTED, true)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _emblem(parent: Node, rect: Rect2, tint: Color, glyph: String, family: String = "orbit") -> void:
	var art := ART.new()
	art.emblem = true
	art.family = family
	art.accent = tint
	art.position = rect.position
	art.size = rect.size
	parent.add_child(art)
	if glyph != "": V.glyph(art, glyph, Rect2(rect.size * 0.3, rect.size * 0.4), tint)

func _scroll(parent: Node, rect: Rect2) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.position = rect.position
	scroll.size = rect.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var bar := scroll.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll", THEME.frame(THEME.RECESSED, Color.TRANSPARENT, 0, 4))
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]: bar.add_theme_stylebox_override(state, THEME.frame(THEME.LINE, Color.TRANSPARENT, 0, 4))
	return scroll

func _skin(button: Button, tint: Color, selected: bool = false) -> void:
	var identity: Dictionary = button.get_meta("identity", {})
	var fill: Color = identity.get("fill", PAPER)
	var edge: Color = identity.get("edge", THEME.LINE)
	THEME.material_identity(button, identity)
	var rest := THEME.frame(fill if selected else PAPER.lerp(fill, 0.72), edge if selected else Color(edge, 0.5), 2 if selected else 1, 5)
	rest.shadow_size = 2
	rest.shadow_color = Color("655339", 0.08)
	button.set_meta("rest_style", rest)
	button.add_theme_stylebox_override("normal", rest)
	button.add_theme_stylebox_override("hover", THEME.frame(fill.lerp(THEME.HOVER, 0.35), edge, 1, 5))
	button.add_theme_stylebox_override("pressed", THEME.frame(INK, GOLD, 1, 5))
	button.add_theme_stylebox_override("disabled", THEME.frame(INK, Color(THEME.LINE, 0.2), 1, 5))
	var focus := THEME.frame(Color.TRANSPARENT, GOLD, 2, 5)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_pressed_color", WHITE)
	button.add_theme_color_override("font_disabled_color", THEME.FAINT)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 21)

func _button(parent: Node, words: String, rect: Rect2, action: Callable, tint: Color, selected: bool = false) -> Button:
	var button := Button.new()
	button.text = words
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_skin(button, tint, selected)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _title_text(parent: Node, words: String, rect: Rect2, font_size: int, color: Color = WHITE, centered: bool = false) -> Label:
	var label := V.text(parent, words, rect, font_size, color, centered)
	label.add_theme_font_override("font", FONT)
	return label

func _rule(parent: Node, rect: Rect2, tint: Color) -> void:
	var line := ColorRect.new()
	line.color = Color(tint, 0.3)
	line.position = rect.position
	line.size = rect.size
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func _ink_tint(tint: Color) -> Color:
	return THEME.quiet(tint)

func _rarity_ink(id: String) -> Color:
	var tint := FightData.rarity_color(id)
	return GOLD if tint.r > 0.9 and tint.b < 0.75 else THEME.BLUE if tint.b > tint.r + 0.1 else WHITE

func _clear(parent: Node, keep_surface: bool = false) -> void:
	for child in parent.get_children():
		if keep_surface and child.name == "SurfaceArt": continue
		parent.remove_child(child)
		child.queue_free()

func close() -> void:
	if _closing: return
	_closing = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func() -> void:
		closed.emit()
		queue_free())

func _input(event: InputEvent) -> void:
	if MOBILE.enabled(): return
	if has_node("CardDetail"): return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event is InputEventMouseButton and event.pressed:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if not _pane.get_rect().has_point(local) and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			get_viewport().set_input_as_handled()
			close()


func _ready_mobile() -> void:
	name = "BattleArchive"
	z_index = 95
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.05, 0.9)
	shade.size = size
	add_child(shade)
	_pane = V.panel(self, Rect2(30, 20, 1860, 1040), INK, GOLD, 8)
	_title = _title_text(_pane, "", Rect2(40, 20, 1380, 64), 42)
	_subtitle = V.text(_pane, "", Rect2(40, 90, 1380, 42), 28, MUTED)
	_button(_pane, "关闭", Rect2(1530, 20, 290, 120), close, GOLD).add_theme_font_size_override("font_size", 36)
	var tabs_scroll := _scroll(_pane, Rect2(40, 155, 1780, 138))
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 18)
	tabs_scroll.add_child(_tabs)
	_body = Control.new()
	_body.name = "ArchiveBody"
	_body.position = Vector2(40, 320)
	_body.size = Vector2(1780, 670)
	_pane.add_child(_body)
	_footer = V.text(_pane, "", Rect2(40, 998, 1780, 36), 25, MUTED)
	show_page(initial_page)

func _mobile_content(key: String) -> void:
	_clear(_body)
	_clear(_tabs)
	_title.text = PAGES[key][0]
	_subtitle.text = PAGES[key][1]
	for tab_key in PAGES:
		if tab_key == "calculation" and key != "calculation": continue
		var tab := _button(_tabs, PAGES[tab_key][0], Rect2(), func(): show_page(tab_key), PAGES[tab_key][2], key == tab_key)
		tab.name = "ArchiveTab_" + tab_key
		tab.custom_minimum_size = Vector2(310, 120)
		tab.add_theme_font_size_override("font_size", 34)
		if key == tab_key:
			(_tabs.get_parent() as ScrollContainer).set_deferred("scroll_horizontal", maxi(0, _tabs.get_child_count() - 3) * 328)
	_footer.text = "横向滑动切换栏目 · 上下滑动阅读"
	if key in ["settings", "bestiary", "effects", "attributes"]:
		var component: Control
		match key:
			"settings":
				component = SettingsPanel.new()
				component.embedded = true
			"bestiary": component = preload("res://scripts/ui/enemy_bestiary.gd").new()
			"effects": component = preload("res://scripts/ui/battle_mechanics.gd").new()
			_: component = ATTRIBUTE_CHART.new()
		component.size = _body.size
		_body.add_child(component)
	else:
		var scroll := _scroll(_body, Rect2(Vector2.ZERO, _body.size))
		scroll.name = "MobileArchiveScroll"
		var rows := VBoxContainer.new()
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_theme_constant_override("separation", 24)
		scroll.add_child(rows)
		if key == "log":
			for entry in FightSystem.get_log(): _mobile_text(rows, String(entry))
		elif key == "characters":
			for unit in FightSystem.allies:
				_mobile_text(rows, "%s · Lv.%d · 生命 %d / %d · %s" % [unit.name, FightProgression.hero_level(unit.id), unit.hp, unit.max_hp, FightData.attr_name(unit.attribute)], 38)
				_mobile_text(rows, "被动：" + FightData.passive(unit.id, unit.attribute))
				var ultimate := FightData.ultimate(unit.id, unit.attribute)
				_mobile_text(rows, "终结技 · " + ultimate.name + "\n" + ultimate.desc)
				for skill in FightSystem.loadout(unit.id):
					if rows.has_node("Skill_" + unit.id + "_" + skill): continue
					var button := _mobile_button(rows, FightData.skill(skill).name + " · 查看技能", func(): _show_equipped_skill(skill, unit.id))
					button.name = "Skill_" + unit.id + "_" + skill
				if unit.id == "li_anya": _mobile_button(rows, "双形态技能对照", func(): add_child(preload("res://scripts/ui/anya_form_reference.gd").new()))
		elif key == "items":
			var count := 0
			for id in FightEquipmentData.CONSUMABLES:
				var amount := Inventory.count(id, GameState.BAG_HIGHSCHOOL)
				if amount <= 0: continue
				count += 1
				var definition: Dictionary = FightEquipmentData.CONSUMABLES[id]
				_mobile_text(rows, "%s × %d\n%s" % [definition.name, amount, definition.desc])
				var use := _mobile_button(rows, "选择目标" if definition.target != "party" else "使用道具", func(): _selected_item = id; _use_item())
				use.name = "UseBattleItem_" + id
				var error := FightSystem.item_error(id, -1, false)
				use.disabled = not error.is_empty()
				if not error.is_empty(): _mobile_text(rows, error)
			if count == 0: _mobile_text(rows, "暂无战斗道具。可以在塔间补给点购买。")
		else:
			var cards := _pile(key).duplicate(true)
			if key in ["deck", "discard"]: cards.sort_custom(func(a, b): return String(a.caster_id) + String(a.skill_id) < String(b.caster_id) + String(b.skill_id))
			for index in cards.size():
				var card: Dictionary = cards[index]
				var button := _mobile_button(rows, "%02d · %s    %s    能量 %s    查看详情" % [index + 1, V.card_title(card), V.owner_name(card), str(FightSystem.card_cost(card))], func(): V.detail(self, card))
				button.name = "ArchiveCard_%d" % index
			if cards.is_empty(): _mobile_text(rows, "这里暂时没有卡牌。")
	page_changed.emit(key)

func _mobile_text(rows: VBoxContainer, words: String, font_size: int = 34) -> void:
	var label := Label.new()
	label.text = words
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	rows.add_child(label)

func _mobile_button(rows: VBoxContainer, words: String, action: Callable) -> Button:
	var button := _button(rows, words, Rect2(), action, GOLD)
	button.custom_minimum_size = Vector2(0, 144)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 34)
	return button
