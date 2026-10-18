extends Control
const V := preload("res://scripts/ui/fc_card_visuals.gd")
var card: Dictionary = {}
const PANE_WIDTH := 676.0
const BODY_WIDTH := 608.0
const BODY_TOP := 156.0
const MAX_BODY_HEIGHT := 600.0
var pane: Panel
var scroll: ScrollContainer
var body: Label
var effects: Control
var footer: Label

func _ready() -> void:
	name = "CardDetail"
	z_index = 110
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.68)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var id := String(card.skill_id)
	pane = V.panel(self, Rect2(622, 273, PANE_WIDTH, 534), Color("101e32"), FightData.rarity_color(id), 16)
	pane.name = "DetailPane"
	V.icon(pane, FightData.skill_icon(id), Rect2(28, 27, 100, 100))
	V.text(pane, V.card_title(card), Rect2(150, 28, 492, 48), 31, V.GOLD)
	V.text(pane, "%s · %s · %s费" % [V.owner_name(card), FightData.rarity_name(id), "X" if int(FightData.skill(id).get("cost", 0)) < 0 else str(FightSystem.card_cost(card))], Rect2(150, 80, 492, 35), 20, V.MUTED)
	scroll = ScrollContainer.new()
	scroll.name = "DescriptionScroll"
	scroll.position = Vector2(34, BODY_TOP)
	scroll.size = Vector2(BODY_WIDTH, MAX_BODY_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	pane.add_child(scroll)
	body = Label.new()
	body.name = "Description"
	# Configure wrapping before assigning text or entering the tree. A Label
	# created unwrapped keeps its expanded width even after wrapping is enabled.
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.add_theme_font_size_override("font_size", 25)
	body.add_theme_color_override("font_color", Color("e6edf5"))
	body.add_theme_constant_override("line_spacing", 5)
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.text = FightData.description(id, FightData.card_level(card))
	scroll.add_child(body)
	effects = V.effect_icons(pane, card, Vector2.ZERO, 36)
	footer = V.text(pane, "", Rect2(34, 473, BODY_WIDTH, 32), 18, V.MUTED, true)
	body.minimum_size_changed.connect(_layout_description)
	_layout_description.call_deferred()

func _layout_description() -> void:
	if not is_instance_valid(footer): return
	var height := clampf(body.get_combined_minimum_size().y, 96.0, MAX_BODY_HEIGHT)
	scroll.size = Vector2(BODY_WIDTH, height)
	var next_y := BODY_TOP + height + 20.0
	effects.position = Vector2(34, next_y)
	if effects.get_child_count() > 0: next_y += 52.0
	footer.position = Vector2(34, next_y)
	footer.text = "滚轮滚动描述 · 点击描述外或按 Esc 关闭" if body.get_combined_minimum_size().y > MAX_BODY_HEIGHT else "点击任意位置或按 Esc 关闭"
	pane.size = Vector2(PANE_WIDTH, next_y + 32.0 + 28.0)
	pane.position = (size - pane.size) * 0.5

func _input(event: InputEvent) -> void:
	var dismiss := event.is_action_pressed("ui_cancel")
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var point: Vector2 = scroll.get_global_transform_with_canvas().affine_inverse() * event.position
		# Wheel/scrollbar input belongs to the description, not the modal close action.
		if scroll.get_v_scroll_bar().visible and Rect2(Vector2.ZERO, scroll.size).has_point(point): return
		dismiss = true
	if dismiss:
		get_viewport().set_input_as_handled()
		# Stop the release event from selecting the card behind the popup.
		hide()
		queue_free()
