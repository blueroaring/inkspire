extends Control
## Out-of-battle reference pages use the same definitions and art as the archive.
const T := preload("res://scripts/ui/battle_theme.gd")
const V := preload("res://scripts/ui/fc_card_visuals.gd")
const M := preload("res://scripts/ui/battle_management_ui.gd")
var page := "attributes"
var hero_id := "zhoumingyuan"
var read_only := false

func _ready() -> void:
	name = "CharacterReference"
	size = Vector2(1792, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	match page:
		"attributes":
			var chart := preload("res://scripts/ui/battle_attribute_chart.gd").new()
			chart.position = Vector2(124, 46)
			chart.size = Vector2(1544, 600)
			var attribute := FightSystem.current_attribute(hero_id)
			if FightData.ADVANTAGE.has(attribute): chart.selected_attribute = attribute
			add_child(chart)
			V.text(self, "与战斗中的克制图一致 · 点击学科查看对应关系", Rect2(124, 669, 1544, 32), 19, T.MUTED, true)
		"items": _items()
		"effects": _effects()
		"bestiary":
			var bestiary := preload("res://scripts/ui/enemy_bestiary.gd").new()
			bestiary.size = size
			add_child(bestiary)

func _items() -> void:
	var supplies := preload("res://scripts/ui/battle_equipment_panel.gd").new()
	supplies.mode = "supplies"
	supplies.read_only = read_only
	add_child(supplies)

func _effects() -> void:
	var guide := preload("res://scripts/ui/battle_mechanics.gd").new()
	guide.position = Vector2(24, 0)
	guide.size = Vector2(1744, 696)
	add_child(guide)
