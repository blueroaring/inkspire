extends SpiritRun
## 留守开门 → 跨岸交接 → 双齿共鸣。两人和机关属于同一份可撤销状态。
var actors: Array[Vector3i] = []
var opened := false
var gate_latched := false
var bridge_latched := false
var actor_facing := [1, 1]
var history: Array[Dictionary] = []
const STARTS := [Vector3i(2, 1, 0), Vector3i(2, 7, 0)]
const HOLD := Vector3i(3, 1, 0)
const LEVER := Vector3i(8, 4, 0)
const RELAY := Vector3i(9, 7, 0)
const CATCH := Vector3i(13, 7, 0)
const ANCHOR := Vector3i(16, 4, 0)
const CROSSING := [Vector3i(10, 4, 0), Vector3i(11, 4, 0)]
const FAR_GATE := Vector3i(14, 4, 0)
const PLATES := [Vector3i(15, 7, 0), Vector3i(17, 7, 0)]
const DOOR := Vector3i(18, 4, 0)
const GATES := [Vector3i(6, 3, 0), Vector3i(6, 5, 0)]
const SOLUTION := [[0,"D"], [1,"DDDDWWWDD"], [1,"DSSS"],
	[0,"DDDSSSDDDDDDDSSS"], [1,"WWWDDDDDDD"], [1,"DSSS"],
	[0,"WWWDDSSS"], [1,"WWWD"], [0,"WWWDDD"]]

static func definition() -> Dictionary:
	var l := SpiritLevels._make("clinic-key", "过去的钥匙", "双人时序回溯", [[
		"                    ",
		" ......             ",
		" .    .             ",
		" .    .             ",
		" .    ............. ",
		" .    .  .   . . .  ",
		" .    .  .   . . .  ",
		" ......  .   . . .  ",
		"                    ",
	]], 76, "两人都抵达出口。", "")
	l.start = STARTS[0]
	l["cooperative"] = true
	l["room_style"] = "clinic"
	l["required_keys"] = 0
	l["clear_reward"] = {"xp": 0, "money": 0, "fragments": 0}
	for pair in [[HOLD,"A"],[RELAY,"B"],[CATCH,"C"],[PLATES[0],"D"],[PLATES[1],"E"]]:
		l.cells[pair[0]] = {"kind":"plate", "channel":pair[1]}
	for pos in GATES: l.cells[pos] = {"kind":"gate", "channel":"A"}
	l.cells[FAR_GATE] = {"kind":"gate", "channel":"C"}
	for pos in CROSSING: l.cells[pos] = {"kind":"void"}
	l.cells[LEVER] = {"kind":"switch", "channel":"A"}
	l.cells[ANCHOR] = {"kind":"switch", "channel":"C"}
	l.cells[DOOR] = {"kind":"exit"}
	l["hints"] = [
		"① 艾莉娜向右站在 A 上。周明远沿钥匙环下侧走到中轴，触碰金色锁扣，让 A 门保持开启。",
		"② 周明远走到第一根长齿末端 B，升起断桥。艾莉娜过桥后走到 C：由她接替支撑，同时打开右侧闸门。",
		"③ C 上的人先别动。另一人离开 B、过桥穿过 C 门，触碰右侧锁扣，固定断桥与闸门。",
		"④ 两人分别走到 D、E 两根钥匙齿末端。共鸣打开出口后，再依次回到中轴，走进最右侧的门。Q 可撤销上一步。"]
	return l

func setup(def: Dictionary, entry: int, maximum: int, stock: Dictionary = {}) -> void:
	actors.assign(STARTS)
	opened = false
	gate_latched = false
	bridge_latched = false
	actor_facing = [1,1]
	history.clear()
	super.setup(def, maxi(1, entry), maxi(1, maximum), stock)
	_sync_coop()
	message = ""

func phase() -> int:
	if opened: return 4
	if bridge_latched: return 3
	if gate_latched: return 2
	return 1

func move_actor(index: int, direction: int) -> bool:
	if index not in [0,1] or direction < 0 or direction > 3 or status != "playing": return false
	var destination: Vector3i = actors[index] + SpiritTiles.DIRECTIONS[direction]
	if not cells.has(destination) or kind_at(destination) in ["void","wall"]:
		message = "断桥尚未升起。" if destination in CROSSING else "无法通行。"
		return false
	if destination in GATES and not (gate_latched or actors.has(HOLD)):
		message = "A 门未开启。"
		return false
	if destination == FAR_GATE and not (bridge_latched or actors.has(CATCH)):
		message = "C 门未开启。"
		return false
	if destination == actors[1-index] and destination != DOOR:
		message = "同伴占据此格。"
		return false
	if destination == DOOR and not opened:
		message = "出口未开启。"
		return false
	if not bridge_latched and actors[index] in [RELAY,CATCH] and actors[1-index] in CROSSING:
		message = "同伴仍在桥上。"
		return false
	history.append({"actors":actors.duplicate(), "facing":actor_facing.duplicate(),
		"gate":gate_latched, "bridge":bridge_latched, "opened":opened, "message":message})
	var was_opened := opened
	var was_gate_latched := gate_latched
	var was_bridge_latched := bridge_latched
	actors[index] = destination
	actor_facing[index] = direction
	command_facing = actor_facing[0]
	facing = command_facing
	player = actors[0]
	steps -= 1
	spent += 1
	turn += 1
	_sync_coop()
	if actors[0] == DOOR and actors[1] == DOOR and opened:
		status = "won"
		message = "两人都抵达了出口。医务室钥匙的回忆已复制。"
	elif steps <= 0: fail("步数用尽。Q 撤销 / R 重试。")
	elif opened and not was_opened: message = "出口已开启。"
	elif bridge_latched and not was_bridge_latched: message = "断桥与 C 门已固定。"
	elif gate_latched and not was_gate_latched: message = "A 门已固定。"
	else: message = ""
	return true

func undo() -> bool:
	if history.is_empty() or status == "won": return false
	var before: Dictionary = history.pop_back()
	actors.assign(before.actors)
	actor_facing = before.facing
	gate_latched = before.gate
	bridge_latched = before.bridge
	opened = before.opened
	player = actors[0]
	command_facing = actor_facing[0]
	facing = command_facing
	steps += 1
	spent -= 1
	turn -= 1
	status = "playing"
	message = "已撤销。"
	_sync_coop()
	return true

func _sync_coop() -> void:
	if actors.has(LEVER): gate_latched = true
	if actors.has(ANCHOR): bridge_latched = true
	if bridge_latched and actors.has(PLATES[0]) and actors.has(PLATES[1]): opened = true
	for pos in GATES: cells[pos]["open"] = gate_latched or actors.has(HOLD) or actors.has(pos)
	cells[FAR_GATE]["open"] = bridge_latched or actors.has(CATCH) or actors.has(FAR_GATE)
	for pos in CROSSING:
		cells[pos] = {"kind":"floor" if bridge_latched or actors.has(RELAY) or actors.has(CATCH) else "void", "bridge_piece":true}
	for pos in [HOLD, RELAY, CATCH, PLATES[0], PLATES[1]]: cells[pos]["pressed"] = actors.has(pos)
	cells[LEVER]["active"] = gate_latched
	cells[ANCHOR]["active"] = bridge_latched
	cells[DOOR]["open"] = opened
