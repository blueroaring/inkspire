class_name SpiritRun
extends RefCounted
## 一次灵境尝试的纯规则状态。外部存档只在通关时提交，重试由入口快照重建。

var level: Dictionary
var cells: Dictionary = {}
var player := Vector3i.ZERO
var facing := 1
var steps := 0
var spent := 0
var quotas: Dictionary = {}
var keys := 0
var hp := 1
var max_hp := 1
var wet := false
var shield := 0
var flight := 0
var rewinds := 0
var bridges: Dictionary = {}
var command_facing := 1 # 角色动画保留上一条主动指令，机关转向仅影响规则 facing。
var enemies: Array = []
var regions: Dictionary = {}
var powered := false
## 一个格子可处于多台发电机的照明范围内；任意一台供电即可照亮重叠部分。
var lighting_zones: Array[Dictionary] = []
var _light_sources: Dictionary = {}
var reveal_hidden := true
var status := "playing"
var message := ""
var trace: Array[Vector3i] = []
var motion_trace: Array[Dictionary] = []
var pending_rewards := {"xp": 0, "money": 0, "fragments": 0}
var turn := 0
## 回合内的连续机关；规则按固定小步推进，画面读取同一位置，不先判整条射线。
var effects: Array[Dictionary] = []
var effect_events: Array[Dictionary] = []
var _effect_serial := 0
var _effect_phase := 0 # 1：等待玩家机关，再轮到怪物；2：等待怪物机关，再检查步数。
var _pending_exit := false
var tutorial_index := 0
var tutorial_entered_turn := 0
var _checkpoint: Dictionary = {}
var _checkpoint_pending := false
const CHECKPOINT_FIELDS := ["cells", "player", "facing", "command_facing", "steps", "spent", "quotas", "keys", "hp", "max_hp", "wet", "shield",
	"flight", "rewinds", "bridges", "enemies", "regions", "powered", "reveal_hidden", "pending_rewards", "turn", "tutorial_index", "tutorial_entered_turn"]

func setup(definition: Dictionary, entry_hp: int, entry_max_hp: int, stock: Dictionary = {}) -> void:
	level = definition.duplicate(true)
	cells = level["cells"].duplicate(true)
	player = level["start"]
	facing = int(level.get("facing", 1))
	command_facing = facing
	steps = int(level["steps"])
	spent = 0
	quotas = level.get("quotas", {}).duplicate(true)
	keys = 0
	max_hp = entry_max_hp
	hp = clampi(entry_hp, 0, max_hp)
	wet = false
	shield = 0
	flight = 0
	rewinds = int(level.get("rewinds", 0))
	bridges = stock.duplicate(true)
	enemies = level.get("enemies", []).duplicate(true)
	for enemy in enemies:
		enemy["name"] = "试卷兽"
		if enemy.get("mode") == "sentry": enemy["home_facing"] = int(enemy.get("facing", 1))
	regions = level.get("regions", {}).duplicate(true)
	powered = false
	_build_lighting_zones()
	reveal_hidden = true
	status = "playing" if hp > 0 else "failed"
	message = "" if hp > 0 else "艾莉娜的生命值不足。"
	trace = [player]
	motion_trace.clear()
	pending_rewards = {"xp": 0, "money": 0, "fragments": 0}
	turn = 0
	effects.clear()
	effect_events.clear()
	_effect_serial = 0
	_effect_phase = 0
	_pending_exit = false
	tutorial_index = 0
	tutorial_entered_turn = 0
	_checkpoint.clear()
	_sync_gates(false)
	_checkpoint_pending = not level.get("tutorial_zones", []).is_empty()
	_save_checkpoint()

func tile_at(pos: Vector3i) -> Dictionary:
	return cells.get(pos, {"kind": "void"})

func kind_at(pos: Vector3i) -> String:
	return String(tile_at(pos).get("kind", "void"))

func inside(pos: Vector3i) -> bool:
	var sizes: Array = level["sizes"]
	return pos.z >= 0 and pos.z < sizes.size() and pos.x >= 0 and pos.y >= 0 and pos.x < sizes[pos.z].x and pos.y < sizes[pos.z].y

func visible_at(pos: Vector3i) -> bool:
	if not inside(pos) or lighting_hidden(pos): return false
	var radius := int(level.get("vision", -1))
	if level.get("follow_camera", false):
		return pos.z == player.z and maxi(absi(pos.x - player.x), absi(pos.y - player.y)) <= radius
	return radius < 0 or (pos.z == player.z and absi(pos.x - player.x) + absi(pos.y - player.y) <= radius)

