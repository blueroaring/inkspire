extends Control
## Full illustration and rules, shared by character management and battle reference.
const M := preload("res://scripts/ui/battle_management_ui.gd")
const T := preload("res://scripts/ui/battle_theme.gd")
var unit: Dictionary = {}
var ultimate: Dictionary = {}

func _ready() -> void:
	preload("res://scripts/ui/tower_mobile.gd").register_back(self, queue_free)
	name = "UltimateReference"
	size = Vector2(1920, 1080)
	z_index = 220
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color(0.02, 0.03, 0.05, 0.9)
	add_child(shade)
	var pane := M.panel(Rect2(120, 112, 1680, 856))
	add_child(pane)
	T.apply(pane)
	M.heading(pane, "终结技 · " + String(FightData.hero(String(unit.id)).name), Rect2(36, 24, 1400, 48), 31)
	pane.add_child(M.button("关闭", Rect2(1494, 24, 150, 48), queue_free))
	var art := M.ultimate_illustration(pane, unit, 680)
	art.position = Vector2(36, 100)
	art.size = Vector2(790, 680)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(866, 116)
	scroll.size = Vector2(758, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pane.add_child(scroll)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 24)
	scroll.add_child(words)
	M.paragraph(words, String(ultimate.get("name", "终结技")), Rect2(), 34, T.GOLD)
	var charge := "锁定 · 退场时自动释放" if ultimate.get("locked", false) else "%s：%d" % ["涅槃充能" if unit.id == "li_anya" else "所需能量", int(ultimate.get("energy", 0))]
	M.paragraph(words, charge, Rect2(), 23, T.MUTED)
	M.paragraph(words, String(ultimate.get("desc", "")), Rect2(), 25)
	M.paragraph(words, "目标：" + FightData.target_name(String(ultimate.get("target", "self"))), Rect2(), 21, T.MUTED)
	if preload("res://scripts/ui/tower_mobile.gd").enabled():
		for child in pane.get_children():
			if child is Button: child.position = Vector2(1330, 12); child.size = Vector2(310, 120); child.add_theme_font_size_override("font_size", 36)
		scroll.position.y = 150
		scroll.size.y = 650
		preload("res://scripts/ui/tower_mobile_layout.gd").readable_tree(words, 38)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		queue_free()
