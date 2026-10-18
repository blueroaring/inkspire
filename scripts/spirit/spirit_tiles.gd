class_name SpiritTiles
extends RefCounted
## 灵境格子规则与显示资料；水汽为附加状态，不覆盖格子本来的机关。

const DIRECTIONS := [Vector3i(0, -1, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(-1, 0, 0)]
const ARROWS := ["↑", "→", "↓", "←"]
const NAMES := {
	"void": "空地板", "floor": "地板", "wall": "障碍物", "key": "钥匙", "exit": "出口大门",
	"jump": "朝向跳跃", "jump_fixed": "定向跳跃", "portal": "传送", "fire": "火焰", "trap": "陷阱", "slide": "持续行走",
	"flight": "飞行", "pickup": "神经通路补给", "fragile": "脆弱地板", "rewind": "回溯机关",
	"hidden": "隐形地板", "random": "游移地板", "switch": "地形开关", "buff": "强化",
	"spike": "刺发射器", "trigger": "刺机关开关", "water": "水", "electric": "导电格",
	"generator": "发电机", "evaporate": "蒸发", "reservoir": "蓄水", "steam": "蒸汽", "turn": "转向",
	"plate": "重力压板", "gate": "联动门",
}
const SYMBOLS := {
	" ": "void", ".": "floor", "S": "floor", "#": "wall", "K": "key", "E": "exit",
	"J": "jump", "j": "jump_fixed", "P": "portal", "F": "fire", "X": "trap", "I": "slide", "A": "flight",
	"B": "pickup", "C": "fragile", "R": "rewind", "H": "hidden", "?": "random", "T": "switch",
	"+": "buff", "^": "spike", "!": "trigger", "W": "water", "Z": "electric", "G": "generator",
	"V": "evaporate", "O": "reservoir", "U": "steam", ">": "turn",
	"p": "plate", "g": "gate",
}
const GLYPHS := {
	"void": "", "floor": "", "wall": "■", "key": "钥", "exit": "门", "jump": "跃", "portal": "传",
	"jump_fixed": "向", "fire": "火", "trap": "陷", "slide": "滑", "flight": "翼", "pickup": "路", "fragile": "裂",
	"rewind": "溯", "hidden": "隐", "random": "移", "switch": "改", "buff": "强", "spike": "刺",
	"trigger": "射", "water": "水", "electric": "电", "generator": "机", "evaporate": "干",
	"reservoir": "流", "steam": "汽", "turn": "转",
	"plate": "压", "gate": "闸",
}
const BRIDGES := {
	"single": {"name": "单格 · 临时", "shape": [Vector2i(0, 0)], "temporary": true},
	"line": {"name": "直线二格 · 永久", "shape": [Vector2i(0, 0), Vector2i(1, 0)], "temporary": false},
	"corner": {"name": "折角三格 · 永久", "shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)], "temporary": false},
}

static func bridge_shape(id: String, rotation: int = 0) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset: Vector2i in BRIDGES.get(id, {}).get("shape", []):
		for turn in posmod(rotation, 4): offset = Vector2i(-offset.y, offset.x)
		cells.append(offset)
	return cells

static func tint(kind: String) -> Color:
	match kind:
		"void": return Color("11192b")
		"wall", "spike": return Color("344055")
		"fire", "trap", "electric", "trigger": return Color("873e55")
		"water", "reservoir", "portal": return Color("225d7b")
		"key", "exit", "buff", "generator": return Color("786440")
		"rewind", "hidden", "random": return Color("57497c")
		"flight", "pickup", "switch": return Color("32655f")
		"plate", "gate": return Color("387d86")
		_: return Color("304259")

static func description(tile: Dictionary) -> String:
	match String(tile.get("kind", "void")):
		"floor": return "普通地板，可以安全站立。"
		"void": return "踏入会坠落。可铺神经通路，也可能藏有隐形地板。"
		"wall": return "无法步行穿过；可跳越或飞过。"
		"key": return "用于开启门锁。"
		"exit": return "持有所需钥匙后踏入，即可通关。"
		"jump": return "沿角色朝向跳跃 %d 格，不额外消耗步数。" % int(tile.get("distance", 2))
		"jump_fixed":
			if tile.has("target"): return "跳至第 %d 层的固定落点，不额外消耗步数。" % (int(tile["target"].z) + 1)
			return "固定向 %s 跳跃 %d 格，不受角色朝向影响。" % [ARROWS[int(tile.get("direction", 1))], int(tile.get("distance", 2))]
		"portal": return "踏入即传送至指定位置，可以跨层。"
		"fire": return "伤害角色与怪物。伤害：%s" % (str(tile["damage"]) if tile.has("damage") else "致命")
		"trap": return "踩中坠落，本次尝试失败。"
		"slide": return "沿 %s 持续行走，遇阻停下，沿途机关仍生效。" % (ARROWS[int(tile["direction"])] if tile.has("direction") else "当前朝向")
		"flight": return "接下来数格忽略地形与机关，仍会遇敌；结束时必须落在可站立处。"
		"pickup": return "获得指定形状的神经通路；通关后剩余数量进入背包。"
		"fragile": return "离开后坍塌；临时神经通路也遵守此规则。"
		"rewind": return "站在这里按 Q，让附近的地形回到过去或现在。每次使用消耗一次回溯机会。"
		"hidden": return "只会显现一小会儿。记住位置，看不见后仍然能走上去。"
		"random": return "每次移动后切换位置。"
		"switch": return "永久改变指定区域；只有整关重置能还原。"
		"buff": return "获得一次减伤护盾，怪物也能获得。"
		"spike": return "蓄能后缓慢射出低空飞刺，命中首个地面目标后消失。墙和关闭的门会阻挡；飞行状态可从上方越过。"
		"trigger": return "踩下后启动飞刺发生器。飞刺会沿箭头方向飞出，击中目标后消失。"
		"water": return "走过会沾湿；相邻水格能够传导电击。"
		"electric": return "踩上后向相连的水路送电。身上沾湿时会触电，先烘干再来。"
		"generator": return "发电机 · %s。机身挡路，需要从旁边绕过。通过水路送电后，能照亮附近的停电区域。" % ("已启动" if tile.get("powered", false) else "未供电")
		"evaporate": return "沾湿时安全并消除水汽；干燥时受到伤害。"
		"reservoir": return "踩上后沿面朝的方向放水，箭头可以让水转弯。水能熄火，也能散去蒸汽。"
		"steam": return "踩上后沿面朝的方向喷汽，遇到箭头会转弯。蒸汽能蒸干积水，也能点燃另一个喷口。"
		"turn": return "强制并锁定朝向 %s；也会将水流和蒸汽转向此方向。" % ARROWS[int(tile.get("direction", 1))]
		"plate": return "压板 %s · %s。站在上面就能打开对应的门，怪物也能帮忙踩住。" % [tile.get("channel", "A"), "已压下" if tile.get("pressed", false) else "未压下"]
		"gate": return "%s · 需要压板 %s 同时压下。%s" % ["已开启" if tile.get("open", false) else "已关闭",
			" + ".join(tile.get("channels", [tile.get("channel", "A")])),
			"打开后就不会再关上。" if tile.get("latch", false) else "压板松开后会关闭。有人正在通过时，会等人离开再关门。"]
		_: return "普通地板，可以安全站立。"
