extends RefCounted
## Shared identity and rules for effects granted by different enemies, cards and items.
const ALIASES := {"labor":"weakness", "item_smoke":"weakness", "finale_stun":"stun"}
const DEFINITIONS := {
	"weakness":{"name":"虚弱", "desc":"造成的普通伤害降低25%；重复施加只延长持续回合，不叠加减伤幅度。", "debuff":true, "damage_out_mult":0.75},
	"shiver":{"name":"颤栗", "desc":"受到的普通伤害提高50%；重复施加只延长持续回合。", "debuff":true, "damage_taken_mult":1.5},
	"fragile":{"name":"脆弱", "desc":"每层使获得的护盾降低15%，最低为0；不自然消退，每次净化移除1层。", "debuff":true, "cleanse_one":true},
	"stun":{"name":"眩晕", "desc":"我方无法主动释放技能或终结技；敌方跳过行动。可净化。", "debuff":true, "control":true},
	"debuff_immunity":{"name":"负面免疫", "desc":"每层抵挡一次负面效果施加；同次同名的多层效果只消耗1层。", "debuff":false},
	"poison_guard":{"name":"个人临时护盾", "desc":"本轮敌方行动结束后消失；在共享护盾之后、个人常驻护盾之前抵挡伤害。", "debuff":false},
	"resilience":{"name":"坚毅", "desc":"每层抵挡一次致命伤害、违纪处决或虚无离场；抵挡处决或虚无时清除对应标记或虚无。", "debuff":false}
}

## Status-box naming. Buffs and debuffs keep the classic captions; marks, rules,
## counters and temporary special states are neither and must not pose as buffs.
const CAPTIONS := {
	"buff": "增 益 状 态",
	"debuff": "负 面 状 态",
	"mark": "标 记",
	"rule": "战 斗 规 则",
	"passive": "被 动",
	"counter": "计 数",
	"special": "特 殊 状 态",
	"role": "角 色 状 态",
}
## Neutral bookkeeping is excluded from dispel/cleanse. Phase persistence is
## a separate explicit status property, never implied by this category.
const NEUTRAL_CATEGORIES := ["mark", "rule", "passive", "counter", "special", "role"]

static func category(status: Dictionary) -> String:
	var explicit := String(status.get("category", ""))
	if CAPTIONS.has(explicit): return explicit
	if String(status.get("icon", "")) in ["dead", "downed"]: return "role"
	return "debuff" if bool(status.get("debuff", false)) else "buff"

static func caption(status: Dictionary) -> String:
	return String(CAPTIONS.get(category(status), "状 态"))

static func neutral(status: Dictionary) -> bool:
	return category(status) in NEUTRAL_CATEGORIES

static func is_buff(status: Dictionary) -> bool:
	return category(status) == "buff"

static func is_debuff(status: Dictionary) -> bool:
	return category(status) == "debuff"

static func canonical(id: String) -> String:
	return String(ALIASES.get(id, id))

static func definition(id: String, data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	result.merge(DEFINITIONS.get(canonical(id), {}), true)
	return result

static func apply_debuff(unit: Dictionary, id: String, data: Dictionary) -> void:
	id = canonical(id)
	data = definition(id, data)
	if id == "stun" and unit.has("intent"): data.tick_on_action = true
	# Duration is supplied as the newly added amount by every source.
	if id in ["weakness", "shiver"]:
		var turns := int(data.get("turns", 1))
		for old_id in unit.statuses.keys():
			if canonical(String(old_id)) != id: continue
			var old_turns := int(unit.statuses[old_id].get("turns", 0))
			turns = -1 if turns < 0 or old_turns < 0 else turns + old_turns
			unit.statuses.erase(old_id)
		data.turns = turns
	data.debuff = true
	unit.statuses[id] = data

static func grant_ward(unit: Dictionary, amount: int, temporary: bool) -> void:
	var ward: Dictionary = unit.statuses.get("cleanseable_immunity", {"stacks":0, "temporary_stacks":0})
	ward.stacks = int(ward.stacks) + amount
	if temporary: ward.temporary_stacks = int(ward.temporary_stacks) + amount
	unit.statuses.cleanseable_immunity = ward
	update_ward(unit)

static func update_ward(unit: Dictionary) -> void:
	var ward: Dictionary = unit.statuses.cleanseable_immunity
	if int(ward.stacks) <= 0:
		unit.statuses.erase("cleanseable_immunity")
		return
	ward.name = "可净化负面免疫"
	ward.desc = "每层抵挡一次可净化负面状态；不抵挡不可净化效果。优先消耗临时层数。"
	if int(ward.temporary_stacks) > 0: ward.desc += "其中%d层在本轮敌方行动结束后消失。" % int(ward.temporary_stacks)
	ward.turns = 1 if int(ward.stacks) == int(ward.temporary_stacks) else -1
	ward.debuff = false
	ward.fc_after_enemy = true

static func consume_ward(unit: Dictionary) -> bool:
	if not unit.statuses.has("cleanseable_immunity"): return false
	var ward: Dictionary = unit.statuses.cleanseable_immunity
	ward.stacks -= 1
	ward.temporary_stacks = maxi(0, int(ward.temporary_stacks) - 1)
	update_ward(unit)
	return true

static func expire_ward(unit: Dictionary) -> void:
	if not unit.statuses.has("cleanseable_immunity"): return
	var ward: Dictionary = unit.statuses.cleanseable_immunity
	ward.stacks -= int(ward.temporary_stacks)
	ward.temporary_stacks = 0
	update_ward(unit)

static func skip_action(unit: Dictionary) -> bool:
	if not unit.statuses.has("stun"): return false
	var status: Dictionary = unit.statuses.stun
	status.turns = int(status.get("turns", 1)) - 1
	if int(status.turns) <= 0: unit.statuses.erase("stun")
	return true