func _build_lighting_zones() -> void:
	lighting_zones.clear()
	_light_sources.clear()
	for pos: Vector3i in cells:
		if kind_at(pos) != "generator": continue
		var bounds: Rect2i = tile_at(pos).get("light_bounds", Rect2i(Vector2i(pos.x - 3, pos.y - 3), Vector2i(7, 7)))
		lighting_zones.append({"generator": pos, "bounds": bounds})
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				var cell := Vector3i(x, y, pos.z)
				if not inside(cell): continue
				if not _light_sources.has(cell): _light_sources[cell] = []
				_light_sources[cell].append(pos)

func generator_powered(pos: Vector3i) -> bool:
	return kind_at(pos) == "generator" and bool(tile_at(pos).get("powered", false))

func in_darkness(pos: Vector3i) -> bool:
	if not _light_sources.has(pos): return false
	for source: Vector3i in _light_sources[pos]:
		if generator_powered(source): return false
	return true

func lighting_hidden(pos: Vector3i) -> bool:
	return in_darkness(pos) and pos != player and kind_at(pos) not in ["generator", "electric"]

func tutorial_zone() -> Dictionary:
	var zones: Array = level.get("tutorial_zones", [])
	return zones[tutorial_index] if not zones.is_empty() else {}

func _enter_tutorial_zone() -> void:
	var zones: Array = level.get("tutorial_zones", [])
	if tutorial_index + 1 >= zones.size(): return
	var next: Dictionary = zones[tutorial_index + 1]
	if player != next.entry: return
	tutorial_index += 1
	tutorial_entered_turn = turn + 1
	reveal_hidden = bool(next.get("reveal_hidden", false))
	_checkpoint_pending = true

