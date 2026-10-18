extends TextureRect
## Resolve cosmetics live so changing style inside the battle archive also updates HUD/cards.
var hero_id := ""
var attribute := ""
var source_card: Dictionary = {}
var form_portrait := "":
	set(value):
		form_portrait = value
		if is_node_ready(): _refresh()
var living_portrait: Control
var interactive_motion := false:
	set(value):
		interactive_motion = value
		if is_node_ready(): _refresh()
var _living_key := ""

func _ready() -> void:
	Settings.setting_changed.connect(_on_setting_changed)
	_refresh()

func _on_setting_changed(section: String, key: String, _value: Variant) -> void:
	if section == "battle" and key == "portrait_styles": _refresh()

func _refresh() -> void:
	var profile := FightData.card_owner(source_card) if not source_card.is_empty() else FightData.hero(hero_id, attribute)
	texture = load(form_portrait if not form_portrait.is_empty() else String(profile.portrait))
	texture_filter = TEXTURE_FILTER_NEAREST if preload("res://scripts/data/battle_portrait_data.gd").is_pixel(texture) else TEXTURE_FILTER_LINEAR
	var phoenix := form_portrait.ends_with("/anya/portrait_phoenix.webp")
	if phoenix or interactive_motion:
		var key := texture.resource_path
		if not is_instance_valid(living_portrait) or _living_key != key:
			if is_instance_valid(living_portrait):
				remove_child(living_portrait)
				living_portrait.queue_free()
			if phoenix: living_portrait = preload("res://scripts/ui/anya_living_portrait.gd").new()
			else:
				living_portrait = preload("res://scripts/ui/battle_living_portrait.gd").new()
				living_portrait.portrait_texture = texture
				living_portrait.profile_key = living_portrait.key_for(hero_id, attribute if not attribute.is_empty() else String(GameState.fight_attributes.get(hero_id, "none")))
				living_portrait.pixel_art = preload("res://scripts/data/battle_portrait_data.gd").is_pixel(texture)
			_living_key = key
			add_child(living_portrait)
			living_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		self_modulate.a = 0
	else:
		self_modulate.a = 1
		if is_instance_valid(living_portrait): living_portrait.queue_free()
		living_portrait = null
		_living_key = ""