func _save_checkpoint() -> void:
	if not _checkpoint_pending or status != "playing" or effects_busy(): return
	_checkpoint.clear()
	for field in CHECKPOINT_FIELDS:
		var value: Variant = get(field)
		_checkpoint[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	_checkpoint_pending = false

func restore_checkpoint() -> bool:
	if _checkpoint.is_empty(): return false
	for field in CHECKPOINT_FIELDS:
		var value: Variant = _checkpoint[field]
		set(field, value.duplicate(true) if value is Dictionary or value is Array else value)
	status = "playing"
	message = "已回到「%s」入口，先前完成的区域保留。" % tutorial_zone().get("title", "本段")
	effects.clear()
	effect_events.clear()
	motion_trace.clear()
	trace = [player]
	_effect_phase = 0
	_pending_exit = false
	_checkpoint_pending = false
	return true

func display_kind(pos: Vector3i) -> String:
	if lighting_hidden(pos): return "dark"
	if not visible_at(pos): return "fog"
	var kind := kind_at(pos)
	return "void" if kind == "hidden" and not reveal_hidden else kind

func set_facing(direction: int) -> bool:
	if status != "playing" or effects_busy() or direction < 0 or direction > 3: return false
	if kind_at(player) == "turn" and flight <= 0:
		facing = int(tile_at(player).get("direction", 1))
		message = "转向格锁定朝向：%s。" % SpiritTiles.ARROWS[facing]
		if direction == facing: command_facing = direction
		return direction == facing
	facing = direction
	command_facing = direction
	return true

func can_enter(pos: Vector3i, flying: bool = false) -> bool:
	return inside(pos) and (flying or not blocks_at(pos))

func blocks_at(pos: Vector3i) -> bool:
	return kind_at(pos) in ["wall", "spike", "generator"] or (kind_at(pos) == "gate" and not tile_at(pos).get("open", false))

func move(direction: int = -1) -> bool:
	if status != "playing" or effects_busy(): return false
	if direction >= 0 and not set_facing(direction): return false
	var destination: Vector3i = player + SpiritTiles.DIRECTIONS[facing]
	if not can_enter(destination, flight > 0):
		message = "前方无法通行"
		return false
	if steps <= 0 or int(quotas.get(facing, 1)) <= 0:
		message = "该方向的步数已用尽"
		return false
	steps -= 1
	spent += 1
	if quotas.has(facing): quotas[facing] = int(quotas[facing]) - 1
	reveal_hidden = false
	trace = [player]
	motion_trace.clear()
	message = ""
	_travel(destination)
	if status != "playing": return true
	if effects.is_empty(): _finish_turn()
	else: _effect_phase = 1
	return true

func _finish_turn() -> void:
	turn += 1
	_update_random_tiles()
	if status == "playing": _move_enemies()
	_sync_gates()
	if not effects.is_empty():
		_effect_phase = 2
		return
	_check_budget()

func _check_budget() -> void:
	if status == "playing" and steps == 0:
		fail("行动步数用尽，尚未抵达出口。")
	elif status == "playing" and not quotas.is_empty() and not _has_direction_budget():
		fail("四个方向的行动次数已用尽。")
	_save_checkpoint()

func _has_direction_budget() -> bool:
	for direction in 4:
		if int(quotas.get(direction, 1)) > 0: return true
	return false

func _leave_tile() -> void:
	var old := tile_at(player)
	if old.get("kind") == "fragile" or bool(old.get("temporary", false)):
		effect_events.append({"kind": "collapse", "effect": "fragile", "pos": player})
		cells[player] = {"kind": "void"}

func _travel(destination: Vector3i) -> void:
	var sliding := false
	var travel_kind := "fly" if flight > 0 else "walk"
	# 传送/转向/滑行环不会挂死游戏；失败可完整重试。
	for chain_index in maxi(64, cells.size() * 4):
		if not can_enter(destination, flight > 0):
			if not sliding: fail("机关的落点被障碍挡住。")
			return
		var motion := {"from": player, "to": destination, "kind": travel_kind,
			"air_before": flight > 0, "air_after": flight > 0,
			"from_tile": tile_at(player).duplicate(true), "to_tile": tile_at(destination).duplicate(true)}
		motion_trace.append(motion)
		_leave_tile()
		player = destination
		trace.append(player)
		_enter_tutorial_zone()
		_sync_gates()
		if _contact_enemy(): return
		var tile := tile_at(player)
		var kind := kind_at(player)
		if flight > 0:
			flight -= 1
			_sync_gates()
			motion["air_after"] = flight > 0
			if flight == 0 and (kind in ["void", "wall", "spike", "trap"] or blocks_at(player)):
				motion["air_after"] = true
				fail("飞行结束时没有可以落脚的地板。")
			return
		if kind in ["void", "trap"]:
			fail("艾莉娜掉下去了。")
			return
		if kind == "water" or bool(tile.get("water", false)):
			wet = true
			effect_events.append({"kind": "activate", "effect": "water", "pos": player})
		if kind in ["fire", "evaporate", "switch", "trigger"]:
			effect_events.append({"kind": "activate", "effect": kind, "pos": player})
		match kind:
			"key":
				keys += int(tile.get("count", 1))
				cells[player] = {"kind": "floor"}
				message = "钥匙 +1"
			"exit":
				if bool(tile.get("requires_power", false)) and not powered:
					message = "门锁未通电"
					return
				var required := int(tile.get("keys", level.get("required_keys", 1)))
				if keys >= required:
					if tile.has("target"):
						keys -= required
						destination = tile["target"]
						travel_kind = "portal"
						continue
					if effects.is_empty():
						status = "won"
						message = "通关。"
					else: _pending_exit = true
					return
				message = "钥匙不足（%d / %d）" % [keys, required]
			"pickup":
				var id := String(tile.get("bridge", "single"))
				bridges[id] = int(bridges.get(id, 0)) + int(tile.get("count", 1))
				cells[player] = {"kind": "floor"}
				message = "获得%s。" % SpiritTiles.BRIDGES[id]["name"]
			"fire": _hurt(int(tile.get("damage", max_hp)))
			"electric":
				if wet: _hurt(int(tile.get("damage", 8)))
				_electrify(tile.get("source", player), int(tile.get("damage", 8)), true)
			"evaporate":
				if wet: wet = false
				else: _hurt(int(tile.get("damage", 6)))
			"buff":
				shield += int(tile.get("amount", 6))
				cells[player] = {"kind": "floor"}
			"flight":
				flight = int(tile.get("distance", 3))
				motion["air_after"] = flight > 0
			"turn": facing = int(tile.get("direction", 1))
			"rewind": message = "可使用时序回溯"
			"switch":
				_change_terrain(tile.get("changes", {}), player, "switch")
				if tile.has("electric_source"): _electrify(tile["electric_source"], int(tile.get("damage", 8)))
			"trigger":
				for emitter in tile.get("emitters", []): _spike_ray(emitter)
			"reservoir": _flow(player, facing, false)
			"steam": _flow(player, facing, true)
		_sync_gates()
		if status != "playing": return
		# 变地形可能把操作者脚下的地板一起移走。
		if kind_at(player) in ["void", "trap"]:
			fail("机关改变了脚下的地形。")
			return
		if kind in ["jump", "jump_fixed"]:
			if kind == "jump_fixed": facing = int(tile.get("direction", 1))
			destination = player + SpiritTiles.DIRECTIONS[facing] * int(tile.get("distance", 2))
			if kind == "jump_fixed": destination = tile.get("target", destination)
			travel_kind = "jump"
			continue
		if kind == "portal":
			destination = tile.get("target", player)
			travel_kind = "portal"
			continue
		if kind == "slide":
			sliding = true
			if tile.has("direction"): facing = int(tile["direction"])
		if sliding:
			destination = player + SpiritTiles.DIRECTIONS[facing]
			travel_kind = "slide"
			if not can_enter(destination): return
			continue
		return
	fail("机关陷入循环。")

func fail(reason: String) -> void:
	status = "failed"
	message = reason

func _hurt(damage: int) -> void:
	var absorbed := mini(shield, damage)
	shield -= absorbed
	hp = maxi(0, hp - damage + absorbed)
	message = "受到 %d 点伤害。" % (damage - absorbed)
	if hp == 0: fail("艾莉娜的生命值归零。")

func rewind_region() -> bool:
	if status != "playing" or effects_busy(): return false
	var tile := tile_at(player)
	if tile.get("kind") != "rewind":
		message = "当前位置无法回溯"
		return false
	if rewinds <= 0:
		message = "回溯次数已用尽"
		return false
	var id := String(tile.get("region", ""))
	if not regions.has(id): return false
	var region: Dictionary = regions[id]
	var active := not bool(region.get("active", false))
	var patch: Dictionary = region["past"] if active else region["present"]
	_change_terrain(patch, player, "rewind")
	region["active"] = active
	rewinds -= 1
	message = "已回到过去" if active else "已回到现在"
	if kind_at(player) in ["void", "trap", "wall"]: fail("回溯使脚下失去了落脚点。")
	for enemy in enemies:
		if int(enemy.get("hp", 1)) > 0: _enemy_land(enemy)
	_sync_gates()
	return true

func _change_terrain(patch: Dictionary, source: Vector3i, effect: String) -> void:
	for pos: Vector3i in patch:
		var before := tile_at(pos).duplicate(true)
		var after: Dictionary = patch[pos].duplicate(true)
		if before == after: continue
		cells[pos] = after
		effect_events.append({"kind": "terrain", "effect": effect, "pos": pos, "source": source,
			"before": before, "after": after.duplicate(true)})

func bridge_cells(id: String, anchor: Vector3i, rotation: int) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if not SpiritTiles.BRIDGES.has(id): return result
	for offset: Vector2i in SpiritTiles.bridge_shape(id, rotation):
		result.append(anchor + Vector3i(offset.x, offset.y, 0))
	return result

func can_place_bridge(id: String, anchor: Vector3i, rotation: int) -> bool:
	return bridge_placement_error(id, anchor, rotation).is_empty()

func bridge_placement_error(id: String, anchor: Vector3i, rotation: int) -> String:
	if status != "playing": return "当前无法铺设"
	if effects_busy(): return "机关正在运行"
	if int(bridges.get(id, 0)) <= 0: return "通路不足"
	if anchor.z != player.z: return "仅限角色所在楼层"
	var footprint := bridge_cells(id, anchor, rotation)
	if footprint.is_empty(): return "尚未选择通路"
	for pos in footprint:
		# 隐形格与空格等价：不提供能探测隐形地板的额外反馈。
		if not inside(pos): return "超出边界"
		if not visible_at(pos): return "超出视野"
		if kind_at(pos) not in ["void", "hidden"] or pos == player: return "位置已被占用"
	return ""

func place_bridge(id: String, anchor: Vector3i, rotation: int) -> bool:
	if not can_place_bridge(id, anchor, rotation):
		message = "此处无法铺设：通路需完整覆盖可见的空格"
		return false
	for pos in bridge_cells(id, anchor, rotation):
		cells[pos] = {"kind": "floor", "built": true, "temporary": SpiritTiles.BRIDGES[id]["temporary"]}
	bridges[id] = int(bridges[id]) - 1
	message = "通路已铺设"
	return true

func _contact_enemy() -> bool:
	for enemy in enemies:
		if int(enemy.get("hp", 1)) > 0 and enemy["pos"] == player:
			var lead := "强敌截断了去路。" if bool(enemy.get("strong", false)) else "遇到了记忆中的怪物。"
			fail(lead + "\n艾莉娜没有攻击能力。")
			return true
	return false

func _update_random_tiles() -> void:
	for group in level.get("random_groups", []):
		if group.has("tutorial_zone") and int(group.tutorial_zone) != tutorial_index: continue
		var positions: Array = group["positions"]
		var local_turn := turn - tutorial_entered_turn if group.has("tutorial_zone") else turn
		var index := (local_turn + int(group.get("offset", 0))) % positions.size()
		for i in positions.size():
			# 已铺的通路不会被随机格删除。
			if not bool(tile_at(positions[i]).get("built", false)):
				cells[positions[i]] = {"kind": "random" if i == index else "void"}
	if kind_at(player) == "void" and flight == 0: fail("脚下的游移地板移开了。")
	for enemy in enemies:
		if int(enemy.get("hp", 1)) > 0 and kind_at(enemy["pos"]) == "void": _defeat_enemy(enemy)

func _move_enemies() -> void:
	for enemy in enemies:
		if int(enemy.get("hp", 1)) <= 0: continue
		if enemy.has("tutorial_zone") and (int(enemy.tutorial_zone) != tutorial_index or turn <= tutorial_entered_turn): continue
		# 慢速敌人也会观察，但仅在自己的行动回合移动。
		var mode := String(enemy.get("mode", "static"))
		if mode in ["sentry", "hunter"]: _observe_enemy(enemy)
		var patrol_turn := turn - tutorial_entered_turn if enemy.has("tutorial_zone") else turn
		if posmod(patrol_turn + int(enemy.get("phase", 0)), maxi(1, int(enemy.get("interval", 1)))) != 0: continue
		var pos: Vector3i = enemy["pos"]
		var destination := pos
		if mode == "patrol":
			var path: Array = enemy.get("path", [])
			if path.size() > 1:
				var index := int(enemy.get("path_index", maxi(0, path.find(pos))))
				var stride := int(enemy.get("path_stride", 1))
				if enemy.get("ping_pong", false) and (index + stride >= path.size() or index + stride < 0): stride = -stride
				var next_index := posmod(index + stride, path.size())
				# 巡逻路径必须相邻；阻挡时保留目标，不隔墙瞬移。
				if path[next_index] - pos in SpiritTiles.DIRECTIONS and can_enter(path[next_index]):
					destination = path[next_index]
					enemy["path_index"] = next_index
					enemy["path_stride"] = stride
		elif mode == "chase" and pos.z == player.z and absi(pos.x - player.x) + absi(pos.y - player.y) <= int(enemy.get("sight", 4)):
			var best := 99999
			for direction in SpiritTiles.DIRECTIONS:
				var next: Vector3i = pos + direction
				var distance := absi(next.x - player.x) + absi(next.y - player.y)
				if can_enter(next) and distance < best:
					best = distance
					destination = next
		elif mode in ["sentry", "hunter"] and enemy.has("target"):
			var path := _enemy_path(enemy, enemy["target"])
			if path.size() > 1: destination = path[1]
		if kind_at(pos) == "turn" and int(enemy.get("flight", 0)) <= 0 and destination != pos:
			destination = pos + SpiritTiles.DIRECTIONS[int(tile_at(pos).get("direction", 1))]
		if destination != pos and can_enter(destination, int(enemy.get("flight", 0)) > 0):
			enemy["facing"] = _direction_between(pos, destination, int(enemy.get("facing", 1)))
			if kind_at(pos) == "fragile" or bool(tile_at(pos).get("temporary", false)):
				effect_events.append({"kind": "collapse", "effect": "fragile", "pos": pos})
				cells[pos] = {"kind": "void"}
			enemy["pos"] = destination
			_sync_gates()
			if _contact_enemy(): return
			_enemy_land(enemy)
		_sync_gates()
		if _contact_enemy(): return

func _observe_enemy(enemy: Dictionary) -> void:
	var sees := false
	if enemy.get("mode") == "sentry":
		sees = player in enemy_sight_cells(enemy)
	else:
		var path := _enemy_path(enemy, player)
		sees = not path.is_empty() and path.size() - 1 <= int(enemy.get("sight", 7))
	if sees:
		enemy["target"] = player
		enemy["alert_left"] = int(enemy.get("memory", 3))
	elif int(enemy.get("alert_left", 0)) > 0:
		enemy["alert_left"] -= 1
	else:
		enemy.erase("target")
		if enemy.get("mode") == "sentry": enemy["facing"] = int(enemy.get("home_facing", enemy.get("facing", 1)))

func enemy_sight_cells(enemy: Dictionary) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var pos: Vector3i = enemy["pos"]
	var direction: Vector3i = SpiritTiles.DIRECTIONS[int(enemy.get("facing", 1))]
	for i in int(enemy.get("sight", 5)):
		pos += direction
		if not inside(pos) or blocks_at(pos): break
		result.append(pos)
	return result

func _enemy_path(enemy: Dictionary, target: Vector3i) -> Array[Vector3i]:
	var start: Vector3i = enemy["pos"]
	if target.z != start.z: return []
	var queue: Array[Vector3i] = [start]
	var previous := {start: start}
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		if current == target:
			var result: Array[Vector3i] = [current]
			while current != start:
				current = previous[current]
				result.push_front(current)
			return result
		for direction: Vector3i in SpiritTiles.DIRECTIONS:
			var next := current + direction
			if previous.has(next) or not can_enter(next): continue
			# 追猎型会绕开已知致命地形；直追型仍可被诱入火焰。
			if kind_at(next) in ["void", "trap", "fire"]: continue
			if kind_at(next) == "electric" and enemy.get("wet", false): continue
			previous[next] = current
			queue.append(next)
	return []

## 压板按实际占用实时结算。已开启的门有人占用时保持开启，离开后再关闭。
func _sync_gates(emit_events: bool = true) -> void:
	var active: Dictionary = {}
	for pos: Vector3i in cells:
		if kind_at(pos) != "plate": continue
		var pressed := player == pos and flight <= 0
		for enemy in enemies:
			if enemy["pos"] == pos and int(enemy.get("hp", 0)) > 0 and int(enemy.get("flight", 0)) <= 0: pressed = true
		if emit_events and bool(cells[pos].get("pressed", false)) != pressed:
			effect_events.append({"kind": "press" if pressed else "release", "effect": "plate", "pos": pos})
		cells[pos]["pressed"] = pressed
		if pressed: active[String(cells[pos].get("channel", "A"))] = true
	for pos: Vector3i in cells:
		if kind_at(pos) != "gate": continue
		var tile: Dictionary = cells[pos]
		var channels: Array = tile.get("channels", [tile.get("channel", "A")])
		var opened := not channels.is_empty()
		for channel in channels:
			if not active.has(String(channel)): opened = false
		if tile.get("latch", false) and opened: tile["latched"] = true
		var occupied := player == pos
		for enemy in enemies:
			if enemy["pos"] == pos and int(enemy.get("hp", 0)) > 0: occupied = true
		# 占用保护只维持已开启的门，不能借飞越未解锁的门凭空开锁。
		opened = opened or bool(tile.get("latched", false)) or (bool(tile.get("open", false)) and occupied)
		if emit_events and bool(tile.get("open", false)) != opened:
			effect_events.append({"kind": "open" if opened else "close", "effect": "gate", "pos": pos})
		tile["open"] = opened

func enemy_description(enemy: Dictionary) -> String:
	var mode := String(enemy.get("mode", "static"))
	var behavior: String = {"static": "守在原地", "patrol": "按标记路线往返" if enemy.get("ping_pong", false) else "按标记路线循环",
		"chase": "近距离直追，可诱入危险地形", "sentry": "只看面朝直线，墙与关闭的门遮挡", "hunter": "沿可走道路索敌，绕开火焰和深坑"}.get(mode, mode)
	var interval := maxi(1, int(enemy.get("interval", 1)))
	var patrol_turn := turn - tutorial_entered_turn if enemy.has("tutorial_zone") else turn
	var until := interval - posmod(patrol_turn + int(enemy.get("phase", 0)), interval)
	var sensing := "\n索敌 %d 格 · 丢失后记忆 %d 回合" % [enemy.get("sight", 7), enemy.get("memory", 3)] if mode in ["hunter", "sentry"] else ""
	return "%s · %s\n%s%s\n生命 %d · %d 回合后行动%s" % [enemy.get("name", "试卷兽"), "强敌" if enemy.get("strong", false) else "普通",
		behavior, sensing, enemy.get("hp", 1), until, " · 正在追踪" if enemy.has("target") else ""]

func _direction_between(from: Vector3i, to: Vector3i, fallback: int) -> int:
	var delta := to - from
	for i in 4:
		if delta == SpiritTiles.DIRECTIONS[i]: return i
	return fallback

func _enemy_damage(enemy: Dictionary, damage: int) -> void:
	var absorbed := mini(int(enemy.get("shield", 0)), damage)
	var remaining := int(enemy.get("hp", 1)) - damage + absorbed
	enemy["shield"] = int(enemy.get("shield", 0)) - absorbed
	if remaining <= 0: _defeat_enemy(enemy)
	else: enemy["hp"] = remaining

func _defeat_enemy(enemy: Dictionary) -> void:
	if int(enemy.get("hp", 0)) <= 0: return
	enemy["hp"] = 0
	pending_rewards["xp"] += int(enemy.get("xp", 15))
	pending_rewards["money"] += int(enemy.get("money", 25))
	pending_rewards["fragments"] += 1
	message = "怪物已被机关击败"

func _enemy_land(enemy: Dictionary) -> void:
	if enemy.has("tutorial_zone") and int(enemy.tutorial_zone) != tutorial_index: return
	var sliding := false
	for i in maxi(64, cells.size() * 4):
		var pos: Vector3i = enemy["pos"]
		var tile := tile_at(pos)
		var kind := kind_at(pos)
		if int(enemy.get("flight", 0)) > 0:
			enemy["flight"] -= 1
			if int(enemy["flight"]) == 0 and (kind in ["void", "trap", "wall", "spike"] or blocks_at(pos)): _defeat_enemy(enemy)
			return
		if kind in ["void", "trap"]:
			_defeat_enemy(enemy)
			return
		if kind == "water" or bool(tile.get("water", false)):
			enemy["wet"] = true
			effect_events.append({"kind": "activate", "effect": "water", "pos": pos})
		if kind in ["fire", "evaporate", "switch", "trigger"]:
			effect_events.append({"kind": "activate", "effect": kind, "pos": pos})
		if kind == "fire": _enemy_damage(enemy, int(tile.get("damage", 999)))
		if kind == "electric":
			# 源格也在导电遍历中，避免对站在源格的怪物重复扣血。
			_electrify(tile.get("source", pos), int(tile.get("damage", 8)))
			if bool(enemy.get("wet", false)) and tile.get("source", pos) != pos:
				_enemy_damage(enemy, int(tile.get("damage", 8)))
		if kind == "evaporate":
			if not bool(enemy.get("wet", false)): _enemy_damage(enemy, int(tile.get("damage", 6)))
			enemy["wet"] = false
		if kind == "buff":
			enemy["shield"] = int(enemy.get("shield", 0)) + int(tile.get("amount", 6))
			cells[pos] = {"kind": "floor"}
		if kind == "flight": enemy["flight"] = int(tile.get("distance", 3))
		if kind in ["turn", "slide"] and tile.has("direction"): enemy["facing"] = int(tile["direction"])
		if kind == "jump_fixed": enemy["facing"] = int(tile.get("direction", 1))
		if kind == "switch":
			_change_terrain(tile.get("changes", {}), pos, "switch")
			if tile.has("electric_source"): _electrify(tile["electric_source"], int(tile.get("damage", 8)))
		if kind == "trigger":
			for emitter in tile.get("emitters", []): _spike_ray(emitter)
		if kind == "reservoir": _flow(pos, int(enemy.get("facing", 1)), false)
		if kind == "steam": _flow(pos, int(enemy.get("facing", 1)), true)
		if int(enemy.get("hp", 0)) <= 0: return
		if kind == "slide": sliding = true
		var next := pos
		if kind == "portal": next = tile.get("target", pos)
		elif kind in ["jump", "jump_fixed"]:
			next = pos + SpiritTiles.DIRECTIONS[int(enemy.get("facing", 1))] * int(tile.get("distance", 2))
			if kind == "jump_fixed": next = tile.get("target", next)
		elif sliding: next = pos + SpiritTiles.DIRECTIONS[int(enemy.get("facing", 1))]
		else: return
		if not can_enter(next): return
		if kind == "fragile" or bool(tile.get("temporary", false)):
			effect_events.append({"kind": "collapse", "effect": "fragile", "pos": pos})
			cells[pos] = {"kind": "void"}
		enemy["pos"] = next
		_sync_gates()
		if next == player and int(enemy.get("hp", 0)) > 0:
			_contact_enemy()
			return
	_defeat_enemy(enemy)

func _conducts(pos: Vector3i) -> bool:
	return kind_at(pos) in ["water", "generator", "electric"] or bool(tile_at(pos).get("water", false))

func _electrify(source: Vector3i, damage: int, player_already_hit: bool = false) -> void:
	var queue: Array[Vector3i] = [source]
	var visited: Dictionary = {}
	var distances := {source: 0}
	var parents := {source: source}
	while not queue.is_empty():
		var pos: Vector3i = queue.pop_front()
		if visited.has(pos) or not inside(pos) or not _conducts(pos): continue
		visited[pos] = true
		effect_events.append({"kind": "electric", "effect": "electric", "pos": pos, "from": parents.get(pos, source), "delay": int(distances.get(pos, 0)) * 0.075})
		if kind_at(pos) == "generator":
			powered = true
			cells[pos]["powered"] = true
			continue # 发电机接收电力，不充当能穿过机身的导电地板。
		if pos == player and wet and not player_already_hit and flight == 0: _hurt(damage)
		for enemy in enemies:
			if enemy["pos"] == pos and int(enemy.get("hp", 1)) > 0 and int(enemy.get("flight", 0)) == 0:
				if kind_at(pos) != "electric" or bool(enemy.get("wet", false)): _enemy_damage(enemy, damage)
		for direction in SpiritTiles.DIRECTIONS:
			var next: Vector3i = pos + direction
			if not distances.has(next):
				distances[next] = int(distances.get(pos, 0)) + 1
				parents[next] = pos
			queue.append(next)

func _spike_ray(emitter: Vector3i) -> void:
	_launch_effect("spike", emitter, int(tile_at(emitter).get("direction", 1)), float(tile_at(emitter).get("speed", 2.2)))

func _flow(source: Vector3i, direction: int, steam: bool) -> void:
	_launch_effect("steam" if steam else "water", source, direction, 2.8 if steam else 2.4)

func effects_busy() -> bool:
	return not effects.is_empty() or _effect_phase != 0

func _launch_effect(kind: String, source: Vector3i, direction: int, speed: float) -> void:
	_effect_serial += 1
	effects.append({"id": _effect_serial, "kind": kind, "source": source, "cell": source,
		"direction": direction, "position": Vector3(source), "progress": 0.0, "age": 0.0,
		"windup": 0.32 if kind == "spike" else 0.16, "speed": clampf(speed, 0.5, 8.0),
		"path": [source], "visited": {}, "finished": false})
	effect_events.append({"kind": "launch", "effect": kind, "pos": source})

## 纯规则入口：实机每帧调用，测试以相同时间步长推进。大帧也不能穿过目标或墙。
func advance_effects(delta: float) -> void:
	if status != "playing": return
	var remaining := maxf(0.0, delta)
	while remaining > 0.0 and not effects.is_empty() and status == "playing":
		var dt := minf(remaining, 1.0 / 60.0)
		remaining -= dt
		for effect in effects:
			_advance_effect(effect, dt)
			if status != "playing": break
		for index in range(effects.size() - 1, -1, -1):
			if effects[index]["finished"]: effects.remove_at(index)
		_sync_gates()
	if status != "playing":
		effects.clear()
		_effect_phase = 0
		return
	if effects.is_empty():
		var phase := _effect_phase
		_effect_phase = 0
		if _pending_exit:
			_pending_exit = false
			status = "won"
			message = "通关。"
		elif phase == 1: _finish_turn()
		elif phase == 2: _check_budget()

func _advance_effect(effect: Dictionary, dt: float) -> void:
	var previous_age := float(effect["age"])
	effect["age"] += dt
	if float(effect["age"]) < float(effect["windup"]): return
	if previous_age < float(effect["windup"]):
		effect_events.append({"kind": "emit", "effect": effect["kind"], "pos": effect["source"]})
	effect["progress"] += dt * float(effect["speed"])
	var pos: Vector3i = effect["cell"]
	var direction: Vector3i = SpiritTiles.DIRECTIONS[int(effect["direction"])]
	var next := pos + direction
	var amount := float(effect["progress"])
	# 关闭中的门或墙也在飞行时读取，不能用发射时缓存的射线穿透。
	if (not inside(next) or blocks_at(next)) and amount >= (0.04 if effect["kind"] == "spike" else 0.45):
		effect["finished"] = true
		effect_events.append({"kind": "blocked", "effect": effect["kind"], "pos": pos})
		return
	effect["position"] = Vector3(pos).lerp(Vector3(next), minf(amount, 1.0))
	# 弹头在模型中心前方约 0.48 格；与实体半径相交时命中，而不是穿过中心才命中。
	if effect["kind"] == "spike" and amount >= 0.28:
		if next == player and flight <= 0:
			effect_events.append({"kind": "impact", "effect": "spike", "pos": next})
			fail("飞刺击中了艾莉娜。\n留意发射器的朝向，利用墙壁或关闭的门避开射线。")
			effect["finished"] = true
			return
		for enemy in enemies:
			if enemy["pos"] == next and int(enemy.get("hp", 0)) > 0 and int(enemy.get("flight", 0)) <= 0:
				_defeat_enemy(enemy)
				effect_events.append({"kind": "impact", "effect": "spike", "pos": next})
				effect["finished"] = true
				return
	if amount < 1.0: return
	effect["cell"] = next
	effect["progress"] -= 1.0
	effect["path"].append(next)
	if effect["kind"] == "spike": return
	var marker := "%s:%d" % [next, effect["direction"]]
	if effect["visited"].has(marker):
		effect["finished"] = true
		return
	effect["visited"][marker] = true
	var tile := tile_at(next).duplicate(true)
	var kind := String(tile["kind"])
	if kind == "turn": effect["direction"] = int(tile.get("direction", 1))
	var steam: bool = effect["kind"] == "steam"
	tile["water"] = not steam
	tile["steam"] = steam
	if steam:
		if kind == "water": tile["kind"] = "floor"
		elif kind == "steam": tile["kind"] = "fire"
	else:
		if kind == "fire":
			tile["kind"] = "steam"
			effect_events.append({"kind": "extinguish", "effect": "fire", "pos": next})
		elif kind == "steam": tile["kind"] = "floor"
	cells[next] = tile
	if next == player and flight == 0: wet = not steam
	for enemy in enemies:
		if enemy["pos"] == next and int(enemy.get("flight", 0)) == 0: enemy["wet"] = not steam
	if steam and kind == "steam":
		# 喷流点燃脚下喷口时立即结算，不能等目标下一次移动才受伤。
		if next == player and flight <= 0: _hurt(int(tile.get("damage", max_hp)))
		for enemy in enemies:
			if enemy["pos"] == next and int(enemy.get("hp", 0)) > 0 and int(enemy.get("flight", 0)) <= 0:
				_enemy_damage(enemy, int(tile.get("damage", 999)))
		effect_events.append({"kind": "impact", "effect": "fire", "pos": next})
	effect_events.append({"kind": "flow", "effect": effect["kind"], "pos": next})
